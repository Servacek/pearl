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

local ChatMessage = PEARL.loadfile("models/chatmessage")

local MESSAGES = PEARL.loadfile("utils/messages")
local EMBEDS = PEARL.loadfile("utils/embeds")

-------------------------------------
-- Contants
-------------------------------------

local SLASH_COMMANDS = {}
local REQUIRED_FIELDS = {
    params = {},
}

local SLASH_COMMAND_DELIM   = "/"
local KLEI_ID_DELIM         = "K"
local PLAYER_NAME_DELIM     = "@"

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

local function AddSlashCommand(name, command)
    local _serverfn = command.serverfn
    command.serverfn = make_safe_cb(name, function(params, caller, ...)
        local responses = command.mainfn and {command.mainfn(params, caller, ...)}

        local response = responses and responses[1]
        if type(_serverfn) == "function" then
            response = _serverfn(params, caller, PEARL.unpack(responses))
        end

        if type(response) == "string" then
            -- Handle slash command response
            PEARL.ServerNetwork:SendCommandResponse(caller.userid, response)
        end
    end)

    if command.localfn then
        command.localfn = make_safe_cb(name, command.localfn)
    end

    if command.canstartfn then
        command.canstartfn = make_safe_cb(name, command.canstartfn)
    end

    AddUserCommand(name, command)

    if name then
        SLASH_COMMANDS[name] = command

        if command.aliases then
            for _, alias in ipairs(command.aliases) do
                SLASH_COMMANDS[alias] = command
            end
        end
    end
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

local function EnsureRequiredFields(command)
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

    EnsureRequiredFields(command)

    PEARL.info("Registering command", name)

    command.slash = command.slash ~= false and PEARL.CONFIG.SLASH_COMMANDS
    command.console = command.console ~= false and PEARL.CONFIG.CONSOLE_COMMANDS
    command.discord = command.discord ~= false and PEARL.CONFIG.DISCORD_COMMANDS

    -- Console commands are server-only.
    if not TheNet:GetIsServer() then
        command.console = false
    end

    if command.console ~= false then
        AddConsoleCommand(command.consolename or name, function(...)
            local caller = ThePlayer
            local params = ParseParamsArray(command, toarrayornil(...))
            local response = command.mainfn and {command.mainfn(params, caller)}

            if response and response[1] then
                -- Handle console command response
                PEARL.info(response[1])
            end

            if type(command.consolefn) == "function" then
                return command.consolefn(params, caller, PEARL.unpack(response))
            end

            return PEARL.unpack(response)
        end)

        if command.consolename and command.consolename ~= name then
            if not command.aliases then
                command.aliases = {}
            end

            -- Register the console name as an alias for better consistency.
            if not table.contains(command.aliases, command.consolename) then
                command.aliases[#command.aliases+1] = command.consolename
            end
        end
    end

    if command.discord == true then
        UserCommands.AddDiscordCommand(name, command)
    end

    if command.slash == true or command.usermenu or command.servermenu then
        AddSlashCommand(name, command)
    end
end

------------------------------------
-- Slash commands [ADMIN]
------------------------------------

local function extinguish_near(pos, radius)
    radius = radius or PEARL.CONSTS.EXTINGUISH_RADIUS
    local onfire = TheSim:FindEntities(pos.x, pos.y, pos.z, radius,
        nil, -- must-have tags
        {'wildfireprotected', 'campfire', 'NOCLICK', 'FX','DECOR','INLIMBO','burnt'}, -- cant-have tags
        {'fire','smolder'} -- must-have-one tags
    )

    for i = 1, #onfire do
        if onfire[i].components and onfire[i].components.burnable then
            onfire[i].components.burnable:Extinguish()
        end
    end
end

AddCommand("fire", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"},
    paramsoptional = {true},

    mainfn = function(params, caller)
        local pt_postfix = caller and "_DOER" or ""

        if params.player then
            local player = UserToPlayer(params.player)
            if player ~= nil then
                extinguish_near(player:GetPosition(), PEARL.CONSTS.EXTINGUISH_RADIUS)

                TheNet:Announce(STRINGS.PEARL.LOGS["EXTINGUISH_NEAR"..pt_postfix]:format(
                    caller and caller.name or player.name, player.name
                ), caller and caller.entity)
                return
            end

            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        extinguish_near({x = 0, y = 0, z = 0}, WORLD_TILES_OCEAN_SIZE)

        TheNet:Announce(STRINGS.PEARL.LOGS["EXTINGUISH"..pt_postfix]:format(
            caller and caller.name or "Shenanigans"
        ), caller and caller.entity)
    end,
})

