--[[
   Additional utility functions for the age component
--]]

local Age = require("components/age")

local MIN_TRUSTWORTHY_AGE   = 24
local MAX_NEWCOMER_AGE      = 5

function Age:IsTrustworthy()
    return self:GetAgeInDays() >= MIN_TRUSTWORTHY_AGE
end

function Age:IsNewcomer()
    return self:GetAgeInDays() <= MAX_NEWCOMER_AGE
end

function Age:GetPercent()
    return self:GetDisplayAgeInDays() / (TheWorld.state.cycles + 1)
end
