--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local USERID = "KU_12345678"

local function EnsureRecord()
    if not PEARL.DB:HasRecordFile(USERID) then
        PEARL.AddDebugRecord(USERID, "bob", 140, "12345678901")
    end
end

function Changes()
    EnsureRecord()

    PEARL.DB:UnloadRecord(USERID)
    local record = PEARL.DB:GetRecordFor(USERID)
    assert(record, "Failed to create the record!")
    print(record)
    assert(record:IsUpToDate() == true)
    assert(record:IsReadOnly() == false)

    local olddays = record.totaldays

    local timenow = os.time()
    record.totaldays = record.totaldays
    assert(record:IsUpToDate() == true)
    print("\n\nFIRST SAVING")
    PEARL.EventProcessor:HandleEvent("save")
    print(record)
    PEARL.DB:LoadRecordFor(USERID, false, record) -- It is unloaded after saving...
    print(record)

    local newtotaldays = record.totaldays + 10
    print("EDITING THE FIELD")
    record.totaldays = newtotaldays
    print("EDIT COMPLETE")
    assert(record.totaldays == newtotaldays)
    assert(record:IsUpToDate() == false)
    -- print("\n\nSECOND SAVING")
    PEARL.DB:PrintDebugInfo()
    print(PEARL.DB._records[USERID] == record)
    PEARL.EventProcessor:HandleEvent("save")
    PEARL.DB:PrintDebugInfo()
    print(record.lastupdate, timenow)
    assert(tonumber(record.lastupdate) == tonumber(timenow))
    assert(record:IsUpToDate() == true)

    print("\n\nRELOADING")
    PEARL.DB:UnloadRecord(USERID)
    record = PEARL.DB:GetRecordFor(USERID)
    assert(record, "Failed to reload the record!")
    assert(record.totaldays == newtotaldays)
    record.totaldays = olddays
end

function Defaults()
    EnsureRecord()

    PEARL.DB:UnloadRecord(USERID)
    local record = PEARL.DB:GetRecordFor(USERID)
    assert(record, "Failed to create the record!")
    print(record)
    assert(record:IsUpToDate() == true)
    assert(record:IsReadOnly() == false)

    local oldrep = PEARL.DB:GetField(USERID, "reputation.value")
    PEARL.DB:SetField(USERID, "reputation.value", nil)
    print("")
    assert(PEARL.DB:GetField(USERID, "reputation.value") == PEARL.Reputation.FIELD_DEFAULT[
        PEARL.Reputation.FIELD.VALUE
    ])

    PEARL.DB:SetField(USERID, "reputation.value", oldrep)
end