local function repair_near(pos, radius)
    local burned_entities = TheSim:FindEntities(
        pos.x, pos.y, pos.z, radius, {'burnt','structure'}, {'INLIMBO'}
    )

    for _, ent in ipairs(burned_entities) do
        if ent.components.workable and ent.components.workable:HasBuilder() then
            -- Inherit the builder for player-made structures.
            local builder = ent.components.workable and ent.components.workable:GetBuilder()
            local inst = ReplacePrefab(ent, ent.prefab, ent.skinname, ent.skin_id)
            if inst and inst.components.workable then
                inst.components.workable:SetBuilder(builder)
            end
        end
    end
end

AddCommand("repair", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.REPAIR.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.REPAIR.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"},
    paramsoptional = {true},

    mainfn = function(params, caller)
        local pt_postfix = caller and "_DOER" or ""

        if params.player then
            local player = UserToPlayer(params.player)
            if player ~= nil then
                repair_near(player:GetPosition(), PEARL.CONSTS.REPAIR_RADIUS)

                TheNet:Announce(STRINGS.PEARL.LOGS["REPAIR_NEAR"..pt_postfix]:format(
                    caller and caller.name or "Shenanigans"
                ), caller and caller.entity)

                return
            end

            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        repair_near({x = 0, y = 0, z = 0}, WORLD_TILES_OCEAN_SIZE)

        TheNet:Announce(STRINGS.PEARL.LOGS["REPAIR_ALL"..pt_postfix]:format(
            caller and caller.name or "Shenanigans"
        ), caller and caller.entity)
    end,
})

AddCommand("unban", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"},
    paramsoptional= { false },

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        if PEARL.BlackList:RemovePlayerByID(userid) then
            PEARL.info("Successfully removed", userid, "from the blocklist!")
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_SUCCESS
        end

        PEARL.info("Attempt to unban", userid, "failed.")
        return STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_NOTFOUND
    end,
})

AddCommand("grant", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    cantargetself = false,
    cantargetadmin = false,
    params = {"player"},
    paramsoptional= { false },

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
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
})

AddCommand("revoke", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"}, -- Net/Klei ID
    paramsoptional= { false },

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        if not PEARL.AllowList:Contains(userid) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_NOTFOUND
        end

        PEARL.AllowList:Remove(userid)
        TheNet:Kick(userid)

        if PEARL.AllowList:Save() then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_SUCCESS:format(userid)
        end

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_FAILURE
    end,
})

AddCommand("inv", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"}, -- Net/Klei ID
    paramsoptional= { false },

    discordfn = function(params, caller, userid)
        return MESSAGES.InvReport(userid)
    end,

    mainfn = function(params, caller)
        return UserToClientID(params.player) or params.player
    end,

    -- Called via slash commands, requires report webhook
    serverfn = function(params, caller, userid)
        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
        end

        if PEARL.DiscordReporter:ReportInventory(userid) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_SUCCESS
        end

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_NOTFOUND
    end,
})

AddCommand("inv-find", {
    aliases = {"item-find", "invf"},
    consolename = "invf",
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    discord = false,
    console = false,
    params = {"prefab"},
    paramsoptional = { false },

    mainfn = function(params, caller)
        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
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
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_FAILURE
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

        return message, item_owners
    end,

    serverfn = function(params, caller, message, item_owners)
        if not Message.is_instance(message) then
            return message
        end

        PEARL.DiscordReporter:SendRawReportMessage(message)

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_SUCCESS:format(
            #item_owners
        )
    end,

    consolefn = function(...)
        local command = UserCommands.GetCommandFromName("inv-find")
        return command.serverfn(...)
    end,
})

