local Sanitizer = {}

-- Yes, it is AI generated :)

--- Sanitizes any Lua value into a JSON-friendly table structure.
-- Handles circular references, functions, userdata, threads, NaN, Inf, and non-string/number table keys.
-- @param val any: The input Lua value
-- @param maxString number|nil: Optional max string length truncation
-- @return table|string|number|boolean|nil: JSON-safe value
function Sanitizer.sanitize(val, maxString)
    maxString = maxString or 2000
    local seen = {} -- Tracks seen tables to detect circular references

    local function convert(v, path)
        path = path or "root"
        local t = type(v)

        -- 1. Functions
        if t == "function" then
            return { ["$"] = "fn", repr = tostring(v) }
        end

        -- 2. Userdata (LVGL objects, C pointers, lightuserdata)
        if t == "userdata" or t == "lightuserdata" then
            return { ["$"] = "userdata", repr = tostring(v) }
        end

        -- 3. Coroutines / Threads
        if t == "thread" then
            return { ["$"] = "thread", repr = tostring(v) }
        end

        -- 4. Numbers (Check NaN and Infinity)
        if t == "number" then
            if v ~= v then
                return { ["$"] = "nan" }
            elseif v == math.huge then
                return { ["$"] = "inf" }
            elseif v == -math.huge then
                return { ["$"] = "ninf" }
            end
            return v
        end

        -- 5. Strings (Truncate if needed)
        if t == "string" then
            if #v > maxString then
                return v:sub(1, maxString) .. "..."
            end
            return v
        end

        -- 6. Booleans and Nil
        if t == "boolean" or t == "nil" then
            return v
        end

        -- 7. Tables (Handles Arrays, Objects, Circular References, and Mixed Keys)
        if t == "table" then
            -- Circular reference check
            if seen[v] then
                return { ["$"] = "ref", to = seen[v] }
            end
            seen[v] = path

            local out = {}
            for k, child in pairs(v) do
                local keyStr = tostring(k)
                local currentPath = path .. "." .. keyStr

                -- Safely convert child values
                local success, res = pcall(convert, child, currentPath)
                if success then
                    out[keyStr] = res
                else
                    out[keyStr] = {
                        ["$"] = "err",
                        message = tostring(res)
                    }
                end
            end

            return out
        end

        -- Fallback default
        return tostring(v)
    end

    return convert(val)
end

return Sanitizer