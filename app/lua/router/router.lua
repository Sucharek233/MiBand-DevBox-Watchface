local Router = {}
Router.__index = Router

function Router:new()
    local obj = {
        routes = {}
    }

    setmetatable(obj, self)
    return obj
end

function Router:register(type, handler)
    self.routes[type] = handler
end

function Router:handle(message)
    local handler = self.routes[message.type]
    if not handler then
        return {
            state = "error",
            reason = "Bad type",
            type = message.type
        }
    end
    return handler(message)
end

return Router