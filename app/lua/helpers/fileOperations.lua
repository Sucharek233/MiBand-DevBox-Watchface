local FileOps = {}

local lvgl = require "lvgl"

local function openRead(path, mode)
    local file, err = io.open(path, mode)

    if not file then
        return nil, err
    end

    local content = file:read("*a")
    file:close()
    return content
end

function FileOps.read(path)
    return openRead(path, "r")
end

function FileOps.readBytes(path)
    return openRead(path, "rb")
end

local function openWrite(path, mode, content)
    local file, err = io.open(path, mode)

    if not file then
        return false, err
    end

    file:write(content)
    file:close()
    return true
end

function FileOps.write(path, content)
    return openWrite(path, "w", content)
end

function FileOps.writeBytes(path, content)
    return openWrite(path, "wb", content)
end

function FileOps.dirExists(path)
    local dir = lvgl.fs.open_dir(path)

    if dir then
        dir:close()
        return true
    else
        return false
    end
end

function FileOps.fileExists(path)
    local file = io.open(path, "rb")

    if file then
        file:close()
        return true
    else
        return false
    end
end

return FileOps