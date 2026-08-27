local Apps = {}
Apps.__index = Apps

local listParser = require "router.activities.apps.listParser"

function Apps:new(mailbox)
    local obj = {
        type = "apps",
        mailbox = mailbox,
        paths = nil,

        appList = nil,
        appListRaw = nil
    }

    setmetatable(obj, self)
    return obj
end

function Apps:setPaths(paths)
    self.paths = paths
end

function Apps:readAppList(dontParse, reread)
    if self.appListRaw == nil or reread == true then
        self.appListRaw = FileOps.read(self.paths.jsonList)
        self.appList = JSON.decode(self.appListRaw)
    end

    if dontParse then
        return self.appListRaw
    end

    return self.appList
end

function Apps:writeAppList(appList)
    if not appList then
        return MailboxStates.ERROR, "No content"
    end

    local appListStr
    local appListType = type(appList)

    if appListType == "string" then
        appListStr = appList
    elseif appListType == "table" then
        appListStr = JSON.encode(appList)
    end

    FileOps.write(self.paths.jsonList, appListStr)

    -- Update list
    self:readAppList(true, true)
    return MailboxStates.DONE, "Written"
end

function Apps:handle(request)
    local args = request.args
    local type = args.type

    if self.appListRaw == nil then
        self:readAppList(true, true)
    end

    local state = nil
    local result = nil
    if type == "list" then
        result = self:readAppList(true)
        state = MailboxStates.DONE

    elseif type == "writeList" then
        state, result = self:writeAppList(self.appList)

    elseif type == "listApps" then
        result = listParser.getApps(self.appList)
        state = MailboxStates.DONE

    elseif type == "info" then
        state, result = listParser.getAppInfo(self.appList, args.pkg)

    elseif type == "manifest" then
        state, result = listParser.readManifest(self.paths.appPath, args.pkg)

    elseif type == "writeManifest" then
        state, result = listParser.writeManifest(self.paths.appPath, args.pkg, args.content)

    elseif type == "icon" then
        state, result = listParser.getIcon(self.paths.appPath, args.pkg)
    end

    request.args = nil
    request.state = MailboxStates.DONE
    request.appState = state
    request.res = result
    self.mailbox:writeMailbox(request)
end

function Apps:clean()
    
end

return Apps