--- @TODO: Check if this works properly
-- AddCommand("daysback", {
--     prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DAYSBACK.PRETTYNAME,
--     desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DAYSBACK.DESC,
--     permission = COMMAND_PERMISSION.ADMIN,
--     slash = true,
--     confirm = true,
--     console = false,
--     params = { "days" },
--     paramsoptional= { false },

--     serverfn = function(params, caller)
--         if not (params and caller and params.days) then
--             return
--         end

--         PEARL.RollbackByDays(tonumber(params.days), function(success, result)
--             if success then
--                 return TheNet:Announce(result)
--             end

--             PEARL.ServerNetwork:SendCommandResponse(caller.userid, result)
--         end, DAYSBACK_DELAY)
--     end,
-- })

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

local function send_mods_report(params, caller, response, userid, mods)
    -- We are sending this to the report channel not to the log channel.
    if PEARL.DiscordReporter:IsDisabled() then
        return STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
    end

    if response then
        return response
    end

    PEARL.DiscordReporter:ReportMods(userid, mods)
    return STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.ON_SUCCESS
end

--- currently the cfd data are erased every time we restart the server.
AddCommand("mods", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = { "player" }, -- Do not use "user" for offline support
    paramsoptional = { false },

    discordfn = function(params, caller, response, userid, mods)
        if not response then
            return MESSAGES.ModsReport(userid, mods)
        end
    end,

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        local mods = PEARL.PlayerDB:GetField(userid, "lastmods")
        if not mods then
            local cfd = PEARL.ServerNetwork:GetCachedCFDFor(userid)
            mods = cfd and cfd.enabled_mods
        end

        -- Using table.size even though this should be an array for additional safety and flexibility.
        if type(mods) ~= "table" or type(mods.list) ~= "table" or table.size(mods.list) <= 0 then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.NO_MODS
        end

        return nil, userid, mods
    end,

    serverfn = send_mods_report,
    consolefn = send_mods_report,
})

AddCommand("save", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = false, -- Already implemented by the game.

    mainfn = function()
        TheWorld:PushEvent("ms_save")
    end,
})

AddCommand("reboot", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false,

    mainfn = function()
        --- @HACK: Crashing the server will result in automatic restart by the provider.
        --- This is an engine side crash so no reports are sent to discord.
        TheSim:Crash()
    end,
})

AddCommand("shutdown", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false, -- already implemented by the game

    mainfn = function()
        -- Make sure the world is being saved before shutdown!
        c_shutdown(true)
    end
})

AddCommand("setrep", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"player", "value"},
    paramsoptional = {false, false},
    slash = true,
    console = true,

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        if PEARL.Reputation:SetTo(userid, tonumber(params.value)) then
            PEARL.PlayerDB:SaveRecordFor(userid)

            return STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.ON_SUCCESS
        end

        return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
    end,
})

AddCommand("giverep", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.DESC,
    permission = COMMAND_PERMISSION.USER,
    params = {"player"},
    paramsoptional = {false},
    slash = true,
    discord = false, -- No discord support until we have some authentication system.
    console = false, -- This is meant to be a user-only command.

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        if caller.userid == userid and not PEARL.CONFIG.DEBUG_MODE then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.ON_SELF
        end

        if PEARL.Reputation:GiveTo(userid, GIVEREP_AMOUNT) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.ON_SUCCESS
        end

        return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
    end,
})

