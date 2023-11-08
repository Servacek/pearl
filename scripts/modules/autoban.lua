--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------------
-- [[ Constants ]]
--------------------------------------

local CONFIG = PEARL.CONFIG.AUTOBAN

local STARTING_REPUTATION = PEARL.Reputation.STARTING_VALUE

local BAN_DELAY = 5
local BAN_DELAY_OFFLINE = 0

local WARNING_HEALTH_PENALTY = 10
local WARNING_ATTACK_TYPE = "electric"
local WARNING_SANITY_PENALTY = TUNING.SANITY_MED

local WARNING_THRESHOLDS = {
    [1] = STARTING_REPUTATION / 2,
    [2] = STARTING_REPUTATION / 8,
}

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function PreparePlayerForBan(player)
    player:DoTaskInTime(2, function()
        if player.components then
            -- Drop the inventory before the ban
            if player.components.inventory then
                player.components.inventory:DropEverything()
            end

            if player.components.talker then
                player.components.talker:Say(STRINGS.PEARL.GRIEFER_WARNINGS.BAN)
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

local function OnReputationChanged(userid, old, new)
    print("OnReputationChanged", old, new)
    if old <= new then
        return
    end

    if new <= PEARL.CONFIG.AUTOBAN.THRESHOLD then
        -- Ban Time!

        local player = LookupPlayerInstByUserID(userid)
        if player then
            PreparePlayerForBan(player)
        end

        local delay = player and BAN_DELAY or BAN_DELAY_OFFLINE
        PEARL.WallScheduler:ExecuteInTime(delay, function()
            PEARL.info("Banning player", player and player:GetDisplayName() or userid, "for being a griefer.")
            TheNet:BanForTime(userid, CONFIG.DURATION)

            PEARL.DB:SafeSetField(userid, "wasautobanned", true)
            -- Reset reputation value in case of an unban.
            PEARL.Reputation:SetFor(userid, PEARL.Reputation.STARTING_VALUE)
        end)
    end
end

local function OnReputationEarned(userid, old, new)
    -- This player has too much reputation for being penalized in any way.
    -- Keeping this after ban since the threshold can be any number configured.
    if WARNING_THRESHOLDS[1] < new then
        return
    end

    local warning_level = 0
    for i = 1, #WARNING_THRESHOLDS do
        if WARNING_THRESHOLDS[i] < old and WARNING_THRESHOLDS > new then
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
-- [[ Event Listeners ]]
--------------------------------------

PEARL.EventProcessor:HandleEvent("onreputationchanged", OnReputationChanged)
PEARL.EventProcessor:HandleEvent("onreputationearned", OnReputationEarned)
