--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]




function math.round(num, dp)
    local mult = 10^(dp or 0)

    return math.floor((num * mult) + 0.5) / mult
end

function math.sigmoid(x)
    return 1 / (1 + math.exp(-x))
end

function math.logb(x, base)
    return math.log(x) / math.log(base)
end
