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

-- maps an integer x from the range <s_min, s_max> to the new range <d_min, d_max>
function math.map(x, s_min, s_max, d_min, d_max)
    if x < s_min or x > s_max then
        return error("number not from given interval")
    end

    if s_min == s_max or d_min == d_max then
        return error("invalid source or destination range provided")
    end

    local src, dst = (s_max - s_min), (d_max - d_min)
    return math.floor(d_min + x * (dst / src))
end
