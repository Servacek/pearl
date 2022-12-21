
--- @class Edible
local Edible = require("components/edible")

--------------------------------
-- [[ Member Functions ]]
--------------------------------

function Edible:GetFoodValue()
    return (self:GetHunger() / 2) + self:GetHealth()
end

function Edible:FulfillsDiet(diet)
    for _, type in ipairs(diet.types) do
        if self.foodtype == type then
            return true
        end
    end

    return false
end
