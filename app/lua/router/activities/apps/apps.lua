local Apps = {}
Apps.__index = Apps

local listParser = require "router.activities.apps.listParser"

local handlers = {
    list = {
        required = {},
        optional = {},

        run = function(self, _)
            return self:readAppList(true)
        end
    },

    writeList = {
        required = {
            content = "string"
        },
        optional = {},

        run = function(self, args)
            return self:writeAppList(args.content)
        end
    },

    listApps = {
        required = {},
        optional = {},

        run = function(self, _)
            return MailboxStates.DONE, listParser.getApps(self.appList)
        end
    },

    info = {
        required = {
            pkg = "string"
        },
        optional = {},

        run = function(self, args)
            return listParser.getAppInfo(self.appList, args.pkg)
        end
    },

    manifest = {
        required = {
            pkg = "string"
        },
        optional = {},

        run = function(self, args)
            return listParser.readManifest(self.paths.appPath, args.pkg)
        end
    },

    writeManifest = {
        required = {
            pkg = "string",
            content = "string"
        },
        optional = {},

        run = function(self, args)
            return listParser.writeManifest(
                self.paths.appPath,
                args.pkg,
                args.content
            )
        end
    },

    icon = {
        required = {
            pkg = "string"
        },
        optional = {},

        run = function(self, args)
            return listParser.getIcon(self.paths.appPath, args.pkg)
        end
    }
}

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

-- if invalid, keep the old list and return error
function Apps:readAppList(dontParse, reread)
    if self.appListRaw == nil or reread == true then
        local appListRaw = FileOps.read(self.paths.jsonList)

        local ok, err = pcall(function()
            self.appList = JSON.decode(appListRaw)
        end)
        if not ok then
            self.appList = nil
            self.appListRaw = nil
            return MailboxStates.ERROR, "Unable to parse app list: " .. err
        else
            self.appListRaw = appListRaw
        end
    end

    if dontParse then
        return MailboxStates.DONE, self.appListRaw
    end

    return MailboxStates.DONE, self.appList
end

function Apps:writeAppList(appList)
    FileOps.write(self.paths.jsonList, appList)

    -- Update list
    local state, res = self:readAppList(true, true)
    if state == MailboxStates.ERROR then
        return state, res
    end

    return MailboxStates.DONE, "Written"
end

function Apps:handle(request)
    local args = request.args or {}
    local type = args.type

    if self.appListRaw == nil then
        self:readAppList(true, true)
    end

    local handler = handlers[type]

    local state, result

    if not handler then
        state, result = MailboxStates.ERROR, "Unknown type"
    else
        local valid, err = ArgsValidator.validate(args, handler)

        if not valid then
            state, result = MailboxStates.ERROR, err
        else
            state, result = handler.run(self, args)
        end
    end

    request.args = nil
    request.state = MailboxStates.DONE
    request.appState = state
    request.res = result

    self.mailbox:writeMailbox(request)
end

return Apps