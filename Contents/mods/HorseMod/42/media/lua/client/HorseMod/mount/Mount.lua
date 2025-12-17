local MountController = require("HorseMod/mount/MountController")
local HorseDamage = require("HorseMod/horse/HorseDamage")
local HorseUtils = require("HorseMod/Utils")
local AnimationVariables = require("HorseMod/AnimationVariables")


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


---@namespace HorseMod


---Main handler of player mounting horse state.
---@class Mount
---
---@field pair MountPair
---
---@field controller MountController
local Mount = {}
Mount.__index = Mount


---@return MountController.Input
---@nodiscard
function Mount:getCurrentInput()
    local x = 0.0
    local y = 0.0
    local run = false

    local pad = self.pair.rider:getJoypadBind()
    if pad >= 0 then
        -- controller input
        x = getJoypadMovementAxisX(pad)
        y = getJoypadMovementAxisY(pad)

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
    else
        -- keyboard input
        local core = getCore()

        if isKeyDown(core:getKey("Forward")) then 
            y = y - 1
        end

        if isKeyDown(core:getKey("Backward")) then
            y = y + 1
        end

        if isKeyDown(core:getKey("Left")) then
            x = x - 1
        end

        if isKeyDown(core:getKey("Right")) then
            x = x + 1
        end

        run = isKeyDown(core:getKey("Run")) or isKeyDown(core:getKey("Sprint"))
    end

    return {
        movement = {
            x = x,
            y = y
        },
        run = run,
        -- FIXME: Change this when fixing the mod option keybinds
        trot = self.pair.mount:getVariableBoolean(AnimationVariables.TROT),
    }
end


---@return boolean
---@nodiscard
function Mount:dying()
    if self.pair.mount:getVariableBoolean(AnimationVariables.DYING) then
        self.pair.rider:setIgnoreMovement(true)
        self.pair.rider:setBlockMovement(true)
        self.pair.rider:setIgnoreInputsForDirection(true)
        self.pair.rider:setVariable(AnimationVariables.DYING, true)
        HorseUtils.runAfter(0.5, function()
            HorseDamage.knockDownNearbyZombies(self.pair.mount)
        end)
        return true
    else
        return false
    end
end


function Mount:update()
    local input = self:getCurrentInput()
    if self.pair.mount and self:dying() then
        return
    end
    self.controller:update(input)
end


function Mount:cleanup()
    self.pair:setAnimationVariable(AnimationVariables.RIDING_HORSE, false)
    self.pair:setAnimationVariable(AnimationVariables.TROT, false)

    local attached = self.pair.rider:getAttachedAnimals()
    attached:remove(self.pair.mount)
    self.pair.mount:getData():setAttachedPlayer(nil)

    self.pair.mount:getBehavior():setBlockMovement(false)
    self.pair.mount:getPathFindBehavior2():reset()

    self.pair.rider:setVariable(AnimationVariables.TROT, false)
    self.pair.rider:setVariable(AnimationVariables.DISMOUNT_STARTED, false)
    self.pair.rider:setAllowRun(true)
    self.pair.rider:setAllowSprint(true)
    self.pair.rider:setTurnDelta(1)
    self.pair.rider:setSneaking(false)
    self.pair.rider:setIgnoreAutoVault(false)

    self.pair.mount:setVariable("bPathfind", false)
    self.pair.mount:setVariable("animalWalking", false)
    self.pair.mount:setVariable("animalRunning", false)

    self.pair.rider:setVariable(AnimationVariables.MOUNTING_HORSE, false)
    self.pair.rider:setVariable("isTurningLeft", false)
    self.pair.rider:setVariable("isTurningRight", false)
end


---@param pair MountPair
---@return Mount
---@nodiscard
function Mount.new(pair)
    pair.rider:getAttachedAnimals():add(pair.mount)
    pair.mount:getData():setAttachedPlayer(pair.rider)

    pair:setAnimationVariable(AnimationVariables.RIDING_HORSE, true)
    pair:setAnimationVariable(AnimationVariables.TROT, false)
    pair.rider:setAllowRun(false)
    pair.rider:setAllowSprint(false)

    pair.rider:setTurnDelta(0.65)

    pair.rider:setVariable("isTurningLeft", false)
    pair.rider:setVariable("isTurningRight", false)

    local geneSpeed = pair.mount:getUsedGene("speed"):getCurrentValue()
    pair.rider:setVariable(AnimationVariables.GENE_SPEED, geneSpeed)

    pair.mount:getPathFindBehavior2():reset()
    pair.mount:getBehavior():setBlockMovement(true)
    pair.mount:stopAllMovementNow()

    pair.mount:setVariable("bPathfind", false)
    pair.mount:setVariable("animalWalking", false)
    pair.mount:setVariable("animalRunning", false)

    -- TODO: are these even needed
    pair.mount:setWild(false)
    pair.mount:setVariable(AnimationVariables.IS_HORSE, true)

    local o = setmetatable(
        {
            pair = pair
        },
        Mount
    )

    o.controller = MountController.new(o)

    return o
end


return Mount