AddCommand("reload", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.RELOAD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.RELOAD.DESC,
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
        local task = PEARL.WallScheduler:GetTask(PEARL.CONSTS.TASK_ID.INPUTPROXY_FETCH)
        if not task then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.BOOST.ON_FAILURE
        end

        local _time = task:gettime()
        task:settime(PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL_FAST)
        task:restart()

        PEARL.WallScheduler:ExecuteInTime(PEARL.CONFIG.DISCORD.PROXY.BOOST_DELAY, function()
            task:settime(_time or PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL)
            task:restart()

            PEARL.DiscordLogger:LogString(STRINGS.PEARL.UI.BUILTINCOMMANDS.BOOST.ON_TIMEOUT)
        end)

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.BOOST.ON_SUCCESS
    end,
})

--- @TODO: Add slash and console command support.
AddCommand("profile", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false,

    discordfn = function(params)
        local userid = UserToClientID(params.player) or params.player
        local record = PEARL.PlayerDB:GetRecordFor(userid)
        if not record then
            return "Player not found!"
        end

        return EMBEDS.ClientProfile(userid, record)
    end,
})

--- @TODO: Maybe make these for offline players by simulating the inventory?
AddCommand("give", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = false, -- Already implemented for console by the game.
    params = {"player", "prefab", "count"},
    paramsoptional = {false, false, true},

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        params.count = tonumber(params.count)

        local item
        local prefab = string.lower(params.prefab)
        local count_left = math.max(type(params.count) == "number" and params.count or 1, 1)
        local count = count_left
        while count_left > 0 do
            item = SpawnPrefab(prefab)
            if not item or not item.components.inventoryitem then
                if item then
                    item:Remove()
                end

                return STRINGS.PEARL.UI.CMD_ERRORS.ITEM_PREFAB_INVALID
            end

            local maxsize = item.components.stackable and item.components.stackable.maxsize or 1
            -- Between 1 - maxsize
            local stacksize = math.max(math.min(maxsize, count_left), 1)

            if item.components.stackable and stacksize > 1 then
                item.components.stackable:SetStackSize(stacksize)
            end

            player.components.inventory:GiveItem(item)

            count_left = count_left - stacksize
        end

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.ON_SUCCESS:format(
            count, item:GetBasicDisplayName(), player.name
        )
    end,
})

AddCommand("take", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.TAKE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.TAKE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = true,
    params = {"player", "prefab", "count"},
    paramsoptional = {false, false, true},

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        local prefab = string.lower(params.prefab)
        params.count = tonumber(params.count)

        -- Take all items by default.
        local count = type(params.count) == "number" and params.count or math.huge
        local items = player.components.inventory:GetItemByName(prefab, count, false)
        if not items or table.empty(items) then
            return STRINGS.PEARL.UI.CMD_ERRORS.ITEM_NOT_FOUND
        end

        local item_name
        local total_count = 0
        for item, amount in pairs(items) do
            amount = math.min(count, amount)
            total_count = total_count + amount

            if not item_name then
                item_name = item:GetBasicDisplayName()
            end

            local stacksize = item.components.inventoryitem:GetStackSize()
            if amount < stacksize and item.components.stackable then
                item.components.stackable:SetStackSize(stacksize - amount)
            else
                -- Remove the items completely.
                item:Remove()
            end
        end

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.TAKE.ON_SUCCESS:format(
            total_count, item_name or "UNKNOWN", player.name
        )
    end,
})

AddCommand("drop", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = true,
    params = {"player", "prefab", "count"},
    paramsoptional = {false, true, true},

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        -- If no item specified, drop everything.
        if type(params.prefab) ~= "string" then
            player.components.inventory:DropEverything()

            return STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.DROP_ALL:format(
                player.name
            )
        end

        local prefab = string.lower(params.prefab)
        params.count = tonumber(params.count)

        -- Take all items by default.
        local count = type(params.count) == "number" and params.count or math.huge
        local items = player.components.inventory:GetItemByName(prefab, count, false)
        if not items or table.empty(items) then
            return STRINGS.PEARL.UI.CMD_ERRORS.ITEM_NOT_FOUND
        end

        local item_name
        local total_amount = 0
        for stack, amount in pairs(items) do
            amount = math.min(count, amount)
            total_amount = total_amount + amount
            local item = stack.components.stackable and stack.components.stackable:Get(amount) or stack

            if not item_name then
                item_name = item:GetBasicDisplayName()
            end

            -- Drop the whole stack of the item taken from the source stack!
            player.components.inventory:DropItem(item, true)
        end

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.DROP:format(
            total_amount, item_name or "UNKNOWN", player.name
        )
    end,
})

