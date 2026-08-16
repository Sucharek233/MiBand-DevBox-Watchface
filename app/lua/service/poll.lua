local Mailbox = require "service.mailbox"

local PollService = {}
PollService.__index = PollService

function PollService:new(period, mailbox)
    local timer = lvgl.Timer({
        period = period,
        repeat_count = -1,
        paused = true,
        cb = function ()
           mailbox:process()
        end
    })

    local obj = {
        mailbox = mailbox,
        timer = timer,
        period = period
    }

    setmetatable(obj, self)
    return obj
end

function PollService:start()
    self.timer:resume()
end

function PollService:stop()
    self.timer:pause()
end

function PollService:setPeriod(newPeriod)
    self.period = newPeriod
    self.timer:set {
        period = newPeriod
    }
end

return PollService