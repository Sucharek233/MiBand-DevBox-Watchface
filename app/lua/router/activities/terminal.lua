local Terminal = {}
Terminal.__index = Terminal

function Terminal:new(mailbox)
    local obj = {
        type = "cmd",
        mailbox = mailbox,
        paths = nil
    }

    setmetatable(obj, self)
    return obj
end

function Terminal:setPaths(paths)
    self.paths = paths
end

local function sanitizeShellCmd(cmd)
    return tostring(cmd)
        :gsub('\\', '\\\\')
        :gsub('"', '\\"')
        :gsub('%$', '\\$')
        :gsub('`', '\\`')
end

function Terminal:run(request)
    local command = request.args.cmd

    request.state = "running"
    self.mailbox:writeMailbox(request)

    -- Wrapping the command in `sh -c` is needed to properly handle redirection and such
    local safeCmd = sanitizeShellCmd(command)
    local shellCommand = string.format('sh -c "%s" > "%s"', safeCmd, self.paths.real .. "/" .. self.paths.outputFile)
    local _, reason, code = os.execute(shellCommand)

    request.state = MailboxStates.DONE
    request.reason = reason
    request.code = code
    request.out = self.paths.quickapp .. "/" .. self.paths.outputFile
    request.args = nil
    self.mailbox:writeMailbox(request)
end

function Terminal:clean()
    os.remove(self.paths.real .. "/" .. self.paths.outputFile)
end

return Terminal