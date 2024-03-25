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

local function ResetFieldForActivePlayers(field)
    -- For active players within the shard (writable records)
    for userid, _ in pairs(PEARL.ServerNetwork:GetLocalClientIDs()) do
        PEARL.Reputation:ResetFieldFor(userid, field)
    end
end

PEARL.EventProcessor:AddSafeEventHandler("newmonth", function()
    -- Give some time to the other handlers so they can use the value if needed.
    PEARL.WallScheduler:ExecuteInTime(0, function()
        ResetFieldForActivePlayers(PEARL.Reputation.FIELD.MONTHGAINS)

        PEARL.DB:SaveUnsavedRecords()
    end)
end)

-- In case the players are playing on the server when this event occurs.
PEARL.EventProcessor:AddSafeEventHandler("newday", function()
    ResetFieldForActivePlayers(PEARL.Reputation.FIELD.DAYGAINS)
end)

PEARL.EventProcessor:AddSafeEventHandler("clientbanned", function(userid)
    -- Reset the reputation fields in case of an unban.
    PEARL.Reputation:ResetFor(userid)
end)

--- @param record PlayerRecord
PEARL.EventProcessor:AddSafeEventHandler("db_recordloaded", function(userid, record)
    if record and userid and record:IsWriteable() then
        local lastupdate = PEARL.DB:GetField(userid, "lastupdate", PEARL.DB:GetRecordLastUpdateTimeFor(userid))
        if lastupdate then
            local lastseentimetbl = PEARL.TimestampToTable(lastupdate)
            local currenttimetbl = PEARL.TimestampToTable(os.time())
            local yearmismatch = lastseentimetbl.year ~= currenttimetbl.year
            local monthmismatch = lastseentimetbl.month ~= currenttimetbl.month
            if lastseentimetbl.day ~= currenttimetbl.day or monthmismatch or yearmismatch then
                PEARL.Reputation:ResetFieldFor(userid, PEARL.Reputation.FIELD.DAYGAINS)

                if monthmismatch or yearmismatch then
                    PEARL.Reputation:ResetFieldFor(userid, PEARL.Reputation.FIELD.MONTHGAINS)
                end
            end
        end

        if TheWorld and TheWorld.state then
            local lastcycle = PEARL.DB:GetField(userid, "lastcycle")
            local lastsessionid = PEARL.DB:GetField(userid, "lastsessionid")
            local cycle = TheWorld.state.cycles
            local sessionid = TheNet:GetSessionIdentifier()
            if cycle ~= lastcycle or lastsessionid ~= sessionid then
                PEARL.Reputation:ResetFieldFor(userid, PEARL.Reputation.FIELD.CYCLEGAINS)
            end
        end
    end
end)

PEARL.AddWorldPostInit(function(world)
    world:SafeListenForEvent("cycleschanged", function()
        ResetFieldForActivePlayers(PEARL.Reputation.FIELD.CYCLEGAINS)
    end)
end)
