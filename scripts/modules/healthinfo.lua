--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local Text = require "widgets/text"
local Health = require("components/health")

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

local HEALTH_NOTE_PT = "󰀍 %d/%d"
local HEALTH_INFO_POS = Vector3(0, 80, 0)
local HEATLH_INFO_FONT = UIFONT
local HEALTH_INFO_FSIZE = 24
local HEATLH_THRESHOLDS = {
    FULL = 1 / 1.5,
    HALF = 1 / 3,
}
local HEALTH_COLOURS = {
    FULL = WEBCOLOURS.GREEN,
    HALF = WEBCOLOURS.YELLOW,
    LOW  = WEBCOLOURS.RED,
}

-------------------------------
-- [[ Local Functions ]]
-------------------------------

local function GetColour(percent)
    if percent > HEATLH_THRESHOLDS.FULL then
        return HEALTH_COLOURS.FULL
    end

    if percent > HEATLH_THRESHOLDS.HALF then
        return HEALTH_COLOURS.HALF
    end

    return HEALTH_COLOURS.LOW
end

local function OnHealthPercentDirty(inst)
    inst.replica.health._current = inst.replica.health._max:value() * inst.replica.health._percent:value()
end

local function OnHealthDelta(self, data)
    if self.replica.health._percent:value() ~= data.newpercent then
        self.replica.health._percent:set(data.newpercent)
    end
end

PEARL.AddClassFunctionPostCall("SetMaxHealth", function(self, max)
    if not self.inst.replica.health or not self.inst.replica.health._max or self.inst.replica.health._max:value() == max then
        return
    end

    self.inst.replica.health._max:set(max)
    self.inst.replica.health._percent:set(1)
    self.inst.replica.health._current = max
end, Health)

-- We use a class-post-construct because a regular component-post-init
-- doesn't work for replicated components.
PEARL.AddClassPostConstruct("components/health_replica", function(self, inst)
    if not (table.empty(PEARL.CONFIG.HEALTH_INFO.TAGS) or inst:HasOneOfTags(PEARL.CONFIG.HEALTH_INFO.TAGS)) then
        return
    end

    self._current = 100

    self._max = net_uint(inst.GUID, PEARL.MODNAME.."_health._max", PEARL.MODNAME.."healthmaxdirty")
    self._max:set(100)

    self._percent = net_float(inst.GUID, PEARL.MODNAME.."_health._percent", PEARL.MODNAME.."healthpercentdirty")
    self._percent:set(1)

    if TheWorld.ismastersim then
        self.inst:SafeListenForEvent("healthdelta", OnHealthDelta)
    else
        self.inst:SafeListenForEvent(PEARL.MODNAME.."healthpercentdirty", OnHealthPercentDirty)
    end
end)

if TheNet:GetIsServer() then
    return
end

PEARL.AddClassPostConstruct("widgets/hoverer", function(self)
    local health_info = self:AddChild(Text(HEATLH_INFO_FONT, HEALTH_INFO_FSIZE))
    health_info:SetPosition(HEALTH_INFO_POS)

    local controller = self.owner.components.playercontroller
    if not controller then
        return
    end

    PEARL.AddClassFunctionPostCall("OnUpdate", function(self)
        if not self.text:IsVisible() then
            return health_info:Hide()
        end

        local lmb = controller:GetLeftMouseAction()
        local inst = lmb and lmb.target
        -- Check for the net vars as well synce they may not be initialized for the current prefab.
        if not inst or not inst.replica or not inst.replica.health or not inst.replica.health._max or not inst.replica.health._percent then
            return
        end

        health_info:SetString(HEALTH_NOTE_PT:format(
            (inst.replica.health._current or 0), inst.replica.health._max:value()
        ))
        -- Update the colour as well
        health_info:SetColour(unpack(GetColour(inst.replica.health._percent:value())))
        health_info:Show()
    end, self)
end)
