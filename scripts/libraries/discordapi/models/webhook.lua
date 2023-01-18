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
-- [[ Class Declarations ]]
-------------------------------------

--- @class Webhook Dataclass representing a discord webhook object
local Webhook = Class(function(self, id, token)
    self._id = id
    self._token = token

    self.url = PEARL.CONSTS.DISCORD.WEBHOOK_URL_TEMPLATE:format(
        PEARL.CONSTS.DISCORD.API_VERSION, self._id, self._token
    )
end)

return Webhook
