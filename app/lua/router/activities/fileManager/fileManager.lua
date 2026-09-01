local FileManager = {}
FileManager.__index = FileManager

local enumerator = require "router.activities.fileManager.enumerator"
local operations = require "router.activities.fileManager.operations"
local fileStreamer = require "router.activities.fileManager.fileStreamer"

function FileManager:new(mailbox)
    local obj = {
        type = "io",
        mailbox = mailbox,
        paths = nil,

        streamer = nil
    }

    setmetatable(obj, self)
    return obj
end

function FileManager:setPaths(paths)
    self.paths = paths
end

function FileManager:handle(request)
    local args = request.args
    local type = args.type

    -- Wall of if statements incoming
    -- dw will change this later
    local state, result
    if type == "list" then
        if args.path then
            state, result = self:listDir(args.path)
        else
            state, result = MailboxStates.ERROR, "path missing"
        end

    elseif type == "cp" then
        if args.src and args.dst then
            state, result = operations.copy(args.src, args.dst)
        else
            state, result = MailboxStates.ERROR, "src or dst missing"
        end

    elseif type == "mv" then
        if args.src and args.dst then
            state, result = operations.move(args.src, args.dst)
        else
            state, result = MailboxStates.ERROR, "src or dst missing"
        end

    elseif type == "rm" then
        if args.path then
            state, result = operations.remove(args.path)
        else
            state, result = MailboxStates.ERROR, "path missing"
        end


    elseif type == "getStream" then
        -- lSize
        if args.path then
            if self.streamer ~= nil then
                state, result = MailboxStates.ERROR, "Already streaming"
            else
                self.streamer = fileStreamer:new(self.paths, args.path, args.lSize, args.b64)
                state, result = self.streamer:open()
            end
        end

    elseif type == "chunk" then
        if self.streamer then
            state, result = self.streamer:nextChunk()
            if state == MailboxStates.DONE then
                self.streamer:close()
                self.streamer = nil
            end
        else
            state, result = MailboxStates.ERROR, "Streamer uninitialized"
        end
    end

    request.args = nil
    request.state = MailboxStates.DONE
    request.appState = state
    request.res = result
    self.mailbox:writeMailbox(request)
end

function FileManager:listDir(path)
    local result = enumerator.listDir(path)

    if not result then
        return MailboxStates.ERROR, nil
    end

    return MailboxStates.DONE, result
end

function FileManager:clean()
    if self.streamer then
        self.streamer:clean()
    else
        os.remove(self.paths.real .. "/" .. self.paths.chunkFile)
    end
end

return FileManager