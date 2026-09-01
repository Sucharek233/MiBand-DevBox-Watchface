-- oh boy
local FileStreamer = {}
FileStreamer.__index = FileStreamer

local base64 = require "libs.base64"

function FileStreamer:new(paths, path, chunkSize, useB64)
    if useB64 == nil then useB64 = true end

    local chunkPath = paths.real .. "/" .. paths.chunkFile
    local quickappPath = paths.quickapp .. "/" .. paths.chunkFile

    local obj = {
        path = path,
        chunkSize = chunkSize or (1024 * 1024), -- default to 1MB
        useB64 = useB64,

        file = nil,
        fileSize = 0,
        currPos = 0,
        chunkCount = 0,
        
        chunkPath = chunkPath,
        quickappPath = quickappPath
    }

    setmetatable(obj, self)
    return obj
end

function FileStreamer:open()
    local fileSize, err = FileOps.getFileSize(self.path)
    if fileSize == -1 then
        return MailboxStates.ERROR, err
    end

    -- file already opened and checked in getFileSize - no need to check again
    local file = io.open(self.path, "rb")
    self.file = file
    self.fileSize = fileSize

    return MailboxStates.DONE, {
        fileSize = fileSize,
        path = self.quickappPath
    }
end

function FileStreamer:close()
    if self.file then
        self.file:close()
        self.file = nil
    end
    self:clean()
end

function FileStreamer:readChunk()
    if not self.file then
        return MailboxStates.ERROR, "File not open"
    end

    local chunk = self.file:read(self.chunkSize)
    if not chunk then
        return MailboxStates.DONE, nil -- EOF
    end

    self.currPos = self.currPos + #chunk
    self.chunkCount = self.chunkCount + 1

    if self.useB64 then
        chunk = base64.encode(chunk)
    end

    return MailboxStates.DONE, chunk
end

local function execInTmp(cmd)
    local tmpFile = "/tmp/tmp.txt"
    local fullCmd = cmd .. " > " .. tmpFile
    os.execute(fullCmd)

    local content = FileOps.read(tmpFile)
    os.remove(tmpFile)

    return content
end

function FileStreamer:nextChunk()
    local state, chunk = self:readChunk()
    if state == MailboxStates.ERROR then
        return state, chunk
    end

    if not chunk then
        return MailboxStates.DONE, nil -- EOF
    end

    local written, err = FileOps.writeBytes(self.chunkPath, chunk)
    if not written then
        return MailboxStates.ERROR, err
    end

    local md5sum = execInTmp("md5 " .. self.chunkPath)

    return MailboxStates.STREAM, {
        currPos = self.currPos,
        md5sum = md5sum
    }
end

function FileStreamer:clean()
    os.remove(self.chunkPath)
end

return FileStreamer