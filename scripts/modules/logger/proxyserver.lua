--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnProxyServerStart()

end

local function OnProxyServerStop()

end

local function OnProxyServerError()

end

local function OnProxyServerUnreachable()

end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddEventHandler("proxy_server_start", OnProxyServerStart)
PEARL.EventProcessor:AddEventHandler("proxy_server_error", OnProxyServerError)
PEARL.EventProcessor:AddEventHandler("proxy_server_stop", OnProxyServerStop)
PEARL.EventProcessor:AddEventHandler("proxy_server_unreachable", OnProxyServerUnreachable)
