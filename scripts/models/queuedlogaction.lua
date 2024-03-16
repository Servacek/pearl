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

--- @class QueuedLogAction
local QueuedLogAction = Class(function(self, pattern)
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

    self.queued = false

    --- @type Task?
    self.task = nil
end)

--------------------------------
-- [[ Static ]]
--------------------------------

QueuedLogAction.FIELDS  = {
    DOER        = "doer",
    OWNER       = "owner",
    SOURCE      = "source",
    TOOL        = "tool",
    TARGET      = "target",
    REMAINING   = "remaining",
    ITEM        = "item",
}

--------------------------------
-- [[ Setters ]]
--------------------------------

--- @param target string|EntityScript
--- @param stacksize integer? Optional stacksize override for case where the target's stacksize cannot be used.
--- @return QueuedLogAction
function QueuedLogAction:AddTarget(target, stacksize, ...)
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

function QueuedLogAction:AddTargets(targets, ...)
    for _, target in ipairs(targets) do
        self:AddTarget(target, ...)
    end
end

--- @return QueuedLogAction
function QueuedLogAction:SetColorEntity(entity)
    if EntityScript.is_instance(entity) then
        self.colorentity = entity
    elseif type(entity) == "table" then
        self.colorentity = entity.entity
    end

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetQueueTask(task)
    if self.task then
        PEARL.warn("Queue task already!")
    end

    --- @type Task
    self.task = task

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetIsSilent(silent)
    -- By default silent is set to true.
    -- Non-silent announcements have higher priority than silent ones,
    -- so when stacking actions keep that in mind so they are not overriden.
    if self.silent ~= false then
        self.silent = silent
    end

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetQueueTime(time)
    if self.queuetime ~= time then
        self.queuetime = time

        if self.task then
            self.task:settime(self.queuetime)
            self.task:restart()
        end
    end

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetQueueTimeMult(mult)
    self.queuetimemult = mult

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:AddToStackableField(field, key, stacksize, noprefix)
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
--- @return QueuedLogAction
function QueuedLogAction:SetStackableField(field, value)
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

--- @return QueuedLogAction
function QueuedLogAction:SetLogType(ltp)
    self.logtype = ltp

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetIcon(icon)
    self.icon = icon

    return self
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function QueuedLogAction:HasStackableField(field)
    return self.stackable and self.stackable[field] ~= nil or false
end

function QueuedLogAction:GetString()
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

--- @return boolean
function QueuedLogAction:IsInQueue()
    return self.queued
end

--- Stackable actions are defined as action with at least one dynamic field.
--- @return boolean
function QueuedLogAction:IsStackable()
    return self.stackable and not table.empty(self.stackable)
end

function QueuedLogAction:IsExecutable()
    return self.task ~= nil
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function QueuedLogAction:CancelQueueTask()
    if self.task then
        self.task:cancel()
        self.task = nil
    end
end

--- @param cb function
function QueuedLogAction:StartQueueTask(cb)
    if self.task then
        self.task:settime(self.queuetime)
        self.task:setcb(cb)
        self.task:restart()
    end
end

function QueuedLogAction:Repeat()
    if not self.task or not self.timestart then
        return self
    end

    if (os.time() - self.timestart) < MAX_DELAY then
        self.task:settime(self.queuetime * self.queuetimemult)
        self.task:restart()

        return self
    end

    -- Log it immediately.
    self:Execute()

    return self
end

function QueuedLogAction:Queue()
    if self.queued then
        return self
    end

    if type(self.queuefn) == "function" then
        self.queuefn(self, self.queuefninst)
    end

    self.queued = true

    return self
end

function QueuedLogAction:Execute()
    if self.task then
        self.task:run()
        self:CancelQueueTask()
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return QueuedLogAction
