--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @type KnownModIndex
KnownModIndex = KnownModIndex

--- @class KnownModIndex
local KnownModIndex = KnownModIndex

---------------------------
-- [[ Attributes ]]
---------------------------

KnownModIndex._blocked_mods_count = 0

---------------------------
-- [[ Constants ]]
---------------------------

-- Allowlists and blocklists can be empty.
local MOD_BLOCKLIST = PEARL.CONFIG.MOD_BLOCKLIST or {}
local MOD_ALLOWLIST = PEARL.CONFIG.MOD_ALLOWLIST or {}
local ALLOWLISTING  = PEARL.CONFIG.MOD_BLOCKER.ALLOWLIST
local MAX_REPORTS   = 25

---------------------------
-- [[ Private ]]
---------------------------

local function IsModReportable(modname)
    if modname == PEARL.MODNAME then
        return false
    end

    return KnownModIndex:IsModEnabledOrBlocked(modname)
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
    return modinfo and modinfo.client_only_mod == true or false
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
    if (TheNet:GetIsServerAdmin() and not PEARL.CONFIG.DEBUG_MODE) or modname == PEARL.MODNAME then
        return true -- All mods are allowed for admins
    end

    -- ALWAYS block private mods since all the other checks can be bypassed
    if self:IsModPrivate(modname) then
        return false
    end

    if self:IsModBlocklisted(modname) then
        PEARL.info("Blocklisted mod!")
        return false
    end

    if not self:IsClientOnlyMod(modname) then
        return false
    end

    return not self:IsModBlocklisted(modname) and (not ALLOWLISTING or self:IsModAllowlisted(modname))
end

function KnownModIndex:Block(modname)
    self:Disable(modname)

    if not self.savedata.known_mods[modname] then
        self.savedata.known_mods[modname] = {}
    end

    if not self:IsModBlocked(modname) then
        self._blocked_mods_count = self._blocked_mods_count + 1
    end

    -- This is just a temporary flag that will be removed after the game restarts
    -- The thing that will stay is the disabled flag.
    self.savedata.known_mods[modname].blocked = true
end

function KnownModIndex:IsModBlocked(modname)
	local known_mod = self.savedata.known_mods[modname]
	return known_mod and known_mod.blocked == true
end

function KnownModIndex:IsModDisablingDisabled()
    return self.modsettings.disablemods == false
end

function KnownModIndex:AreAnyModsBlocked()
    return self._blocked_mods_count > 0
end

function KnownModIndex:AreAllModsBlocked()
    return self._blocked_mods_count >= (self:GetAllEnabledModsCount() - 1)
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

function KnownModIndex:IsModEnabledOrBlocked(modname)
    return KnownModIndex:IsModEnabledAny(modname) or KnownModIndex:IsModBlocked(modname)
end

function KnownModIndex:GetEnabledModFancyNames()
    local fancynames = {}
    for _, modname in ipairs(self:GetModNames()) do
        if self:IsModEnabledOrBlocked(modname) then
            fancynames[#fancynames + 1] = KnownModIndex:GetModFancyName(modname)
        end
    end

    return fancynames
end

function KnownModIndex:GetModsReport()
    local report = {
        -- We do not count ourselves!
        count = self:GetAllEnabledModsCount() - 1,
        prohibited_count = 0,
        list = {},
    }

    -- Iterate over all mods since we count blocked mods as enabled even though they can be disabled.
    for _, modname in ipairs(self:GetModNames()) do
        if #report < MAX_REPORTS and IsModReportable(modname) then
            local mod_report = CreateReportForMod(modname)
            local prohibited = mod_report.allowed == false

            if prohibited then
                report.prohibited_count = report.prohibited_count + 1
            end

            -- Show blocked mods at the top.
            -- Note: The list has to ALWAYS start with "1" in order for JSON to encode is as an array.
            local pos = prohibited and 1 or (#report.list + 1)
            table.insert(report.list, pos, mod_report)
        end
    end

    return report
end
