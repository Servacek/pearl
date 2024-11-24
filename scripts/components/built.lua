--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Doer = PEARL.loadfile("models/doer")

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class Built
local Built = PEARL.Class(function(self)
    --- @type Doer?
    self.doer = nil

    --- @type table?
    self.ingredients = nil
end)

--------------------------------
-- [[ Setters ]]
--------------------------------

function Built:SetBuilder(builder)
    self.doer = builder
end

function Built:SetBuilderData(userid, name)
    --PEARL.debug("Built:SetBuilderData", userid, name)

    if not self.doer then
        self.doer = Doer()
    end

    self.doer:Set(userid, name)
end

function Built:SetIngredients(ingredients)
    self.ingredients = ingredients
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- Ingredients used for building this thing.
function Built:GetIngredients()
    return self.ingredients
end

function Built:By(userid)
    return userid and self.doer and self.doer.userid == userid
end

--------------------------------
-- [[ Save/Load ]]
--------------------------------

function Built:OnSave()
    --PEARL.debug("Built:OnSave", self.doer)

    return {
        doer = self.doer:GetData(),
        ingredients = self.ingredients,

        -- Custom flag to ensure this component
        add_component_if_missing = true,
    }
end

function Built:OnLoad(data)
    --PEARL.debug("Built:OnLoad", self.doer)

    self.doer = data.doer and Doer(data.doer) or nil
    self.ingredients = data.ingredients
end

--------------------------------
-- [[ Return ]]
--------------------------------

return Built
