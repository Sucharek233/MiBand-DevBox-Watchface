local Sensors = {}
Sensors.__index = Sensors

local SensorProvider = require "router.activities.sensors.sensorProvider"
local sensorInfo = require "router.activities.sensors.sensorInfo"

local handlers = {
    list = {
        run = function(self, _)
            return MailboxStates.DONE, sensorInfo.getAvailableSensors()
        end
    },

    listPre = {
        run = function(self, _)
            return MailboxStates.DONE, sensorInfo.getAvailablePredefinedSensors()
        end
    },

    sub = {
        required = {
            sensor = "string"
        },
        optional = {
            provider = {
                type = "string",
                default = "file"
            },
            useKnown = {
                type = "boolean",
                default = true
            },
            dataPollPeriod = {
                type = "number",
                default = 80
            },
            streamEntries = {
                type = "number",
                default = 10
            },
            sendInterval = {
                type = "number",
                default = 1000
            }
        },

        run = function(self, args)
            local state, result = self:subscribe(args)

            return state, result
        end
    },

    unsub = {
        run = function(self, _)
            return self:unsubscribe()
        end
    }
}

function Sensors:new(mailbox)
    local obj = {
        type = "sensorsLua",
        mailbox = mailbox,
        paths = nil,
        quickappOutputFile = nil,

        activeSensor = {
            obj = nil,
            provider = nil,
            known = false
        },
        buffer = {},

        flushTimer = nil,
        flushTimerPeriod = 1000, -- 1 second 
        maxCapPerFlush = 10,
    }

    setmetatable(obj, self)
    return obj
end

function Sensors:setPaths(paths)
    self.paths = paths

    self.quickappOutputFile = self.paths.quickapp .. "/" .. self.paths.outputFile
end

--- ------------------------------
--- Here lies subscription parsing
--- -------------------------------

local function sanitizeForJSON(val)
    local t = type(val)
    
    if t == "userdata" or t == "cdata" then
        return tostring(val)
    elseif t == "table" then
        local cleanTable = {}
        for k, v in pairs(val) do
            if not IsNaN(v) then
                local cleanKey = (type(k) == "userdata") and tostring(k) or k
                cleanTable[cleanKey] = sanitizeForJSON(v)
            end
        end
        return cleanTable
    else
        return val
    end
end

local function parseReading(rawReading, provider, props)
    if not rawReading then return nil end

    -- Topic already returns structured data, no need to parse
    if provider == "topic" then
        return rawReading
    end

    -- We don't know the format of these raw readings
    -- The predefined list in sensorInfo helps with this
    local parsedValues = {}

    if props and #props > 0 then
        for i, propName in ipairs(props) do
            -- prop _ means the value is unwanted
            if propName ~= "_" then
                parsedValues[propName] = rawReading.values[i]
            end
        end
    else
        -- Unknown sensor: keep raw values array
        parsedValues = rawReading.values
    end

    return parsedValues
end

-- 
function Sensors:startFlushing()
    if self.flushTimer then return end

    self.flushTimer = lvgl.Timer({
        paused = false,
        period = self.flushTimerPeriod, -- 1 second
        repeat_count = -1,
        cb = function()
            self:flushBufferToFile()
        end
    })
end

function Sensors:stopFlushing()
    if self.flushTimer then
        self.flushTimer:pause()
        self.flushTimer:delete()
        self.flushTimer = nil
    end
    -- Flush remaining data
    self:flushBufferToFile()
end

function Sensors:flushBufferToFile()
    local totalReadings = #self.buffer
    if totalReadings == 0 or not self.paths or not self.paths.outputFile then
        return
    end

    local selectedReadings = {}

    if totalReadings <= self.maxCapPerFlush then
        selectedReadings = self.buffer
    else
        -- Downsample evenly across the accumulated buffer
        local step = totalReadings / self.maxCapPerFlush
        for i = 1, self.maxCapPerFlush do
            local index = math.floor(i * step)
            table.insert(selectedReadings, self.buffer[index])
        end
    end

    local filePath = self.paths.real .. "/" .. self.paths.outputFile
    pcall(function()
        local readingsJSON = JSON.encode(selectedReadings)
        FileOps.write(filePath, readingsJSON)
    end)

    self.buffer = {}
end

function Sensors:subscribe(args)
    if self.activeSensor.obj then
        return MailboxStates.ERROR, "Already subscribed"
    end

    local provider = args.provider
    local sensorName = args.sensor
    local useKnown = args.useKnown
    local period = args.dataPollPeriod
    self.flushTimerPeriod = args.sendInterval
    self.maxCapPerFlush = args.streamEntries

    if not sensorName then
        return MailboxStates.ERROR, "Missing sensor name"
    end

    if not FileOps.fileExistsOld("/dev/uorb/" .. sensorName) then
        return MailboxStates.ERROR, "Sensor not found"
    end

    local props = nil
    if useKnown and provider == "file" then
        local predefined = sensorInfo.getAvailablePredefinedSensors()
        for _, def in pairs(predefined) do
            if def.path == sensorName then
                props = def.props
                break
            end
        end
    end

    local function onSensorData(rawReading)
        local parsed = parseReading(rawReading, provider, props)
        if parsed then
            local parsedSanitized = sanitizeForJSON(parsed)
            table.insert(self.buffer, parsedSanitized)
        end
    end

    local providerObj = SensorProvider:new(sensorName, provider, period, onSensorData)
    providerObj:start()

    self.activeSensor = {
        obj = providerObj,
        provider = provider,
        known = useKnown,
        props = props
    }

    self:startFlushing()

    return MailboxStates.DONE, "Subscribed"
end

function Sensors:unsubscribe()

    if self.activeSensor.obj then
        self.activeSensor.obj:stop()
        self.activeSensor.obj = nil
    else
        return MailboxStates.ERROR, "Not subscribed"
    end

    self.activeSensor.provider = nil
    self.activeSensor.known = false
    self.activeSensor.props = nil

    self:stopFlushing()

    return MailboxStates.DONE, "Unsubscribed"
end

function Sensors:handle(request)
    local args = request.args or {}
    local type = args.type

    local handler = handlers[type]

    local state, result

    if not handler then
        state, result = MailboxStates.ERROR, "Unknown type"
    else
        local valid, err = ArgsValidator.validate(args, handler)

        if not valid then
            state, result = MailboxStates.ERROR, err
        else
            state, result = handler.run(self, args)

            if type == "sub" and state == MailboxStates.DONE then
                request.out = self.quickappOutputFile
            end
        end
    end

    request.args = nil
    request.state = MailboxStates.DONE
    request.appState = state
    request.res = result

    self.mailbox:writeMailbox(request)
end

function Sensors:clean()
    os.remove(self.paths.real .. "/" .. self.paths.outputFile)
end

return Sensors