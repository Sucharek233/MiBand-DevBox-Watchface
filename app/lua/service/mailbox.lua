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

function Mailbox:read()
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

function Mailbox:readState()
    -- FileOps not used because it's reading a single byte
    local f, err = io.open(self.paths.mailboxState, "rb")
    if not f then
        return nil
    end

    local rawChar = f:read(1)
    f:close()

    if not rawChar or rawChar == "" then
        return nil
    end

    return string.byte(rawChar)
end

function Mailbox:writeMailbox(content)
    FileOps.write(self.paths.mailbox, json.encode(content))

    local stateNum = tonumber(content.state) or 0
    local f, err = io.open(self.paths.mailboxState, "wb")
    if f then
        f:write(string.char(stateNum))
        f:close()
    end

    return true
end

function Mailbox:process()
    local state = self:readState()
    
    if state ~= MailboxStates.PENDING then
        return
    end

    local mailbox = self:read()
    if not mailbox then
        return
    end

    self.router:handle(mailbox)
end

function Mailbox:clean()
    os.remove(self.paths.mailbox)
    os.remove(self.paths.mailboxState)
end

return Mailbox