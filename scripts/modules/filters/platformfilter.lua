--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


PEARL.ServerNetwork:AddConnectionFilter(function(userid, data)
    PEARL.debug("Verifying platform", data.platform, "for user", userid)

    if not type(data.platform) == "string" or not table.contains(PEARL.CONFIG.SUPPORTED_CLIENT_PLATFORMS, data.platform) then
        return false, "ID_DST_PLATFORM_NOT_SUPPORTED"
    end
end)
