local SysInfo = {}
SysInfo.__index = SysInfo

function SysInfo:new(mailbox)
    local obj = {
        type = "sysInfoLua",
        mailbox = mailbox
    }

    setmetatable(obj, self)
    return obj
end

local function execInTmp(cmd)
    local tmpFile = "/tmp/tmp.txt"
    local fullCmd = cmd .. " > " .. tmpFile
    os.execute(fullCmd)

    local content = FileOps.read(tmpFile)
    os.remove(tmpFile)
    
    return content
end

function SysInfo:getDiskInfo()
    local info = {
        mount = FileOps.read("/proc/fs/mount") or "",
        blocks = FileOps.read("/proc/fs/blocks") or "",
        usage = FileOps.read("/proc/fs/usage") or ""
    }
    return MailboxStates.DONE, info
end

function SysInfo:gatherInfo()
    local info = {
        cpuInfo = FileOps.read("/proc/cpuinfo"),
        cpuLoad = FileOps.read("/proc/cpuload"),
        memInfo = FileOps.read("/proc/meminfo"),
        memPool = FileOps.read("/proc/mempool"),
        tcbInfo = FileOps.read("/proc/tcbinfo"),
        version = FileOps.read("/proc/version"),
        iobinfo = FileOps.read("/proc/iobinfo"),
        rpmsg = FileOps.read("/proc/rpmsg"),
        partitions = FileOps.read("/proc/partitions"),
    }
    return MailboxStates.DONE, info
end

local function sanitizeInput(value)
    local safe_value = tostring(value or "")
    safe_value = safe_value:gsub("\\", "\\\\")  -- Escape backslashes first
    safe_value = safe_value:gsub('"', '\\"')    -- Escape double quotes
    safe_value = safe_value:gsub("%$", "\\$")   -- Escape dollar signs
    safe_value = safe_value:gsub("`", "\\`")    -- Escape backticks
    return safe_value
end

function SysInfo:getProp(prop)
    local sProp = sanitizeInput(prop)
    local cmd = string.format('getprop "%s"', sProp)

    local values = execInTmp(cmd)
    return MailboxStates.DONE, values
end

function SysInfo:setProp(prop, value)
    local sProp = sanitizeInput(prop)
    local sValue = sanitizeInput(value)

    local cmd = string.format('setprop "%s" "%s"', sProp, sValue)
    local result = os.execute(cmd)
    
    if result then
        return MailboxStates.DONE
    else
        return MailboxStates.ERROR
    end
end

function SysInfo:handle(request)
    local args = request.args
    local type = args.type

    local state, result = nil, nil
    if type == "disk" then
        state, result = self:getDiskInfo()

    elseif type == "info" then
        state, result = self:gatherInfo()

    elseif type == "props" then
        result = execInTmp("getprop")
        state = MailboxStates.DONE

    elseif type == "getProp" then
        local prop = args.prop
        state, result = self:getProp(prop)

    elseif type == "setProp" then
        local prop = args.prop
        local value = args.value
        state = self:setProp(prop, value)
    end

    request.args = nil
    request.state = MailboxStates.DONE
    request.appState = state
    request.res = result
    self.mailbox:writeMailbox(request)
end

return SysInfo