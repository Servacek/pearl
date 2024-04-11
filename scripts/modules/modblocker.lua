--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd


--[[
    Blocks some hacky mods from loading on the client.
--]]

-- Use the redux version instead of the default on since this is newer
local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Private ]]
--------------------------------------

local show_blocked_popup = true

local function PreventManagerFromLoadingMod(modname)
    if type(ModManager.enabledmods) == "table" then
        -- Remove it from the list so ModManager doesn't count this mod as enabled anymore.
        table.removearrayvalue(ModManager.enabledmods, modname)
    end
end

local function BlockMod(modname, nosaving, temp)
    PEARL.debug("Blocking mod "..modname)

    PreventManagerFromLoadingMod(modname)

    if temp == nil then
        -- We do not want to permanently block mods that are just not whitelisted.
        temp = not KnownModIndex:ShouldDisableMod(modname)
    end

    KnownModIndex:Block(modname, temp)

    if nosaving ~= true then
        KnownModIndex:Save()
    end
end

local function VerifyAllLoadedMods()
    local bypassed = false
    for modname, _ in pairs(KnownModIndex.savedata.known_mods) do
        if KnownModIndex:IsModEnabledAny(modname) or table.contains(ModManager.enabledmods, modname) then
            -- If a prohibited mod managed to bypass the loading check.
            -- For uncompatible mods, we will let them bypass this. At worst, they will crash on their own...
            if KnownModIndex:IsModProhibited(modname) and not KnownModIndex:IsModBlocked(modname) then
                -- Even though we are being disconnected,
                -- disable the mods in case of re-join.
                BlockMod(modname, true)

                bypassed = true
            end
        end
    end

    -- Save the changes made to the mod configurations
    KnownModIndex:Save()

    return bypassed
end

--------------------------------------
-- [[ Custom Mod Load Handlers ]]
--------------------------------------

PEARL.AddClassFunctionPreCall("InitializeModMain", function(self, modname)
    if modname == PEARL.MODNAME then
        return -- It's a reasonable idea to not block ourselves I guess.
    end

    if not KnownModIndex:IsModCompatibleWith(PEARL.MODNAME, modname) then
        if not KnownModIndex:IsModEnabledAny(modname) then
            PEARL.info("Temporarily disabling mod", modname, "because it's not compatible!")
            KnownModIndex:TempDisable(modname)

            PreventManagerFromLoadingMod(modname)
        end

        return false -- Silently prevent incompatible mods from loading.
    end

    -- Block prohibited mods while loading.
    -- Each mod calls this function exactly two times (modmain and modworldgenmain)
    if KnownModIndex:IsModProhibited(modname) then
        if not KnownModIndex:IsModBlocked(modname) then
            BlockMod(modname)
        end

        -- Stop further loading of the mod.
        return false
    end
end, ModManager)

--------------------------------------
-- [[ Local Event Listeners ]]
--------------------------------------

-- This is when the game loads for the client and we can start playing
local function OnPlayerActivated()
    if KnownModIndex:AreAnyModsBlocked() and show_blocked_popup then
        show_blocked_popup = false

        local all_blocked = KnownModIndex:AreAllModsBlocked()

        local title = all_blocked and "MODS_BLOCKED_ALL_TITLE" or "MODS_BLOCKED_TITLE"
        local body = all_blocked and "MODS_BLOCKED_ALL_BODY" or "MODS_BLOCKED_BODY"

        local popup
        popup = PopupDialogScreen(
            STRINGS.PEARL.UI[title], STRINGS.PEARL.UI[body], {
                {
                    text = STRINGS.UI.SERVERLISTINGSCREEN.CONTINUE,
                    cb = function()
                        -- Just close the popup
                        TheFrontEnd:PopScreen(popup)
                    end
                }
            }, nil, nil, "dark"
        )

        -- Inform the player that some of his mods were blocked by the server
        TheFrontEnd:PushScreen(popup)
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
--
-- At this point we can also show some popups if needed.
PEARL.AddFrontEndPreInit(function()
    PEARL.info("Checking the mods... again...")

    -- Determines wheters at least one mod was blocked
    -- during regular loading.
    local bypassed = VerifyAllLoadedMods()

    --- @NODE: STRICT mode is handled by the server!
    --- is allowed and at least one mod was blocked.
    if bypassed then
        -- Prohibited mods were loaded even though our efforts to stop them.
        -- The only thing left is to disconnect the user...
        PEARL.ClientNetwork:Disconnect(
           KnownModIndex:AreAllModsBlocked() and "ID_DST_ALL_MODS_PROHIBITED" or "ID_DST_MODS_PROHIBITED"
        )
    end
end)
