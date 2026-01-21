---@namespace HorseMod

local spobjects = require("HorseMod/networking/spobjects")

local IS_CLIENT = isClient()
local IS_SERVER = isServer()
local IS_SINGLEPLAYER = not (IS_CLIENT or IS_SERVER)

local MODULE = "horsemod"

---@class Command<T: table>
---@field name string
---@field id integer

---Command sent by a client to the server.
---@class ClientCommand<T: table> : Command<T>
local ClientCommand = {}

---Sends the command to the server.
---@param sender IsoPlayer? Specific player sending the command. Nil if it doesn't matter.
---@param args T Arguments to send to the server.
function ClientCommand:send(sender, args)
    assert(not IS_SERVER, "tried to send client command from server, name=" .. self.name)
    if sender then
        sendClientCommand(sender, MODULE, tostring(self.id), args)
    else
        sendClientCommand(MODULE, tostring(self.id), args)
    end
end

---Command sent by the server to clients.
---@class ServerCommand<T: table> : Command<T>
local ServerCommand = {}

---Sends the command to the client(s).
---@param recipient IsoPlayer? Specific player to receive the command. Nil to send to all.
---@param args T Arguments to send to the client(s).
function ServerCommand:send(recipient, args)
    assert(not IS_CLIENT, "tried to send server command from client, name=" .. self.name)
    if IS_SERVER then
        if recipient then
            sendServerCommand(recipient, MODULE, tostring(self.id), args)
        else
            sendServerCommand(MODULE, tostring(self.id), args)
        end
    else
        triggerEvent("OnServerCommand", MODULE, tostring(self.id), args)
    end
end

---Framework for registering network commands.
---
---All commands must be registered in a shared module in a fixed order;
---that is, both the client and the server must register the same commands and in the same order.
---
---Command handlers are registered through the :lua:module:`HorseMod.networking.client` and :lua:module:`HorseMod.networking.server` modules.
---All commands must have a handler registered on the receiving end or an error will be raised.
local commands = {}

---@readonly
commands.MODULE = MODULE

---List of all registered server commands.
---@type ServerCommand[]
commands.serverList = {}

---List of all registered client commands.
---@type ClientCommand[]
commands.clientList = {}

---Registers a new server command.
---@generic T
---@param name string Name of the command. Used for debugging purposes only so it does not have to be unique or pretty.
---@return ServerCommand<T> command
function commands.registerServerCommand(name)
    local id = #commands.serverList + 1
    ---@type ServerCommand
    local command = setmetatable(
        {
            name = name,
            id = id
        },
        ServerCommand
    )

    commands.serverList[id] = command

    return command
end

---Registers a new client command.
---@generic T
---@param name string Name of the command. Used for debugging purposes only so it does not have to be unique or pretty.
---@return ClientCommand<T> command
function commands.registerClientCommand(name)
    local id = #commands.clientList + 1
    ---@type ClientCommand
    local command = setmetatable(
        {
            name = name,
            id = id
        },
        ClientCommand
    )

    commands.clientList[id] = command

    return command
end

---@param player IsoPlayer
---@return integer
---@nodiscard
function commands.getPlayerId(player)
    if IS_SINGLEPLAYER then
        return player:getIndex()
    end

    return player:getOnlineID()
end

---@param id integer
---@return IsoPlayer?
---@nodiscard
function commands.getPlayer(id)
    if IS_SINGLEPLAYER then
        return getSpecificPlayer(id)
    end

    return getPlayerByOnlineID(id)
end

---@param animal IsoAnimal
---@return integer
---@nodiscard
function commands.getAnimalId(animal)
    if IS_SINGLEPLAYER then
        return spobjects.animal:getOrAddId(animal)
    end

    return animal:getOnlineID()
end

---@param id integer
---@return IsoAnimal?
---@nodiscard
function commands.getAnimal(id)
    if IS_SINGLEPLAYER then
        return spobjects.animal:getObject(id)
    end
    
    return getAnimal(id)
end

return commands