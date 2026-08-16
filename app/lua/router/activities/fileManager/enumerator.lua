local Enumerator = {}

function Enumerator.getFileSize(path)
    local file = io.open(path, "rb")
    if not file then
        return -1, "open"
    end

    local success, size = pcall(function()
        return file:seek("end")
    end)

    file:close()

    if success and size then
        return size
    else
        return -1, "seek"
    end
end

function Enumerator.listDir(path)
    local result = {
        folders = {},
        files = {}
    }

    local dir, msg, code = lvgl.fs.open_dir(path)
    if not dir then
        return nil, msg or "Failed to open directory"
    end

    local base_path = path:sub(-1) == "/" and path or path .. "/"

    while true do
        local d = dir:read()
        if not d then break end

        -- LVGL prepends a "/" to directory names
        local is_dir = string.byte(d, 1) == string.byte("/", 1)

        if is_dir then
            -- Folders become a flat array of strings
            local folder_name = d:sub(2)
            table.insert(result.folders, folder_name)
        else
            -- Files use the filename as the unique key
            local full_path = base_path .. d
            local size = Enumerator.getFileSize(full_path)
            
            if size ~= -1 then
                result.files[d] = {
                    size = size
                }
            else
                result.files[d] = {}
            end
        end
    end

    dir:close()
    return result
end

return Enumerator