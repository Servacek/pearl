--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local EMBEDS = PEARL.loadfile("utils/embeds")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local LEADERBOARD_FILE_PATH = "leaderboard"

local LEADERBOARD_TYPES = {
    CURRENT     = "current",
    ABSOLUTE    = "absolute",
}

local LEADERBOARD_MAX_LEN = 5

--------------------------------------
-- [[ Local Variables ]]
--------------------------------------

local leaderboard

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function CalculateAbsPosForUser(userid, rep)

end

local function CalculateMonthlyPosForUser()

end

local function CreateRecordFor(userid, rep)
    return {userid = userid, rep = rep}
end

local function GetPosFor(userid, ld_type)
    for i, record in ipairs(leaderboard[ld_type]) do
        if record.userid == userid then
            return i
        end
    end
end

local function GetAbsPosFor(userid)
    return GetPosFor(userid, LEADERBOARD_TYPES.ABSOLUTE)
end

local function GetCurPosFor(userid)
    return GetPosFor(userid, LEADERBOARD_TYPES.CURRENT)
end

local function GetRecordAt(pos, ld_type)
    return pos and leaderboard[ld_type][pos]
end

local function GetAbsRecordFor(userid)
    return GetRecordAt(GetAbsPosFor(userid), LEADERBOARD_TYPES.ABSOLUTE) or nil
end

local function GetCurRecordFor(userid)
    return GetRecordAt(GetCurPosFor(userid), LEADERBOARD_TYPES.CURRENT) or nil
end

local function GetRecordFor(userid, ld_type)
    return GetRecordAt(GetPosFor(userid, ld_type), ld_type) or nil
end

local function OnUpdate()
    local self = PEARL.DiscordLeaderBoarder

    local embed_abs = EMBEDS.Leaderboard(leaderboard[LEADERBOARD_TYPES.ABSOLUTE], false)
    local embed_cur = EMBEDS.Leaderboard(leaderboard[LEADERBOARD_TYPES.CURRENT], true)

    self:SetEmbed(self.EMBED_TYPES.ABS, embed_abs)
    self:SetEmbed(self.EMBED_TYPES.CUR, embed_cur)

    self:DoUpdate()
end

local function UpdateReputationFor(userid, rep)
    -- Update the new reputation in all of our leaderboards
    for _, ld_type in pairs(LEADERBOARD_TYPES) do
        local record = GetRecordFor(userid, ld_type)
        if type(record) == "table" then
            record.rep = rep
        end
    end
end

-- Returns true when the positions were changed in the leaderboard.
local function HandleReputationIncreasedFor(userid, rep, ld_type)
    -- The lowest index is 6 in this case
    local this_pos = GetPosFor(userid, ld_type) or LEADERBOARD_MAX_LEN - 1
    if this_pos == 1 then
        return -- We already on the top!
    end

    local ld = leaderboard[ld_type]

    local up_pos
    local up_record
    local pos_changed = false
    repeat
        up_pos = this_pos - 1 -- We are going upwards!
        up_record = ld[up_pos]
        if up_record == "table" and up_record.rep > rep or (up_pos == LEADERBOARD_MAX_LEN and up_record.rep == rep) then
            -- We can safely break here since it's sorted by the rep
            break
        end

        local this_record = GetRecordAt(this_pos, ld_type) or CreateRecordFor(userid, rep)

        if type(up_record) ~= "table" then
            -- There seems to be a free place above our position? Let's take it!
            ld[up_pos] = this_record
            pos_changed = true
        elseif up_record.rep < rep then
            ld[up_pos] = this_record
            ld[this_pos] = up_record
            pos_changed = true
        end
    until up_pos ~= 1 -- Until we are not on the top!

    return pos_changed
end

