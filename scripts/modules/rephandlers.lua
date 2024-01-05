--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

if TheShard:IsSecondary() then
    PEARL.EventProcessor:AddSafeEventHandler("onreputationchanged", function(userid, old, new)
        PEARL.SendRPCToMaster(PEARL.RPC.ReputationChanged, userid, new)
    end)
end

local function ResetFieldFor(userid, field)
    PEARL.Reputation:SetFieldFor(
        userid, field, PEARL.Reputation.DEFAULT_REP_DATA.monthgains
    )
end

local function ResetFieldForActivePlayers(field)
    -- For active players within the shard (writable records)
    for userid, _ in ipairs(PEARL.ServerNetwork:GetLocalClientIDs()) do
        ResetFieldFor(userid, field)
    end
end

PEARL.EventProcessor:AddSafeEventHandler("newmonth", function()
    ResetFieldForActivePlayers("monthgains")
end)

-- In case the players are playing on the server when this event occurs.
PEARL.EventProcessor:AddSafeEventHandler("newday", function()
    ResetFieldForActivePlayers("daygains")
end)

--- @param record PlayerRecord
PEARL.EventProcessor:AddSafeEventHandler("db_recordloaded", function(userid, record)
    if record and userid and record:IsWriteable() then
        local lastseentime = PEARL.DB:GetField(userid, "lastseentime")
        if lastseentime then
            local lastseentimetbl = PEARL.TimestampToTable(lastseentime)
            local currenttimetbl = PEARL.TimestampToTable(os.time())
            local yearmismatch = lastseentimetbl.year ~= currenttimetbl.year
            local monthmismatch = lastseentimetbl.month ~= currenttimetbl.month
            if lastseentimetbl.day ~= currenttimetbl.day or monthmismatch or yearmismatch then
                ResetFieldFor(userid, "daygains")

                if monthmismatch or yearmismatch then
                    ResetFieldFor(userid, "monthgains")
                end
            end
        end

        if TheWorld and TheWorld.state then
            local lastcycle = PEARL.DB:GetField(userid, "lastcycle")
            local lastsessionid = PEARL.DB:GetField(userid, "lastsessionid")
            local cycle = TheWorld.state.cycles
            local sessionid = TheNet:GetSessionIdentifier()
            if cycle ~= lastcycle or lastsessionid ~= sessionid then
                ResetFieldFor(userid, "cyclegains")
            end
        end
    end
end)

PEARL.AddWorldPostInit(function(world)
    world:SafeListenForEvent("cycleschanged", function()
        ResetFieldForActivePlayers("cyclegains")
    end)
end)
