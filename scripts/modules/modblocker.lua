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

local PEARL = PEARL
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

local _were_mods_blocked = false

local function IsModAllowed(modname)
    local client_only_mod = KnownModIndex:GetModInfo(modname).client_only_mod
    if not client_only_mod then
        return true
    end

    return IsWorkshopMod(modname) and MOD_BLACKLIST[modname] ~= true
end

local function SaveModIndex()
    --- @NOTE: This only works if DEVELOPER MODE is OFF!
    KnownModIndex:Save()

    if PEARL.CONFIG.DEBUG_MODE then
        PEARL.OverrideGlobal("BRANCH", not _G.BRANCH)
        KnownModIndex:Save()
        PEARL.OverrideGlobal("BRANCH", not _G.BRANCH)
    end
end

--------------------------------------
-- [[ Custom Mod Load Handlers ]]
--------------------------------------

PEARL.AddClassFunctionPreCall("InitializeModMain", function(self, modname)
    if IsModAllowed(modname) then
        return true
    end

    PEARL.debug("Blocking mod "..modname)
    -- Remove it from the list so ModManager doesn't count this mod as enabled anymore.
    table.removearrayvalue(self.enabledmods, modname)

    -- Disable permanently so the popup does not show each time during shard migration or reset
    KnownModIndex:Disable(modname)
    SaveModIndex()

    _were_mods_blocked = true

    -- Stop further execution
    return false
end, ModManager)

--------------------------------------
-- [[ Local Event Listeners ]]
--------------------------------------

-- This is when the game loads for the client and we can start playing
local function OnPlayerActivated()
    if _were_mods_blocked then
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
        _were_mods_blocked = false
    end
end

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

AddPlayerPostInit(function(inst)
    inst:ListenForEvent("playeractivated", OnPlayerActivated)
end)

-- Mod loading should be completed at this point.
-- We are using frontend class since 'ModIndex:EndStartupSequence'
-- is being called too late so the server send's the join announcement.
PEARL.AddClientPreLoad(function()
    -- if PEARL.ClientLoader:IsLoaded() then
    --     return
    -- end

    local enabled_mods = ModManager:GetEnabledModNames()
    if type(enabled_mods) ~= "table" then
        return
    end

    local prohibited_mods = false
    for _, modname in ipairs(enabled_mods) do
        if not IsModAllowed(modname) and KnownModIndex:IsModEnabled(modname) then
            prohibited_mods = true

            -- Even though we are being disconnected,
            -- disable the mods in case of re-join.
            KnownModIndex:Disable(modname)
        end
    end

    if prohibited_mods then
        -- Save the changes made to the mod configurations
        SaveModIndex()

        PEARL.ClientNetwork:Disconnect("ID_DST_MODS_PROHIBITED")

        return false
    end
end)

if PEARL.ClientLoader then
    if PEARL.ClientLoader:GetLoadDelay() ~= nil then
        -- No load delay if we are the only module using the client loader
        PEARL.ClientLoader:SetLoadDelay(0)
    end

    -- Enable client loader
    PEARL.ClientLoader:SetIsDisabled(false)
end
