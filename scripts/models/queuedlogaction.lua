--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Constants ]]
--------------------------------

local QUEUE_TIME               = 4
local QUEUE_REPEAT_MULT        = 1.5

local MAX_DELAY                = 9

--------------------------------
-- [[ Local Functions ]]
--------------------------------

--- @param data table
local function _GetStringFromStackableData(data)
    if table.empty(data) then
        return STRINGS.PEARL.LOGS.UNKNOWN
    end

    return PEARL.BuildFancyStringFor(data)
end

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class RepeatableLogAction
local RepeatableLogAction = Class(function(self, pattern)
    --- Represents the identity of the string.
    --- The static, unique, non-stackable part.
    --- This cannot be changed after the first init!
    --- @type string
    self.pattern = pattern

    --- @type integer
    self.timestart = os.time()

    --- @type table<GUID, boolean>?
    self.targets = nil

    --- @type table<name, value>
    self.stackable = nil

    --- We use logtype when dealing with announcements displayed in-game.
    --- @type string?
    self.logtype = nil

    --- For silent announcements displayed outside, changing the icon should be enough.
    --- @type string?
    self.icon = nil

    -- By default everything is silent if not explicitly stated otherwise.
    --- @type boolean
    self.silent = true

    --- @type integer
    self.queuetime = QUEUE_TIME
    --- @type integer
    self.queuetimemult = QUEUE_REPEAT_MULT

    self.logged = false
    self.initialized = false

    --- @type fun(action: RepeatableLogAction)
    self.logfn = nil
    --- @type fun(action: RepeatableLogAction)
    self.initfn = nil

    --- @type Task?
    self.task = nil
end)

--------------------------------
-- [[ Static ]]
--------------------------------

RepeatableLogAction.FIELDS  = {
    DOER        = "doer",
    OWNER       = "owner",
    SOURCE      = "source",
    TOOL        = "tool",
    TARGET      = "target",
    REMAINING   = "remaining",
    ITEM        = "item",
}

--------------------------------
-- [[ Meta Methods ]]
--------------------------------

function RepeatableLogAction:__tostring()
    return "RepeatableLogAction["..(self.pattern or "").."]"
end

--------------------------------
-- [[ Setters ]]
--------------------------------

--- @param target string|EntityScript
--- @param stacksize integer? Optional stacksize override for case where the target's stacksize cannot be used.
--- @return RepeatableLogAction
function RepeatableLogAction:AddTarget(target, stacksize, ...)
    if not target then
        return self
    end

    if EntityScript.is_instance(target) then
        if not self.targets then
            self.targets = {}
        elseif self.targets[target.GUID] == true then
            return self -- Ignore this target!
        end

        -- Only stackable entities are allowed to be reused.
        if target.GUID and not target.components.stackable then
            self.targets[target.GUID] = true
        end
    end

    return self:AddToStackableField(self.FIELDS.TARGET, target, stacksize, ...)
end

function RepeatableLogAction:AddTargets(targets, ...)
    if EntityScript.is_instance(targets) then
        return self:AddTarget(targets, ...)
    end

    for _, target in ipairs(targets) do
        self:AddTarget(target, ...)
    end

    return self
end

--- @return RepeatableLogAction
function RepeatableLogAction:SetColorEntity(entity)
    if EntityScript.is_instance(entity) then
        self.colorentity = entity
    elseif type(entity) == "table" then
        self.colorentity = entity.entity
    end

    return self
end

--- @return RepeatableLogAction
function RepeatableLogAction:SetIsSilent(silent)
    -- By default silent is set to true.
    -- Non-silent announcements have higher priority than silent ones,
    -- so when stacking actions keep that in mind so they are not overriden.
    if self.silent ~= false then
        self.silent = silent
    end

    return self
end

--- @return RepeatableLogAction
function RepeatableLogAction:SetQueueTime(time)
    if self.queuetime ~= time then
        self.queuetime = time

        if self.task then
            self.task:settime(self.queuetime)
            self.task:restart()
        end
    end

    return self
end

--- The multiplier used to calculate the new queuetime
--- after an action was repeated.
--- @return RepeatableLogAction
function RepeatableLogAction:SetQueueTimeMult(mult)
    self.queuetimemult = mult

    return self
end

--- @return RepeatableLogAction
function RepeatableLogAction:AddToStackableField(field, key, stacksize, noprefix)
    PEARL.debug("RepeatableLogAction:AddToStackableField", field)

    -- Ensure that the field exists
    if not self:HasStackableField(field) then
        self:SetStackableField(field, {})
    end

    local name = key
    --- Handle name being the entity.
    if EntityScript.is_instance(name) then
        name = PEARL.GetStandardizedNameFor(name, noprefix)
    end

    if type(name) ~= "string" then
        PEARL.error("Invalid name provided for dynamic field!", field, name, stacksize)
        return self
    end

    stacksize = tonumber(stacksize) or PEARL.GetStackSize(key) or 1
    self.stackable[field][name] = (self.stackable[field][name] or 0) + stacksize

    return self
end

--- Always overrides the value provided for the name.
--- @return RepeatableLogAction
function RepeatableLogAction:SetStackableField(field, value)
    PEARL.debug("QueuedLogAction:SetStackableField", field, value)
    if EntityScript.is_instance(value) then
        value = value:GetStandardizedName()
    end

    if not self.stackable then
        self.stackable = {}
    end

    self.stackable[field] = value

    return self
end

--- Not only that this can set the predefined icon on discord,
--- but it also changes the icon used in the game.
--- @return RepeatableLogAction
function RepeatableLogAction:SetLogType(ltp)
    self.logtype = ltp

    return self
end

--- @return RepeatableLogAction
function RepeatableLogAction:SetIcon(icon)
    self.icon = icon

    return self
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function RepeatableLogAction:HasStackableField(field)
    return self.stackable and self.stackable[field] ~= nil or false
end

function RepeatableLogAction:GetString()
    if table.empty(self.stackable) ~= false then
        return self.pattern -- No changes
    end

    local str = self.pattern
    for name, value in pairs(self.stackable) do
        value = type(value) == "table" and _GetStringFromStackableData(value) or value
        str = str:nformat(name, value)
    end

    return str
end

--- Stackable actions are defined as action with at least one dynamic field.
--- @return boolean
function RepeatableLogAction:IsStackable()
    return self.stackable and not table.empty(self.stackable)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function RepeatableLogAction:CancelTask()
    if self.task then
        self.task:cancel()
        self.task = nil
    end
end

--- @param timeoutfn function Called after "queuetime" when no repetition happened.
function RepeatableLogAction:WaitForRepetition(timeoutfn)
    if self.task then
        self.task:settime(self.queuetime)
        self.task:setcb(timeoutfn)
        self.task:restart()
    else
        self.task = PEARL.WallScheduler:ExecuteInTime(self.queuetime, timeoutfn)
    end
end

--- @return boolean success
function RepeatableLogAction:Repeat()
    if self.task and self.timestart and (os.time() - self.timestart) < MAX_DELAY then
        self.task:settime(self.queuetime * self.queuetimemult)
        self.task:restart()

        return true
    end

    return false
end

--------------------------------
-- [[ Return ]]
--------------------------------

return RepeatableLogAction
