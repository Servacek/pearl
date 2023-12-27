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

function ActionLogQueue()
    local log = c_spawn("log")
    log.components.stackable:SetStackSize(11)

    ActionLog:EntityAct("{doer} lit {target}!", "Fi7iP")
        :AddTarget(c_spawn("pigman"))
        :AddTarget(c_spawn("rocks"))
        :AddTarget(log)
        :AddTarget(c_spawn("log"))
        :AddTarget(c_spawn("pigman"))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.IGNITE)

    ActionLog:Act("{target} burnt up!")
        :AddTarget(log)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)
end

function NonStackable()
    ActionLog:EntityAct("{doer} flew up!", "Fi7iP")

    ActionLog:EntityAct("{doer} flew up!", "Fi7iP")
end

function RawActionLogQueue()
    local log = c_spawn("log")
    log.components.stackable:SetStackSize(11)

    return ActionLog:EntityAct("{doer} lit {target}! Owner: {owner}", "Fi7iP",
        QueuedLogAction.FIELDS.OWNER, "Franta")
        :AddTarget(c_spawn("rocks"))
        :AddTarget(log)
        :AddTarget(c_spawn("log"))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)

end
