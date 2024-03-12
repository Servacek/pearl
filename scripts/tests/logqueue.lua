--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local ActionLog = PEARL.loadfile("libraries/actionlog")
local QueuedLogAction = PEARL.loadfile("models/queuedlogaction")

-- function ActionLogQueue()
--     local log = c_spawn("log")
--     log.components.stackable:SetStackSize(11)

--     ActionLog:EntityAct("{doer} lit {target}!", "Fi7iP")
--         :AddTarget(c_spawn("pigman"))
--         :AddTarget(c_spawn("rocks"))
--         :AddTarget(log)
--         :AddTarget(c_spawn("log"))
--         :AddTarget(c_spawn("pigman"))
--         :SetLogType(PEARL.CONSTS.ANN_TYPE.IGNITE)

--     ActionLog:Act("{target} burnt up!")
--         :AddTarget(log)
--         :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)
-- end

-- function NonStackable()
--     ActionLog:EntityAct("{doer} flew up!", "Fi7iP")

--     ActionLog:EntityAct("{doer} flew up!", "Fi7iP")
-- end

-- function RawActionLogQueue()
--     local log = c_spawn("log")
--     log.components.stackable:SetStackSize(11)

--     return ActionLog:EntityAct("{doer} lit {target}! Owner: {owner}", "Fi7iP",
--         QueuedLogAction.FIELDS.OWNER, "Franta")
--         :AddTarget(c_spawn("rocks"))
--         :AddTarget(log)
--         :AddTarget(c_spawn("log"))
--         :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)

-- end

function TestActions()
    local log = c_spawn("log")
    log.components.stackable:SetStackSize(11)

    ActionLog:EntityAct("{doer} zapálil/a {target}!", "Fi7iP")
        :AddTarget(c_spawn("pigman"))
        :AddTarget(c_spawn("rocks"))
        :AddTarget(log)
        :AddTarget(c_spawn("log"))
        :AddTarget(c_spawn("pigman"))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.IGNITE)
        :Execute()

    ActionLog:EntityAct("{doer} vykopal/a {target}.", "Gertrúda")
        :AddTarget(c_spawn("berrybush"))
        :AddTarget(c_spawn("berrybush"))
        :AddTarget(c_spawn("berrybush"))
        :AddTarget(c_spawn("sapling"))
        :AddTarget(c_spawn("sapling"))
        :AddTarget(c_spawn("grass"))
        :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.SHOVEL)
        :Execute()

    ActionLog:EntityAct("{doer} zjedol/a {target}.", "Gertrúda")
        :AddTarget(c_spawn("berries"))
        :AddTarget(c_spawn("berries"))
        :AddTarget(c_spawn("berries"))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.EAT)

    ActionLog:LogAction(ActionLog:EntityAct("{doer} zasadil/a {target}.", "Gertrúda")
        :AddTarget(c_spawn("berrybush"))
        :AddTarget(c_spawn("berrybush"))
        :AddTarget(c_spawn("berrybush"))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.PLANT)
    )

    PEARL.DiscordLogger:ProccessBuffer()

    PEARL.WallScheduler:ExecuteInTime(3, function()
        ActionLog:EntityAct("{doer} priložil/a {target} do {source}.", "Borb", "source", c_spawn("firepit"))
            :AddTarget(c_spawn("sapling"))
            :AddTarget(c_spawn("sapling"))
            :SetLogType(PEARL.CONSTS.ANN_TYPE.PROPAGATOR)
    end)

    PEARL.WallScheduler:ExecuteInTime(2, function()
        ActionLog:EntityAct("{doer} pohnojil/a {target} s {item}.", "Borb", "item", c_spawn("poop"))
            :AddTarget(c_spawn("berrybush"))
            :AddTarget(c_spawn("berrybush"))
            :AddTarget(c_spawn("berrybush"))
            :AddTarget(c_spawn("grass"))
            :SetLogType(PEARL.CONSTS.ANN_TYPE.FERTILIZE)
    end)

    PEARL.WallScheduler:ExecuteInTime(4, function()
        ActionLog:LogAction(ActionLog:EntityAct("{doer} porazili {target}!", "Mlaskal a Pigman")
            :AddTarget(c_spawn("deerclops"))
            :SetLogType(PEARL.CONSTS.ANN_TYPE.DEFEAT)
        )

        PEARL.DiscordLogger:ProccessBuffer()

        PEARL.WallScheduler:ExecuteInTime(10, function()
            ActionLog:LogAction(ActionLog:EntityAct("{doer} zabil/a {target}!", "Mlaskal")
                :AddTarget(c_spawn("pigman"))
                :SetLogType(PEARL.CONSTS.ANN_TYPE.KILL)
            )

            PEARL.DiscordLogger:ProccessBuffer()

            ActionLog:LogAction(ActionLog:EntityAct("{doer} zjedol/a {target}!", "Pigman")
                :AddTarget(c_spawn("deerclops_eyeball"))
                :SetLogType(PEARL.CONSTS.ANN_TYPE.WASTE)
            )

            PEARL.DiscordLogger:ProccessBuffer()
        end)

        PEARL.WallScheduler:ExecuteInTime(20, function()
            local meat = c_spawn("meat")
            meat.components.stackable:SetStackSize(8)

            ActionLog:EntityAct("{doer} uvaril/a {target} na {tool}!", "Mlaskal", "tool", c_spawn("firepit"))
                :AddTarget(meat)
                :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.FIREPIT)

            ActionLog:EntityAct("{doer} zaspal/a v {target}!", "Mlaskal")
                :AddTarget(c_spawn("tent"))
                :SetLogType(PEARL.CONSTS.ANN_TYPE.SLEEP)

            ActionLog:EntityAct("{doer} uvaril/a {target} v {tool}.", "Gertrúda", "tool", c_spawn("cookpot"))
                :AddTarget(c_spawn("ratatouille"))
                :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.CROCKPOT)

            ActionLog:Act("{target} zhorelo!")
                :AddTarget(log)
                :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)
        end)
    end)
end
