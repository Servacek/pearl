--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
    Periodically checks for new versions of mods and automatically updates the server,
    when an mod update happens.

    This is partly in the game already but it's quite poorly implemented,
    it will spam the server with "mod-out-of-date" messages every 2 minutes
    and it's not even configurable at all. Also it doesn't work when the server
    is paused due to how the built-in scheduler is designed.

    This module fixes these problems, making it less annoying. It's basically an extension
    but I am keeping it in modules cuz of it's high configurablity.
--]]

-------------------------------------
-- [[ Variables ]]
-------------------------------------

--- @type Task?, string?
local task, outdated_mod_fancyname

local _Networking_ModOutOfDateAnnouncement

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function AreAnyModsOutdated()
    return outdated_mod_fancyname ~= nil
end

local function AnnounceOutdatedMods(outdated_mod_fancy_name)
    _Networking_ModOutOfDateAnnouncement(outdated_mod_fancy_name)
end

local function DoVersionCheckTask(mods_to_verify)
    if AreAnyModsOutdated() then
        return AnnounceOutdatedMods(outdated_mod_fancyname)
    end

    -- The actual checking and announcing part is done in the engine.
    TheSim:VerifyModVersions(mods_to_verify)
end

local function GetModsToVerify()
    local mods_to_verify = {}
    for _, modname in ipairs(ModManager:GetEnabledServerModNames()) do
        if not modname:blank() then
            local modinfo = KnownModIndex:GetModInfo(modname)
            if modinfo.all_clients_require_mod then
                mods_to_verify[#mods_to_verify + 1] = {
                    name = modname,
                    version = modinfo.version,
                    version_compatible = modinfo.version_compatible,
                }
            end
        end
    end

    return mods_to_verify
end

local function OnModOutdated(mod_fancy_name)
    outdated_mod_fancyname = mod_fancy_name

    if PEARL.ServerNetwork:GetConnectedClientsCount() <= 0 and task ~= nil then
        task:cancel()
    end
end

-------------------------------------
-- [[ Function Overrides ]]
-------------------------------------

function ModManager:StartVersionChecking()
    if task ~= nil then
        return PEARL.error("Mod version check task already running!")
    end

    local mods_to_verify = GetModsToVerify()
    if table.empty(mods_to_verify) == false then
        local check_after_seconds = PEARL.CONFIG.MOD_VERSION_CHECKER.CHECK_AFTER_MINUTES * 60
        task = PEARL.WallScheduler:ExecutePeriodic(
            check_after_seconds, DoVersionCheckTask, 60,
            PEARL.CONFIG.MOD_VERSION_CHECKER.INITIAL_DELAY, nil, mods_to_verify
        )
    end
end

--------------------------------------
-- [[ Callbacks ]]
--------------------------------------

-- Called directly by the engine when it detects a version mismatch.
_Networking_ModOutOfDateAnnouncement = assert(PEARL.OverrideGlobalVariable( --- @type function
    "Networking_ModOutOfDateAnnouncement", OnModOutdated
))

--------------------------------------
-- [[ Exposing Local Functions ]]
--------------------------------------

--- Expose these in case someone wants to add custom behaviour to them.
return {
    GetModsToVerify = GetModsToVerify,
    DoVerifyModVersions = DoVersionCheckTask,
    AreAnyModsOutOfDate = AreAnyModsOutdated,
    OnModOutdated = OnModOutdated,
}
