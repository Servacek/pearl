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
-- [[ Localization ]
--------------------------------

local Ents = Ents

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class QueuedLogAction
local QueuedLogAction = Class(function(self, pattern, GUID)
    --- @type string
    self.pattern = pattern
    --- @type string
    self.GUID = GUID

    --- @type number
    self.timestart = os.time()

    --- @type table<name, count>?
    self.targets = nil
    --- @type EntityScript?
    self.target = nil

    --- @type table<name, value>
    self.identifiers = nil

    --- @type string?
    self.logtype = nil
    --- @type fun(action: QueuedLogAction): string
    self.strfn = nil

    --- @type Task?
    self.task = nil
end)

--------------------------------
-- [[ Static ]]
--------------------------------

QueuedLogAction.IDENTIFIERS = {
    TOOLNAME = 1,
}

--------------------------------
-- [[ Setters ]]
--------------------------------

function QueuedLogAction:AddTarget(target)
    if not self.target then
        self.target = target
        return self
    end

    if not self.targets then
        self.targets = {}

        self:AddTarget(self.target)
    end

    local name = PEARL.GetStandardizedNameFor(target)
    self.targets[name] = (self.targets[name] or 0) + PEARL.GetStackSize(target)

    return self
end

-- This is for some unique actions with a same pattern.
-- But currenlty, to keep things simple, we assume that
-- a new pattern means also a new unique action.
function QueuedLogAction:AddIdentifier(identifiers)
    self.identifiers = identifiers

    -- Add the identifiers to the pattern.
    self.pattern = self.pattern:nformat(identifiers)
end

function QueuedLogAction:SetQueueTask(task)
    self.task = task

    return self
end

function QueuedLogAction:SetStringFunction(strfn)
    self.strfn = strfn

    return self
end

function QueuedLogAction:SetLogType(ltp)
    self.logtype = ltp

    return self
end

function QueuedLogAction:GetDoer()
    return Ents[self.GUID]
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function QueuedLogAction:GetTargetString()
    if not self.targets then
        if self.target then
            return self.target:GetFancyName()
        end

        return ""
    end

    return PEARL.BuildFancyStringFor(self.targets)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return QueuedLogAction
