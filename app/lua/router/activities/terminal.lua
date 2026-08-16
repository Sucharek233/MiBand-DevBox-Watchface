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

function Terminal:run(request)
    local command = request.args.cmd

    request.state = "running"
    self.mailbox:writeMailbox(request)

    print("[devbox] [terminal] Gonna run " .. command)

    local shellCommand =
        command .. " > " .. self.paths.real .. "/" .. self.paths.outputFile
    local _, reason, code = os.execute(shellCommand)

    request.state = "done"
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