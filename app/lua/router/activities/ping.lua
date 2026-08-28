local Ping = {}
Ping.__index = Ping

function Ping:new(mailbox)
    local obj = {
        type = "ping",
        mailbox = mailbox
    }

    setmetatable(obj, self)
    return obj
end

function Ping:ping(request)
    -- Since os.time() only provides second precision
    -- Ack time back results in negative and imprecise results
    request.state = MailboxStates.DONE
    self.mailbox:writeMailbox(request)
end

return Ping