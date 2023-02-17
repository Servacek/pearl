--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local UpvalueHacker = require("utils/upvaluehacker")

PEARL.AddBrainPostInit("pigbrain", function(self)
    -- print("ON PIG BRAIN POST INIT!")
    -- local FindFoodAction = UpvalueHacker.GetUpvalue(self.OnStart, "FindFoodAction")
    -- PEARL.AddFunctionPreCall(FindFoodAction, function()
    --     print("FINDING FOOD!!!")
    -- end)
end)
