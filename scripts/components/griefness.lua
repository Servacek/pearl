
local WARNING_HEALTH_PENALTY = 10
local WARNING_ATTACK_TYPE = "electric"
local WARNING_SANITY_PENALTY = TUNING.SANITY_MED

-----------------------------------------------
-- [[ Private Functions ]]
-----------------------------------------------

local function DoDrainTask(inst, self)
    if self.drain_delay <= GetTime() and self.draining and self.current > 0 then
        self:DoDelta(-self.drain_rate)
    end
end

-----------------------------------------------
-- [[ Initialization ]]
-----------------------------------------------

local Griefness = Class(function(self, inst)
    self.inst = inst
    self.max = SUB.CONSTS.GRIEFNESS_MAX
    self.current = 0

    self.warn_level = 0
    self.warn_threshold = .4
    self.max_warn_level = SUB.CONSTS.GRIEFNESS_MAX_WARNINGS

    self.draining = false
    self.drain_rate = SUB.CONSTS.GRIEFNESS_DRAIN_RATE
    self.drain_delay = 0
    self.drain_period = SUB.CONSTS.GRIEFNESS_DRAIN_PERIOD

    self.drain_task = self.inst:DoPeriodicTask(
        self.drain_period, DoDrainTask, nil, self
    )

    -- Deprecated: Now we use a periodic task with a delay instead.
    -- Decrement the amount of griefness on every day
    -- self.inst:WatchWorldState("cycles", oncycleschanged)
end)

-----------------------------------------------
-- [[ Public Member Functions ]]
-----------------------------------------------

function Griefness:GetCurrent()
    return self.current
end

function Griefness:GetWarnLevel()
    return self.warn_level
end

function Griefness:GetPercent()
    return self.current / self.max
end

function Griefness:IsSuspicious()
    return self:GetPercent() >= .2
end

function Griefness:Pause()
    self.draining = false
end

function Griefness:Resume()
    self.draining = true
end

function Griefness:IsPaused()
    return self.draining
end

function Griefness:DelayDrain(time)
    if time > 0 then
        self.drain_delay = math.max(self.drain_delay, GetTime() + time)
    end

    return self.drain_delay
end

function Griefness:CalcWarnLevel()
    return math.floor(self:GetPercent() / self.warn_threshold)
end

function Griefness:DoDelta(delta)
    if not delta then
        return
    end

    if delta > 0 then
        self:_OnIncrement()
    end
    -- Apply the age multiplier
    if self.inst.components and self.inst.components.age then
        delta = delta * (1 - math.min(self.inst.components.age:GetPercent(), 0.4))
    end

    SUB.debug("Adding", delta, "griefness to", self.inst.userid)
    self.current = math.clump(self.current + delta, 0, self.max)
    self.inst:PushEvent("sub_griefnessdelta")

    local new_warn_level = self:CalcWarnLevel()
    if self.warn_level < new_warn_level then
        self:DoWarning()
    end
    self.warn_level = new_warn_level

    if self.current >= self.max and self.warn_level > 0 then
        self:DoGracefullBan()
    end

    SUB.debug("Total griefness count", self.griefness, "Warn level:", self.warn_level)

    return self.current
end

function Griefness:DoWarning()
    SUB.debug("Sending a warning to", self.inst.userid)

    self.warn_level = self.warn_level + 1

    if self.inst.components then
        -- Drop the equiped item
        if self.inst.components.inventory then
            local handitem = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if handitem then
                Launch(self.inst.components.inventory:DropItem(handitem), self.inst, 3)
            end
        end

        -- Electric shock and -10 * warning_count HP
        if self.inst.components.combat then
            self.inst.components.combat:GetAttacked(
                nil, WARNING_HEALTH_PENALTY * self.warn_level, nil, WARNING_ATTACK_TYPE
            )
        end

        -- Change state
        if not self.inst.sg:HasStateTag("busy") then
            self.inst.sg:GoToState("hit")
        end

        -- Decrease the sanity
        if self.inst.components.sanity then
            self.inst.components.sanity:DoDelta(
                -WARNING_SANITY_PENALTY * self.warn_level
            )
        end

        -- TODO: Create custom strings for each warning level
        if self.inst.components.talker then
            self.inst.components.talker:Say(
                SUB.STRINGS.GRIEFER_WARNINGS[self.warn_level][
                    math.random(#SUB.STRINGS.GRIEFER_WARNINGS)
                ]
            )
        end
    end

    return self.warnings
end

function Griefness:DoGracefullBan()
    self.inst:DoTaskInTime(2, function()
        if self.inst.components then
            -- Drop the inventory before the ban
            if self.inst.components.inventory then
                self.inst.components.inventory:DropEverything()
            end

            if self.inst.components.talker then
                self.inst.components.talker:Say(SUB.STRINGS.GRIEFER_BAN)
            end
        end

        -- Let's ban them in style
        self.inst.sg:GoToState("teleportato_teleport")
    end)

    SUB.Scheduler:ExecuteInTime(5, function()
        SUB.info("Banning player", self.inst:GetDisplayName(), "for being a griefer.")
        TheNet:BanForTime(self.inst.userid, SUB.CONSTS.GRIEFER_BAN_TIME)
    end)
end

-----------------------------------------------
-- [[ Private Action Handlers ]]
-----------------------------------------------

function Griefness:_OnIncrement()
    -- Do not drain the griefness immediately
    self:DelayDrain(SUB.CONSTS.GRIEFNESS_DRAIN_DELAY)

    -- -- Check if we should warn the player
    -- if self.warn_level < self:CalcWarnLevel() then
    --     self:DoWarning()
    -- end
end

function Griefness:OnRemoveFromEntity()
    if self.drain_task then
        self.drain_task:Cancel()
        self.drain_task = nil
    end
end

function Griefness:OnSave(...)
    -- TODO: Maybe some day we are going to save some info
    -- about the player griefing in the past?
end

function Griefness:OnLoad(...)
    -- TODO: Maybe some day we are going to save some info
    -- about the player griefing in the past?
end

-----------------------------------------------

return Griefness
