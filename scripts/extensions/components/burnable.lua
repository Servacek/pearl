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
-- [[ Local Functions ]]
---------------------------------

local onburnt
onburnt = function(inst)
    if inst.components.burnable and inst.components.burnable.doer then
        inst.components.burnable.doer:SetData(nil)
    end

    inst:RemoveEventCallback("onburnt", onburnt)
end

---------------------------------
-- [[ Public Methods Overrides ]]
---------------------------------

PEARL.AddClassFunctionPreCall("Ignite", function(self, immediate, source, doer)
    local ignitor = (source and source.userid and source) or (doer and doer.userid and doer) or nil
    if ignitor and ignitor.userid and ignitor.name then
        if not self.doer then
            self.doer = Doer()
        end

        print("ADDING IGNITOR")
        self.doer:Set(ignitor.userid, ignitor.name)

        self.inst:SafeListenForEvent("onburnt", onburnt)
    end
    print("BURNABLE IGNITE", source, doer)
end, Burnable)

PEARL.AddClassFunctionPreCall("Extinguish", function(self)
    if self.doer then
        print("REMOVING IGNITOR")
        self.doer:SetData(nil)
        self.inst:RemoveEventCallback("onburnt", onburnt)
    end
end, Burnable)

PEARL.OverrideMethodReturnValue(Burnable, "OnSave", function(data, self)
    if not self.doer then
        return
    end

    if type(data) ~= "table" then
        data = {}
    end

    print("BURNABLE SAVE")
    data.ignitor = self.doer:GetData()

    return data
end, true)

PEARL.AddClassFunctionPreCall("OnLoad", function(self, data)
    print("BURNABLE LOAD")
    self.doer = Doer(data.ignitor)
end, Burnable)
