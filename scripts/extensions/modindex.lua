--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @class KnownModIndex
local KnownModIndex = KnownModIndex

---------------------------
-- [[ Constants ]]
---------------------------

local MOD_BLOCKLIST = PEARL.CONFIG.MOD_BLOCKLIST
local MOD_ALLOWLIST = PEARL.CONFIG.MOD_ALLOWLIST
local ALLOWLISTING  = PEARL.CONFIG.MOD_BLOCKER.ALLOWLIST and not table.empty(PEARL.CONFIG.MOD_ALLOWLIST)
local MAX_REPORTS   = 25

---------------------------
-- [[ Private ]]
---------------------------

local function IsModReportable(modname)
    if modname == PEARL.MODNAME then
        return false
    end

    return KnownModIndex:IsModEnabledAny(modname) or KnownModIndex:IsModBlocked(modname)
end

local function CreateReportForMod(modname)
    return {
        private     = KnownModIndex:IsModPrivate(modname),
        allowed     = KnownModIndex:IsModAllowed(modname),
        id          = GetWorkshopIdNumber(modname),
        fancyname   = GetModFancyName(modname)
    }
end

---------------------------
-- [[ Public ]]
---------------------------

function KnownModIndex:IsClientOnlyMod(modname)
    local modinfo = KnownModIndex:GetModInfo(modname)
    return modinfo and modinfo.client_only_mod == true
end

function KnownModIndex:IsModAllowlisted(modname)
    return table.contains(MOD_ALLOWLIST, GetWorkshopIdNumber(modname))
end

function KnownModIndex:IsModBlocklisted(modname)
    return table.contains(MOD_BLOCKLIST, GetWorkshopIdNumber(modname))
end

function KnownModIndex:IsModPrivate(modname)
    --- @TODO: Disabling this for now because it seems to be very unreliable.
    return not IsWorkshopMod(modname) --or (TheSim:GetWorkshopVersion(modname) == "" and TheSim:GetWorkshopVersionCompatible(modname) == "")
end

function KnownModIndex:IsModAllowed(modname)
    -- ALWAYS block private mods since all the other checks can be bypassed
    return not self:IsModPrivate(modname) and (
        not self:IsClientOnlyMod(modname) or (
            not self:IsModBlocklisted(modname) and (
                not ALLOWLISTING or self:IsModAllowlisted(modname)
            )
        )
    )
end

function KnownModIndex:Block(modname)
    self:Disable(modname)

    if not self.savedata.known_mods[modname] then
        self.savedata.known_mods[modname] = {}
    end

    -- This is just a temporary flag that will be removed after the game restarts
    -- The thing that will stay is the disabled flag.
    self.savedata.known_mods[modname].blocked = true
    self._mods_blocked = true
end

function KnownModIndex:IsModBlocked(modname)
	local known_mod = self.savedata.known_mods[modname]
	return known_mod and known_mod.blocked == true
end

function KnownModIndex:IsModDisablingDisabled()
    return self.modsettings.disablemods == false
end

function KnownModIndex:AreAnyModsBlocked()
    return self._mods_blocked == true
end

-- Counts also blocked mods since they we originally enabled as well.
function KnownModIndex:GetAllEnabledModsCount()
    local count = 0
    for modname, _ in pairs(KnownModIndex.savedata.known_mods) do
        if KnownModIndex:IsModEnabledAny(modname) or KnownModIndex:IsModBlocked(modname) then
            count = count + 1
        end
    end

    return count
end

function KnownModIndex:GetModsReport()
    local report = {
        count = self:GetAllEnabledModsCount(),
        prohibited = false,
    }

    for _, modname in ipairs(KnownModIndex:GetModNames()) do
        if #report < MAX_REPORTS and IsModReportable(modname) then
            local mod_report = CreateReportForMod(modname)
            if not mod_report.allowed then
                -- Show blocked mods at the top.
                table.insert(report, 1, mod_report)
                report.prohibited = true
            else
                report[#report + 1] = mod_report
            end
        end
    end

    return report
end
