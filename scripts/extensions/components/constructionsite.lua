--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @class ConstructionSite
local ConstructionSite = require("components/constructionsite")

-------------------

PEARL.AddClassFunctionPostCall("OnConstruct", function(self, doer, items)
    if self:IsComplete() then
        PEARL.EventProcessor:HandleEvent(
            "constructionfinished", doer, self.inst
        )
    end
end, ConstructionSite)
