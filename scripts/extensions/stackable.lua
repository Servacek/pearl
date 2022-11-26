
local PEARL = PEARL

local Stackable = require("components/stackable")

-----------------------------------
-- [[ Extension Functions ]]
-----------------------------------

function Stackable:GetStackPercent()
    return self.stacksize / self.maxsize
end

PEARL.AddClassFunctionPreCall("Put", function(self, item)
    local owner = self.inst.components.inventoryitem.owner
    print("PUT", item, owner, self.inst)
    if owner and owner:HasTag("player") then
        owner:PushEvent("put_item_on_stack", {
            src_item = item,
            dst_item = self.inst,
        })
    end
end, Stackable)