local function OnReputationIncreased(userid, rep)
    local update = false
    for _, ld_type in pairs(LEADERBOARD_TYPES) do
        local init_pos = GetPosFor(userid, ld_type)

        --- @TODO:
        local last_index = math.min(#leaderboard[ld_type] + 1, LEADERBOARD_MAX_LEN)
        if not leaderboard[ld_type][last_index] or leaderboard[ld_type][last_index] < rep then
            print("ADDING RECORD")
            leaderboard[ld_type][last_index] = userid
        end

        table.sort(leaderboard[ld_type], function(uid1, uid2)
            return PEARL.PlayerDB:GetField(uid1, "rep") > PEARL.PlayerDB:GetField(uid2, "rep")
        end)

        local curr_pos = GetPosFor(userid, ld_type)

        print(curr_pos, init_pos)
        if curr_pos ~= init_pos then
            update = true
        end

        -- if HandleReputationIncreasedFor(userid, rep, ld_type) then
        --     update = true
        -- end
    end


    if update then
        OnUpdate()
    end
end

local function OnReputationDecreased(userid, rep)

end

local function OnReputationDelta(userid, delta)
    print("OnReputationDelta")
    -- Admins should not appear in the leadeboard
    if delta == 0 or (PEARL.ServerNetwork:IsAdmin(userid) and not PEARL.CONFIG.DEBUG_MODE) then
        return
    end

    --- @DEBUG !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!§
    local new_rep = PEARL.PlayerDB:GetField(userid, "rep") + delta
    PEARL.PlayerDB:OptionalSafeSetField(userid, "rep", new_rep)

    if delta > 0 then
        OnReputationIncreased(userid, new_rep)
    else
        OnReputationDecreased(userid, new_rep)
    end

    -- Reputation was changed update the leaderboard.
end

local function OnLoad()
    PEARL.info("Loading the leaderboard...")

    if type(leaderboard) == "table" then
        return PEARL.error("Leadeboard already loaded!")
    end

    io.ensure(LEADERBOARD_FILE_PATH, "[]")

    local rf, err = io.open(LEADERBOARD_FILE_PATH, "r")
    if not rf or err then
        PEARL.error(err)
        return
    end

    local str = rf:read("*a")
    rf:close()

    -- Decoding and un-encoded string should return nil
    local decoded = TheSim:DecodeAndUnzipString(str)
    str = decoded and #decoded > 0 and decoded or str

    local success, data = pcall(json.decode, str)
    data = data or {}

    if not success or type(data) ~= "table" then
        PEARL.error("Failed to decode leaderboard JSON data!", data)
        return
    end

    leaderboard = data
    PEARL.leaderboard = data
    if type(leaderboard) ~= "table" then
        leaderboard = {}
    end

    for _, ld_type in pairs(LEADERBOARD_TYPES) do
        if type(leaderboard[ld_type]) ~= "table" then
            leaderboard[ld_type] = {}
        end
    end

    return data
end

local function OnSave()
    PEARL.debug("Saving the leaderboard...")

    if type(leaderboard) ~= "table" then
        return
    end

    local str = json.encode(leaderboard)
    if PEARL.CONFIG.LEADERBOARD.ENCODE_DATA then
        -- Only encode and zip the data in production
        str = TheSim:ZipAndEncodeString(str)
    end

    if type(str) ~= "string" then
        return false
    end

    local wf, err = io.open(LEADERBOARD_FILE_PATH, "w")
    if not wf or err then
        return false, err
    end

    wf:write(str)
    wf:close()
end

PEARL.AddGamePostInit(function()
    local self = PEARL.DiscordLeaderBoarder
    --- Check the month numbers and years here...

    OnLoad()

    if type(PEARL.CONFIG.DISCORD.BHOOK.MESSAGE_ID) ~= "string" or #PEARL.CONFIG.DISCORD.BHOOK.MESSAGE_ID <= 1 then
        PEARL.WallScheduler:ExecuteInTime(1, self.PostUpdatingMessage, nil, self)

        return
    end

    OnUpdate()
end)

PEARL.EventProcessor:AddEventHandler("onreputationdelta", OnReputationDelta)

PEARL.EventProcessor:AddEventHandler("quit", OnSave)
PEARL.EventProcessor:AddEventHandler("save", OnSave)