AddCommand("kill", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.KILL.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.KILL.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = true,
    params = {"player"},
    paramsoptional = {true},

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        userid = userid or (caller and caller.userid) or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.health then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        player:PushEvent("death", {cause = caller and caller.name})

        -- Implicit response via the announcement
        --return STRINGS.PEARL.UI.BUILTINCOMMANDS.KILL.ON_SUCCESS
    end,
})

AddCommand("revive", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.REVIVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.REVIVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = true,
    params = {"player"},
    paramsoptional = {true},

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        userid = userid or (caller and caller.userid) or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        player:PushEvent("respawnfromghost", {})

        -- Implicit response via the announcement
        --return STRINGS.PEARL.UI.BUILTINCOMMANDS.REVIVE.ON_SUCCESS
    end,
})

-- AddCommand("pause", {
--     prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.PAUSE.PRETTYNAME,
--     desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.PAUSE.DESC,
--     permission = COMMAND_PERMISSION.ADMIN,
--     console = true,
--     discord = true,
--     slash = true,
--     usermenu = false,
--     servermenu = false,

--     mainfn = function(params, caller)
--         SetServerPaused()
--     end
-- })

AddCommand("despawn", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = false, -- Already built in
    params = {"player"},
    paramsoptional = {true},

    mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        userid = userid or (caller and caller.userid) or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        -- Make sure we drop the inventory before it's too late.
        if player.components.inventory then
            player.components.inventory:DropEverything()
        end

        TheWorld:PushEvent("ms_playerdespawnanddelete", player)

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.ON_SUCCESS
    end,
})

-- This is here mainly for debugging purposes, so we do not have to wait
-- for the Master shard to be restarted.
AddCommand("reloadshard", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    discord = false,
    slash = false,
    usermenu = false,
    servermenu = false,

    mainfn = function()
        StartNextInstance({
            reset_action = RESET_ACTION.LOAD_SLOT,
            save_slot = ShardGameIndex:GetSlot()
        })
    end
})

-- This is here mainly for debugging purposes
AddCommand("skip", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    discord = false,
    slash = true,
    usermenu = false,
    servermenu = false,

    mainfn = function()
        TheWorld:PushEvent("ms_nextphase")
    end
})

AddCommand("announce", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ANNOUNCE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ANNOUNCE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = false, -- Already implemented for console.
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,
    params = { "message" },
    paramsoptional = { false },

    mainfn = function(params)
        TheNet:Announce(params.message)
    end
})

AddCommand("dm", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DM.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DM.DESC,
    permission = COMMAND_PERMISSION.USER,
    console = true,
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,
    params = { "player", "message" },
    paramsoptional = { false, false },

    mainfn = function(params, caller)
        local target = UserToClient(params.player)
        if not target or not target.name or not target.userid then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        --- @type ChatMessage
        local message = ChatMessage(params.message)
        message:SetColour(WHISPER_COLOR)
        message:SetReceiver(target.name)

        if caller then
            local name = caller.name
            local client = caller.userid and TheNet:GetClientTableForUser(caller.userid)
            if client then
                message:SetIcon(GetRemotePlayerVanityItem(client.vanity or {}, "profileflair"))
            end

            message:SetAuthor(name, caller.playercolour, caller.userid, caller.netid, caller.prefab, caller.GUID)
        end

        PEARL.ServerNetwork:DisplayChatMessageFor(
            -- Display the direct message for the target user as well as the caller.
            caller and {target.userid, caller.userid} or target.userid, message
        )

        -- Implicit response?
        --return STRINGS.PEARL.UI.BUILTINCOMMANDS.DM.ON_SUCCESS:format(target.name)
    end
})

