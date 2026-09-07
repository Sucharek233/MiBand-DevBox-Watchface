local json = require "libs.json"
local Paths = require "constants.paths"

local Mailbox = {}
Mailbox.__index = Mailbox

function Mailbox:new(router, paths)
    local obj = {
        router = router,
        paths = paths
    }

    setmetatable(obj, self)
    return obj
end

function Mailbox:readMailbox()
    local content, err = FileOps.read(self.paths.mailbox)

    if content == nil or err then
        return nil
    end

    -- check for whitespace
    if content:match("^%s*$") then
        return nil
    end

    return json.decode(content)
end


function Mailbox:writeMailbox(content)
    local success, err = FileOps.write(self.paths.mailbox, json.encode(content))

    if not success and err then
        error(err)
    end

    success, err = FileOps.write(self.paths.mailboxState, content.state)
    if not success and err then
        error(err)
    end

    return true
end


function Mailbox:process()
    local mailbox = self:readMailbox()
    if mailbox == nil then
        -- add some error handling later
        return
    end

    -- we only wanna wait for pending
    local state = mailbox.state
    if state ~= MailboxStates.PENDING then
        return
    end

    self.router:handle(mailbox)
end

function Mailbox:clean()
    local mailboxPath = self.paths.mailbox
    os.remove(mailboxPath)
end

return Mailbox