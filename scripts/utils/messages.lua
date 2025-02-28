--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local EMBEDS = PEARL.loadfile("utils/embeds")

local Message = PEARL.loadfile("libraries/discordapi/models/message")

----------------------------------
-- Declaration
----------------------------------

local MESSAGES = {}

----------------------------------
-- Public
----------------------------------

function MESSAGES.InvReport(userid, pref)
    -- Maybe even calculate the suspiciousness here?
    return Message()
        :AddEmbed(EMBEDS.SuspiciousInventory(pref or PEARL.GetPlayerMetadataFor(userid)))
end

function MESSAGES.ModsReport(userid, mods)
    return Message():AddEmbed(EMBEDS.ClientMods(mods, userid))
end

----------------------------------
-- Return
----------------------------------

return MESSAGES