AddCommand("system", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SYSTEM.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SYSTEM.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,
    params = { "message" },
    paramsoptional = { false },

    mainfn = function(params)
        TheNet:SystemMessage(params.message)
    end
})

AddCommand("gameowner", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    discord = true,
    slash = false,
    usermenu = false,
    servermenu = false,
    params = { "player" },
    paramsoptional = { false },

    mainfn = function(params, caller, commandid)
        local userid = UserToClientID(params.player) or params.player
        local request = PEARL.KleiAccounts:QueryGameOwner(
            userid, PEARL.KleiAccounts.GAME.DST, function(rootid)
                local result = STRINGS.PEARL.UI.BUILTINCOMMANDS.GAMEOWNER.ON_FAILURE
                if type(rootid) == "string" and #rootid > 2 then
                    result = STRINGS.PEARL.UI.BUILTINCOMMANDS.GAMEOWNER.ON_SUCCESS:format(rootid)
                end

                if commandid ~= nil then
                    return PEARL.DiscordProxy:SendCommandResponse(commandid, Message(result))
                end

                PEARL.info(result)
        end)

        if not request then
            error("Failed to encode verification json data!")
        end

        request:Send()
    end
})

AddCommand("pair", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.DESC,
    permission = COMMAND_PERMISSION.USER,
    console = false,
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,
    params = { "id" },
    paramsoptional = { false },

    mainfn = function(params, caller, commandid)
        local bindtype = PEARL.PlayerDB.BINDING_TYPE.DISCORD
        local userid = caller.userid or params.id
        local discordid = caller.discordid or params.id

        if not PEARL.PlayerDB:HasRecordFile(userid) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.NOT_PLAYED
        end

        if PEARL.PlayerDB:BindingExists(userid, discordid, bindtype) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.ALREADY_PAIRED
        end

        local request = PEARL.KleiAccounts:QueryLinkValidation(
            userid, PEARL.KleiAccounts.PLATFORM.DISCORD, discordid
        )
        if not request then
            error("Failed to encode verification json data!")
        end

        request:SetOnComplete(function(data, self, success)
            if not success then
                if not self:IsRetryable() then
                    PEARL.DiscordProxy:SendCommandResponse(
                        commandid, Message(STRINGS.PEARL.UI.CMD_ERRORS.KLEI_SERVERS_UNREACHABLE)
                    )
                end

                return
            end

            if data.Error ~= false then
                error("Verification request failed!")
            end

            if data.Linked then
                PEARL.PlayerDB:AddBinding(userid, discordid, bindtype)
                return PEARL.DiscordProxy:SendCommandResponse(
                    commandid, Message(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.ON_SUCCESS)
                )
            end

            return PEARL.DiscordProxy:SendCommandResponse(
                commandid, Message(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.NOT_PAIR_OFFICIALLY)
            )
        end)
        request:Send()
    end,
})

--- @TODO: Add SYNC and UNSYNC icons
AddCommand("unpair", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.DESC,
    permission = COMMAND_PERMISSION.USER,
    console = false,
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,

    mainfn = function(params, caller)
        local bindtype = PEARL.PlayerDB.BINDING_TYPE.DISCORD
        local userid = caller.userid
        local discordid = caller.discordid
        if userid and not discordid then
            discordid = PEARL.PlayerDB:MapUserIDToType(userid, bindtype)
        elseif discordid and not userid then
            userid = PEARL.PlayerDB:MapDiscordID(discordid)
        end

        if not userid or not discordid or not PEARL.PlayerDB:BindingExists(userid, discordid, bindtype) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.NOT_PAIRED
        end

        PEARL.PlayerDB:RemoveBinding(userid, discordid, bindtype)
        return STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.ON_SUCCESS
    end,
})

