--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



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
    return self:GetAgeInDays() >= PEARL.CONFIG.TRUST_AGE or self:GetPercent() >= PEARL.CONFIG.TRUST_AGE_PERCENT
end

-- function Age:IsNewcomer()
--     return self:GetAgeInDays() <= MAX_NEWCOMER_AGE
-- end

function Age:GetPercent()
    return self:GetDisplayAgeInDays() / (TheWorld.state.cycles + 1)
end
