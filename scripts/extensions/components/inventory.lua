--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODO: This calculating needs some improvements.

local PEARL = PEARL

local Inventory = require("components/inventory")


local LEGALITY_THRESHOLD = .8
local MAX_WEIGHT = 1
local MAX_CONFIDENCE = 1
local WEIGHT_FACTOR = 0.5

local PREDICTIONS = {
    FLAGGED = 1,
    NOT_FLAGGED = 0,
}

-----------------------------------
-- [[ Extension Functions ]]
-----------------------------------

function Inventory:GetSorted()
    local length = 0
    local result = {}
    self:ForEachItem(function(item)
        if not result[item.prefab] then
            length = length + 1
        end

        result[item.prefab] = (result[item.prefab] or 0) + PEARL.GetStackSize(item)
    end)

    return result, length
end

function Inventory:GetItemCount(prefab)
    local count = 0

    for _, item in pairs(self.itemslots) do
        if item.prefab == prefab then
            count = count + PEARL.GetStackSize(item)
        end
    end

    for _, item in pairs(self.equipslots) do
        if item.prefab == prefab then
            count = count + PEARL.GetStackSize(item)
        end
    end

    if self.activeitem and self.activeitem.prefab == prefab then
        count = count + PEARL.GetStackSize(self.activeitem)
    end

    local overflow = self:GetOverflowContainer()
    if overflow ~= nil then
        for _, item in pairs(overflow:FindItems(function(item)
            return item.prefab == prefab
        end)) do
            count = count + PEARL.GetStackSize(item)
        end
    end

    return count
end

function Inventory:DropRareItems(rarity, randomdir, pos)
    -- By default drop only very rare items.
    rarity = rarity or 1

    self:ForEachItem(function(item)
        local item_rarity = PEARL.PREFABS.RARE_ITEMS[item.prefab]
        if item_rarity and item_rarity > rarity then
            self:DropItem(item, true, randomdir, pos)
        end
    end)
end

function Inventory:DoLegalityPrediction(weights)
    local pd = {
        weights = {},
        prediction = PREDICTIONS.NOT_FLAGGED, -- Either 1 if flagged or 0 if not.
        confidence = 0,
        items = 0,
        value = 0,
        normalized_value = 0,
    }
    for _, item in ipairs(self:ReferenceAllItems()) do
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
