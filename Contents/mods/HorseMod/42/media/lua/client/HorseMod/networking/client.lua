---@namespace HorseMod

local commands = require("HorseMod/networking/commands")

local IS_DEBUG = isDebugEnabled()
local IS_CLIENT = isClient()

---@param str string
---@param ... any
local function log(str, ...)
    DebugLog.log("[HorseMod] [Networking] " .. string.format(str, ...))
end


---@type table<integer, fun(args: table)>
local commandHandlers = {}

---@type table<integer, ServerCommand>
local idCommandMap = {}

---@param module string
---@param command string
---@param args table?
local function handleServerCommand(module, command, args)
    if module ~= commands.MODULE then
        return
    end

    local id = tonumber(command)

    if not id then
        log(
            "could not convert command to id command=%s",
            command
        )
        return
    end
    id = math.floor(id)

    if not commandHandlers[id] then
        log(
            "received unknown command id=%d",
            id
        )
        return
    end

    local name = idCommandMap[id].name

    if not args then
        log(
            "received no args for command name=%s",
            name
        )
        return
    end
    
    commandHandlers[id](args)
end

Events.OnServerCommand.Add(handleServerCommand)

local function ensureAllCommandsHaveHandlers()
    ---@type string[]
    local missingHandlerNames = {}

    for i = 1, #commands.serverList do
        local command = commands.serverList[i]
        if not commandHandlers[command.id] then
            missingHandlerNames[#missingHandlerNames + 1] = command.name
        end
    end
    
    if #missingHandlerNames > 0 then
        error("no handler registered for command(s): " .. table.concat(missingHandlerNames, ", "))
    end
end

Events.OnGameStart.Add(ensureAllCommandsHaveHandlers)

local client = {}

---@generic T
---@param command ServerCommand<T>
---@param callback fun(args: T)
function client.registerCommandHandler(command, callback)
    if commandHandlers[command.id] ~= nil then
        if IS_DEBUG then
            log("WARN: overriding handler for command " .. command.name)
        else
            error("tried to register handler for already registered command " .. command.name)
        end
    end
    idCommandMap[command.id] = command
    commandHandlers[command.id] = callback
end

return client