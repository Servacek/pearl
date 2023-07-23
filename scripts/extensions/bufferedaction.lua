--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODO:
--- This is the act table provided to all ACTION handlers.
--- We can use it for storing some stacking data in ActionLog.

--- @class BufferedAction
local BufferedAction = BufferedAction

--------------------------------
-- [[ Public Methods]]
--------------------------------

--- @param target EntityScript
function BufferedAction:AddTarget(target)
    if not self.__targets then
        --- @type table<name, count>
        self.__targets = {}
    end

    local name = PEARL.GetStandardizedNameFor(target)
    self.__targets[name] = PEARL.GetStackSize(target)
end

function BufferedAction:GetTargetString()
    if not self.__targets then
        if self.target then
            return self.target:GetFancyName()
        end

        return ""
    end

    return PEARL.BuildFancyStringFor(self.__targets)
end

function BufferedAction:SetType(type)
    self.__type = type
end

function BufferedAction:GetStandardizedToolName()
    return self.target and self.invobject and PEARL.GetStandardizedNameFor(self.invobject) or nil
end

function BufferedAction:IsStackableWith(dest)
    return dest and dest.type == self.__type and self.target ~= nil and
        dest:GetStandardizedToolName() == self:GetStandardizedToolName()
end

function BufferedAction:SetIdentifiers(pattern, GUID)
    self.__pattern__ = pattern
    self.__GUID__    = GUID
end

function BufferedAction:SetQueueCallback(cb)
    self.__queuecb = cb
end
