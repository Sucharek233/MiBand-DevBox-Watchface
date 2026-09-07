local Paths = {}
Paths.__index = Paths

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
    mailboxState = "state"
}

local activityPaths = {
    cmd = {
        outputFile = "cmd_out",
    },
    sensorsLua = {
        outputFile = "sensor_out"
    },
    io = {
        chunkFile = "chunk"
    },
}

-- If activity path is an object, it'll be checked which one is valid
-- Regular strings aren't checked
-- Always check longer paths first!
local variableActivityPaths = {
    -- These paths are different on the emulator, on my band 10, on band 9
    -- Let's just check all of them one by one...
    apps = {
        jsonList = {
            "/data/quickapp/apps.json",
            "/data/apps.json"
        },
        appPath = {
            "/data/quickapp/app",
            "/data/app"
        },
        filesPath = {
            "/data/quickapp/files",
            "/data/files"
        },
        cachePath = {
            "/data/quickapp/cache",
            "/data/cache"
        },
        -- `/data/quickapp/mass` and `/data/mass` both exist on band 10
        -- but `/data/quickapp/mass` is preferred, because it actually corresponds to `internal://mass` within the quickapp
        -- whereas /data/mass is some tmp folder? it contains `watchface`, `app` and `res`, and all of them are empty...
        massPath = {
            "/data/quickapp/mass",
            "/data/mass"
        },
        -- this folder contains the @system.storage database `usr.db`
        systemPath = "/data/quickapp/system"
    }
}

local function checkPaths()
    local basePath = ""

     for _, path in ipairs(basePaths.real) do
        if FileOps.dirExists(path) then
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
    
    for activity in pairs(variableActivityPaths) do
        local thisActivityPaths = {}
        for key, path in pairs(variableActivityPaths[activity]) do
            if type(path) == "table" then
                for _, p in ipairs(path) do
                    if FileOps.fileExists(p) or FileOps.dirExists(p) then
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
    paths.mailboxState = paths.real .. "/" .. basePaths.mailboxState

    return paths
end

function Paths:get()
    local obj = checkPaths()

    setmetatable(obj, self)
    return obj
end

return Paths