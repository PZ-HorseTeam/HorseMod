---@namespace HorseMod

local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local ModOptions = require("HorseMod/ModOptions")

local JOY_DEADZONE        = 0.30   -- ignore tiny stick drift
local JOY_DIGITAL_THRESHOLD  = 0.55   -- cross this to count as -1 / +1 on that axis


---@param v number
---@return number
---@nodiscard
local function processJoypadAxisInput(v)
    if math.abs(v) < JOY_DEADZONE then
        return 0
    end

    if v > JOY_DIGITAL_THRESHOLD then
        return 1
    end

    if v < -JOY_DIGITAL_THRESHOLD then
        return -1
    end

    return 0
end

---@param playerIndex integer
---@return boolean
---@nodiscard
local function joypadHasUIFocus(playerIndex)
    local data = JoypadState.players[playerIndex + 1]

    if not data then
        return false
    end

    return data.focus and data.focus:isVisible() or false
end


---@class InputManager
---
---Parent mount.
---@field mount Mount
---
---Whether the left joypad bumper was pressed last time the input was polled.
---@field lastJoypadLB boolean
local InputManager = {}
InputManager.__index = InputManager


---@class InputManager.Input
---@field movement {x: number, y: number}
---@field run boolean
---@field trot boolean


---@param pad integer
---@return InputManager.Input
---@nodiscard
function InputManager:getJoypadInput(pad)
    local x = getJoypadMovementAxisX(pad)
    local y = getJoypadMovementAxisY(pad)

    x = processJoypadAxisInput(x)
    y = processJoypadAxisInput(y)

    -- dpad, only active if the joystick is netural
    if x == 0 or y == 0 then
        local povx = getControllerPovX(pad)
        local povy = getControllerPovY(pad)

        if x == 0 then
            x = processJoypadAxisInput(povx)
        end

        if y == 0 then
            y = processJoypadAxisInput(povy)
        end
    end

    local run = false

    local rb = getJoypadRBumper(pad)
    if rb ~= -1 and isJoypadPressed(pad, rb) then
        run = true
    end

    local b = getJoypadBButton(pad)
    if b ~= -1 and isJoypadPressed(pad, b) then
        run = true
    end

    if isJoypadRTPressed(pad) then
        run = true
    end

    local lbPressed = isJoypadLBPressed(pad)
    if lbPressed and not self.lastJoypadLB then
        local rider = self.mount.pair.rider
        if not joypadHasUIFocus(rider:getPlayerNum()) then
            self.mount.controller:toggleTrot()
        end
    end
    self.lastJoypadLB = lbPressed

    return {
        movement = {
            x = x,
            y = y
        },
        run = run,
        trot = self.mount.pair.mount:getVariableBoolean(AnimationVariable.TROT)
    }
end


---@return InputManager.Input
---@nodiscard
function InputManager:getKeyboardInput()
    local CORE = getCore()

    local x = 0.0
    local y = 0.0
    local run = false

    if isKeyDown(CORE:getKey("Forward")) then 
        y = y - 1
    end

    if isKeyDown(CORE:getKey("Backward")) then
        y = y + 1
    end

    if isKeyDown(CORE:getKey("Left")) then
        x = x - 1
    end

    if isKeyDown(CORE:getKey("Right")) then
        x = x + 1
    end

    run = isKeyDown(ModOptions.HorseGallopButton)

    return {
        movement = {
            x = x,
            y = y
        },
        run = run,
        trot = self.mount.pair.mount:getVariableBoolean(AnimationVariable.TROT)
    }
end


---@return InputManager.Input
---@nodiscard
function InputManager:getCurrentInput()
    local pad = self.mount.pair.rider:getJoypadBind()
    if pad >= 0 then
        return self:getJoypadInput(pad)
    end

    return self:getKeyboardInput()
end


---@param key integer
function InputManager:keyPressed(key)
    if key == ModOptions.HorseTrotButton then
        self.mount.controller:toggleTrot()
    elseif key == ModOptions.HorseJumpButton then
        local controller = self.mount.controller
        if controller:canJump() then
            controller:jump()
        end
    end
end


---@param mount Mount
---@return self
function InputManager.new(mount)
    return setmetatable(
        {
            mount = mount,
            lastJoypadLB = false
        },
        InputManager
    )
end


return InputManager
