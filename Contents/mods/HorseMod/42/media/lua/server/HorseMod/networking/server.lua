if isClient() then
    return
end

---@namespace HorseMod

local commands = require("HorseMod/networking/commands")

local IS_DEBUG = isDebugEnabled()

---@param str string
---@param ... any
local function log(str, ...)
    DebugLog.log("[HorseMod] [Networking] " .. string.format(str, ...))
end


---@type table<integer, fun(player: IsoPlayer, args: table)>
local commandHandlers = {}

---@type table<integer, ClientCommand>
local idCommandMap = {}

---@param module string
---@param command string
---@param player IsoPlayer
---@param args table?
local function handleClientCommand(module, command, player, args)
    if module ~= commands.MODULE then
        return
    end

    local id = tonumber(command)

    if not id then
        log(
            "could not convert command to id command=%s, player=%s",
            command,
            player:getUsername()
        )
        return
    end
    id = math.floor(id)

    if not commandHandlers[id] then
        log(
            "received unknown command id=%d, player=%s",
            id,
            player:getUsername()
        )
        return
    end

    local name = idCommandMap[id].name

    if not args then
        log(
            "received no args for command name=%s, player=%s",
            name,
            player:getUsername()
        )
        return
    end
    
    commandHandlers[id](player, args)
end

Events.OnClientCommand.Add(handleClientCommand)

local function ensureAllCommandsHaveHandlers()
    ---@type string[]
    local missingHandlerNames = {}

    for i = 1, #commands.clientList do
        local command = commands.clientList[i]
        if not commandHandlers[command.id] then
            missingHandlerNames[#missingHandlerNames + 1] = command.name
        end
    end
    
    if #missingHandlerNames > 0 then
        error("no handler registered for command(s): " .. table.concat(missingHandlerNames, ", "))
    end
end

Events.OnGameStart.Add(ensureAllCommandsHaveHandlers)

local server = {}

---@generic T
---@param command ClientCommand<T>
---@param callback fun(sender: IsoPlayer, args: T)
function server.registerCommandHandler(command, callback)
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

return server