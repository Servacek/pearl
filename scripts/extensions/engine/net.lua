--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- So the main issue we are trying to solve here is changing the behaviour of
--- the Ban functions so they drop player's inventory upon being called.
--- We override the engine function itself to ensure all calls are handled this way.


--- @engine
--- @class TheNet
local __index = getmetatable(TheNet).__index
TheNet = TheNet --- @type TheNet

-- Provides access to the original functions
local __index_ORIGIN = shallowcopy(__index)

local ItemDepositor = PEARL.loadfile("libraries/itemdepositor")

--------------------------------
-- [[ Private ]]
--------------------------------

local function DoActualBan(userid, seconds, reason, author)
    if not PEARL.BlackList:Contains(userid) then
        PEARL.EventProcessor:HandleEvent("clientbanned", userid, seconds, reason, author)
    end

    PEARL.BlackList:AddGlobal(userid)

    if type(seconds) == "number" then
        return __index_ORIGIN.BanForTime(TheNet, userid, seconds)
    end

    return __index_ORIGIN.Ban(TheNet, userid)
end

--------------------------------
-- [[ Commmon Modules ]]
--------------------------------

function __index:BanForTime(userid, seconds, reason, author)
    PEARL.debug("TheNet:BanForTime", userid, seconds, reason, author)

    local player = PEARL.ServerNetwork:GetClientInstance(userid)
    if player and player.components.inventory then -- Attempt to return the items to the base.
        ItemDepositor:DepositAllItems(player.components.inventory)
    end

    if type(reason) == "string" and PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        return PEARL.ServerNetwork:CloseConnectionFor(
            userid, reason, false, STRINGS.UI.NETWORKDISCONNECT.TITLE["ID_DST_USER_BANNED"],
            function() DoActualBan(userid, seconds, reason, author) end
        )
    end

    return DoActualBan(userid, seconds, reason, author)
end

function __index:Ban(userid, reason, author) -- aka Proxy_TheNet:BanForTime(seconds = nil)
    PEARL.debug("TheNet:Ban", userid, reason, author)
    __index:BanForTime(userid, nil, reason, author)
end

function __index:Unban(userid)
    PEARL.debug("TheNet:Unban", userid)

    PEARL.BlackList:Remove(userid)
end

function __index:Kick(userid, seconds, reason, author)
    PEARL.debug("TheNet:Kick", userid, seconds, reason, author)
    PEARL.EventProcessor:HandleEvent("clientkicked", userid, reason, author, seconds)

    if type(reason) == "string" and PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        return PEARL.ServerNetwork:CloseConnectionFor(
            userid, reason, false, STRINGS.UI.NETWORKDISCONNECT.TITLE["ID_DST_USER_KICKED"],
            function() __index_ORIGIN.Kick(TheNet, userid, seconds) end
        )
    end

    return __index_ORIGIN.Kick(TheNet, userid, seconds)
end
