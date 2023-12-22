--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
    Wrapper for the ingame adminlist for automatized actions.
--]]

local ClusterUserList = PEARL.loadlib("clusteruserlist")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local ADMINLIST_PATH = "../../adminlist.txt"

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @singleton
--- @class AdminList: ClusterUserList
local AdminList = ClusterUserList(ADMINLIST_PATH)

--------------------------------------
-- [[ Return ]]
--------------------------------------

return AdminList
