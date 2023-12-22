--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local Text = require "widgets/text"
local Health = require("components/health")

--- Check also components/healthbar.lua

-------------------------------
-- [[ Constants ]]
-------------------------------

local HEALTH_NOTE_PT = "󰀍 %d/%d"
local HEALTH_INFO_POS = Vector3(0, 80, 0)
local HEATLH_INFO_FONT = UIFONT
local HEALTH_INFO_FSIZE = 24
-- The point where the colours start to flip.
local HEALTH_THRESHOLD = 50
local THRESHOLD_MULT   = 100 / HEALTH_THRESHOLD

-------------------------------
-- [[ Locals ]]
-------------------------------

local colour = shallowcopy(WEBCOLOURS.GREEN)

-------------------------------
-- [[ Local Functions ]]
-------------------------------

-- Smooth colour transition
-- <0.5 -> R = 255
-- 0.5> -> G = 255
-- <=0  -> B = 255
-- Colors are in RGB percent!
local function UpdateColour(percent)
    if percent <= 0 then
        -- Black colour for percentages lower than or equal to zero.
        colour[1], colour[2], colour[3] = 255, 255, 255
        return
    end

    colour[1] = percent > 0.5 and (1 - percent) * THRESHOLD_MULT or 1
    colour[2] = percent < 0.5 and percent * THRESHOLD_MULT or 1
end

local function OnHealthPercentDirty(inst)
    -- Make sure we still have the health component
    -- because it can be removed during runtime.
    if not inst.replica or not inst.replica.health then
        return
    end

    if not inst.replica.health._max or not inst.replica.health._percent then
        return
    end

    inst.replica.health._current = inst.replica.health._max:value() * inst.replica.health._percent:value()
    UpdateColour(inst.replica.health._percent:value())
end

local function OnHealthDelta(self, data)
    if self.replica.health and self.replica.health._percent:value() ~= data.newpercent then
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

local function CanShowHPFor(target)
    return not target or
    not target.replica or not target.replica.health or
    not target.replica.health._max or not target.replica.health._percent
end

PEARL.AddClassPostConstruct("widgets/hoverer", function(self)
    if not (self.owner and self.owner.components) then
        return
    end

    local controller = self.owner.components.playercontroller
    if not controller then
        return
    end

    local health_info = self:AddChild(Text(HEATLH_INFO_FONT, HEALTH_INFO_FSIZE))
    health_info:SetPosition(HEALTH_INFO_POS)

    PEARL.AddClassFunctionPostCall("OnUpdate", function(self)
        local lmb = controller:GetLeftMouseAction()
        local inst = lmb and lmb.target
        -- Check for the net vars as well synce they may not be initialized for the current prefab.
        if CanShowHPFor(inst) then
            return health_info:Hide()
        end

        health_info:SetString(HEALTH_NOTE_PT:format(
            (inst.replica.health._current or 0), inst.replica.health._max:value()
        ))
        health_info:SetColour(colour)
        health_info:Show()
    end, self)
end)
