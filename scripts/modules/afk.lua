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
    Implements the Anti-AFK system.

    NOTES:
        - 'TheNet:Announce' works only server-side.
--]]

-- TheInput should never be nil
--assert(TheInput, "TheInput is nil!")

local PEARL, USERFLAGS = PEARL, USERFLAGS
local TheNet, TheInput = TheNet, TheInput

local UserCommands = require("usercommands")

--------------------------------------
-- [[ AFK Timer ]]
--------------------------------------

local INIT_DELAY = 1 * 60

local AFK_TIME = PEARL.CONFIG.AFK_TIME --1 * 60
local AFK_TIME_INCREMENT = 1 -- +1 every second
local AFK_TIME_KICK = PEARL.CONFIG.AFK_TIME_KICK -- 5 * 60

local AFK_TIME_GHOST_MULT = .5

--------------------------------------
-- [[ Private ]]
--------------------------------------

-- In seconds
local _afk_time_current = 0
local _afk_time_to_kick = AFK_TIME_KICK
local _is_afk = false
local _is_ghost_sanity_drain_enabled = GetGhostSanityDrain(TheNet:GetServerGameMode())
local _tracking_task = nil

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

-- Notify the server that our AFK state changed so it can announce it, for example.
local function UpdateAFKState(afk, kicked)
    if _is_afk ~= afk or kicked then
        _is_afk = afk

        PEARL.SendRPCToServer(PEARL.RPC.AFKStateChanged, afk, kicked)
    end
end

local function OnPlayerRespawnedFromGhost()
    _afk_time_to_kick = AFK_TIME
end

local function OnPlayerBecameGhost()
    _afk_time_to_kick = AFK_TIME * AFK_TIME_GHOST_MULT
end

local function OnBecomeInactive()
    if ThePlayer then
        if ThePlayer.Network then
            ThePlayer.Network:AddUserFlag(USERFLAGS.IS_AFK)
        end

        -- Kick ghosts faster.
        if not ThePlayer:HasTag("playerghost") and ThePlayer.sg and not ThePlayer.sg:HasStateTag("busy") then
            UserCommands.RunUserCommand(
                "sit", {}, ThePlayer, false
            )
        end
    end

    UpdateAFKState(true)
end

local function OnBecomeActive()
    if ThePlayer and ThePlayer.Network then
        ThePlayer.Network:RemoveUserFlag(USERFLAGS.IS_AFK)
    end

    UpdateAFKState(false)
end

local function ResetAFKTime()
    _afk_time_current = 0
end

local function IsTrackingEnabled()
    return not IsMigrating() and InGamePlay() and (not ThePlayer or not ThePlayer:HasTag("sleeping"))
end

--------------------------------------
-- [[ Task Handlers ]]
--------------------------------------

local function StopTrackingTask()
    if _tracking_task ~= nil then
        _tracking_task:Cancel()
        _tracking_task = nil
    end
end

local function CleanUp()
    StopTrackingTask()
    ResetAFKTime()

    _is_afk = false
    if ThePlayer then
        if ThePlayer.Network then
            ThePlayer.Network:RemoveUserFlag(USERFLAGS.IS_AFK)
        end

        ThePlayer:RemoveEventCallback("ms_becameghost", OnPlayerBecameGhost)
        ThePlayer:RemoveEventCallback("ms_respawnedfromghost", OnPlayerRespawnedFromGhost)
    end
end

local function IsPaused()
    return TheNet:IsServerPaused() or #AllPlayers < 1
end

local function OnUpdate()
    if IsPaused() then
        return
    end

    -- Make sure we are not migrating or sleeping, etc...
    if not IsTrackingEnabled() then
        ResetAFKTime()
        return
    end

    _afk_time_current = _afk_time_current + AFK_TIME_INCREMENT
    if _afk_time_to_kick > 0 and _afk_time_current > _afk_time_to_kick then
        UpdateAFKState(true, true)
        PEARL.ClientNetwork:ForceDisconnectWithReason("ID_DST_USER_INACTIVE")

        CleanUp()
        return
    end

    if _afk_time_current >= AFK_TIME and not _is_afk then
        OnBecomeInactive()
    end
end

local function RestartTrackingTask()
    -- TheWorld should be a non-nil value each time this is called, but just in case
    if TheWorld then
        -- If a task exists, restart it for the init delay
        StopTrackingTask()

        -- Associate this task with the world object since it's more stable
        -- and avaiable even in lobby.
        -- Maybe try to use normal periodic task so when sim is paused this is paused as well?
        _tracking_task = TheWorld:DoPeriodicTask(AFK_TIME_INCREMENT, OnUpdate, INIT_DELAY)
    end
end

--------------------------------------
-- [[ Input Handlers ]]
--------------------------------------

-- Called whenever we use the keyboard, mouse or any other controller.
-- We need to restart the AFK timer here.
local function OnInputAny()
    if _afk_time_current and _afk_time_current > 0 then
        ResetAFKTime()

        if _is_afk then
            OnBecomeActive()
        end
    end
end

-- This handles all controll buttons the game can use for all controllers (mouse, joystick, keyboard, ...)
-- Even for chats and consoles.
PEARL.AddClassFunctionPreCall("OnControl", OnInputAny, TheInput)
TheInput:AddMoveHandler(OnInputAny) -- Moving the cursor with a mouse

--------------------------------------
-- [[ Connection Handlers ]]
--------------------------------------

PEARL.AddGlobalFunctionPreCall("OnNetworkDisconnect", CleanUp)

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

local function OnPlayerEnteredGame()
    -- Just to make sure the afk state is properly cleaned up
    -- And we begin with the initial join delay.
    CleanUp()
    OnBecomeActive()
    RestartTrackingTask()

    if ThePlayer ~= nil and _is_ghost_sanity_drain_enabled then
        ThePlayer:ListenForEvent("ms_becameghost", OnPlayerBecameGhost)
        ThePlayer:ListenForEvent("ms_respawnedfromghost", OnPlayerRespawnedFromGhost)
    end
end

local function OnPlayerLeftGame()
    CleanUp()
end

PEARL.AddWorldPostInit(function(world)
    world:ListenForEvent("playeractivated", OnPlayerEnteredGame)
    world:ListenForEvent("playerdeactivated", OnPlayerLeftGame)

    -- This is an lobby alternative for playeractivated
    world:ListenForEvent("entercharacterselect", OnPlayerEnteredGame)
end)
