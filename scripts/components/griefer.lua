-- local SUB = SUB
-- local EQUIPSLOTS = EQUIPSLOTS
-- local Class, Launch = Class, Launch
-- local TheNet = TheNet
-- local math, string = math, string

-- local DEFAULT_POINTS_COUNT      = 1
-- local DEFAULT_PER_ENT           = 1
-- local UPDATE_POINTS_COUNT       = 9
-- local POINTS_FOR_EXTINGUISH     = 3

-- -- local POINTS_MULT_NEWCOMER      = 2
-- -- local POINTS_DIVS_TRUSTWORTHY   = 2

-- local WARNING_COUNT             = 2
-- local POINTS_DEADLINE           = 18
-- local MAX_POINTS                = 6

-- -------------------------------------

-- local function doextinguishextask(pos)
--     if not pos then return end

--     SUB.ExtinguishFiresNear(pos.x, pos.y, pos.z)
--     TheNet:Announce(SUB.STRINGS.EXTINGUISH)
-- end

-- local function oncycleschanged(inst)
--     if inst and inst.components and inst.components.grifer ~= nil then
--         if inst.components.griefer:HasGriefed() then
--             inst.components.griefer:DoDelta(-UPDATE_POINTS_COUNT)
--         end
--     end
-- end

-- -------------------------------------

-- local Griefer = Class(function(self, inst)
--     self.inst = inst
--     self.griefness = 0
--     self.max_griefness = POINTS_DEADLINE
--     -- TODO: Create a reputation system
--     self.reputation = 0
--     self.warnings = 0

--     self.exttask = nil

--     -- Decrement the
--     self.inst:WatchWorldState("cycles", oncycleschanged)
-- end)

-- function Griefer:GetGriefness()
--     return self.griefness
-- end

-- function Griefer:GetGriefnessPercent()
--     return self.griefness / self.max_griefness
-- end

-- function Griefer:HasGriefed()
--     return self.griefness and self.warnings
--     and self.griefness > 0 or self.warnings > 0
-- end

-- function Griefer:HasWarnings()
--     return self.warnings and self.warnings > 0
-- end

-- function Griefer:ShouldBeWarned()
--     SUB.debug("Checking for warnings...")

--     return self.warnings < math.floor(
--         self.griefness / (self.max_griefness * (1 / (WARNING_COUNT + 1)))
--     )
-- end

-- function Griefer:ShouldBeBanned()
--     -- The player has exceeded the max grief attempts count
--     return self.griefness >= POINTS_DEADLINE
-- end

-- function Griefer:StartExtTask(center_xyz)
--     -- Check if the task has finished
--     if not self.exttask or not self.exttask.limit or self.exttask.limit <= 0 then
--         -- The scheduler should take care of cleaning up the task
--         -- after the execution. So no explicit calls to :Cancel() here.
--         self.exttask = SUB.Scheduler:ExecuteInTime(
--             4, doextinguishextask, nil, center_xyz
--         )
--     end
-- end

-- function Griefer:PrepareForBan()
--     if self.inst.components then
--         -- Drop the inventory before the ban
--         if self.inst.components.inventory then
--             self.inst.components.inventory:DropEverything()
--         end

--         if self.inst.components.talker then
--             self.inst.components.talker:Say(SUB.STRINGS.GRIEFER_BAN)
--         end
--     end

--     -- Let's ban them in style
--     self.inst.sg:GoToState("teleportato_teleport")

--     -- Cleanup some of the variables
--     self.griefness = 0
--     self.warnings = 0
--     self.reputation = 0
-- end

-- function Griefer:GetDebugString()
--     return string.format(
--         "<griefness: %d/%d, warnings: %d, reputation: %d>",
--         self.griefness, MAX_POINTS, self.warnings, self.reputation
--     )
-- end

-- ----------------------------------

-- function Griefer:OnExtinguishedFires()
--     self:DoDelta(-POINTS_FOR_EXTINGUISH)
-- end

-- function Griefer:OnSave(...)
--     -- TODO: This should be implemented with the reputation system,
--     -- since we want to save the reputation count.
-- end

-- function Griefer:OnLoad(...)
--     -- TODO: Maybe saving the saved reputation here?
-- end

-- function Griefer:OnRemoveFromEntity()
--     if self.exttask then
--         -- If the ext task was not already executed
--         -- force-call it
--         if self.exttask.fn and self.exttask.limit > 0 then
--             self.exttask.fn(self.exttask.args)
--         end

--         self.exttask:Cancel()
--         self.exttask = nil
--     end

--     self.inst:StopWatchingWorldState("phase", onphasechanged)
-- end

-- return Griefer