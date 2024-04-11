--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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
-- [[ Locals ]]
---------------------------

--- @table<string>
local blocked_mods = {}

---------------------------
-- [[ Constants ]]
---------------------------

-- Allowlists and blocklists can be empty.
local MOD_BLOCKLIST = PEARL.CONFIG.MOD_BLOCKLIST or {}
local MOD_ALLOWLIST = PEARL.CONFIG.MOD_ALLOWLIST or {}
local ALLOWLISTING  = PEARL.CONFIG.MOD_BLOCKER.ALLOWLIST
local MAX_REPORTS   = 25

local WORKSHOP_PREFIX = "workshop-"

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
        fancyname   = GetModFancyName(modname),
        modname     = modname,
    }
end

---------------------------
-- [[ Public ]]
---------------------------

function KnownModIndex:IsClientOnlyMod(modname)
    local modinfo = KnownModIndex:GetModInfo(modname)
    return modinfo and modinfo.client_only_mod == true or false
end

function KnownModIndex:IsModRequiredByServer(modname)
    local listing = TheNet:GetServerListing()
    if type(listing) == "table" and type(listing.mods_description) == "table" then
        for _, mod in pairs(listing.mods_description) do
            if mod.mod_name == modname then
                return true
            end
        end
    end

    return false
end

function KnownModIndex:IsModAllowlisted(modname)
    return table.contains(MOD_ALLOWLIST, GetWorkshopIdNumber(modname))
end

function KnownModIndex:IsModBlocklisted(modname)
    return table.contains(MOD_BLOCKLIST, GetWorkshopIdNumber(modname))
end

function KnownModIndex:IsModPrivate(modname)
    --- These seem to only load up when the mod is enabled from the start of the game (before joining the server).
    --- @Note: December 2023: Testing this again...
    return not IsWorkshopMod(modname) or (TheSim:GetWorkshopVersion(modname) == "" and TheSim:GetWorkshopVersionCompatible(modname) == "")
end

function KnownModIndex:ShouldDisableMod(modname)
    if self:IsModRequiredByServer(modname) then
        PEARL.debug("Mod is required by the server!", modname)
        return false
    end

    -- ALWAYS block private mods since all the other checks can be bypassed
    if self:IsModPrivate(modname) then
        PEARL.debug("Private mod!", modname)
        return true
    end

    if self:IsModBlocklisted(modname) then
        PEARL.debug("Blocklisted mod!", modname)
        return true
    end

    return false
end

function KnownModIndex:IsModAllowed(modname)
    if (TheNet:GetIsServerAdmin() and not PEARL.CONFIG.DEBUG_MODE) or modname == PEARL.MODNAME then
        return true -- All mods are allowed for admins
    end

    if self:ShouldDisableMod(modname) then
        return false
    end

    if ALLOWLISTING == true and not self:IsModAllowlisted(modname) then
        PEARL.debug("Not allowlisted!", modname)
        return false
    end

    return true -- All checks passed!
end

function KnownModIndex:IsModProhibited(modname)
    return not self:IsModAllowed(modname)
end

function KnownModIndex:IsModCompatibleWith(modname, target_modname)
    local modinfo = KnownModIndex:GetModInfo(modname)
    if modinfo and table.empty(modinfo.uncompatible_mods) == false then
        for _, uncompatible_modname in ipairs(modinfo.uncompatible_mods) do
            if uncompatible_modname == target_modname or WORKSHOP_PREFIX..uncompatible_modname == target_modname then
                return false
            end
        end
    end

    return true
end

function KnownModIndex:Block(modname, temp)
    if temp then
        self:TempDisable(modname)
    else
        self:Disable(modname)
    end

    -- This is just a temporary flag that will be removed after the game restarts
    -- The thing that will stay is the disabled flag.
    if not self:IsModBlocked(modname) then
        blocked_mods[modname] = true
    end
end

function KnownModIndex:IsModBlocked(modname)
	return blocked_mods[modname]
end

function KnownModIndex:IsModDisablingDisabled()
    return self.modsettings.disablemods == false
end

function KnownModIndex:GetBlockedCount()
    return table.size(blocked_mods) or 0
end

function KnownModIndex:AreAnyModsBlocked()
    return self:GetBlockedCount() > 0
end

function KnownModIndex:AreAllModsBlocked()
    -- Except this mod of course
    return self:GetBlockedCount() >= (self:GetAllEnabledModsCount() - 1)
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

---------------------------
-- [[ Overrides ]]
---------------------------

if PEARL.CONFIG.DEBUG_MODE then
    -- When debugging, the variable BRANCH is set to "dev" so the dev version of
    -- the modindex file is being used insted. This can cause confusion since
    -- mods disabled in-game are saved to the development modindex while
    -- the modstab uses the default modindex file with none of these changes.
    -- So it may look like a bug.
    PEARL.OverrideMethodReturnValue(KnownModIndex, "GetModIndexName", function(old, self)
        return "modindex" -- Always use the default modindex file in debug mode.
    end)
end
