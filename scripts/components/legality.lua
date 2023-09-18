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
-- [[ Contants ]]
--------------------------------

local LEGALITY_THRESHOLD = .8
local WEIGHT_FACTOR = 0.5

local PREDICTIONS = {
    FLAGGED = 1,
    NOT_FLAGGED = 0,
}

--------------------------------------------------------------------------
--[[ Class Declaration - Legality ]]
--------------------------------------------------------------------------

--- @class Legality
return Class(function(self, inventory)
    function self:Predict(weights)
        local pd = {
            weights = {},
            prediction = PREDICTIONS.NOT_FLAGGED, -- Either 1 if flagged or 0 if not.
            confidence = 0,
            items = 0,
            value = 0,
            normalized_value = 0,
        }
        if inventory:IsEmpty() then
            return pd
        end

        for _, item in ipairs(inventory:ReferenceAllItems()) do
            local stacksize = item.components.inventoryitem:GetStackSize()
            local stackweight = item.components.inventoryitem:GetTotalPredictedWeight(weights)
            local itemweight = stackweight / stacksize

            -- Store highest normalized weight for this item.
            pd.weights[item.prefab] = math.max((pd.weights[item.prefab] or 0), itemweight)
            pd.normalized_value = pd.normalized_value + itemweight
            pd.value = pd.value + stackweight
            pd.items = pd.items + stacksize
        end

        if pd.value >= LEGALITY_THRESHOLD then
            pd.prediction = PREDICTIONS.FLAGGED
        end

        local x = pd.prediction == PREDICTIONS.NOT_FLAGGED and 1 / pd.value or pd.value
        pd.confidence = math.sigmoid(x * WEIGHT_FACTOR)

        print("CONFIDENCE:", pd.confidence * 100)
        print("VALUE:", pd.value)

        return pd
    end

end)
