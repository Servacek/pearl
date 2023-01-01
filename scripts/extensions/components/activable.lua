
--- @class Activatable
local Activatable = require("components/activatable")

--------------------------------
-- [[ Getters ]]
--------------------------------

function Activatable:IsLastPlayerActivator()
    return self._last_player_ac
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function Activatable:SetLastPlayerActivator(activator)
    self._last_player_ac = activator
end
