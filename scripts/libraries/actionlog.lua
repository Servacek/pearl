--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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
    --- @type table<userid, table<string, any>>
    _queue = {},
}

--------------------------------
-- [[ Private Methods ]]
--------------------------------

--- @param action QueuedLogAction
--- @return QueuedLogAction
function ActionLog:_QueueAction(pattern, action)
    self._queue[pattern] = action

    return action:SetQueueTask(PEARL.WallScheduler:ExecuteInTime(action.queuetime, function()
        self:RemoveAction(pattern)
        self:LogAction(
            action.colorentity, action.logtype, action:GetString(), action.silent
        )
    end))
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- @param pattern string Retrive the specific action bound to the provided pattern.
--- Pattern should be always unique per action.
function ActionLog:GetQueuedAction(pattern)
    return self._queue[pattern]
end

--- @param pattern string Removes from the queue action with the provided pattern.
--- @return QueuedLogAction? action The action that was removed from the queue.
function ActionLog:RemoveAction(pattern)
    local action = self._queue[pattern]
    self._queue[pattern] = nil
    return action
end

function ActionLog:LogAction(entity, tp, actionstr, silent, ...)
    return PEARL.AnnounceWithType(
        actionstr, tp, (entity and entity.entity or entity), silent, ...
    )
end

--- @param p string The initial pattern of the action.
--- @param sn string|table<string, string>? The name of the static field in the pattern or the formatting table for the given pattern.
--- @param sv string? The value of the "sn" field, if provided.
--- @return QueuedLogAction action The current action for the given pattern built up from the static data provided.
function ActionLog:QueueAct(p, sn, sv)
    if sn then
        --- @TODO: handle sv being an entity.
        if sv and EntityScript.is_instance(sv) then
            sv = sv:GetFancyName()
        end

        -- This will handle the case where "sn" is a table of fields as well.
        p = p:nformat(sn, sv)
    end

    local queued = self:GetQueuedAction(p)
    if queued then
        return queued:Repeat()
    end

    return self:_QueueAction(p, QueuedLogAction(p))
end

--------------------------------
-- [[ Wrapper Methods ]]
--------------------------------

--- @return QueuedLogAction
function ActionLog:QueueEntAct(p, ent, sn, sv)
    if ent then
        p = p:nformat(QueuedLogAction.STATIC_FIELDS.DOER,
            EntityScript.is_instance(ent) and ent:GetStandardizedName() or ent
        )
    end

    return self:QueueAct(p, sn, sv):SetColorEntity(ent)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ActionLog
