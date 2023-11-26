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
--]]

-- Maybe a better approach would be to send all the mods to the server and let it decide.
-- But in that case we would loose the option to disable the prohibited mods.

-- Use the redux version instead of the default on since this is newer
local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Private ]]
--------------------------------------

local show_popup = true

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

--------------------------------------
-- [[ Custom Mod Load Handlers ]]
--------------------------------------

PEARL.AddClassFunctionPreCall("InitializeModMain", function(self, modname)
    -- If we are in the strict mode leave the blocked mod's for the post mods load handler,
    -- so clients with blocked mods enabled will be disconnected from the server.
    if PEARL.CONFIG.MOD_BLOCKER.STRICT == true or KnownModIndex:IsModAllowed(modname) then
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
        local all_blocked = KnownModIndex:AreAllModsBlocked()

        local title = all_blocked and "MODS_BLOCKED_ALL_TITLE" or "MODS_BLOCKED_TITLE"
        local body = all_blocked and "MODS_BLOCKED_ALL_BODY" or "MODS_BLOCKED_BODY"

        -- Inform the player that some of his mods were blocked by the server
        TheFrontEnd:PushScreen(
            PopupDialogScreen(
                STRINGS.PEARL.UI[title], STRINGS.PEARL.UI[body], {
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
    -- Do not disable mods in STRICT mode
    if PEARL.CONFIG.MOD_BLOCKER.STRICT then
        return
    end

    PEARL.info("Checking the mods... again...")

    local count = 0
    local prohibited_count = 0
    for modname, _ in pairs(KnownModIndex.savedata.known_mods) do
        if KnownModIndex:IsModEnabledAny(modname) or table.contains(ModManager.enabledmods, modname)then
            count = count + 1
            if not KnownModIndex:IsModAllowed(modname) then
                prohibited_count = prohibited_count + 1

                -- Even though we are being disconnected,
                -- disable the mods in case of re-join.
                KnownModIndex:Block(modname)
            end
        end
    end

    if prohibited_count > 0 then
        -- Save the changes made to the mod configurations
        SaveModIndex()

        -- Prohibited mods were loaded even though our efforts to stop them.
        -- The only thing left is to disconnect the user...
        PEARL.ClientNetwork:Disconnect(
           (count - 1) == prohibited_count and "ID_DST_ALL_MODS_PROHIBITED" or "ID_DST_MODS_PROHIBITED"
        )
    end
end)
