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
        - If blocked mods are detected after loading,
          send the mod list to the server...
--]]

local IsWorkshopMod = IsWorkshopMod

-- Use the redux version instead of the default on since this is newer
local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local MOD_BLACKLIST = PEARL.CONFIG.MOD_BLACKLIST

--------------------------------------
-- [[ Private ]]
--------------------------------------

local were_mods_blocked = false

local mods_report = {}
PEARL.ClientNetwork:SetCFDField("enabled_mods", mods_report)

--------------------------------------
-- [[ Helper Wrappers ]]
--------------------------------------

local function IsClientOnlyMod(modname)
    local modinfo = KnownModIndex:GetModInfo(modname)
    return modinfo and modinfo.client_only_mod == true
end

local function IsModBlacklisted(modname)
    return MOD_BLACKLIST[modname] == true
end

local function IsModPrivate(modname)
    return not IsWorkshopMod(modname)
end

local function IsModAllowed(modname)
    -- If the mod is not client_only then it's allowed without any further checks.
    return not IsClientOnlyMod(modname) or (not IsModBlacklisted(modname) and not IsModPrivate(modname))
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

local function AddReportForMod(modname)
    local blocked = IsModBlacklisted(modname)
    mods_report[modname] = {
        client_only = IsClientOnlyMod(modname),
        private     = IsModPrivate(modname),
        blocked     = blocked,
        id          = GetWorkshopIdNumber(modname),
        temp        = KnownModIndex:IsModTempEnabled(modname),
        fancyname   = GetModFancyName(modname)
    }

    if blocked then
        PEARL.ClientNetwork:SetCFDField("mods_prohibited", true)
    end
end

--------------------------------------
-- [[ Custom Mod Load Handlers ]]
--------------------------------------

PEARL.AddClassFunctionPreCall("InitializeModMain", function(self, modname)
    -- If we are in the strict mode leave the blocked mod's for the post mods load handler,
    -- so clients with blocked mods enabled will be disconnected from the server.
    if MOD_BLACKLIST.strict == true then
        return
    end

    if not mods_report[modname] then
        AddReportForMod(modname)
    end

    if IsModAllowed(modname) then
        return true
    end

    PEARL.debug("Blocking mod "..modname)
    -- Remove it from the list so ModManager doesn't count this mod as enabled anymore.
    table.removearrayvalue(self.enabledmods, modname)

    -- Disable permanently so the popup does not show each time during shard migration or reset
    KnownModIndex:Disable(modname)
    SaveModIndex()

    were_mods_blocked = true

    -- Stop further execution
    return false
end, ModManager)

--------------------------------------
-- [[ Local Event Listeners ]]
--------------------------------------

-- This is when the game loads for the client and we can start playing
local function OnPlayerActivated()
    if were_mods_blocked then
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

        -- We do not want multiple popup windows.
        were_mods_blocked = false
    end
end

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

PEARL.AddPlayerPostInit(function(inst)
    inst:ListenForEvent("playeractivated", OnPlayerActivated)
    -- Show the popup in lobby as well.
    inst:ListenForEvent("entercharacterselect", OnPlayerActivated)
end)

-- So far the best place where to drop this check I guess
-- Load this before frontend since on FE post init we send the CFD data.
PEARL.AddFrontEndPreInit(function()
    local prohibited_mods = false
    for _, modname in ipairs(ModManager:GetEnabledModNames() or {}) do
        if not mods_report[modname] then
            AddReportForMod(modname)
        end

        if not IsModAllowed(modname) and KnownModIndex:IsModEnabled(modname) then
            prohibited_mods = true

            -- Even though we are being disconnected,
            -- disable the mods in case of re-join.
            KnownModIndex:Disable(modname)
        end
    end

    if prohibited_mods == true then
        -- Save the changes made to the mod configurations
        SaveModIndex()

        PEARL.ClientNetwork:Disconnect("ID_DST_MODS_PROHIBITED")
    end
end)
