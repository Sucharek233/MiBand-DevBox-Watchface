local SensorProvider = {}
SensorProvider.__index = SensorProvider

local topic = require("topic")
local lvgl = require("lvgl")

local sensorPath = "/dev/uorb"

local function read_uorb_generic(f)
    local data = f:read("*a")

    if not data or #data < 12 then
        return nil
    end

    -- unpack timestamp (two uint32 little endian)
    local ts_lo, ts_hi = string.unpack("<I4I4", data, 1)
    local timestamp = ts_hi << 32 | ts_lo

    local values = {}
    local i = 9  -- start after timestamp (8 bytes)
    while i <= #data - 3 do
        local val
        val, i = string.unpack("<f", data, i)

        -- check for NaN marker (0x7FC00000)
        if val ~= val then  -- NaN check in Lua
            break
        end

        table.insert(values, val)
    end

    return {timestamp = timestamp, values = values}
end

local function getSensor(sensorName, period, callback)
    local path = sensorPath .. "/" .. sensorName

    local sensor = {}
    sensor.path = path
    sensor.period = period
    sensor.callback = callback
    sensor.file = io.open(path, "rb")
    sensor.started = false

    sensor.timer = lvgl.Timer({
        paused = true,
        period = period,
        repeat_count = -1,
        cb = function()
            if not sensor.started then return end
            -- seek back to start before reading fresh data
            local reading = read_uorb_generic(sensor.file)
            if reading and sensor.callback then
                sensor.callback(reading)
            end
        end
    })

    function sensor:start()
        if self.started then return end
        self.started = true
        self.timer:resume()
    end

    function sensor:stop()
        if not self.started then return end
        self.started = false
        self.timer:pause()

        self.file:close()
        self.file = nil

        self.timer:delete()
    end

    function sensor:changePeriod(newPeriod)
        if self.period == newPeriod then return end

        self.period = newPeriod
        self.timer:set {
            period = newPeriod,
        }
    end

    return sensor
end

-- this function that freezes the band in most cases
local function getSensorTopic(name, period, callback)
    local frequency = 1000 / period

    local sensor = {}
    sensor.sub = nil
    sensor.frequency = frequency

    function sensor:start()
        if self.sub then return end
        
        -- topic callback returns: topicObj, status, values
        self.sub = topic.subscribe(name, function(_, _, values)
            -- the values variable is an array
            -- and the actual values are in the first index
            callback(values[1])
        end)

        self.sub:frequency(frequency)
    end

    function sensor:stop()
        if self.sub then
            self.sub:unsubscribe()
            self.sub = nil
        end
    end

    function sensor:changePeriod(newPeriod)
        local newFrequency = 1000 / newPeriod
        if self.frequency == newFrequency then return end

        self.frequency = newFrequency
        if self.sub then
            self.sub:frequency(newFrequency)
        end
    end

    return sensor
end

function SensorProvider:new(sensorName, mode, period, callback)
    local sensor = nil
    if mode == "file" then
        sensor = getSensor(sensorName, period, callback)
    elseif mode == "topic" then
        sensor = getSensorTopic(sensorName, period, callback)
    else
        error("Invalid mode")
    end

    local obj = {
        sensor = sensor
    }

    setmetatable(obj, self)
    return obj
end

function SensorProvider:start()
    self.sensor:start()
end

function SensorProvider:stop()
    self.sensor:stop()
end

function SensorProvider:changePeriod(newPeriod)
    self.sensor:changePeriod(newPeriod)
end

return SensorProvider