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

---------------------------------
-- [[ Class Declaration ]]
---------------------------------

--- @class Deployable
local Deployable = require("components/deployable")

---------------------------------
-- [[ Public Methods Overrides ]]
---------------------------------

PEARL.AddClassFunctionPreCall("Deploy", function(self, pt, deployer)
    print("ON DEPLOY", self, deployer)
    if deployer and deployer.userid then
        if not self.doer then
            self.doer = Doer()
        end

        self.doer:Set(deployer.userid, deployer.name)
    end
end, Deployable)

PEARL.OverrideMethodReturnValue(Deployable, "OnSave", function(data, self)
    if not self.doer or not self.doer:GetData() then
        return
    end

    if type(data) ~= "table" then
        data = {}
    end

    print("DEPLOYABLE SAVE")
    data.deployer = self.doer:GetData()

    return data
end, true)

PEARL.AddClassFunctionPreCall("OnLoad", function(self, data)
    print("DEPLOYABLE LOAD")
    self.doer = Doer(data)
end, Deployable)
