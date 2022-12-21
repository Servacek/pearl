--[[
   Additional utility functions for the age component
--]]

--- @class Age
local Age = require("components/age")

--------------------------------
-- [[ Contants ]]
--------------------------------

-- local MIN_TRUSTWORTHY_AGE   = 24
-- local MAX_NEWCOMER_AGE      = 5

--------------------------------
-- [[ Public Functions ]]
--------------------------------

function Age:IsTrustworthy()
    return self:GetAgeInDays() >= PEARL.TRUST_AGE
end

-- function Age:IsNewcomer()
--     return self:GetAgeInDays() <= MAX_NEWCOMER_AGE
-- end

function Age:GetPercent()
    return self:GetDisplayAgeInDays() / (TheWorld.state.cycles + 1)
end
