local Enumerator = {}

function Enumerator.listDir(path)
    local result = {
        folders = {},
        files = {}
    }

    local dir, _, code = lvgl.fs.open_dir(path)
    if not dir then
        return nil, code or "Failed to open directory"
    end

    local base_path = path:sub(-1) == "/" and path or path .. "/"

    while true do
        local d = dir:read()
        if not d then break end

        -- LVGL prepends a "/" to directory names
        local is_dir = string.byte(d, 1) == string.byte("/", 1)

        if is_dir then
            local folder_name = d:sub(2)
            table.insert(result.folders, folder_name)
        else
            local full_path = base_path .. d
            local size = FileOps.getFileSize(full_path)
            
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