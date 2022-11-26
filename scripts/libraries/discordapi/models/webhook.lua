
--- @class Webhook Dataclass representing a discord webhook object
local Webhook = Class(function(self, id, token)
    self._id = id
    self._token = token

    self.url = PEARL.CONSTS.DISCORD.WEBHOOK_URL_TEMPLATE:format(
        PEARL.CONSTS.DISCORD.API_VERSION, self._id, self._token
    )
end)

return Webhook
