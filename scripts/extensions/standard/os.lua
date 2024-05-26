--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local _os = os
local m_floor = math.floor

local AVERAGE_SECONDS_PER_YEAR = 60 * 60 * 24 * ((365 * 3 + 366) / 4)

os.path = {
    basename = function()

    end
}

function os.timediffyears(t1, t2)
    t2 = t2 or _os.time()
    return m_floor((t2 - t1) / AVERAGE_SECONDS_PER_YEAR)
end
