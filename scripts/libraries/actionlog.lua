--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @TODO: Make doer optional to support environmental actions like structures burned out.


local QueuedLogAction = PEARL.loadfile("models/queuedlogaction")

--------------------------------
-- [[ Constants ]]
--------------------------------

local QUEUE_TIME = 3
local MAX_DELAY  = 8

--------------------------------
-- [[ Class Declaration ]]
--------------------------------


--- @class ActionLog
local ActionLog = {
    --- @type table<userid, table<string, any>>
    _queue = {}
}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function _defaultstrfn(action)
    return action.pattern:nformat{
        doer = PEARL.GetStandardizedNameFor(action:GetDoer()) or action.GUID,
        target = action:GetTargetString(),
        owner = action.GUID, -- GUID in this case is the owner's name, because the player is offline
    }
end

local function _OnActionRepeated(action)
    if not action.task or not action.timestart then
        return
    end

    local timediff = os.time() - action.timestart
    if (timediff + QUEUE_TIME) < MAX_DELAY then
        return action.task:restart()
    end

    -- Send it immediately.
    ActionLog:ExecuteAction(action)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function ActionLog:CreateActionFor(pattern, GUID)
    local action = QueuedLogAction(pattern, GUID)
    action:SetQueueTask(PEARL.WallScheduler:ExecuteInTime(QUEUE_TIME, function()
        self:RemoveAction(pattern, GUID)

        action.strfn = action.strfn or _defaultstrfn
        if type(action.strfn) == "function" then
            self:LogAction(GUID, action.logtype, action.strfn(action))
        end
    end))

    return action
end

function ActionLog:QueueActionFor(pattern, GUID)
    if not self._queue[pattern] then
        self._queue[pattern] = {}
    end

    self._queue[pattern][GUID] = self:CreateActionFor(pattern, GUID)
    return self._queue[pattern][GUID]
end

function ActionLog:GetQueuedAction(pattern, GUID)
    return self._queue[pattern] and self._queue[pattern][GUID]
end

function ActionLog:ExecuteAction(action)
    if action and action.task then
        return action.task:run()
    end
end

function ActionLog:RemoveAction(pattern, GUID)
    local action = self:GetQueuedAction(pattern, GUID)
    if action then
        self._queue[pattern][GUID] = nil
    end

    return action
end

function ActionLog:LogEntityAction(entity, tp, actionstr, ...)
    return PEARL.AnnounceWithType(actionstr, tp, entity and entity.entity or entity, ...)
end

function ActionLog:LogAction(GUID, ltp, actionstr, ...)
    return self:LogEntityAction(Ents[GUID], ltp, actionstr, ...)
end

--- Same pattern means same type!
function ActionLog:QueueAction(pattern, GUID)
    GUID = GUID or ""

    local queued = self:GetQueuedAction(pattern, GUID)
    if queued then
        _OnActionRepeated(queued)

        return queued
    end

    return self:QueueActionFor(pattern, GUID)
end

--------------------------------
-- [[ Wrapper Methods ]]
--------------------------------

function ActionLog:QueueWorldAction(pattern)
    return self:QueueAction(pattern, nil)
end

--- @param entity Entity
--- This function should return the string that should be logged. Taking some stacked action atributes as an argument.
function ActionLog:QueueEntityAction(entity, pattern)
    return self:QueueAction(pattern, entity and entity.GUID or entity)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ActionLog
