
local PEARL = PEARL

local Inventory = require("components/inventory")

-----------------------------------
-- [[ Contants ]]
-----------------------------------

-- Suspicious Inventory Detector
local MAX_SUSPICION = 3

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

--- @TODO Tags:
--[[
    "gem"
    "rangedweapon"
    "rangelighter"
    "weapon"
--]]
function Inventory:CalcSuspicioness()
    local suspicioness = 0
    for _, item in ipairs(self:ReferenceAllItems()) do
        if suspicioness >= MAX_SUSPICION then
            break
        end

        local rarity = item.components.inventoryitem:GetTotalRarity()
        -- print("\tRARITY:", rarity)
        suspicioness = suspicioness + rarity
        -- print("\tTOTAL:", suspicioness)
        -- print("-----------------")
    end

    --PEARL.debug("SUSPICION:", suspicioness)
    return suspicioness / MAX_SUSPICION
end

-------------------------------
-- [[ Function Post Calls ]]
-------------------------------
-- PEARL.AddClassFunctionPreCall("GiveItem", function(self, item, slot)
--     if not (item and item.components and item.components.inventoryitem and item:IsValid()) then
--         return
--     end

--     -- new owner -> self.inst
--     -- prev owner -> item.components.inventoryitem.owner
--     -- prev container -> item.prevcontainer
--     -- new container -> self
--     PEARL.debug(string.format("GIVE ITEM[%s] (NEW OWNER: %s PREV OWNER: %s PREV CONTAINER: %s)",
--         tostring(item), tostring(self.inst), tostring(item.components.inventoryitem.owner), tostring(item.prevcontainer)
--     ))
-- end, Inventory)
