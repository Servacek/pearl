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

-- So we can use the console commands immediately in command declarations.
require("consolecommands")

local UserCommands = require("usercommands")

local Message = PEARL.loadfile("libraries/discordapi/models/message")

local MESSAGES = PEARL.loadfile("utils/messages")
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
local ROLLBACK_DELAY = 3

local GIVEREP_AMOUNT = 25

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

-- When executed from STDIN, these are always in a protected call.
local function AddConsoleCommand(name, fn)
    PEARL.OverrideValue(_G, "c_"..name:gsub("-", "_"), fn)
end

local function ParseParamsArray(command, params_array)
    local params = {}
    for i, paramname in ipairs(command.params) do
        if params_array and params_array[i] ~= nil then
            params[paramname] = params_array[i]
        else
            if command.paramsoptional ~= nil and command.paramsoptional[i] == true then
                break
            end

            PEARL.error("Didn't supply enough arguments to command!")
            return
        end
    end

    return params
end

local function EnsureRequiredCommands(command)
    for key, value in pairs(REQUIRED_FIELDS) do
        if command[key] == nil then
            command[key] = value
        end
    end
end

local function AddCommand(name, command, ...)
    if PEARL.CONFIG.COMMAND_BLOCKLIST[name] == true then
        return -- Even custom commands can be blocklisted if needed.
    end

    if command.slash ~= true and not TheNet:GetIsServer() then
        return -- Ignore backend-only commands
    end

    local origin = UserCommands.GetCommandFromName(name)
    if origin ~= nil then
        PEARL.warn("Overriding command", name)
    end

    EnsureRequiredCommands(command)

    PEARL.info("Registering command", name)

    command.slash = command.slash ~= false and PEARL.CONFIG.SLASH_COMMANDS

    -- By default we will register console accessible function for each admin command.
    if command.console ~= false and command.permission == COMMAND_PERMISSION.ADMIN then
        local consolefn = command.consolefn or command.mainfn or command.serverfn
        if type(consolefn) ~= "function" then
            return error("Invalid admin console command callback! Command: "..name)
        end

        AddConsoleCommand(command.consolename or name, function(...)
            consolefn(ParseParamsArray(command, toarrayornil(...)))
        end)

        if command.consolename then
            if not command.aliases then
                command.aliases = {}
            end

            -- Register the console name as an alias for better consistency.
            if not table.contains(command.aliases, command.consolename) then
                command.aliases[#command.aliases+1] = command.consolename
            end
        end
    end

    local _serverfn = command.serverfn
    command.serverfn = make_safe_cb(name, function(params, caller, ...)
        local response = command.mainfn and command.mainfn(params, caller, ...)

        if type(_serverfn) == "function" then
            return _serverfn(params, caller, response)
        end
    end)

    if command.localfn then
        command.localfn = make_safe_cb(name, command.localfn)
    end

    if command.canstartfn then
        command.canstartfn = make_safe_cb(name, command.canstartfn)
    end

    AddUserCommand(name, command)

    if name and command.slash then
        table.insert(SLASH_COMMANDS, name)

        if command.aliases then
            for _, alias in ipairs(command.aliases) do
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

    mainfn = function(params, caller)
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

    mainfn = function(params, caller)
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
    params = {"userid"},
    params_optional= { false },

    discordfn = function(params, caller, response)
        return Message(response)
    end,

    mainfn = function(params, caller)
        local success = PEARL.UnbanUserByID(UserToClientID(params.userid) or params.userid)
        return STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN[success and "ON_SUCCESS" or "ON_NOTFOUND"]
    end,

    serverfn = function(params, caller, response)
        PEARL.ServerNetwork:SendCommandResponse(caller.userid, response)
    end,
})

AddCommand("allow", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    cantargetself = false,
    cantargetadmin = false,
    params = {"userid"},
    params_optional= { false },

    discordfn = function(params, caller, response)
        return Message(response)
    end,

    mainfn = function(params, caller)
        local userid = UserToClientID(params.user) or params.user
        if PEARL.BlackList:Contains(userid) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_BANNED
        end

        if PEARL.AllowList:Contains(userid) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_ALREADY_WHITELISTED
        end

        PEARL.AllowList:Add(userid)
        if PEARL.AllowList:Save() then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_SUCCESS:format(userid)
        end

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_FAILURE:format(userid)
    end,

    serverfn = function(params, caller, response)
        return PEARL.ServerNetwork:SendCommandResponse(caller.userid, response)
    end,
})

AddCommand("allowlist-remove", {
    aliases = {"deny"},
    consolename = "deny",
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"userid"}, -- Net/Klei ID
    params_optional= { false },
    console = false,

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

    discordfn = function(params, caller, userid)
        return MESSAGES.InvReport(userid)
    end,

    mainfn = function(params, caller)
        return UserToClientID(params.userid) or params.userid
    end,

    -- Called via slash commands, requires report webhook
    serverfn = function(params, caller, userid)
        local response

        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            response = STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
        elseif PEARL.DiscordReporter:ReportInventory(userid) then
            response = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_SUCCESS
        else
            response = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_NOTFOUND
        end

        return PEARL.ServerNetwork:SendCommandResponse(caller.userid, response)
    end,
})

