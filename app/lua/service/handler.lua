local Handler = {}
Handler.__index = Handler

local PollService = require "service.poll"
local Paths = require "constants.paths"

local Router = require "router.router"
local RouterRegister = require "router.registerActivities"

local Mailbox = require "service.mailbox"

function Handler:new(pollRate)
    local paths = Paths:get()

    local router = Router:new()
    local mailbox = Mailbox:new(router, paths)
    local routerRegister = RouterRegister:new(router, mailbox, paths)

    local poll = PollService:new(pollRate, mailbox)

    routerRegister:registerAll()

    local obj = {
        poll = poll,
        paths = paths,

        router = router,
        routerRegister = routerRegister,
        mailbox = mailbox
    }

    setmetatable(obj, self)
    return obj
end

-- Polling
function Handler:startPolling()
    self.poll:start()
end

function Handler:stopPolling()
    self.poll:stop()
end

function Handler:clean()
    self.mailbox:clean()
    self.routerRegister:clean()
    -- more stuff will be here later
end

return Handler