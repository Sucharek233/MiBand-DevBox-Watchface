function get_data_free_space()
    local tmp_file = "/tmp/df_out.txt"
    
    -- 1. Execute df (or df -h) and dump all mounts to the RAM-disk
    os.execute("df > " .. tmp_file)
    
    -- 2. Read the content back into Lua
    local file = io.open(tmp_file, "r")
    if not file then 
        return nil, "Failed to read from RAM-disk" 
    end
    local output = file:read("*a")
    file:close()
    
    -- 3. Clean up the RAM-disk space immediately
    os.remove(tmp_file)
    
    -- 4. Parse the output line by line looking for /data
    for line in output:gmatch("[^\r\n]+") do
        if line:match("/data%s*$") or line:match("/data$") then
            -- Match the numbers layout from your standard df layout:
            -- Size, Blocks, Used, Available, Mounted on
            local blk_size, blocks, used, available = line:match("%s*(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
            
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