--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



function CheckAdding()
    PEARL.DB:SetIsEnabled(true)
    local count = PEARL.DB:GetTotalRecordCount()
    local userid = PEARL.GenerateRandomKleiID()
    print("REGISTER USER", userid)
    local record, created = PEARL.DB:CreateRecordFile(userid)

    print(record, created)
    assert(type(record) == "table")
    assert(PEARL.DB:GetTotalRecordCount() == count + 1)
    assert(PEARL.DB._records[userid] ~= nil)
    assert(PEARL.DB:IsRecordLoadedFor(userid))

    PEARL.DB:UnloadRecord(userid)
end