AddCommand("inv-find", {
    aliases = {"item-find", "invf"},
    consolename = "invf",
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = false,
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
    console = false,
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
    console = false,
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
    params = { "userid" }, -- Do not use "user" for offline support
    paramsoptional = { false },

    discordfn = function(params, caller, userid, mods, response)
        if response then
            return Message(response)
        end

        return MESSAGES.ModsReport(userid, mods)
    end,

    mainfn = function(params, caller)
        local userid = UserToClientID(params.userid) or params.userid
        local mods = PEARL.PlayerDB:GetField(userid, "lastmods")

        local response = type(mods) ~= "table" and STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.NO_MODS

        return userid, mods, response
    end,

    serverfn = function(params, caller, userid, mods, response)
        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
            )
        end

        if response then
            return PEARL.ServerNetwork:SendCommandResponse(caller.userid, response)
        end

        PEARL.DiscordReporter:ReportMods(userid, mods)
        return PEARL.ServerNetwork:SendCommandResponse(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.ON_SUCCESS)
    end,
})

AddCommand("save", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = false,

    mainfn = function()
        TheWorld:PushEvent("ms_save")
    end,

    discordfn = function()
        return Message("You have saved the world! Thank you!")
    end
})

AddCommand("reboot", {
    slash = false,
    console = false,

    mainfn = function()
        --- @HACK: Crashing the server will result in automatic restart by the provider.
        --- This is an engine side crash so no reports are sent to discord.
        TheSim:Crash()
    end,
})

AddCommand("shutdown", {
    slash = false,
    console = false,

    mainfn = function()
        c_shutdown(true)
    end
})

AddCommand("setrep", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"userid", "value"},
    params_optional = {false, false},
    slash = true,
    console = true,

    mainfn = function(params, caller)
        if PEARL.PlayerDB:OptionalSafeSetField(params.userid, "rep", params.value) then
            return "Reputation set!"
        end

        return "Failed to set reputation."
    end,

    discordfn = function(params, caller, response)
        PEARL.DiscordLogger:LogString(response)
    end,

    serverfn = function(params, caller, response)
        PEARL.ServerNetwork:SendCommandResponse(caller.userid, response)
    end
})

AddCommand("giverep", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.USER,
    params = {"user"},
    params_optional = {false, false},
    slash = true,
    console = false,

    mainfn = function(params, caller)
        local userid = UserToClientID(params.user) or params.user
        if PEARL.Reputation:GiveTo(userid, GIVEREP_AMOUNT) then
            return "Player's reputation has increased!"
        end

        return "Player not found!"
    end,

    discordfn = function(params, caller, response)
        PEARL.DiscordLogger:LogStringRaw(response)
    end,

    serverfn = function(params, caller, response)
        PEARL.ServerNetwork:SendCommandResponse(caller.userid, response)
    end
})

AddCommand("reload", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = true,

    mainfn = c_reset,
})

AddCommand("boost", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false,

    discordfn = function()
        print("DISCORD FN!")

        local task = PEARL.WallScheduler:GetTask(PEARL.CONSTS.TASK_ID.INPUTPROXY_FETCH)
        if not task then
            return "Task not found!"
        end

        local _time = task:gettime()
        task:settime(PEARL.CONFIG.DISCORD.INPUT_PROXY.SYNC_INTERVAL_FAST)
        task:restart()

        PEARL.WallScheduler:ExecuteInTime(PEARL.CONFIG.DISCORD.INPUT_PROXY.BOOST_DELAY, function()
            task:settime(_time or PEARL.CONFIG.DISCORD.INPUT_PROXY.SYNC_INTERVAL)
            task:restart()

            PEARL.DiscordLogger:LogString("Server response latency back to normal.")
        end)

        return PEARL.DiscordLogger:LogString("Lower server latency for 2 minutes!")
    end,
})

AddCommand("profile", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false,

    discordfn = function(params)
        local userid = UserToClientID(params.userid) or params.userid
        local record = PEARL.PlayerDB:GetRecordFor(userid)
        if not record then
            return "Player not found!"
        end

        return EMBEDS.ClientProfile(userid, record)
    end,
})

-------------------------------------------
-- Command Post Inits
-------------------------------------------

PEARL.AddUserCommandPostInit("rollback", function(command)
    command.mainfn = function(params, caller)
        local after = params.after ~= nil and tonumber(params.after) or ROLLBACK_DELAY
        local snapshots = params.snapshots ~= nil and tonumber(params.snapshots)

        TheNet:Announce(STRINGS.PEARL.LOGS.ROLLBACK_AFTER:format(snapshots, after))
        PEARL.WallScheduler:ExecuteInTime(after, function()
            TheNet:SendWorldRollbackRequestToServer(snapshots)
        end)
    end
end)

PEARL.AddUserCommandPostInit("kick", function(command)
    command.mainfn = function(params, caller)
        if params.reason then
            -- Display the reason if any.
            PEARL.ServerNetwork:CloseConnectionFor(
                params.userid, params.reason, false, STRINGS.UI.NETWORKDISCONNECT["ID_DST_USER_KICKED"].TITLE
            )
        end

        -- Give the reason popup some time to display so it's not overriden
        local delay = params.reason and 5 or 0
        PEARL.WallScheduler:ExecuteInTime(delay, function()
            TheNet:Kick(params.userid, params.time)
        end)
    end
end)

PEARL.AddUserCommandPostInit("ban", function(command)
    command.mainfn = function(params, caller)
        if params.reason then
            -- Display the reason if any.
            PEARL.ServerNetwork:CloseConnectionFor(
                params.userid, params.reason, false, STRINGS.UI.NETWORKDISCONNECT["ID_DST_USER_BANNED"].TITLE
            )
        end

        -- Give the reason popup some time to display so it's not overriden
        local delay = params.reason and 5 or 0
        PEARL.WallScheduler:ExecuteInTime(delay, function()
            if params.time then
                return TheNet:BanForTime(params.userid, params.time)
            end

            TheNet:Ban(params.userid)
        end)
    end
end)

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
