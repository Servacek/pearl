--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--------------------------------
-- [[ Localization ]]
--------------------------------

local AllRecipes = AllRecipes

--------------------------------
-- [[ Global Prefab Post Init ]]
--------------------------------

PEARL.AddPrefabPostInitAny(function(inst)
    if POPULATING then
        return
    end

    -- An recipe exists for this prefab so its buildable by a player.
    if inst and inst.prefab and AllRecipes[inst.prefab] ~= nil then
        PEARL.AddClassFunctionPreCall("onPreBuilt", function(self, builder, materials, recipe)
            if builder and builder.userid and builder.name then
                if not self.components.built then
                    self:AddComponent("built")
                end

                self.components.built:SetBuilder(builder.userid, builder.name)
                self.components.built:SetRecipe(recipe)
            end
        end, inst)
    end
end)
