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

--- @class Burnable
local Burnable = require("components/burnable")

---------------------------------
-- [[ Public Methods Overrides ]]
---------------------------------

PEARL.AddClassFunctionPreCall("Ignite", function(self, immediate, source, doer)
    local ignitor = (source and source.userid and source) or (doer and doer.userid and doer) or nil
    if ignitor and ignitor.userid and ignitor.name then
        if not self.doer then
            self.doer = Doer()
        end

        self.doer:Set(ignitor.userid, ignitor.name)
    end
end, Burnable)

PEARL.OverrideMethodReturnValue(Burnable, "OnSave", function(data, self)
    if not self.doer then
        return
    end

    if type(data) ~= "table" then
        data = {}
    end

    data.ignitor = self.doer:GetData()

    return data
end, true)

PEARL.AddClassFunctionPreCall("OnLoad", function(self, data)
    self.doer = Doer(data.ignitor)
end, Burnable)
