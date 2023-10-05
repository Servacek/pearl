--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



function CheckAdding()
    PEARL.PlayerDB:SetIsEnabled(true)
    local count = PEARL.PlayerDB:GetTotalRecordCount()
    local userid = PEARL.GenerateRandomKleiID()
    print("REGISTER USER", userid)
    local record, created = PEARL.PlayerDB:EnsureRecordFor(userid)

    print(record, created)
    assert(type(record) == "table")
    assert(PEARL.PlayerDB:GetTotalRecordCount() == count + 1)
    assert(PEARL.PlayerDB._records[userid] ~= nil)
    assert(PEARL.PlayerDB:IsRecordLoadedFor(userid))

    PEARL.PlayerDB:UnloadRecord(userid)
end
