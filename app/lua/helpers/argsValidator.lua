local ArgsValidator = {}

function ArgsValidator.validate(args, schema)
    args = args or {}

    local required = schema.required or {}
    local optional = schema.optional or {}

    local allowed = {}

    -- Required arguments
    for name, expectedType in pairs(required) do
        allowed[name] = true

        if args[name] == nil then
            return false, name .. " missing"
        end

        if type(args[name]) ~= expectedType then
            return false, name .. " must be " .. expectedType
        end
    end

    -- Optional arguments
    for name, definition in pairs(optional) do
        allowed[name] = true

        if args[name] == nil then
            if definition.default ~= nil then
                args[name] = definition.default
            end
        elseif type(args[name]) ~= definition.type then
            return false, name .. " must be " .. definition.type
        end
    end

    -- Reject unknown arguments
    for name in pairs(args) do
        if name ~= "type" and not allowed[name] then
            return false, name .. " not allowed"
        end
    end

    return true
end

return ArgsValidator