local RouterRegister = {}
RouterRegister.__index = RouterRegister

local Terminal = require "router.activities.terminal"
local FileManager = require "router.activities.fileManager.fileManager"
local Sensors = require "router.activities.sensors.sensors"
local Ping = require "router.activities.ping"
local LuaShell = require "router.activities.shell.shell"

function RouterRegister:new(router, mailbox, paths)
    local obj = {
        router = router,
        mailbox = mailbox,
        paths = paths
    }
    setmetatable(obj, self)
    return obj
end

function RouterRegister:getPathsForActivity(activity, paths)
    local type = activity.type
    local activityPaths = paths.activityPaths[type]
    activityPaths.real = paths.real
    activityPaths.quickapp = paths.quickapp

    return activityPaths
end

function RouterRegister:registerAll()
    -- Terminal
    local terminal = Terminal:new(self.mailbox)
    local terminalPaths = self:getPathsForActivity(terminal, self.paths)
    terminal:setPaths(terminalPaths)
    self.router:register(terminal.type, function(request)
        return terminal:run(request)
    end)
    self.terminal = terminal

    -- File manager
    local fileManager = FileManager:new(self.mailbox)
    self.router:register(fileManager.type, function(request)
        return fileManager:handle(request)
    end)

    -- Sensors
    local sensors = Sensors:new(self.mailbox)
    local sensorsPaths = self:getPathsForActivity(sensors, self.paths)
    sensors:setPaths(sensorsPaths)
    self.router:register(sensors.type, function(request)
        return sensors:handle(request)
    end)
    self.sensors = sensors

    -- Ping
    local ping = Ping:new(self.mailbox)
    self.router:register(ping.type, function(request)
        return ping:ping(request)
    end)

    -- Lua shell
    local shell = LuaShell:new(self.mailbox)
    self.router:register(shell.type, function(request)
        return shell:execute(request)
    end)
end

function RouterRegister:clean()
    self.terminal:clean()
    self.sensors:clean()
end

return RouterRegister