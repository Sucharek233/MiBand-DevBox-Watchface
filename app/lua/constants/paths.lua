local Paths = {}
Paths.__index = Paths

local fileOps = require("helpers.fileOperations")

local basePaths = {
    -- this was made mainly because the emulator and band 10 have different paths
    -- and I didn't want to check them every single time I wanted to test on real device
    -- in the end, this is a pretty nice addition :)
    -- it adds compatibility with other models too
    real = {
        "/data/quickapp/files",
        "/data/files"
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

-- If activity path is an object, it'll be checked which one is valid
-- Regular strings aren't checked
local variableActivityPaths = {
    apps = {
        jsonList = {
            "/data/quickapp/apps.json",
            "/data/apps.json"
        },
        appPath = {
            "/data/quickapp/app",
            "/data/app"
        }
    }
}

local function checkPaths()
    local basePath = ""

     for _, path in ipairs(basePaths.real) do
        if fileOps.dirExists(path) then
            basePath = path
            break
        end
    end

    if basePath == "" then
        error("No valid path found")
    end

    local paths = {
        real = basePath .. "/" .. basePaths.pkgName,
        quickapp = basePaths.quickapp,

        activityPaths = activityPaths
    }
    
    for _, activity in ipairs(variableActivityPaths) do
        local thisActivityPaths = {}
        for key, path in pairs(activity) do
            if type(path) == "table" then
                for _, p in ipairs(path) do
                    if fileOps.fileExists(p) or fileOps.dirExists(p) then
                        thisActivityPaths[key] = p
                        break
                    end
                end
            else
                thisActivityPaths[key] = path
            end
        end
        paths.activityPaths[activity] = thisActivityPaths
    end
     
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