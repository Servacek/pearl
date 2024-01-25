--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local ItemDepositor = PEARL.loadfile("libraries/itemdepositor")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local CONFIG = PEARL.CONFIG.AUTOBAN

local BAN_DELAY = 5
local BAN_DELAY_OFFLINE = 0

local WARNING_HEALTH_PENALTY = 10
local WARNING_ATTACK_TYPE = "electric"
local WARNING_SANITY_PENALTY = TUNING.SANITY_MED

local WARNING_THRESHOLDS = {
    [1] = PEARL.Reputation.LIMIT.BAD,
    [2] = PEARL.Reputation.LIMIT.VERY_BAD / 2,
}

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function IsPlayerUntouchable(userid)
    return PEARL.ServerNetwork:IsAdmin(userid) and not PEARL.CONFIG.DEBUG_MODE
end

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function PreparePlayerForBan(player)
    player:DoTaskInTime(2, function()
        if player.components then
            if player.components.talker then
                player.components.talker:Say(STRINGS.PEARL.GRIEFER_WARNINGS.BAN)
            end

            if player.components.inventory then
                -- Return the items to the base.
                ItemDepositor:DepositAllItems(player.components.inventory)
            end
        end

        -- Let's ban them in style
        player.sg:GoToState("teleportato_teleport")
    end)
end

local function WarnPlayer(player, level)
    -- Drop the equiped item
    if player.components.inventory then
        local handitem = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if handitem then
            Launch(player.components.inventory:DropItem(handitem), player, 3)
        end
    end

    -- Electric shock and -10 * warning_count HP
    if player.components.combat then
        player.components.combat:GetAttacked(
            nil, WARNING_HEALTH_PENALTY * level, nil, WARNING_ATTACK_TYPE
        )
    end

    -- Change state
    if not player.sg:HasStateTag("busy") then
        player.sg:GoToState("hit")
    end

    -- Decrease the sanity
    if player.components.sanity then
        player.components.sanity:DoDelta(-WARNING_SANITY_PENALTY * level)
    end

    -- Display warning text for the player
    if player.components.talker then
        player.components.talker:Say(
            STRINGS.PEARL.GRIEFER_WARNINGS[level][
                math.random(#STRINGS.PEARL.GRIEFER_WARNINGS)
            ]
        )
    end
end

local function BanPlayer(userid, player)
    local delay = player and BAN_DELAY or BAN_DELAY_OFFLINE
    PEARL.WallScheduler:ExecuteInTime(delay, function()
        PEARL.info("Banning player", player and player:GetDisplayName() or userid, "for being a griefer.")
        TheNet:BanForTime(userid, CONFIG.DURATION, STRINGS.PEARL.UI.STATIC_BAN_REASONS.AUTO, PEARL.CONSTS.BAN_AUTHORS.SYSTEM)
    end)
end

local function CheckForBanableRep(userid, rep)
    rep = rep or PEARL.Reputation:GetOf(userid)
    if rep < PEARL.CONFIG.AUTOBAN.THRESHOLD then
        -- Ban Time!

        local player = LookupPlayerInstByUserID(userid)
        if player then
            PreparePlayerForBan(player)
        end

        BanPlayer(userid, player)
    end
end

local function OnReputationChanged(userid, old, new)
    if old <= new or IsPlayerUntouchable(userid) then
        return
    end

    CheckForBanableRep(userid)
end

local function OnReputationEarned(userid, old, new)
    -- This player has too much reputation for being penalized in any way.
    -- Keeping this after ban since the threshold can be any number configured.
    if WARNING_THRESHOLDS[1] < new or IsPlayerUntouchable(userid) then
        return
    end

    local warning_level = 0
    for i = 1, #WARNING_THRESHOLDS do
        -- We have just crossed the threshold
        if WARNING_THRESHOLDS[i] < old and WARNING_THRESHOLDS[i] > new then
            warning_level = i
        else
            break -- No other threshold will meet the criteria.
        end
    end

    if warning_level > 0 then
        local player = LookupPlayerInstByUserID(userid)
        if player then
            WarnPlayer(player, warning_level)
        end
    end
end

--------------------------------------
-- [[ Connection Filters ]]
--------------------------------------

PEARL.ServerNetwork:AddConnectionFilter(function(userid)
    CheckForBanableRep(userid)
end)

--------------------------------------
-- [[ Event Listeners ]]
--------------------------------------

PEARL.EventProcessor:AddSafeEventHandler("onreputationchanged", OnReputationChanged)
PEARL.EventProcessor:AddSafeEventHandler("onreputationearned", OnReputationEarned)
