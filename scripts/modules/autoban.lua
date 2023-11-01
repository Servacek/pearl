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

local BAN_DELAY = 5
local BAN_DELAY_OFFLINE = 0

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

local function OnReputationChanged(userid, old, new)
    if old <= new then
        return
    end

    if PEARL.CONFIG.AUTOBAN.ENABLED == true and new <= PEARL.CONFIG.AUTOBAN.THRESHOLD then
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
        end)
    end
end

--------------------------------------
-- [[ Event Listeners ]]
--------------------------------------

PEARL.EventProcessor:HandleEvent("onreputationchanged", OnReputationChanged)
