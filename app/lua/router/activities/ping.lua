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

-- quick ai generated function :)
local function getPreciseTimestampMs()
    local sec = os.time()
    local clock = os.clock()

    if not _G.__time_anchor then
        _G.__time_anchor = sec - clock
    end

    local preciseTime = _G.__time_anchor + clock
    return math.floor(preciseTime * 1000)
end

function Ping:ping(request)
    request.state = "done"
    request.time = getPreciseTimestampMs()
    self.mailbox:writeMailbox(request)
end

return Ping