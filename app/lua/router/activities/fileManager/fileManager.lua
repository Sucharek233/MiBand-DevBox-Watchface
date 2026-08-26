local FileManager = {}
FileManager.__index = FileManager

local enumerator = require "router.activities.fileManager.enumerator"

function FileManager:new(mailbox)
    local obj = {
        type = "io",
        mailbox = mailbox,
        enumerator = enumerator
    }

    setmetatable(obj, self)
    return obj
end

function FileManager:handle(request)
    local args = request.args
    local type = args.type

    local result = nil
    if type == "list" then
        result = self:listDir(args)
    end

    -- keep type in args
    request.args = nil
    request.args = {
        type = type
    }

    if result == nil then
        request.state = MailboxStates.ERROR
        self.mailbox:writeMailbox(request)
        return
    end

    request.state = MailboxStates.DONE
    request.result = result
    self.mailbox:writeMailbox(request)
end

function FileManager:listDir(args)
    local path = args.path
    local result = enumerator.listDir(path)
    return result
end

return FileManager