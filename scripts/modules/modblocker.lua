--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd


--[[
    Blocks some hacky mods from loading on the client.

    TODOS:
        - Make the detection of non-workshop mods better. TheSim:GetWorkshopVersion?
        - Debug allowlist
--]]

-- Use the redux version instead of the default on since this is newer
local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local MOD_BLOCKLIST = PEARL.CONFIG.MOD_BLOCKLIST
local MOD_ALLOWLIST = PEARL.CONFIG.MOD_ALLOWLIST
local ALLOWLISTING  = PEARL.CONFIG.MOD_BLOCKER.ALLOWLIST and not IsTableEmpty(PEARL.CONFIG.MOD_ALLOWLIST)
local MAX_REPORT_COUNT = 10

--------------------------------------
-- [[ Private ]]
--------------------------------------

local show_popup = true

local mods_report = {
    count = #ModManager:GetEnabledModNames(),
    prohibited = false,
}

--------------------------------------
-- [[ Helper Wrappers ]]
--------------------------------------

local function IsClientOnlyMod(modname)
    local modinfo = KnownModIndex:GetModInfo(modname)
    return modinfo and modinfo.client_only_mod == true
end

local function IsModAllowlisted(modname)
    return table.contains(MOD_ALLOWLIST, GetWorkshopIdNumber(modname))
end

local function IsModBlocklisted(modname)
    return table.contains(MOD_BLOCKLIST, GetWorkshopIdNumber(modname))
end

local function IsModPrivate(modname)
    -- return IsWorkshopMod(modname)
    --- @EXPERIMENTAL
    return TheSim:GetWorkshopVersion(modname) == "" and TheSim:GetWorkshopVersionCompatible(modname) == ""
end

local function IsModAllowed(modname)
    local allowlisted = IsModAllowlisted(modname)
    -- ALWAYS block private mods since all the other checks can be bypassed
    return (not IsModPrivate(modname) and not IsClientOnlyMod(modname)) or (
        not IsModBlocklisted(modname) and (
            not ALLOWLISTING or IsModAllowlisted(modname)
        )
    )
end

local function IsModReportable(modname)
    return (KnownModIndex:IsModEnabled(modname) and not KnownModIndex:IsModTempEnabled(modname)) or KnownModIndex:IsModBlocked(modname)
end

local function SaveModIndex()
    --- @NOTE: This only works if DEVELOPER MODE is OFF!
    KnownModIndex:Save()

    if PEARL.CONFIG.DEBUG_MODE then
        local _BRANCH = _G.BRANCH

        PEARL.OverrideVariable("BRANCH", "release")
        KnownModIndex:Save()
        PEARL.OverrideVariable("BRANCH", _BRANCH)
    end
end

local function CreateReportForMod(modname)
    return {
        private     = IsModPrivate(modname),
        allowed     = IsModAllowed(modname),
        id          = GetWorkshopIdNumber(modname),
        fancyname   = GetModFancyName(modname)
    }
end

local function AddReportForMod(modname)
    local mod_report = CreateReportForMod(modname)
    if not mod_report.allowed then
        -- Show blocked mods at the top.
        table.insert(mods_report, 1, mod_report)
        mods_report.prohibited = true
    else
        mods_report[#mods_report + 1] = mod_report
    end
end

--------------------------------------
-- [[ Custom Mod Load Handlers ]]
--------------------------------------

PEARL.AddClassFunctionPreCall("InitializeModMain", function(self, modname)
    -- If we are in the strict mode leave the blocked mod's for the post mods load handler,
    -- so clients with blocked mods enabled will be disconnected from the server.
    if PEARL.CONFIG.MOD_BLOCKER.STRICT == true or IsModAllowed(modname) then
        return
    end

    if KnownModIndex:IsModEnabled(modname) then
        PEARL.debug("Blocking mod "..modname)
        -- Remove it from the list so ModManager doesn't count this mod as enabled anymore.
        table.removearrayvalue(self.enabledmods, modname)

        -- Disable permanently so the popup does not show each time during shard migration or reset
        KnownModIndex:Block(modname)
        SaveModIndex()
    end

    -- Stop further execution
    return false
end, ModManager)

--------------------------------------
-- [[ Local Event Listeners ]]
--------------------------------------

-- This is when the game loads for the client and we can start playing
local function OnPlayerActivated()
    if KnownModIndex:AreAnyModsBlocked() and show_popup then
        -- Inform the player that some of his mods were blocked by the server
        TheFrontEnd:PushScreen(
            PopupDialogScreen(
                STRINGS.PEARL.UI.MODS_BLOCKED_TITLE, STRINGS.PEARL.UI.MODS_BLOCKED_BODY, {
                    {
                        text = STRINGS.UI.SERVERLISTINGSCREEN.CONTINUE,
                        cb = function()
                            -- Just close the popup
                            TheFrontEnd:PopScreen()
                        end
                    }
                }, nil, nil, "dark"
            )
        )

        show_popup = false
    end
end

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    world:ListenForEvent("playeractivated", OnPlayerActivated)
    -- Show the popup in lobby as well.
    world:ListenForEvent("entercharacterselect", OnPlayerActivated)
end)

-- This is being called before we send the CFD to server.
--
-- So far the best place where to drop this check I guess
-- Load this before frontend since on FE post init we send the CFD data.
PEARL.AddFrontEndPreInit(function()
    local disconnect = false
    for _, modname in ipairs(KnownModIndex:GetModNames()) do
        if #mods_report < MAX_REPORT_COUNT and IsModReportable(modname) then
            AddReportForMod(modname)
        end

        if KnownModIndex:IsModEnabled(modname) and not IsModAllowed(modname) then
            disconnect = true

            -- Even though we are being disconnected,
            -- disable the mods in case of re-join.
            KnownModIndex:Block(modname)
        end
    end

    PEARL.ClientNetwork:SetCFDField("enabled_mods", mods_report)

    if disconnect == true then
        -- Save the changes made to the mod configurations
        SaveModIndex()

        PEARL.ClientNetwork:Disconnect("ID_DST_MODS_PROHIBITED")
    end
end)
