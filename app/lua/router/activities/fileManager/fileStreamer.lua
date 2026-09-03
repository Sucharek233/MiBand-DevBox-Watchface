local FileStreamer = {}
FileStreamer.__index = FileStreamer

local base64 = require "libs.base64"

function FileStreamer:new(paths, path, chunkSize, useB64)
    if useB64 == nil then useB64 = true end

    local chunkPath = paths.real .. "/" .. paths.chunkFile
    local quickappPath = paths.quickapp .. "/" .. paths.chunkFile

    local obj = {
        path = path,
        chunkSize = chunkSize or (1024 * 512), -- 512 KB
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

    local file = io.open(self.path, "rb")
    if not file then
        return MailboxStates.ERROR, "Failed to open source file"
    end

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

local function execInTmp(cmd)
    local tmpFile = "/tmp/tmp.txt"
    local fullCmd = cmd .. " > " .. tmpFile
    os.execute(fullCmd)

    local content = FileOps.read(tmpFile)
    os.remove(tmpFile)

    return content
end

-- Processes a chunk in small RAM-friendly sub-blocks and writes directly to disk
function FileStreamer:nextChunk()
    if not self.file then
        return MailboxStates.ERROR, "File not open"
    end

    -- Check EOF
    if self.currPos >= self.fileSize then
        return MailboxStates.DONE, nil
    end

    -- Open destination chunk file in binary write mode
    local outFile, err = io.open(self.chunkPath, "wb")
    if not outFile then
        return MailboxStates.ERROR, "Failed to open chunk file"
    end

    -- safe 12 KB
    -- 64+ KB was crashing on real hardware
    local subBlockSize = 12288
    local bytesReadThisChunk = 0

    while bytesReadThisChunk < self.chunkSize do
        -- Calculate remaining bytes to finish this chunk
        local remainingInChunk = self.chunkSize - bytesReadThisChunk
        local toRead = math.min(subBlockSize, remainingInChunk)

        local block = self.file:read(toRead)
        if not block or #block == 0 then
            break
        end

        bytesReadThisChunk = bytesReadThisChunk + #block

        -- slowly append chunk to file
        if self.useB64 then
            block = base64.encode(block)
        end

        outFile:write(block)
    end

    outFile:close()

    -- If no bytes were read at all, EOF
    if bytesReadThisChunk == 0 then
        os.remove(self.chunkPath)
        return MailboxStates.DONE, nil
    end

    self.currPos = self.currPos + bytesReadThisChunk
    self.chunkCount = self.chunkCount + 1

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