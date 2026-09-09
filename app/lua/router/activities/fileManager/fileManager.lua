local FileManager = {}
FileManager.__index = FileManager

local enumerator = require "router.activities.fileManager.enumerator"
local operations = require "router.activities.fileManager.operations"
local fileStreamer = require "router.activities.fileManager.fileStreamer"

local handlers = {
    list = {
        required = {
            path = "string"
        },

        run = function(self, args)
            return self:listDir(args.path)
        end
    },

    cp = {
        required = {
            src = "string",
            dst = "string"
        },

        run = function(self, args)
            return operations.copy(args.src, args.dst)
        end
    },

    mv = {
        required = {
            src = "string",
            dst = "string"
        },

        run = function(self, args)
            return operations.move(args.src, args.dst)
        end
    },

    rm = {
        required = {
            path = "string"
        },

        run = function(self, args)
            return operations.remove(args.path)
        end
    },

    getStream = {
        required = {
            path = "string"
        },
        optional = {
            lSize = {
                type = "number",
                default = 1024 * 512 -- 512 KB
            },

            b64 = {
                type = "boolean",
                default = false
            }
        },

        run = function(self, args)
            if self.streamer ~= nil then
                return MailboxStates.ERROR, "Already streaming"
            end

            self.streamer = fileStreamer:new(
                self.paths,
                args.path,
                args.lSize,
                args.b64
            )

            local state, result = self.streamer:open()

            if state == MailboxStates.ERROR then
                self:clearStreamer()
            end

            return state, result
        end
    },

    chunk = {
        run = function(self, _)
            if not self.streamer then
                return MailboxStates.ERROR, "Streamer uninitialized"
            end

            local state, result = self.streamer:nextChunk()

            if state == MailboxStates.DONE or state == MailboxStates.ERROR then
                self:clearStreamer()
            end

            return state, result
        end
    },

    stop = {
        run = function(self, _)
            if not self.streamer then
                return MailboxStates.ERROR, "Streamer uninitialized"
            end

            self:clearStreamer()

            return MailboxStates.DONE, "Stopped"
        end
    }
}

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
    local args = request.args or {}
    local type = args.type

    local handler = handlers[type]

    local state, result

    if not handler then
        state, result = MailboxStates.ERROR, "Unknown type"
    else
        local valid, err = ArgsValidator.validate(args, handler)

        if not valid then
            state, result = MailboxStates.ERROR, err
        else
            state, result = handler.run(self, args)
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

function FileManager:clearStreamer()
    if self.streamer then
        self.streamer:close()
        self.streamer = nil
    end
end

function FileManager:clean()
    if self.streamer then
        self:clearStreamer()
    else
        os.remove(self.paths.real .. "/" .. self.paths.chunkFile)
    end
end

return FileManager