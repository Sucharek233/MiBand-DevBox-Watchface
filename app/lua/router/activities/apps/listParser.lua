local ListParser = {}

local base64 = require "libs.base64"

function ListParser.getApps(list)
    local installedApps = list.InstalledApps

    local appInfo = {}
    for _, app in ipairs(installedApps) do
        local pkg = app.package
        
        local names = app.names
        -- grab the first name
        -- most apps don't do any localization and contain just one name 
        local name = names[1].value

        appInfo[pkg] = name
    end

    return appInfo
end

function ListParser.getAppInfo(list, pkgName)
    if not pkgName then
        return MailboxStates.ERROR, "No app specified"
    end

    local installedApps = list.InstalledApps

    for _, app in ipairs(installedApps) do
        if app.package == pkgName then
            return MailboxStates.DONE, app
        end
    end

    return MailboxStates.ERROR, "Not found"
end

local function getManifestPath(appPath, pkgName)
    if not pkgName then
        return MailboxStates.ERROR, "No app specified"
    end

    local pkgPath = appPath .. "/" .. pkgName
    if not FileOps.dirExists(pkgPath) then
        return MailboxStates.ERROR, "App not found"
    end

    local manifestPath = pkgPath .. "/manifest.json"
    if not FileOps.fileExists(manifestPath) then
        return MailboxStates.ERROR, "Manifest not found"
    end

    return MailboxStates.DONE, manifestPath
end

function ListParser.readManifest(appPath, pkgName)
    local state, result = getManifestPath(appPath, pkgName)
    if state == MailboxStates.ERROR then
        return state, result
    end

    local manifest = FileOps.read(result)
    return MailboxStates.DONE, manifest
end

function ListParser.writeManifest(appPath, pkgName, content)
    if not content then
        return MailboxStates.ERROR, "No content"
    end

    local state, result = getManifestPath(appPath, pkgName)
    if state == MailboxStates.ERROR then
        return state, result
    end

    FileOps.write(result, content)
    return MailboxStates.DONE, "Written"
end

function ListParser.getIcon(appPath, pkgName)
    local state, result = ListParser.readManifest(appPath, pkgName)
    if state == MailboxStates.ERROR then
        return state, result
    end

    local manifest = JSON.decode(result)
    local iconPath = manifest.icon

    if not iconPath then
        return MailboxStates.ERROR, "No icon specified"
    end

    local fullIconPath = appPath .. "/" .. pkgName .. "/" .. iconPath
    if not FileOps.fileExists(fullIconPath) then
        return MailboxStates.ERROR, "Icon not found"
    end

    local iconData = FileOps.read(fullIconPath)
    local iconBase64 = base64.encode(iconData)
    return MailboxStates.DONE, iconBase64
end

return ListParser