AddCommand("blockmod", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    slash = true,
    params = {"id"},
    paramsoptional = {false},

    mainfn = function(params)
        local modid = tostring(params.id)
        PEARL.CONFIG.MOD_BLOCKLIST = PEARL.CONFIG.MOD_BLOCKLIST or {}
        if table.contains(PEARL.CONFIG.MOD_BLOCKLIST, modid) then
            return STRINGS.PEARL.UI.CMD_ERRORS.MOD_ALREADY_BLOCKED
        end

        table.insert(PEARL.CONFIG.MOD_BLOCKLIST, modid)
        if PEARL.CONFIG.MOD_ALLOWLIST and table.removearrayvalue(PEARL.CONFIG.MOD_ALLOWLIST, modid) then
            PEARL.ClusterPersistance:SetFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, PEARL.CONFIG.MOD_ALLOWLIST)
        end

        PEARL.ClusterPersistance:SetFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, PEARL.CONFIG.MOD_BLOCKLIST)

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.ON_SUCCESS
    end
})

------------------------------------
-- These should be safe.
-- They are here for debugging and special case handling purposes.

AddCommand("exec", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = false,
    slash = false,
    usermenu = false,
    servermenu = false,
    params = {"command", "shard"},
    paramsoptional = {false, true},

    discordfn = function(params)
        if params.shardid ~= nil and params.shardid ~= SHARDID.MASTER and not PEARL.ServerNetwork:IsShardConnected(params.shardid) then
            return STRINGS.PEARL.UI.CMD_ERRORS.SHARD_NOT_FOUND
        end

        PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, params.shardid, params.command)
    end
})

AddCommand("setdbfield", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    slash = false,
    usermenu = false,
    servermenu = false,
    params = {"player", "field", "value"},
    paramsoptional = {false, false, false},

    mainfn = function(params)
        if not PEARL.PlayerDB:IsEnabled() then
            return STRINGS.PEARL.UI.CMD_ERRORS.DB_DISABLED
        end

        local userid = UserToClientID(params.player) or params.player
        if not userid or not PEARL.PlayerDB:HasRecordFile(userid) then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        if not PEARL.PlayerDB:SetField(userid, params.field, params.value) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_DB_FIELD.ON_FAILURE
        end

        PEARL.PlayerDB:SaveRecordFor(userid)
        return STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_DB_FIELD.ON_SUCCESS
    end
})

AddCommand("setrarity", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    slash = false,
    usermenu = false,
    servermenu = false,
    params = {"prefab", "value"},
    paramsoptional = {false, false},

    mainfn = function(params)
        if not PEARL.CONFIG.INVENTORY_REPORTER.ENABLED then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_RARITY.ON_DISABLED
        end

        PEARL.EventProcessor:HandleEvent("set_item_rarity", params.prefab, tonumber(params.value))
        return STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_RARITY.ON_SUCCESS
    end
})

AddCommand("setslots", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    slash = true,
    usermenu = false,
    servermenu = false,
    params = {"count"},
    paramsoptional = {false},

    mainfn = function(params)
        local count = tonumber(params.count)
        if type(count) ~= "number" or count <= 0 then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_INVALID_INPUT
        end

        if count < PEARL.ServerNetwork:GetConnectedClientsCount() then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_COUNT_TOO_LOW
        end

        -- This prints some weird error at first use. But the count is actually set.
        TheNet:SetDefaultMaxPlayers(tostring(count))

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_SUCCESS
    end
})

-------------------------------------------
-- Command Post Inits
-------------------------------------------

PEARL.AddUserCommandPreInit("rollback", function(command)
    command.mainfn = function(params, caller)
        local after = params.after ~= nil and tonumber(params.after) or ROLLBACK_DELAY
        -- local days = params.days ~= nil and tonumber(params.days)
        -- if days and days >= 0 then
        --     return PEARL.RollbackByDays(days, nil, after)
        -- end

        local snapshots = params.snapshots ~= nil and tonumber(params.snapshots)

        TheNet:Announce(STRINGS.PEARL.LOGS.ROLLBACK_AFTER:format(snapshots, after))
        PEARL.WallScheduler:ExecuteInTime(after, function()
            TheNet:SendWorldRollbackRequestToServer(snapshots)
        end)
    end
end)

