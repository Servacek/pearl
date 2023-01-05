--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



----------------------------------
-- Declaration
----------------------------------

--- @class ClientNetwork
local ClientNetwork = {}

----------------------------------
-- Public
----------------------------------

function ClientNetwork:Disconnect(reason)
    PEARL.info("ClientNetwork:Disconnect", reason)

    PEARL.ClientLoader:CancelDelayedLoad()
    TheNet:JoinServerResponse(true)
    TheNet:Disconnect(true)
    OnNetworkDisconnect(reason, true, false)
end

return ClientNetwork
