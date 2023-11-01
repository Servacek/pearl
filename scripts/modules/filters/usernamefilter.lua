--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Username Profanity Filter ]]
-------------------------------------

PEARL.ServerNetwork:AddConnectionFilter(function(userid, data)
    if type(data.username) ~= "string" then
        return
    end

    local valid

    -- Check if the username has changed.
    -- Note: On first join the username will be nil!
    local saved_username = PEARL.DB:GetField(userid, "username")
    if saved_username == data.username then
        valid = PEARL.DB:GetField(userid, "usernamevalid")
    else
        valid = not ProfanityFilter:Detect(data.username)
    end

    PEARL.DB:SafeSetField(userid, "usernamevalid", valid)
    return valid, "ID_DST_USERNAME_BLOCKED"
end)
