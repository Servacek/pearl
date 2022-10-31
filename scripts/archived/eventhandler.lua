local http = require('tools/http')
local formatter = require('tools/formatter')

local G = GLOBAL


----- LOCAL FUNCTIONS -----

local function GetClient(userid)
    for _, client in ipairs(G.GetPlayerClientTable()) do
        if client.userid == userid then
            return client
        end
    end

    return {}
end

------------------------- CHAT EVENTS -----------------------

local _Networking_Announcement = G.Networking_Announcement
G.Networking_Announcement = function(message, colour, announce_type)
    if G.TheShard:IsMaster() then
        http.send(formatter.FormatAnnouncement(message, announce_type))
    end

    return _Networking_Announcement(message, colour, announce_type)
end

local _Networking_SkinAnnouncement = G.Networking_SkinAnnouncement
G.Networking_SkinAnnouncement = function(user_name, user_colour, skin_name)
    if G.TheShard:IsMaster() then
        http.send(formatter.FormatSkinAnnouncement(user_name, skin_name))
    end

    return _Networking_SkinAnnouncement(user_name, user_colour, skin_name)
end

local _Networking_Say = G.Networking_Say
G.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity)
    -- The whisper check is due to cave whispers
    if whisper then
        http.send(formatter.FormatWhisper(message, name, userid, prefab))
    elseif G.TheShard:IsMaster() then
        http.send(formatter.FormatMessage(message, name, userid, prefab))
    end

    return _Networking_Say(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity)
end

local OLD_AUTH_COMPLETE = G.ClientAuthenticationComplete
G.ClientAuthenticationComplete = function(userid)
    local client = GetClient(userid)
    http.send(formatter.FormatAuthentication(client.name, client.userid))

    return OLD_AUTH_COMPLETE(userid)
end

------------------------- WORLD EVENTS -----------------------

AddSimPostInit(function()
    -- cycleschanged and phasechanged events are pushed multiple times on start
    -- these vars are here to prevent logging these events multiple times
    local last_cycle = nil
    local last_phase = nil

    G.TheWorld:ListenForEvent("cycleschanged", function(_, cycle)
        if G.TheShard:IsMaster() and last_cycle ~= cycle then
            http.send(formatter.FormatCyclesChanged(cycle))

            last_cycle = cycle
        end
    end)

    G.TheWorld:ListenForEvent("phasechanged", function(_, phase)
        if phase == nil or phase == "day" or not G.TheShard:IsMaster() or last_phase == phase then
            return
        end

        http.send(formatter.FormatPhaseChanged(phase))

        last_phase = phase
    end)
end)

-------------------------------- Server State --------------------------------

local _SaveAndShutdown = G.SaveAndShutdown
G.SaveAndShutdown = function()
    http.send("**Shutting down!**")

    return _SaveAndShutdown()
end

local _WorldResetFromSim = G.WorldResetFromSim
G.WorldResetFromSim = function()
    http.send("**Regenerating world...**")

    return _WorldResetFromSim()
end

local _WorldRollbackFromSim = G.WorldRollbackFromSim
G.WorldRollbackFromSim = function(count)
    if count ~= nil and count > 0 then
        http.send("`Rolling server "..count.." snapshot(s) back...`")
    else
        http.send("**Restarting...**")
    end

    return _WorldRollbackFromSim(count)
end

local _ExecuteConsoleCommand = G.ExecuteConsoleCommand
G.ExecuteConsoleCommand = function(fnstr, guid, x, z)
    local doer = G.Ents[guid]
    if doer ~= nil then
        http.send(formatter.FormatConsoleCommand(fnstr, doer))
    end

    return _ExecuteConsoleCommand(fnstr, guid, x, z)
end
