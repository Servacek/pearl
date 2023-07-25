--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd & BackEnd

--- @TODO: Add some "requires" flag for commands that require a specific webhook to run.

local TheNet = TheNet

local Message = PEARL.loadfile("libraries/discordapi/models/message")
local EMBEDS = PEARL.loadfile("utils/embeds")

-------------------------------------
-- Contants
-------------------------------------

local SLASH_COMMANDS = {}
local REQUIRED_FIELDS = {
    params = {},
}

local SLASH_COMMAND_DELIM = "/"
local KLEI_ID_DELIM = "K"

local DAYSBACK_DELAY = 3

-------------------------------------
-- Helpers
-------------------------------------

local function make_safe_cb(name, cb)
    return function(params, caller, ...)
        local result = {PEARL.SafeRun(cb, params, caller, ...)}
        if not result[1] then
            local traceback = result[2] or "No Traceback"
            PEARL.error("Failed to run command '/"..name.."'!\n", traceback)

            if PEARL.ServerNetwork and type(caller) == "table" and caller.userid then
                PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                    STRINGS.PEARL.UI.CMD_ERRORS.EXECUTION
                )
            end

            -- Send the traceback to the server as well.
            if PEARL.ClientNetwork then
                PEARL.ClientNetwork:SendErrorTracebackToServer(traceback)
            end

            return
        end

        -- Skip the first element which is the status code.
        return unpack(result, 2)
    end
end

local function AddCommand(name, data, ...)
    if PEARL.CONFIG.COMMAND_BLOCKLIST[name] == true then
        return
    end

    if data.serverfn then
        data.serverfn = make_safe_cb(name, data.serverfn)
    end

    if data.localfn then
        data.localfn = make_safe_cb(name, data.localfn)
    end

    if data.canstartfn then
        data.canstartfn = make_safe_cb(name, data.canstartfn)
    end

    for key, value in pairs(REQUIRED_FIELDS) do
        if data[key] == nil then
            data[key] = value
        end
    end

    AddUserCommand(name, data)

    if name and data.slash then
        table.insert(SLASH_COMMANDS, name)

        if data.aliases then
            for _, alias in ipairs(data.aliases) do
                table.insert(SLASH_COMMANDS, alias)
            end
        end
    end
end

------------------------------------
-- Slash commands [ADMIN]
------------------------------------

AddCommand("fire", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,

    serverfn = function(params, caller)
        PEARL.ExtinguishFiresNearAll()

        TheNet:Announce(STRINGS.PEARL.LOGS.EXTINGUISH_ALL:format(
            caller and caller:GetDisplayName() or "Shenanigans"
        ), caller and caller.entity)
    end,
})

AddCommand("repair", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.REPAIR.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.REPAIR.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,

    serverfn = function(params, caller)
        PEARL.RepairStructuresNearAll()

        TheNet:Announce(STRINGS.PEARL.LOGS.REPAIR_ALL:format(
            caller and caller:GetDisplayName() or "Shenanigans"
        ), caller and caller.entity)
    end,
})

AddCommand("unban", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"userid"}, -- Net/Klei ID
    params_optional= { false },

    -- This is executed on the local shard
    serverfn = function(params, caller)
        if not (params and caller and params.userid) then
            return
        end

        local userid = UserToClientID(params.userid) or params.userid
        if PEARL.UnbanUserByID(userid) then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid, string.format(
                STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_SUCCESS, userid
            ))
        end

        PEARL.ServerNetwork:SendCommandResponse(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_NOTFOUND)
    end,
})

AddCommand("allowlist-add", {
    aliases = {"allow"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"userid"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if not (params and caller and params.userid) then
            return
        end

        local userid = UserToClientID(params.userid) or params.userid
        if PEARL.BlackList:Contains(userid) then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_BANNED
            )
        end

        if PEARL.AllowList:Contains(userid) then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_ALREADY_WHITELISTED
            )
        end

        PEARL.AllowList:Add(userid)
        if PEARL.AllowList:Save() then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid, string.format(
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_SUCCESS,
                userid
            ))
        end

        PEARL.ServerNetwork:SendCommandResponse(caller.userid, string.format(
            STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_FAILURE,
            userid
        ))
    end,
})

AddCommand("allowlist-remove", {
    aliases = {"deny"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"userid"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if not (params and caller and params.userid) then
            return
        end

        local userid = UserToClientID(params.userid) or params.userid
        if not PEARL.AllowList:Contains(userid) then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_NOTFOUND
            )
        end

        PEARL.AllowList:Remove(userid)
        TheNet:Kick(userid)

        if PEARL.AllowList:Save() then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid, string.format(
                    STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_SUCCESS,
                    userid
                )
            )
        end

        return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
            STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_FAILURE
        )
    end,
})

AddCommand("inv", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"userid"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if not (params and caller) then
            return
        end

        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
            )
        end

        local userid = UserToClientID(params.userid) or params.userid
        if PEARL.DiscordReporter:ReportInventory(userid) then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_SUCCESS
            )
        end

        return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
            STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_NOTFOUND
        )
    end,
})

