--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local QueuedLogAction = PEARL.loadfile("models/queuedlogaction")

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ActionLog
local ActionLog = {
    --- @type table<string, table<string, any>>
    _queue = {},
    _queueindex = {},
}

--------------------------------
-- [[ Private Methods ]]
--------------------------------

--- @param action QueuedLogAction
local function _OnActionInitialized(action)
    if not action:IsExecutable() then
        return
    end

    -- The action did not manage to become stackable during its construction,
    -- so it won't be added to the queue but logged right away.
    if not action:IsStackable() then
        ActionLog:LogAction(action)
        return
    end

    ActionLog:QueueAction(action)
    action:StartQueueTask(function()
        ActionLog:LogAction(action)
    end)
end

--- @param pattern string
--- @return QueuedLogAction
local function _InitializeAction(pattern)
    print("initialize action")
    local action = QueuedLogAction(pattern)

    -- Wait a tick until the action is fully constructed.
    return action:SetQueueTask(PEARL.WallScheduler:ExecutePeriodic(0, function()
        print("INIT")
        _OnActionInitialized(action)
    end, 2)) -- 1. Initialization, 2. Queue (optional)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- @param pattern string Retrive the specific action bound to the provided pattern.
--- Pattern should be always unique per action.
function ActionLog:GetQueuedAction(pattern)
    return self._queue[pattern]
end

--- @param pattern string Retrive the specific actions index.
--- @return integer?
function ActionLog:GetQueuedActionIndex(pattern)
    return table.index(self._queueindex, pattern)
end

--- @param pattern string Removes from the queue action with the provided pattern.
function ActionLog:DequeueAction(pattern)
    self._queue[pattern] = nil
    table.remove(self._queueindex, self:GetQueuedActionIndex(pattern))
end

--- @param action QueuedLogAction
function ActionLog:QueueAction(action)
    self._queue[action.pattern] = action
    self._queueindex[#self._queueindex+1] = action.pattern
end

function ActionLog:Log(ent, tp, str, slt, icon)
    return PEARL.AnnounceWithType(
        str, tp, (ent and ent.entity or ent), slt, icon
    )
end

--- @param action QueuedLogAction
function ActionLog:LogAction(action)
    PEARL.debug("ActionLog:LogAction")
    local index = self:GetQueuedActionIndex(action.pattern) or 1
    for i = 1, index do
        local queued = self._queue[self._queueindex[i]]
        self:DequeueAction(queued.pattern)

        -- Prevent the action from being logged twice.
        queued:CancelQueueTask()

        self:Log(
            queued.colorentity, queued.logtype, queued:GetString(), queued.silent, queued.icon
        )
    end
end

--- @param p string The initial pattern of the action.
--- @param sn string|table? The name of the static field in the pattern or the formatting table for the given pattern.
--- @param sv string? The value of the "sn" field, if provided.
--- @return QueuedLogAction action The current action for the given pattern built up from the static data provided.
function ActionLog:Act(p, sn, sv)
    if sn then
        -- Handle sv being an entity
        if sv and EntityScript.is_instance(sv) then
            sv = sv:GetFancyName()
        end

        -- Handle sn being a table of entities
        if type(sn) == "table" then
            for name, value in pairs(sn) do
                if type(value) == "table" then
                    sn[name] = PEARL.GetStandardizedNameFor(value)
                end
            end
        end

        -- This will handle the case where "sn" is a table of fields as well.
        p = p:nformat(sn, sv)
    end

    local queued = self:GetQueuedAction(p)
    if queued then
        return queued:Repeat()
    end

    return _InitializeAction(p)
end

--------------------------------
-- [[ Wrapper Methods ]]
--------------------------------

--- @return QueuedLogAction
function ActionLog:EntityAct(p, ent, sn, sv)
    if ent then
        p = p:nformat(QueuedLogAction.FIELDS.DOER,
            EntityScript.is_instance(ent) and ent:GetStandardizedName() or ent
        )
    end

    return self:Act(p, sn, sv):SetColorEntity(ent)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ActionLog
