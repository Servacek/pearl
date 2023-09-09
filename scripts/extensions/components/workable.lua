--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Implements a builder table for all prefabs with the 'workable'
--]]

local PEARL = PEARL

--- @class Workable
local Workable = require("components/workable")

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function onbuilt(target, data)
    if not (data and target and data.builder and data.builder:HasTag("player")) then
        return
    end

    if not target.components.workable:HasBuilder() then
        target.components.workable:SetBuilder({
            name    = data.builder.name,
            userid  = data.builder.userid,
        })
    end
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function Workable:HasBuilder()
    return type(self._builder) == "table"
        and type(self._builder.userid) == "string"
        and type(self._builder.name) == "string"
end

function Workable:GetBuilder()
    return self._builder
end

function Workable:GetBuilderName()
    return self._builder and tostring(self._builder.name) or "UNKNOWN"
end

function Workable:IsBuildBy(userid)
    return userid and self._builder and self._builder.userid == userid
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function Workable:SetBuilder(builder)
    self._builder = builder
end

--------------------------------
-- [[ Function Post Calls ]]
--------------------------------

local _OnSave = Workable.OnSave
Workable.OnSave = function(self, data, ...)
    data = _OnSave and _OnSave(self, data, ...) or data or {}
    if self:HasBuilder() then
        data.builder = self:GetBuilder()
    end

    return data
end

local _OnLoad = Workable.OnLoad
Workable.OnLoad = function(self, data, ...)

    if _OnLoad then
        _OnLoad(self, data, ...)
    end

    if data and data.builder then
        self:SetBuilder(data.builder)
    end
end

--------------------------------
-- [[ Constructor ]]
--------------------------------

PEARL.AddClassPostConstruct("components/workable", function(self)
    if self.inst and self.inst:HasTag("structure") then
        self.inst:SafeListenForEvent("onbuilt", onbuilt)
    end
end)
