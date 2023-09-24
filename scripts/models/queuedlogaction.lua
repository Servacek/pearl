--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Constants ]]
--------------------------------

local QUEUE_TIME        = 4
local QUEUE_REPEAT_MULT = 2

local MAX_DELAY         = 15

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class QueuedLogAction
local QueuedLogAction = Class(function(self, pattern)
    --- @type string
    self.pattern = pattern

    --- @type number
    self.timestart = os.time()

    --- @type table<name, count>?
    self.targets = nil

    --- @type table<name, value>
    self.data = nil

    --- @type string?
    self.logtype = nil
    --- @type fun(data: table<name, value>)
    self.datafn = nil

    --- @type fun(action)
    self.queuefn = nil
    self.queuefninst = nil

    --- @type number
    self.queuetime = QUEUE_TIME
    --- @type number
    self.queuetimemult = QUEUE_REPEAT_MULT

    self.queued = false

    --- @type Task?
    self.task = nil
end)

--------------------------------
-- [[ Static ]]
--------------------------------

QueuedLogAction.STATIC_FIELDS = {
    DOER        = "doer",
    OWNER       = "owner",
    SOURCE      = "source",
    TOOL        = "tool",
}

QueuedLogAction.DYNAMIC_FIELDS = {
    TARGET      = "target",
    REMAINING   = "remaining",
}

--------------------------------
-- [[ Private ]]
--------------------------------

function QueuedLogAction:_GetTargetString()
    if not self:HasAnyTargets() then
        return STRINGS.PEARL.LOGS.UNKNOWN
    end

    return PEARL.BuildFancyStringFor(self.targets)
end

--------------------------------
-- [[ Setters ]]
--------------------------------

--- @param target string|EntityScript
--- @param stacksize integer? Optional stacksize override for case where the target's stacksize cannot be used.
--- @return QueuedLogAction
function QueuedLogAction:AddTarget(target, stacksize)
    if target == nil then
        return self
    end

    if type(self.targets) ~= "table" then
        self.targets = {}
    end

    local name = PEARL.GetStandardizedNameFor(target)
    stacksize = tonumber(stacksize) or PEARL.GetStackSize(target) or 1
    PEARL.debug("QueuedLogAction:AddTarget", name, stacksize)
    self.targets[name] = (self.targets[name] or 0) + stacksize

    return self
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
    --- @type Task
    self.task = task

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetIsSilent(silent)
    self.silent = silent

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetQueueFn(fn, inst)
    self.queuefn = fn
    self.queuefninst = inst

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
function QueuedLogAction:SetFormatDataFn(datafn)
    self.datafn = datafn

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetStaticField(name, value)
    if not value or not name or self.queued then
        return self
    end

    if EntityScript.is_instance(value) then
        value = value:GetStandardizedName()
    end

    self.pattern = self.pattern:nformat(name, value)

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetDynamicField(name, value)
    if not value or not name then
        return self
    end

    if EntityScript.is_instance(value) then
        value = value:GetStandardizedName()
    end

    if not self.data then
        self.data = {}
    end

    self.data[name] = value

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetData(data)
    self.data = data

    return self
end

--- @return QueuedLogAction
function QueuedLogAction:SetLogType(ltp)
    self.logtype = ltp

    return self
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function QueuedLogAction:HasAnyTargets()
    return type(self.targets) == "table" and not table.empty(self.targets)
end

function QueuedLogAction:GetString()
    self.data = self.data or {}
    if type(self.datafn) == "function" then
        self.datafn(self.data)
    end

    -- Assing dynamic data fields
    self.data.target = self:_GetTargetString()

    return self.pattern:nformat(self.data)
end

--- @return boolean
function QueuedLogAction:IsInQueue()
    return self.queued
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

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
        self.task:cancel()
        self.task = nil
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return QueuedLogAction
