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
--- @TODO: Debug


local TheNet = TheNet

local Message = require("libraries/discordapi/models/message")
local MARKDOWN = require("libraries/markdown")

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
        local success, result = PEARL.SafeRun(cb, params, caller, ...)
        if not success then
            PEARL.error("Failed to run command '/"..name.."'! Error:\n", result or "unknown...")

            if type(caller) == "table" and caller.userid then
                PEARL.SendMessageToClient(caller.userid,
                    STRINGS.PEARL.UI.CMD_ERRORS.EXECUTION
                )
            end
        end
    end
end

local function AddCommand(name, data, ...)
    if data.rhook_required == true and not PEARL.DiscordReporter or PEARL.DiscordReporter:IsDisabled() then
        return
    end

    if PEARL.CONFIG.COMMAND_BLOCKLIST[name] == false then
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
        -- if caller and caller.Transform then
        --     PEARL.ExtinguishFiresNear(caller.Transform:GetWorldPosition())

        --     return TheNet:Announce(STRINGS.PEARL.LOGS.EXTINGUISH_NEAR:format(
        --         caller:GetDisplayName()
        --     ), caller.entity)
        -- end

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
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },

    -- This is executed on the local shard
    serverfn = function(params, caller)
        if params == nil or caller == nil then
            return
        end

        if PEARL.UnbanUserByID(params.player_id) then
            return PEARL.SendMessageToClient(caller.userid, string.format(
                STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_SUCCESS, params.player_id
            ))
        end

        PEARL.SendMessageToClient(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_NOTFOUND)
    end,
})

AddCommand("allowlist-add", {
    aliases = {"allow"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if not (params and caller and params.player_id) then
            return
        end

        if PEARL.BlackList:Contains(params.player_id) then
            return PEARL.SendMessageToClient(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_BANNED
            )
        end

        if PEARL.AllowList:Contains(params.player_id) then
            return PEARL.SendMessageToClient(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_ALREADY_WHITELISTED
            )
        end

        PEARL.AllowList:Add(params.player_id)
        if PEARL.AllowList:Save() then
            return PEARL.SendMessageToClient(caller.userid, string.format(
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_SUCCESS,
                params.player_id
            ))
        end

        PEARL.SendMessageToClient(caller.userid, string.format(
            STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_FAILURE,
            params.player_id
        ))
    end,
})

AddCommand("allowlist-remove", {
    aliases = {"deny"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if not (params and caller and params.player_id) then
            return
        end

        if not PEARL.AllowList:Contains(params.player_id) then
            return PEARL.SendMessageToClient(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_NOTFOUND
            )
        end

        PEARL.AllowList:Remove(params.player_id)
        TheNet:Kick(params.player_id)

        if PEARL.AllowList:Save() then
            return PEARL.SendMessageToClient(caller.userid, string.format(
                    STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_SUCCESS,
                    params.player_id
                )
            )
        end

        return PEARL.SendMessageToClient(caller.userid,
            STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_FAILURE
        )
    end,
})

AddCommand("inv", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },
    rhook_required = true,

    serverfn = function(params, caller)
        if not (params and caller) then
            return
        end

        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return PEARL.SendMessageToClient(caller.userid,
                STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
            )
        end

        if PEARL.LogInventoryFor(params.player_id) then
            return PEARL.SendMessageToClient(caller.userid,
                STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_SUCCESS
            )
        end

        return PEARL.SendMessageToClient(caller.userid,
            STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_NOTFOUND
        )
    end,
})

AddCommand("inv-find", {
    aliases = {"item-find"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"item_prefab"},
    params_optional = { false },
    rhook_required = true,

    serverfn = function(params, caller)
        if not (params and caller and params.item_prefab) then
            return
        end

        -- We are sending this to the report channel not to the log channel.
        if PEARL.DiscordReporter:IsDisabled() then
            return PEARL.SendMessageToClient(caller.userid,
                STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK
            )
        end

        local item_owners = {}
        for _, player in ipairs(AllPlayers) do
            local items = player.components.inventory:FindItems(function(item)
                return item.prefab == params.item_prefab
            end)

            if items and #items > 0 then
                item_owners[#item_owners + 1] = {
                    player = player,
                    item_count = #items,
                }
            end
        end

        if #item_owners <= 0 then
            return PEARL.SendMessageToClient(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_FAILURE)
        end

        table.sort(item_owners, function(k1, k2)
            return item_owners[k1].item_count > item_owners[k2].item_count
            and item_owners[k1].player.components.age:GetAge() < item_owners[k1].player.components.age:GetAge()
        end)

        -- Anounce first 5 inventories reversed
        -- so the first one is on the bottom of the chat.
        --- @type Message
        local message = Message(STRINGS.PEARL.LOGS.SEARCH_RESULTS_FOR:format(
            params.item_prefab, #item_owners
        ))
        for i = math.min(#item_owners, 5), 1, -1 do
            local player = item_owners[i].player

            local inventory, prefab, name = PEARL.GetInventoryTabelFor(player.userid, player)
            local embed = PEARL.InventoryToEmbed(inventory, prefab, player.name or name, player.userid)
            if not message:AddEmbed(embed) then
                break -- The message is full and doesn't accept any more embeds
            end
        end

        PEARL.DiscordReporter:SendRawReportMessage(message)
        return PEARL.SendMessageToClient(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_SUCCESS:format(
            #item_owners
        ))
    end,
})

AddCommand("daysback", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DAYSBACK.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DAYSBACK.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
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

            PEARL.SendMessageToClient(caller.userid, result)
        end, DAYSBACK_DELAY)
    end,
})

--- @temporary solution
local ChatQueue
AddCommand("toggle", {
    prettyname = "Toggle the Chat Queue",
    desc = "Turns on/off the chat queue when it becomes annoying.",
    permission = COMMAND_PERMISSION.USER,
    slash = true,

    localfn = function()
        if ChatQueue:Toggle() then
            return ChatHistory:SendCommandResponse("The chat queue is hidden!")
        end

        return ChatHistory:SendCommandResponse("The chat queue is back!")
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
    rhook_required = true,

    canstartfn = function(command, caller)
        if GetTime() <= (caller.__soscall_cd_time or 0) then
            return false, "COOLDOWN"
        end

        return true
    end,

    -- Handle's the cooldown locally
    localfn = function(params, caller)
        local curr_time = GetTime()
        if caller.__soscall_cd_time < curr_time then
            return -- This should not happen
        end

        caller.__soscall_cd_time = curr_time + (PEARL.CONFIG.ADMIN_CALL_COOLDOWN or 0)
    end,

    serverfn = function(params, caller)
        -- In case the webhook reporter was disabled during runtime
        if not PEARL.DiscordReporter or PEARL.DiscordReporter:IsDisabled() then
            return PEARL.SendMessageToClient(caller.userid, STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK)
        end

        PEARL.DiscordReporter:SendRawReportMessage(Message(STRINGS.PEARL.LOGS.PLAYER_REPORT:format(
            PEARL.ICONS.ANNOUNCEMENTS["default"], caller.userid, MARKDOWN.escape(caller:GetDisplayName()), MARKDOWN.escape(params.message or "")
        )):AllowMentionsForType(Message.MENTION_TYPES.EVERYONE))

        PEARL.SendMessageToClient(caller.userid, STRINGS.PEARL.UI.BUILTINCOMMANDS.SOS.ON_SUCCESS)
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

-------------------------------------------
-- Chat Queue
-------------------------------------------

PEARL.AddClassPostConstruct("widgets/redux/chatqueue", function(self)
    ChatQueue = self
end)
