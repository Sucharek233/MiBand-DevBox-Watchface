-- No need to os.execute("df > /tmp/aaa")
function get_data_free_space()
    -- 1. Read the content back into Lua
    local file = io.open("/proc/fs/blocks", "r")
    if not file then
        return nil, "Failed to read from RAM-disk"
    end
    local output = file:read("*a")
    file:close()

    -- 2. Parse the output line by line looking for /data
    for line in output:gmatch("[^\r\n]+") do
        if line:match("/data%s*$") or line:match("/data$") then
            -- Match the numbers layout from your standard df layout:
            -- Size, Blocks, Used, Available, Mounted on
            local blk_size, _, _, available = line:match("%s*(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")

            if blk_size and available then
                local b_size = tonumber(blk_size)
                local b_avail = tonumber(available)
                local free_bytes = b_avail * b_size

                return free_bytes, string.format("%.2f MB", free_bytes / (1024^2))
            end
        end
    end

    return nil, "Could not locate or parse /data partition"
end

-- Run it
local bytes, readable = get_data_free_space()
if bytes then
    print("Free space bytes:", bytes)
    print("Readable format :", readable)
else
    print("Error:", readable)
end