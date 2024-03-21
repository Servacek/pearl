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
-- [[ Global Prefab Post Init ]]
--------------------------------

local function GetAllIngredientsForRecipe(recipe)
    local ingredients = {}
    for k, v in pairs(recipe) do
        if tostring(k):endswith("ingredients") and table.isarray(v) then
            for _, ingredient in ipairs(v) do
                if type(ingredient) ~= "table" then
                    break
                end

                table.insert(ingredients, shallowcopy(ingredient))
            end
        end
    end

    return ingredients
end

local function OnBuilt(builder, data)
    local inst = data.item
    if not inst then
        return
    end

    if not inst.components.built then
        inst:AddComponent("built")
    end

    inst.components.built:SetBuilderData(builder.userid, builder.name)
    if data.recipe then
        inst.components.built:SetIngredients(GetAllIngredientsForRecipe(data.recipe))
    end
end

PEARL.AddPrefabPostInitAny(function(inst)
    if inst and inst.userid then
        inst:SafeListenForEvent("builditem", OnBuilt)
        inst:SafeListenForEvent("buildstructure", OnBuilt)
    end
end)
