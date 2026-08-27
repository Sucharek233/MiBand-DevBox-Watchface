local LuaShell = {}
LuaShell.__index = LuaShell

local sanitizer = require "router.activities.shell.sanitizer"

function LuaShell:new(mailbox)
    local obj = {
        type = "luashell",
        mailbox = mailbox
    }

    setmetatable(obj, self)
    return obj
end

function LuaShell:execute(request)
    local codeStr = request.args.code
    request.state = MailboxStates.DONE

    local printLogs = {}
    local originalPrint = print

    -- Temporary print replacement to capture logs
    local function customPrint(...)
        local args = { ... }
        local strArgs = {}
        for i, v in ipairs(args) do
            table.insert(strArgs, tostring(v))
        end
        table.insert(printLogs, table.concat(strArgs, "\t"))
    end

    local chunk, err = load(codeStr)

    if not chunk then
        request.luaState = MailboxStates.ERROR
        request.reason = "syntax"
        request.msg = tostring(err)
        request.args = nil
        self.mailbox:writeMailbox(request)
        return
    end

    -- print intercept
    _G.print = customPrint
    local success, result = pcall(chunk)
    _G.print = originalPrint

    local printOutput = #printLogs > 0 and table.concat(printLogs, "\n") or nil

    if not success then
        request.luaState = MailboxStates.ERROR
        request.reason = "runtime"
        request.msg = tostring(result)
        request.print = printOutput
        request.args = nil
        self.mailbox:writeMailbox(request)
        return
    end

    result = sanitizer.sanitize(result)

    request.luaState = MailboxStates.DONE
    request.res = result
    request.print = printOutput -- will be run through JSON.encode anyway, here it's already sanitized
    request.args = nil
    self.mailbox:writeMailbox(request)
end

return LuaShell