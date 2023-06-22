--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @TODO: Add griefness and reputation components here!
PEARL.AddPlayerPostInit(function(player)
    if not player or not player.userid then
        return
    end

    PEARL.PlayerDB:UpdateRecordFor(player)
end)

PEARL.EventProcessor:AddSafeEventHandler("save", function()
    PEARL.info("Saving the database.")
    PEARL.PlayerDB:Save()
end)

PEARL.EventProcessor:AddSafeEventHandler("quit", function()
    PEARL.info("Saving the database.")
    PEARL.PlayerDB:Save()
end)
