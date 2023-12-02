--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


------------------------------------------
-- [[ Localization ]]
------------------------------------------

local unpack = unpack

------------------------------------------
-- [[ Extended Builtins  ]]
------------------------------------------

--- Same as the default unpack but supports nil as an argument for cleaner syntax.
--- @param t table<T>?
--- @return ...<T>
PEARL.unpack = function(t, ...)
    if t == nil then
        return t
    end

    return unpack(t, ...)
end
