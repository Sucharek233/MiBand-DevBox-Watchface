local Operations = {}

local function escapePath(p)
    return "'" .. tostring(p):gsub("'", "'\\''") .. "'"
end

local function validatePaths(src, dst)
    local srcType = FileOps.getType(src)
    if not srcType then
        return nil, "Source doesn't exist"
    end

    local dstType = FileOps.getType(dst)

    -- Rule: Cannot copy/move a directory onto an existing regular file
    if srcType == "dir" and dstType == "file" then
        return nil, "Cannot overwrite file with directory"
    end

    return srcType, dstType
end

function Operations.copy(src, dst)
    local srcType, dstType = validatePaths(src, dst)
    -- srcType is state and dstType is error :)
    if not srcType then
        return MailboxStates.ERROR, dstType
    end

    local safeSrc = escapePath(src)
    local safeDst = escapePath(dst)

    local cmd
    if srcType == "dir" then
        -- Destination needs to be created before copying
        -- Shell doesn't support &&, ; is used instead
        cmd = string.format('mkdir -p %s ; cp -r %s %s', safeDst, safeSrc, safeDst)
    else
        cmd = string.format('cp %s %s', safeSrc, safeDst)
    end

    local result = os.execute(cmd)

    return result and MailboxStates.DONE or MailboxStates.ERROR
end

function Operations.move(src, dst)
    local srcType, dstType = validatePaths(src, dst)
    -- srcType is state and dstType is error :)
    if not srcType then
        return MailboxStates.ERROR, dstType
    end

    local success, _, code = os.rename(src, dst)
    if success then
        return MailboxStates.DONE
    end

    -- os.rename can't handle moving across partitions
    -- and returns error 18 EXDEV
    -- the mv command also reports error code 18
    if code == 18 then
        local safeSrc = escapePath(src)
        local safeDst = escapePath(dst)

        local cmd
        if srcType == "dir" then
            -- Create target directory, copy contents recursively, then delete source
            cmd = string.format('mkdir -p %s ; cp -r %s %s ; rm -rf %s', safeDst, safeSrc, safeDst, safeSrc)
        else
            -- Copy file, then delete source
            cmd = string.format('cp %s %s ; rm %s', safeSrc, safeDst, safeSrc)
        end

        local result = os.execute(cmd)
        print("[devbox] " .. cmd)

        return result and MailboxStates.DONE or MailboxStates.ERROR
    end

    return MailboxStates.ERROR, code
end

function Operations.remove(path)
    local pathType = FileOps.getType(path)
    if not pathType then
        return MailboxStates.ERROR, "Path doesn't exist"
    end

    local status, _, code = os.remove(path)
    if status then
        return MailboxStates.DONE
    end

    if pathType == "dir" then
        local safePath = escapePath(path)
        local cmd = string.format('rm -rf %s', safePath)

        local result = os.execute(cmd)

        return result and MailboxStates.DONE or MailboxStates.ERROR
    end

    return MailboxStates.ERROR, code
end

return Operations