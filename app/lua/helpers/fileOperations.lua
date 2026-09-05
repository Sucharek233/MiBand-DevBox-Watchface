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
    -- An interesting discovery made in the emulator
    -- You can apparently open dirs as files in /tmp
    -- So this is here to prevent that
    -- It doesn't seem to happen on real device though
    if FileOps.dirExists(path) then
        return false
    end

    local file = io.open(path, "rb")

    if file then
        file:close()
        return true
    else
        return false
    end
end

-- *sigh*
-- Apparently, /dev/uorb/sensorname is a directory when opening with lvgl.fs.open_dir (tested on mb10 as well)
-- This fucks up if sensor is valid checks
-- So here's the regular function
function FileOps.fileExistsOld(path)
    local file = io.open(path, "rb")

    if file then
        file:close()
        return true
    else
        return false
    end
end

function FileOps.getType(path)
    if FileOps.dirExists(path) then
        return "dir"
    elseif FileOps.fileExists(path) then
        return "file"
    end

    return nil
end

function FileOps.getFileSize(path)
    local file = io.open(path, "rb")
    if not file then
        return -1, "open"
    end

    local success, size = pcall(function()
        return file:seek("end")
    end)

    file:close()

    if success and size then
        return size
    else
        return -1, "seek"
    end
end

function FileOps.getPartitionInfo(partition)
    local info = FileOps.read("/proc/fs/blocks")
    if not info then
        return nil, MailboxStates.ERROR
    end

    for line in info:gmatch("[^\r\n]+") do
        if line:match(partition .. "%s*$") or
           line:match(partition .. "$")
        then
            -- Size, Blocks, Used, Available, Mounted on
            local blk_size, blocks, _, available = line:match("%s*(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")

            if blk_size and available then
                local b_size = tonumber(blk_size)
                local b_avail = tonumber(available)
                local free_bytes = b_avail * b_size

                local partitionInfo = {
                    blkSize = b_size,
                    blkAvail = b_avail,
                    blks = blocks,
                    freeBytes = free_bytes
                }

                return partitionInfo, MailboxStates.DONE
            end
        end
    end

    return nil, MailboxStates.ERROR
end

function FileOps.getFreeSpace()
    local info, state = FileOps.getPartitionInfo("/data")
    if not info or state == MailboxStates.ERROR then
        return nil, state
    end

    return info.freeBytes, MailboxStates.DONE
end

return FileOps