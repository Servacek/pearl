--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--------------------------------------
-- [[ Constants ]]
--------------------------------------

local NAMESPACE = "__"..PEARL.MODNAME

--------------------------------------
-- [[ Private ]]
--------------------------------------

local new_params = {}
local old_params = Settings

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class GameInstParams
local GameInstParams = {}

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

function GameInstParams:SetModParam(name, value)
    new_params[name] = value
end

function GameInstParams:GetModParam(name)
    return old_params[NAMESPACE] and old_params[NAMESPACE][name]
end

function GameInstParams:GetParam(name)
    return old_params[name]
end

--------------------------------------
-- [[ Handlers ]]
--------------------------------------

local _SimReset = SimReset
PEARL.OverrideVariable("SimReset", function(params, ...)
    params = params or {}
    if not IsTableEmpty(new_params) and not params[NAMESPACE] then
        params[NAMESPACE] = new_params
    end

    ---@diagnostic disable-next-line: redundant-parameter
    _SimReset(params, ...)
end, _G)

--------------------------------------
-- [[ Return ]]
--------------------------------------

return GameInstParams