PEARL.AddUserCommandPreInit("regenerate", function(command)
    if not command.aliases then
        command.aliases = {}
    end

    table.insert(command.aliases, "regen")

    command.mainfn = function(params)
        if params.shard == nil then
            return c_regenerateworld()
        end

        local shardid = tostring(params.shard)
        if shardid == SHARDID.MASTER then
            return c_regenerateshard()
        end

        PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, shardid, "c_regenerateshard()")
    end
end)

PEARL.AddUserCommandPreInit("kick", function(command)
    command.mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player
        if not PEARL.ServerNetwork:IsUserConnected(userid) then
            return STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND
        end

        local has_reason = type(params.reason) == "string"
        if has_reason then
            -- Display the reason if any.
            PEARL.ServerNetwork:CloseConnectionFor(
                userid, params.reason, false, STRINGS.UI.NETWORKDISCONNECT["ID_DST_USER_KICKED"].TITLE
            )
        end

        -- Give the reason popup some time to display so it's not overriden
        local delay = has_reason and 5 or 0
        PEARL.WallScheduler:ExecuteInTime(delay, function()
            TheNet:Kick(userid, params.time)
        end)

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.KICK.ON_SUCCESS
    end

    AddConsoleCommand("kick", command.mainfn)
end)

PEARL.AddUserCommandPreInit("ban", function(command)
    command.mainfn = function(params, caller)
        local userid = UserToClientID(params.player) or params.player

        if PEARL.BlackList:Contains(userid) then
            return STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ALREADY_BANNED
        end

        local has_reason = type(params.reason) == "string"
        if has_reason then
            -- Display the reason if any.
            PEARL.ServerNetwork:CloseConnectionFor(
                userid, params.reason, false, STRINGS.UI.NETWORKDISCONNECT.TITLE["ID_DST_USER_BANNED"]
            )
        end

        -- Give the reason popup some time to display so it's not overriden
        local delay = has_reason and 5 or 0
        PEARL.WallScheduler:ExecuteInTime(delay, function()
            if params.time then
                return TheNet:BanForTime(userid, params.time)
            end

            TheNet:Ban(userid)
        end)

        return STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ON_SUCCESS
    end

    AddConsoleCommand("ban", command.mainfn)
end)

if TheNet:GetIsServer() then
    return -- Nothing interesting for the server here
end

-------------------------------------------
-- Command Prediction
-------------------------------------------

-- AddClassPostConstruct("screens/chatinputscreen", function(self)
--     local permission = COMMAND_PERMISSION.USER
--     if TheNet:GetIsServerAdmin() then
--         permission = COMMAND_PERMISSION.ADMIN
--     end

--     -- Setup prediction for our custom slash commands
--     for _, v in pairs(self.chat_edit.prediction_widget.word_predictor.dictionaries) do
--         if v.delim == PEARL.CONSTS.DELIMS.SLASH_COMMAND then
--             for name, command in pairs(SLASH_COMMANDS) do
--                 -- Only autocomplete the commands we have permission to.
--                 if command.permission == nil or command.permission == permission then
--                     table.insert(v.words, name)
--                 end
--             end
--         end
--     end

--     local userids = {}
--     local names = {}
--     for _, v in ipairs(AllPlayers) do
--         if v and v.userid then
--             -- Remove the delim from the userid
--             table.insert(userids, v.userid:sub(#PEARL.CONSTS.DELIMS.KLEI_ID + 1))
--             table.insert(names, v.name)
--         end
--     end

--     -- Auto-complete for user ids
--     self.chat_edit:AddWordPredictionDictionary({
--         delim = PEARL.CONSTS.DELIMS.KLEI_ID,
--         words = userids,
--     })

--     -- Auto-complete for player names
--     self.chat_edit:AddWordPredictionDictionary({
--         delim = PEARL.CONSTS.DELIMS.PLAYER_NAME,
--         words = names,
--     })
-- end)
