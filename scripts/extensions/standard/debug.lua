--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


debug.PEARL = {}

------------------------------------------
-- [[ Contants ]]
------------------------------------------

local SOURCE_PATTERN = "<%s>:%d"

function debug.PEARL.getfn(path)
    return type(path) == "string" and path:match("([^/]*).lua")
end

function debug.PEARL.getsrc(level)
    local info = debug.getinfo(level, "Sl")
    local filename = info and debug.PEARL.getfn(info.source)
    if not info or not filename or not info.currentline then
        return
    end

    return SOURCE_PATTERN:format(
        filename, info.currentline
    )
end
