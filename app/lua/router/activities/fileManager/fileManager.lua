local FileManager = {}
FileManager.__index = FileManager

local enumerator = require "router.activities.fileManager.enumerator"
local operations = require "router.activities.fileManager.operations"

function FileManager:new(mailbox)
    local obj = {
        type = "io",
        mailbox = mailbox
    }

    setmetatable(obj, self)
    return obj
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

return FileManager