AddCommand("inv-find", {
    aliases = {"item-find", "invf"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"prefab"},
    params_optional = { false },

    serverfn = function(params, caller)
        if not (params and caller and params.prefab) then
            return
        end

        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
            )
        end

        local item_owners = {}
        for _, player in ipairs(AllPlayers) do
            local items = player.components.inventory:FindItems(function(item)
                return item.prefab == params.prefab
            end)

            if items and #items > 0 then
                item_owners[#item_owners + 1] = {
                    player = player,
                    item_count = #items,
                }
            end
        end

        if #item_owners <= 0 then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_FAILURE)
        end

        -- Sort by item count and player age
        table.sort(item_owners, function(v1, v2)
            return v1.item_count > v2.item_count
            and v1.player.components.age:GetAge() < v2.player.components.age:GetAge()
        end)

        -- Anounce first 5 inventories reversed
        -- so the first one is on the bottom of the chat.
        --- @type Message
        local message = Message(STRINGS.PEARL.LOGS.SEARCH_RESULTS_FOR:format(
            params.prefab, #item_owners
        ))
        for i = math.min(#item_owners, 5), 1, -1 do
            local player_reference = PEARL.GetPlayerMetadataFor(item_owners[i].player.userid)
            local embed = EMBEDS.Inventory(player_reference, {params.prefab})
            if not message:AddEmbed(embed) then
                break -- The message is full and doesn't accept any more embeds
            end
        end

        PEARL.DiscordReporter:SendRawReportMessage(message)
        return PEARL.ServerNetwork:SendCommandResponse(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_SUCCESS:format(
            #item_owners
        ))
    end,
})

--- @TODO: Check if this works properly
AddCommand("daysback", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DAYSBACK.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DAYSBACK.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    confirm = true,
    params = { "days" },
    params_optional= { false },

    serverfn = function(params, caller)
        if not (params and caller and params.days) then
            return
        end

        PEARL.RollbackByDays(tonumber(params.days), function(success, result)
            if success then
                return TheNet:Announce(result)
            end

            PEARL.ServerNetwork:SendCommandResponse(caller.userid, result)
        end, DAYSBACK_DELAY)
    end,
})

AddCommand("admins", {
    aliases = {"staff", "sos"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SOS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SOS.DESC,
    permission = COMMAND_PERMISSION.USER,
    confirm = true,
    slash = true,
    servermenu = true,
	menusort = 2,
    params = { "message" },
    paramsoptional = { true },

    canstartfn = function(command, caller)
        if GetTime() <= (caller.__soscall_cd_time or 0) then
            return false, "COOLDOWN"
        end

        return true
    end,

    -- Handle's the cooldown locally
    localfn = function(params, caller)
        local curr_time = GetTime()
        if curr_time <= (caller.__soscall_cd_time or 0) then
            return -- This should not happen
        end

        caller.__soscall_cd_time = curr_time + (PEARL.CONFIG.ADMIN_CALL_COOLDOWN or 0)

        -- Send all the input strings...
        -- The server will answer at this point.
        PEARL.ClientNetwork:SendPlayerReportToServer(tostring(params.message or "").." "..(tostring(params.rest or "")))
    end,

    -- For server handling we use RPCs so the command is not being sent to the server.
    -- We do not want to log the messages.
})

--- currently the cfd data are erased every time we restart the server.
AddCommand("mods", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = { "userid" },
    paramsoptional = { false },

    serverfn = function(params, caller)
        if type(params.userid) ~= "string" or type(caller) ~= "table" then
            return
        end

        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
            )
        end

        local mods = PEARL.PlayerDB:GetField(params.userid, "lastmods")
        if type(mods) == "table" then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.NO_MODS)
        end

        PEARL.DiscordReporter:ReportMods(params.userid, mods)
        return PEARL.ServerNetwork:SendCommandResponse(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.ON_SUCCESS)
    end,
})

if TheNet:GetIsServer() then
    return -- Nothing interesting for the server here
end

-------------------------------------------
-- Command Prediction
-------------------------------------------

AddClassPostConstruct("screens/chatinputscreen", function(self)
    -- Setup prediction for our custom slash commands
    for _, v in pairs(self.chat_edit.prediction_widget.word_predictor.dictionaries) do
        if v.delim == SLASH_COMMAND_DELIM then
            for _, cmd_name in ipairs(SLASH_COMMANDS) do
                table.insert(v.words, cmd_name)
            end
        end
    end

    local userids = {}
    for _, v in ipairs(AllPlayers) do
        if v and v.userid then
            -- Remove the delim from the userid
            table.insert(userids, v.userid:sub(#KLEI_ID_DELIM + 1))
        end
    end

    -- Auto-complete for user ids
    self.chat_edit:AddWordPredictionDictionary({
        delim = KLEI_ID_DELIM,
        words = userids,
    })
end)
