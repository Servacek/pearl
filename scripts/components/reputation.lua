
local SUB = PEARL
local Class = Class

-- TODO:
local Reputation = Class(function(self, inst)
    self.inst = inst
    self.current = 0
    self.max = SUB.CONSTS.REPUTATION_MAX -- TODO: some const here

    --self.inst:ListenForEvent("buildstructure", onbuildstructure)
end)

return Reputation
