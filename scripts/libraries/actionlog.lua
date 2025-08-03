--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local RepeatableLogAction = PEARL.loadfile("models/queuedlogaction")

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @singleton
--- @class ActionLog
local ActionLog = {
    _pattern_to_action = {},    --- @type table<string, RepeatableLogAction>
    _dynamic_queue     = {},    --- @type table<number, string>
    _uninitialized     = setmetatable({}, {
        __mode = "v" -- Let the values be garbage collected if needed.
    }),    --- @type table<number, RepeatableLogAction>

    _init_task         = nil,   --- @type Task?
}

--------------------------------
-- [[ Private Methods ]]
--------------------------------

local function _LogActionRaw(action)
    ActionLog:DequeueAction(action.pattern)
    ActionLog:Log(
        action.colorentity, action.logtype, action:GetString(), action.silent, action.icon
    )

    action:CancelTask()
end

local function _InitTaskDone()
    if ActionLog._init_task then
        ActionLog._init_task:stop()
    end

    for i = #ActionLog._uninitialized, 1, -1 do
        local action = ActionLog._uninitialized[i]
        ActionLog:InitializeAction(action)

        if action.logged or action.initialized then
            table.remove(ActionLog._uninitialized, i)
        end
    end
end

--- @param pattern string
--- @return RepeatableLogAction
local function _CreateNewAction(pattern)
    PEARL.debug("_CreateNewAction", pattern)

    local action = RepeatableLogAction(pattern)
    --- It cannot be logged immediatelly because we are not yet initialized!
    -- if string.nformatable(pattern) then
        if not ActionLog._init_task then
            ActionLog._init_task = PEARL.WallScheduler:ExecutePeriodic(0, _InitTaskDone)
        elseif not ActionLog._init_task.running then
            --- Interesting way would be to use the "task._args"
            --- but that would be kinda... hacky...
            ActionLog._init_task:restart()
        end

        --- @TODO: Maybe our custom queue would fit better here?
        table.insert(ActionLog._uninitialized, 1, action)
        --ActionLog._uninitialized[#ActionLog._uninitialized + 1] = action
    -- else
    --     ActionLog:InitializeAction(action)
    -- end

    return action
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return RepeatableLogAction
function ActionLog:GetRepeatableActionAt(index)
    return self._pattern_to_action[self._dynamic_queue[index]]
end

--- @param pattern string Retrive the specific action bound to the provided pattern.
--- Pattern should be always unique per action.
function ActionLog:GetQueuedAction(pattern)
    return self._pattern_to_action[pattern]
end

--- @param pattern string Retrive the specific actions index.
--- @return integer?
function ActionLog:GetQueuedActionIndex(pattern)
    return table.index(self._dynamic_queue, pattern)
end

-- --- @param pattern string Retrive the specific actions index.
-- --- @return boolean
-- function ActionLog:IsActionQueued(pattern)
--     return self.queue[pattern] ~= nil
-- end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- @param pattern string Removes from the queue action with the provided pattern.
function ActionLog:DequeueAction(pattern)
    self._pattern_to_action[pattern] = nil
    table.remove(self._dynamic_queue, self:GetQueuedActionIndex(pattern))
end

--- Stores the action in our table so we can look it up in case of the action being repeated.
--- @param action RepeatableLogAction
function ActionLog:QueueAction(action)
    self._pattern_to_action[action.pattern] = action
    self._dynamic_queue[#self._dynamic_queue + 1] = action.pattern
end

function ActionLog:Log(ent, tp, str, slt, icon)
    return PEARL.AnnounceWithType(str, tp, (ent and ent.entity or ent), slt, icon)
end

--- Called when an action is fully constructed and we can say if an action is stackable.
--- @param action RepeatableLogAction
function ActionLog:InitializeAction(action)
    --PEARL.debug("ActionLog:InitializeAction", action)

    if action.initialized ~= false or action.logged ~= false then
        return
    end
    action.initialized = true

    if action:IsStackable() then
        self:QueueAction(action)
        action:WaitForRepetition(function() self:LogAction(action) end)
        return
    end

    -- The action did not manage to become stackable during its construction,
    -- so it won't be added to the queue but logged right away.
    self:LogAction(action)
end

function ActionLog:LogAllQueuedActions()
    for _, action in pairs(self._pattern_to_action) do
        self:LogAction(action)
    end
end

function ActionLog:LogAction(action)
    PEARL.debug("ActionLog:LogAction", action)

    if action.logged then
        return
    end
    action.logged = true

    if not action.initialized then
        PEARL.warn("Logging an uninitialized action!", action)
    end
    action.initialized = true

    local queued_index = self:GetQueuedActionIndex(action.pattern)
    local stop = queued_index and queued_index - 1 or #self._dynamic_queue

    --- Log all the actions that were created before us!
    for i = stop, 1, -1 do
        local queued = self:GetRepeatableActionAt(i)
        if queued then
            _LogActionRaw(queued)
        end
    end

    _LogActionRaw(action)
end

--- @param p string The initial pattern of the action.
--- @param sn string|table? The name of the static field in the pattern or the formatting table for the given pattern.
--- @param sv string? The value of the "sn" field, if provided.
--- @return RepeatableLogAction action The current action for the given pattern built up from the static data provided.
function ActionLog:Act(p, sn, sv)
    if sn and (type(sn) == "string" or (table.empty(sn) == false and sn._ctor == nil)) then
        -- Handle sv being an entity
        if sv and EntityScript.is_instance(sv) then
            sv = PEARL.GetStandardizedNameFor(sv)
        end

        -- Handle sn being a table of entities (Not a class!)
        if type(sn) == "table" then
            for name, value in pairs(sn) do
                if type(value) == "table" then
                    sn[name] = PEARL.GetStandardizedNameFor(value)
                end
            end
        end

        -- This will handle the case where "sn" is a table of fields as well.
        p = p:nformat(sn, sv)
    elseif sn ~= nil then
        PEARL.error("Invalid static field name provided, string expected got", sn)
    end

    local queued = self:GetQueuedAction(p)
    if queued then
        if queued:Repeat() ~= true then
            --- Repeating failed, log immediatelly (no point in waiting any longer).
            self:LogAction(queued)
        end

        return queued
    end

    return _CreateNewAction(p)
end

--------------------------------
-- [[ Wrapper Methods ]]
--------------------------------

--- @param p string
--- @param ent EntityScript|string?
--- @param sn string?
--- @param sv any
--- @return RepeatableLogAction
function ActionLog:EntityAct(p, ent, sn, sv)
    if ent then
        p = p:nformat(RepeatableLogAction.FIELDS.DOER,
            EntityScript.is_instance(ent) and ent:GetStandardizedName() or ent
        )
    end

    return self:Act(p, sn, sv):SetColorEntity(ent)
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

--- Make sure we log out everything as soon as the simulation get's interrupted.
local function OnSimulationInterrupted()
    ActionLog:LogAllQueuedActions()
end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddSafeEventHandler("simulation_paused", OnSimulationInterrupted)

PEARL.EventProcessor:AddSafeEventHandler("quit", OnSimulationInterrupted)

--------------------------------
-- [[ Return ]]
--------------------------------

return ActionLog
