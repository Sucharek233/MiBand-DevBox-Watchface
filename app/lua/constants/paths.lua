local Paths = {}
Paths.__index = Paths

local fileOps = require("helpers.fileOperations")

local basePaths = {
    -- this was made mainly because the emulator and band 10 have different paths
    -- and I didn't want to check them every single time I wanted to test on real device
    -- in the end, this is a pretty nice addition :)
    -- it adds compatibility with other models too
    real = {
        var1 = "/data/files",
        var2 = "/data/quickapp/files"
    },
    quickapp = "internal://files",
    pkgName = "com.sucharek.miband_interconnect_test",

    mailbox = "mailbox.json",
}

local activityPaths = {
    cmd = {
        outputFile = "cmd_out",
    },
    sensorsLua = {
        outputFile = "sensor_out"
    }
}

local function checkPaths()
    local basePath = ""
    if fileOps.dirExists(basePaths.real.var1) then
        basePath = basePaths.real.var1
    elseif fileOps.dirExists(basePaths.real.var2) then
        basePath = basePaths.real.var2
    else
        error("No valid path found")
    end

    local paths = {
        real = basePath .. "/" .. basePaths.pkgName,
        quickapp = basePaths.quickapp,

        activityPaths = activityPaths
    }
    -- don't need quickapp path for mailbox, since it's already set there
    paths.mailbox = paths.real .. "/" .. basePaths.mailbox

    return paths
end

function Paths:get()
    local obj = checkPaths()

    setmetatable(obj, self)
    return obj
end

return Paths