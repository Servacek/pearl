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

    --- @type table
    self.recipe = nil
end)

function Built:SetBuilder(userid, name)
    if not self.doer then
        self.doer = Doer()
    end

    self.doer:Set(userid, name)
end

function Built:SetRecipe(recipe)
    self.recipe = recipe
end

function Built:OnSave()
    PEARL.debug("Built:OnSave", self.doer)

    return {
        doer = self.doer:GetData(),
        materials = self.recipe,
    }
end

function Built:OnLoad(data)
    PEARL.debug("Built:OnLoad", self.doer)

    self.doer = data.doer and Doer(data.doer) or nil
    self.recipe = data.recipe
end

--------------------------------
-- [[ Return ]]
--------------------------------

return Built
