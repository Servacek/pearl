--[[
   Implements a builder table for all prefabs with the 'workable' component
--]]

local PEARL = PEARL

local Workable = require("components/workable")

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function onbuilt(target, data)
    if not (data and target and data.builder and data.builder:HasTag("player")) then
        return
    end

    if not target:HasBuilder() then
        target:SetBuilder({
            name    = data.builder.name,
            userid  = data.builder.userid,
        })
    end
end

--------------------------------
-- [[ Function Post Calls ]]
--------------------------------

local _OnSave = Workable.OnSave
Workable.OnSave = function(self, data, ...)
    data = _OnSave and _OnSave(self, data, ...) or data or {}
    if self.inst and self.inst:HasBuilder() then
        data.builder = self.inst.builder
    end

    return data
end

local _OnLoad = Workable.OnLoad
Workable.OnLoad = function(self, data, ...)

    if _OnLoad then
        _OnLoad(self, data, ...)
    end

    if self.inst and data and data.builder then
        PEARL.debug("LOAD BUILDER")

        self.inst:SetBuilder(data.builder)
    end
end

--------------------------------
-- [[ Constructor ]]
--------------------------------

AddClassPostConstruct("components/workable", function(self)
    if self.inst and self.inst:HasTag("structure") then
        self.inst:ListenForEvent("onbuilt", onbuilt)
    end
end)
