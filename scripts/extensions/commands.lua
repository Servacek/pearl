--[[====================================================[==[
    The "Pearl" - modification software for
    the game "Don"t Starve Together" by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the "Pearl" software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd & BackEnd
--- @alias PlayerInst EntityScript
--- @alias ClientTable table<string, any>


--- @TODO: Command for showing arbitrary files on the system?
--- @TODO: Command for showing mod logs.
--- @TODO: Add find command for finding an item globally.

-------------------------------------
-- Dependencies
-------------------------------------

-- So we can use the console commands immediately in command declarations.
require("consolecommands")

--- @type UserCommands
local UserCommands = require("usercommands")

local Message = PEARL.loadfile("libraries/discordapi/models/message")

local ChatMessage = PEARL.loadfile("models/chatmessage")
local CommandContext = PEARL.loadfile("models/commandcontext")
local OptionChoice = PEARL.loadfile("libraries/discordapi/models/choice")

local MESSAGES = PEARL.loadfile("utils/messages")
local EMBEDS = PEARL.loadfile("utils/embeds")

local MARKDOWN = PEARL.loadfile("libraries/markdown")

local Leaderboard = PEARL.loadfile("libraries/database/models/leaderboard")

local ItemDepositor = PEARL.loadfile("libraries/itemdepositor")

-------------------------------------
-- Localization
-------------------------------------

local TheNet = TheNet
local AddCommand = UserCommands.AddCustomCommand
local AddAsyncCommand = UserCommands.AddCustomAsyncCommand

-------------------------------------
-- Constants
-------------------------------------

local DEFAULT_AOE_RADIUS = 32

local OPTION_TYPE = UserCommands.OPTION_TYPE
local PARAMS = UserCommands.STD_PARAMS

local COMMAND_PERMISSION = UserCommands.PERMISSION

--local DAYSBACK_DELAY = 3
local DEFAULT_ROLLBACK_DELAY    = 3
local MAX_ROLLBACK_DELAY        = 600
local MIN_ROLLBACK_DELAY        = 0

local GIVEREP_AMOUNT = 25

local SEED_PATH = MODROOT.."data/seed.txt"

-- Sort choices by common usage.
local STATIC_CHOICES = {
    LEADERBOARD_TYPE = {
        OptionChoice(STRINGS.PEARL.UI.OPTION_CHOICES.LEADERBOARD.MONTHLY, Leaderboard.TYPE.MONTHLY),
        OptionChoice(STRINGS.PEARL.UI.OPTION_CHOICES.LEADERBOARD.ABSOLUTE, Leaderboard.TYPE.ABSOLUTE),
    },
    YES_NO = {
        OptionChoice(STRINGS.PEARL.UI.OPTION_CHOICES.YES_NO.YES, true),
        OptionChoice(STRINGS.PEARL.UI.OPTION_CHOICES.YES_NO.NO, false),
    },
}

------------------------------------
-- Slash commands [ADMIN]
------------------------------------

local function extinguish_near(pos, radius)
    radius = radius or PEARL.CONSTS.EXTINGUISH_RADIUS
    local onfire = TheSim:FindEntities(pos.x, pos.y, pos.z, radius,
        nil, -- must-have tags
        {"wildfireprotected", "campfire", "NOCLICK", "FX","DECOR","INLIMBO","burnt"}, -- cant-have tags
        {"fire","smolder"} -- must-have-one tags
    )

    local count = 0
    for i = 1, #onfire do
        if onfire[i].components and onfire[i].components.burnable then
            onfire[i].components.burnable:Extinguish()
            count = count + 1
        end
    end

    return count
end

local function repair_near(pos, radius)
    local burned_entities = TheSim:FindEntities(
        pos.x, pos.y, pos.z, radius, {"burnt","structure"}, {"INLIMBO"}
    )

    local count = 0
    for _, ent in ipairs(burned_entities) do
        if ent.components.built then
            -- Inherit the builder for player-made structures.
            local builder = ent.components.built.doer
            local inst = ReplacePrefab(ent, ent.prefab, ent.skinname, ent.skin_id)
            if inst then
                count = count + 1

                if not inst.components.built then
                    inst:AddComponent("built")
                end

                inst.components.built:SetBuilder(builder)
            end
        end
    end

    return count
end

local function do_aoe_action(author, target, fn, str_base, radius)
    local pt_postfix = author and "_DOER" or "_ALL"
    local doer_name = author.name or "Shenanigans"

    if target then
        pt_postfix = pt_postfix.."_NEAR"
        local count = fn(target:GetPosition(), radius or DEFAULT_AOE_RADIUS)

        -- Keep it global.
        return TheNet:Announce(STRINGS.PEARL.LOGS[str_base..pt_postfix]:nformat{
            doer = doer_name, count = count, target = target.name or STRINGS.PEARL.LOGS.UNKNOWN
        }, target.entity)
    end

    local count = fn({x = 0, y = 0, z = 0}, WORLD_TILES_OCEAN_SIZE)

    -- This is called on all shards so only show the message to the shard players.
    PEARL.ServerNetwork:AnnounceFor(PEARL.ServerNetwork:GetConnectedClientIDs(),
        STRINGS.PEARL.LOGS[str_base..pt_postfix]:nformat{
            doer = doer_name, count = count
        }, nil, author.colour
    )
end

AddCommand("fire", {
    permission = COMMAND_PERMISSION.ADMIN,
    routingfallback = UserCommands.SHARD_ROUTINGFALLBACK.ALL,
    instrequired = true,
    options = {PARAMS.PLAYER{optional = true}},

    --- @param ctx CommandContext
    --- @param player PlayerInst?
    fn = function(ctx, player)
        do_aoe_action(ctx.author, player, extinguish_near, "EXTINGUISH", PEARL.CONSTS.EXTINGUISH_RADIUS)
    end,
})

AddCommand("repair", {
    permission = COMMAND_PERMISSION.ADMIN,
    routingfallback = UserCommands.SHARD_ROUTINGFALLBACK.ALL,
    instrequired = true,
    options = {PARAMS.PLAYER{optional = true}},

    --- @param ctx CommandContext
    --- @param player PlayerInst?
    fn = function(ctx, player)
        do_aoe_action(ctx.author, player, repair_near, "REPAIR", PEARL.CONSTS.REPAIR_RADIUS)
    end,
})

AddCommand("unban", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.NONE,
    options = {PARAMS.PLAYER{validate = false}},

    --- @param ctx CommandContext
    --- @param userid string
    fn = function(ctx, userid)
        if PEARL.BlackList:Remove(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_NOTFOUND)
    end,
})

AddCommand("grant", {
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.NONE,
    options = {PARAMS.PLAYER{validate = false}},

    --- @param ctx CommandContext
    --- @param userid string
    fn = function(ctx, userid)
        if PEARL.BlackList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GRANT.ON_BANNED)
        end

        if PEARL.WhiteList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GRANT.ON_ALREADY_WHITELISTED)
        end

        PEARL.WhiteList:Add(userid)
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GRANT.ON_SUCCESS:format(userid))
    end,
})

AddCommand("revoke", {
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.NONE,
    options = {PARAMS.PLAYER{validate = false}},

    --- @param ctx CommandContext
    --- @param userid string
    fn = function(ctx, userid)
        if not PEARL.WhiteList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.REVOKE.ON_NOTFOUND)
        end

        PEARL.WhiteList:Remove(userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.REVOKE.ON_SUCCESS:format(userid))
    end,
})

AddCommand("inv", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    privateresponse = true,
    options = {
        PARAMS.PLAYER,
        {name = "raw", type = OPTION_TYPE.BOOLEAN, optional = true, choices = STATIC_CHOICES.YES_NO}
    },

    --- @param ctx CommandContext
    --- @param userid string
    --- @param raw boolean?
    fn = function(ctx, userid, raw)
        local reference = PEARL.GetPlayerMetadataFor(userid)
        local inventory = reference and reference:GetInventory()
        if table.empty(inventory) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_NOTFOUND)
        end

        if raw == true then
            local success, inventory_json = pcall(json.encode, inventory)
            if success == false then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.FAILED_TO_ENCODE)
            end

            local content = MARKDOWN.bold(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.INVENTORY_HEADER:format(
                reference:GetName() or PEARL.DB:GetField(userid, "username", userid)
            ))..MARKDOWN.codeblock(inventory_json, "json")

            ctx:ReplyDiscordMessage(Message(content))
        else
            ctx:ReplyDiscordMessage(MESSAGES.InvReport(userid, reference))
        end
    end,
})

--- @TODO: Make it search even offline inventories (use the DB binding files)
AddCommand("invf", {
    aliases = {"inv-find"},
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.ALL,
    options = {PARAMS.PREFAB},

    --- @param ctx CommandContext
    --- @param prefab string
    fn = function(ctx, prefab)
        local item_owners = {}
        for _, player in ipairs(AllPlayers) do
            local items = player.components.inventory:FindItems(function(item)
                return item.prefab == prefab
            end)

            if items and #items > 0 then
                item_owners[#item_owners + 1] = {
                    player = player,
                    item_count = #items,
                }
            end
        end

        if #item_owners <= 0 then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INVF.ON_FAILURE)
        end

        -- Sort by item count and player age
        table.sort(item_owners, function(v1, v2)
            return v1.item_count > v2.item_count
            and v1.player.components.age:GetAge() < v2.player.components.age:GetAge()
        end)

        -- Anounce first 5 inventories reversed
        -- so the first one is on the bottom of the chat.
        --- @type Message
        local message = Message(MARKDOWN.bold(STRINGS.PEARL.LOGS.SEARCH_RESULTS_FOR:format(
            prefab, #item_owners
        )))
        for i = math.min(#item_owners, 5), 1, -1 do
            local player_reference = PEARL.GetPlayerMetadataFor(item_owners[i].player.userid)
            local embed = EMBEDS.Inventory(player_reference, {prefab})
            if not message:AddEmbed(embed) then
                break -- The message is full and doesn"t accept any more embeds
            end
        end

        ctx:ReplyDiscordMessage(message)

        if ctx.type ~= CommandContext.TYPE.DISCORD then
            ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INVF.ON_SUCCESS:format(
                #item_owners
            ))
        end
    end,
})

--- @TODO: Migrate to the new cooldown API, keep all cooldowns on the server.
--- Remove the unnecessary RPC call... (can be replaced with a serverfn)
-- Slash commands only
AddCommand("admins", {
    aliases = {"staff", "sos"}, -- So it reaches to more players
    permission = COMMAND_PERMISSION.USER,
    confirm = true,
    console = false,
    discord = false,
    slash = true,
    servermenu = true,
	menusort = 2,
    params = {"message"},
    paramsoptional = {true},

    -- Called only for slash commands
    canstartfn = function(command, caller)
        if GetTime() <= (caller.__soscall_cd_time or 0) then
            return false, "COOLDOWN"
        end

        return true
    end,

    -- Handles the cooldown locally
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

AddCommand("mods", {
    permission = COMMAND_PERMISSION.ADMIN,
    options = {PARAMS.PLAYER},

    --- @param ctx CommandContext
    --- @param userid string
    fn = function(ctx, userid)
        -- First try to get the mods from the CFD since that"s faster
        local cfd = PEARL.ServerNetwork:GetCachedCFDFor(userid)
        local mods = cfd and cfd.enabled_mods
        if not mods then
            -- If that didn"t work, look in the DB.
            mods = PEARL.DB:GetField(userid, "lastmods")
        end

        -- Using table.size even though this should be an array for additional safety and flexibility.
        if type(mods) ~= "table" or type(mods.list) ~= "table" or table.size(mods.list) <= 0 then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.NO_MODS)
        end

        ctx:ReplyDiscordMessage(MESSAGES.ModsReport(userid, mods))
    end,
})

AddCommand("server", {
    slash = false,
    permission = COMMAND_PERMISSION.USER,

    --- @param ctx CommandContext
    fn = function(ctx)
        ctx:ReplyDiscordEmbed(EMBEDS.ServerInfo())
    end
})

AddCommand("players", {
    slash = false,
    permission = COMMAND_PERMISSION.USER,

    --- @param ctx CommandContext
    fn = function(ctx)
        ctx:ReplyDiscordEmbed(EMBEDS.PlayerInfo())
    end,
})

AddCommand("world", {
    slash = false,
    permission = COMMAND_PERMISSION.USER,
    routing = UserCommands.SHARD_ROUTING.AUTO, -- Let the API do the routing for us.
    options = {PARAMS.SHARD{optional = true}}, -- Display master info as default.

    --- @param ctx CommandContext
    fn = function(ctx)
        ctx:ReplyDiscordEmbed(EMBEDS.WorldInfo())
    end,
})

AddCommand("save", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = false, -- Already implemented by the game.

    fn = function()
        TheWorld:PushEvent("ms_save")
    end,
})

AddCommand("reboot", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false,
    exectime = 0,

    fn = function()
        PEARL.Reboot()
    end
})

AddCommand("shutdown", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false, -- already implemented by the game
    exectime = 0,

    fn = function()
        --- @Note For some odd reason, when setting the "save" parameter to "true"
        --- it will exist the server but some providers may think that
        c_shutdown() -- Saves by default
    end
})

AddCommand("setrep", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    options = {PARAMS.PLAYER, {name = "value", type = OPTION_TYPE.NUMBER}},

    --- @param value number
    --- @param ctx CommandContext
    fn = function(ctx, userid, value)
        if PEARL.Reputation:SetFor(userid, value) then
            if PEARL.DB:SaveRecordFor(userid) then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.ON_SUCCESS)
            end

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.ON_FAILURE)
        end

        return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
    end,
})

AddCommand("giverep", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.DESC,
    permission = COMMAND_PERMISSION.USER,
    console = false, -- This is meant to be a user-only command.
    cantargetself = false,
    cooldown = 6 * 60 * 60, -- Cooldown for six hours.
    options = {
        PARAMS.PLAYER,
        {name = "value", optional = true, permission = COMMAND_PERMISSION.ADMIN, type = OPTION_TYPE.NUMBER, min_value = 1},
    },

    --- @param ctx CommandContext
    --- @param userid string
    --- @param value number?
    fn = function(ctx, userid, value)
        if not ctx.author.userid then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.MISSING_BINDING:format(
                PEARL.CONSTS.HELP_URLS.ACCOUNT_BINDINGS
            ))
        end

        if PEARL.Reputation:GiveTo(userid, value or GIVEREP_AMOUNT) then
            UserCommands.StartCommandCooldownFor(ctx.author.userid, ctx.command)

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
    end,
})

AddAsyncCommand("borrowed", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.NONE, -- No need for routing in this case
    options = {PARAMS.PLAYER{validate = false}},

    --- @param ctx CommandContext
    --- @param userid string
    fn = function(ctx, userid)
        local request = PEARL.KleiAccounts:QueryGameOwner(userid, PEARL.KleiAccounts.GAME.DST, function(rootid)
            if type(rootid) ~= "string" then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.ON_FAILURE)
            end

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.ON_SUCCESS:format(
                ctx.type == CommandContext.TYPE.DISCORD and MARKDOWN.codeline(rootid) or rootid
            ))
        end)

        if not request then
            -- This error will be catched an propagated to the caller of this command.
            error("Failed to encode verification json data!")
        end

        request:Send()
    end,
})

AddCommand("reload", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.RELOAD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.RELOAD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    --- This function is being automatically routed to the target shard.
    routing = UserCommands.SHARD_ROUTING.AUTO,
    options = {PARAMS.SHARD{optional = true}},
    exectime = 0,

    --- @param ctx CommandContext
    --- @param shardid string?
    fn = function(ctx, shardid)
        PEARL.ReloadShard()
    end,
})

AddCommand("count", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.ALL, -- Count on all connected shards.
    options = {PARAMS.PREFAB},

    --- @param ctx CommandContext
    --- @param prefab string
    fn = function(ctx, prefab)
        local discord = ctx.type == CommandContext.TYPE.DISCORD
        local name, count = PEARL.PrefabToName(prefab), PEARL.CountPrefabs(prefab)
        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.ON_SUCCESS:format(
            discord and MARKDOWN.codeline(tostring(count)),
            discord and MARKDOWN.bold(name) or name, PEARL.GetShardFancyName()
        ))
    end,
})

AddCommand("profile", {
    permission = UserCommands.PERMISSION.USER,
    privateresponse = true,
    -- Only admins can see profiles of other players
    options = {PARAMS.PLAYER{permission = COMMAND_PERMISSION.ADMIN, optional = true}},

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        local playerid = userid or ctx.author.userid
        if not playerid then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.MISSING_BINDING)
        end

        local record = playerid and PEARL.DB:GetRecordFor(playerid)
        if not record then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        local show_moderator_info = ctx.author.permission == COMMAND_PERMISSION.ADMIN
        return ctx:ReplyDiscordEmbed(EMBEDS.ClientProfile(playerid, record, show_moderator_info))
    end,
})

AddCommand("stats", {
    permission = COMMAND_PERMISSION.USER,
    routing = UserCommands.SHARD_ROUTING.NONE, -- Leaderboard is centralized
    privateresponse = true,
    targetselfbydefault = true,
    options = {
        PARAMS.PLAYER{optional = true, permission = UserCommands.PERMISSION.ADMIN},
    },

    --- @param ctx CommandContext
    --- @param userid string
    fn = function(ctx, userid)
        if not userid then
            ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.MISSING_BINDING)
            return
        end

        local reputation = PEARL.Reputation:GetOf(userid, PEARL.Reputation.DISPLAY_DECIMAL_PLACES)
        local daygains   = PEARL.Reputation:GetDisplayField(userid, PEARL.Reputation.FIELD.DAYGAINS)
        local monthgains = PEARL.Reputation:GetDisplayField(userid, PEARL.Reputation.FIELD.MONTHGAINS)
        local username   = PEARL.DB:GetField(userid, "username", userid)

        local m_board    = PEARL.LeaderboardService:GetLeaderboard(Leaderboard.TYPE.MONTHLY)
        local m_place    = m_board and m_board:GetPositionFor(userid) or nil

        local a_board    = PEARL.LeaderboardService:GetLeaderboard(Leaderboard.TYPE.ABSOLUTE)
        local a_place    = a_board and a_board:GetPositionFor(userid) or nil

        if ctx.type == CommandContext.TYPE.DISCORD then
            return ctx:ReplyDiscordData({
                value = reputation,
                daygains = daygains,
                monthgains = monthgains,
                username = username,
                peak = PEARL.Reputation:GetDisplayField(userid, PEARL.Reputation.FIELD.PEAK),
                lowest = PEARL.Reputation:GetDisplayField(userid, PEARL.Reputation.FIELD.LOWEST),
                starting_rep = PEARL.Reputation.STARTING_VALUE,
                bad_rep_threshold = PEARL.Reputation.BAD_REP_THRESHOLD,
                position = {
                    absolute = a_place,
                    monthly = m_place,
                    prev_month = PEARL.DB:GetField(userid, "last_monthly_position")
                }
            })
        end

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.STATS.RESULT:format(
            m_place or "???", a_place or "???", username, reputation, daygains, monthgains
        ))
    end,
})

AddCommand("leaderboard", {
    permission = COMMAND_PERMISSION.USER,
    routing = UserCommands.SHARD_ROUTING.NONE, -- Leaderboard is centralized
    options = {{name = "typ", optional = true, choices = STATIC_CHOICES.LEADERBOARD_TYPE}},

    --- @param ctx CommandContext
    --- @param typ string?
    fn = function(ctx, typ)
        local leaderboards = PEARL.LeaderboardService:GetAllLeaderboards()
        if ctx.type == CommandContext.TYPE.DISCORD and table.empty(leaderboards) == false then
            local message = Message()
            if typ ~= nil then
                local leaderboard = PEARL.LeaderboardService:GetLeaderboard(typ)
                if not leaderboard then
                    return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.LEADERBOARD.NOT_FOUND)
                end

                message:AddEmbed(leaderboard:GetEmbed())
            else
                for _, leaderboard in pairs(leaderboards) do
                    -- Max 10 leaderboard embeds
                    message:AddEmbed(leaderboard:GetEmbed())
                end
            end

            return ctx:ReplyDiscordMessage(message)
        end

        return ctx:Reply(PEARL.LeaderboardService:ToString())
    end,
})

AddCommand("give", {
    consolename = "giveto",
    permission = COMMAND_PERMISSION.ADMIN,
    instrequired = true,
    options = {PARAMS.PLAYER, PARAMS.PREFAB,
        {name = "count", type = OPTION_TYPE.INTEGER, optional = true}
    },

    --- @param ctx CommandContext
    --- @param player PlayerInst
    --- @oaram prefab string
    --- @param count number?
    fn = function(ctx, player, prefab, count)
        local item, given = player.components.inventory:GiveItemPrefabCount(prefab, count)
        if not item then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.ITEM_PREFAB_INVALID)
        end

        local isactive = PEARL.ServerNetwork:HasClientActiveInstance(player.userid)
        local postfix = isactive and "" or "\n"..STRINGS.PEARL.UI.CMD_WARN.SAVE_REQUIRED

        given = given or 1
        count = tonumber(count) or 1
        if given < count then
            if given <= 0 then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.NONE)
            end

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.SOME:format(
                given, item:GetBasicDisplayName(), player.name
            )..postfix)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.ALL:format(
            given, item:GetBasicDisplayName(), player.name
        )..postfix)
    end,
})

AddCommand("giveall", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false, -- Would be really ackward since it doesn't support multi word parameters.
    instrequired = true,
    options = {PARAMS.PLAYER, PARAMS.JSON},

    --- @param ctx CommandContext
    --- @param player PlayerInst
    --- @param items table<string, number>
    fn = function(ctx, player, items)
        local isactive = PEARL.ServerNetwork:HasClientActiveInstance(player.userid)
        local postfix = isactive and "" or "\n"..STRINGS.PEARL.UI.CMD_WARN.SAVE_REQUIRED
        local added, ignored = player.components.inventory:GiveItemPrefabs(items)
        if ignored > 0 then
            if added > 0 then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEALL.GAVE_SOME:format(
                    added, player.name, ignored
                )..postfix)
            end

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEALL.GAVE_NONE)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEALL.GAVE_ALL:format(
            added, player.name
        )..postfix)
    end,
})

AddCommand("take", {
    permission = COMMAND_PERMISSION.ADMIN,
    instrequired = true,
    options = {PARAMS.PLAYER, PARAMS.PREFAB, {name = "count", type = "integer", optional = true}},

    --- @param ctx CommandContext
    --- @param player PlayerInst
    --- @param prefab string
    --- @param count number?
    fn = function(ctx, player, prefab, count)
        -- Take all items by default.
        count = count or math.huge
        local items = player.components.inventory:GetItemByName(prefab, count, false)
        if not items or table.empty(items) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.ITEM_NOT_FOUND)
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

        local isactive = PEARL.ServerNetwork:HasClientActiveInstance(player.userid)
        local postfix = isactive and "" or "\n"..STRINGS.PEARL.UI.CMD_WARN.SAVE_REQUIRED
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.TAKE.ON_SUCCESS:format(
            total_count, item_name or "UNKNOWN", player.name
        )..postfix)
    end,
})

AddCommand("drop", {
    permission = COMMAND_PERMISSION.ADMIN,
    activeinstrequired = true,
    options = {
        PARAMS.PLAYER,
        PARAMS.PREFAB{optional = true},
        {name = "count", type = OPTION_TYPE.INTEGER, optional = true},
    },

    --- @param ctx CommandContext
    --- @param player PlayerInst
    --- @param prefab string
    --- @param count number?
    fn = function(ctx, player, prefab, count)
        -- If no item specified, drop everything.
        if not prefab then
            player.components.inventory:DropEverything()

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.ALL:format(
                player.name
            ))
        end

        -- Take all items by default.
        count = count or math.huge
        local items = player.components.inventory:GetItemByName(prefab, count, false)
        if not items or table.empty(items) ~= false then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.ITEM_NOT_FOUND)
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

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.SOME:format(
            total_amount, item_name or "UNKNOWN", player.name
        ))
    end,
})

AddCommand("deposit", {
    permission = COMMAND_PERMISSION.ADMIN,
    instrequired = true,
    options = {
        PARAMS.PLAYER,
        PARAMS.PREFAB{optional = true},
        {name = "count", type = OPTION_TYPE.INTEGER, optional = true},
    },

    --- @param ctx CommandContext
    --- @param player PlayerInst
    --- @param prefab string?
    --- @param count number?
    fn = function(ctx, player, prefab, count)
        local isactive = PEARL.ServerNetwork:HasClientActiveInstance(player.userid)
        local postfix = isactive and "" or "\n"..STRINGS.PEARL.UI.CMD_WARN.SAVE_REQUIRED

        -- If no item specified, drop everything.
        if not prefab then
            -- Use depositor to support offline inventories.
            ItemDepositor:DepositAllItems(player.components.inventory)

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DEPOSIT.ALL:format(
                player.name
            )..postfix, PEARL.ICONS.PLAYER_STATE.DROP_ITEMS)
        end

        -- Take all items by default.
        count = count or math.huge
        local items = player.components.inventory:GetItemByName(prefab, count, false)
        if not items or table.empty(items) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.ITEM_NOT_FOUND)
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
            ItemDepositor:DepositItem(player.components.inventory, item)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DEPOSIT.SOME:format(
            total_amount, item_name or "UNKNOWN", player.name
        )..postfix)
    end,
})

AddCommand("spawn", {
    consolename = "spawnat",
    permission = COMMAND_PERMISSION.ADMIN,
    instrequired = true,
    options = {PARAMS.PLAYER, PARAMS.PREFAB, {name = "count", type = "integer", optional = true}},

    --- @param ctx CommandContext
    --- @param player PlayerInst
    --- @param prefab string
    --- @param count number?
    fn = function(ctx, player, prefab, count)
        local spawned = 0
        local position = player and player:GetPosition()
        for _ = 1, math.max(count or 1, 1) do
            local entity = SpawnPrefab(prefab)
            if entity then
                if entity.Transform then
                    entity.Transform:SetPosition(position:Get())
                    spawned = spawned + 1
                else
                    entity:Remove()
                end
            end
        end

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SPAWN.ON_SUCCESS:format(
            spawned, PEARL.PrefabToName(prefab)
        ))
    end,
})

AddCommand("teleport", {
    console = false,
    permission = COMMAND_PERMISSION.ADMIN,
    activeinstrequired = true,
    options = {PARAMS.PLAYER, PARAMS.ENTITY{optional = true},
        {name = "x", type = "number", optional = true},
        {name = "y", type = "number", optional = true},
        {name = "z", type = "number", optional = true},
    },

    --- @param ctx CommandContext
    --- @param player PlayerInst
    --- @param inst EntityScript?
    --- @param x number?
    --- @param y number?
    --- @param z number?
    fn = function(ctx, player, inst, x, y, z)
        if (x or y or z) then
            if inst ~= nil then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.TELEPORT.BAD_TARGET)
            end

            if not (x and z) then
                return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.COORDINATES_MISSING)
            end
        else
            if not inst then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.TELEPORT.BAD_TARGET)
            end

            x, y, z = inst.Transform:GetWorldPosition()
        end

        y = y or 0 -- Fallback to ground Y
        player.Transform:SetPosition(x, y, z)

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.TELEPORT.ON_SUCCESS:format(x, y, z))
    end,
})


AddCommand("removeall", {
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.ALL, -- Run on all shards.
    console = false, -- Already implemented
    options = { PARAMS.PREFAB, {name = "count", type = "integer", optional = true} },

    --- @param ctx CommandContext
    --- @param prefab string
    --- @param count number?
    fn = function(ctx, prefab, count)
        local removedcount = 0
        for _, ent in pairs(Ents) do
            if ent.prefab == prefab then
                ent:Remove()
                removedcount = removedcount + 1
            end

            if count and removedcount >= count then
                break
            end
        end

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.REMOVEALL.ON_SUCCESS:format(
            removedcount, PEARL.PrefabToName(prefab), PEARL.GetShardFancyName()
        ))
    end,
})

AddCommand("kill", {
    permission = COMMAND_PERMISSION.ADMIN,
    targetselfbydefault = true,
    activeinstrequired = true,
    options = {PARAMS.PLAYER{optional = true}},

    --- @param ctx CommandContext
    --- @param player PlayerInst
    fn = function(ctx, player)
        player:PushEvent("death", {cause =(ctx.author.name or STRINGS.NAMES.SHENANIGANS)
                        .." "..STRINGS.PEARL.UI.CMD_INFO.BY_COMMAND})
    end,
})

AddCommand("revive", {
    permission = COMMAND_PERMISSION.ADMIN,
    targetselfbydefault = true,
    activeinstrequired = true,
    options = {PARAMS.PLAYER{optional = true}},

    --- @param ctx CommandContext
    --- @param player string
    fn = function(ctx, player)
        player:PushEvent("respawnfromghost", {
            user = {
                GetDisplayName = function()
                    return (ctx.author.name or STRINGS.NAMES.SHENANIGANS)
                        .." "..STRINGS.PEARL.UI.CMD_INFO.BY_COMMAND
                end
            }
        })
    end,
})

AddCommand("permissive", {
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.ALL, -- All shards need to be effected

    --- @param ctx CommandContext
    fn = function(ctx)
        PEARL.CONFIG.PERMISSIVE_MODE = not PEARL.CONFIG.PERMISSIVE_MODE
        if PEARL.CONFIG.PERMISSIVE_MODE == true then
            if TheShard:IsMaster() then -- Only announcing on the main shard is enough
                TheNet:Announce(STRINGS.PEARL.LOGS.PERMISSIVE_MODE_WARNING)
            end

            -- Save it for next game instance.
            PEARL.GameInstParams:SetModParam(PEARL.INSTANCE_PARAMS.PERMISSIVE_MODE, PEARL.CONFIG.PERMISSIVE_MODE)
        else
            ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PERMISSIVE.ON_TURN_OFF)
        end
    end
})

--- @TODO?
-- AddCommand("setsession", {
--     permission = COMMAND_PERMISSION.ADMIN,
--     options = {{name = "sessionid"}},

--     --- @param ctx CommandContext
--     fn = function(ctx, sessionid)
--         PEARL.CONFIG.PERMISSIVE_MODE = not PEARL.CONFIG.PERMISSIVE_MODE
--         if PEARL.CONFIG.PERMISSIVE_MODE == true then
--             if TheShard:IsMaster() then -- Only announcing on the main shard is enough
--                 TheNet:Announce(STRINGS.PEARL.LOGS.PERMISSIVE_MODE_WARNING)
--             end

--             -- Save it for next game instance.
--             PEARL.GameInstParams:SetModParam(PEARL.INSTANCE_PARAMS.PERMISSIVE_MODE, PEARL.CONFIG.PERMISSIVE_MODE)
--         else
--             ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PERMISSIVE.ON_TURN_OFF)
--         end
--     end
-- })

AddCommand("despawn", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = false, -- Already built in
    activeinstrequired = true,
    options = {PARAMS.PLAYER{optional = true}},
    targetselfbydefault = true,

    --- @param ctx CommandContext
    --- @param player PlayerInst
    fn = function(ctx, player)
        -- Make sure we drop the inventory before it"s too late.
        if player.components.inventory then
            player.components.inventory:DropEverything()
        end

        TheWorld:PushEvent("ms_playerdespawnanddelete", player)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.ON_SUCCESS)
    end,
})

AddCommand("skip", {
    permission = COMMAND_PERMISSION.ADMIN,

    fn = function()
        TheWorld:PushEvent("ms_nextphase") -- Implicit response
    end
})

AddCommand("announce", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = false, -- Already implemented for console.
    options = { {name = "message"} },

    --- @param ctx CommandContext
    --- @param message string
    fn = function(ctx, message)
        TheNet:Announce(message)
    end
})

AddCommand("dm", {
    permission = COMMAND_PERMISSION.USER,
    clientrequired = true,
    options = {PARAMS.PLAYER, {name = "message"}},

    --- @param ctx CommandContext
    --- @param target ClientTable
    --- @param message string
    fn = function(ctx, target, message)
        local userid = target.userid
        --- @type ChatMessage
        local chat_message = ChatMessage(message)
        chat_message:SetColour(WHISPER_COLOR)
        chat_message:SetReceiver(target.name)

        local icon
        if ctx.type == CommandContext.TYPE.DISCORD then
            icon = PEARL.CONSTS.PROFILE_FLAIRS.DISCORD
        else
            local client = ctx.author.userid and TheNet:GetClientTableForUser(ctx.author.userid)
            icon = client and GetRemotePlayerVanityItem(client.vanity or {}, "profileflair")
        end

        local player = LookupPlayerInstByUserID(ctx.author.userid)
        chat_message:SetAuthor(ctx.author.name, ctx.author.colour, ctx.author.userid, ctx.author.netid, player and player.prefab, player and player.GUID)
        chat_message:SetIcon(icon)

        -- Author can send DM to himself.
        local receivers = (
            (ctx.author.userid ~= userid and {userid, ctx.author.userid}) or
            userid
        )

        -- Display the direct message for the target user as well as the ctx.author.
        PEARL.ServerNetwork:DisplayChatMessageFor(receivers, chat_message)
    end
})

AddCommand("system", {
    permission = COMMAND_PERMISSION.ADMIN,
    options = { {name = "message"} },

    --- @param ctx CommandContext
    --- @param message string
    fn = function(ctx, message)
        TheNet:SystemMessage(message)
    end
})

AddCommand("notify", {
    permission = COMMAND_PERMISSION.ADMIN,
    --- @TODO: allow changing the title for discord slash commands.
    options = {PARAMS.PLAYER, {name = "message"}},--, {name = "title", optional = true}},

    --- @param ctx CommandContext
    --- @param userid string
    --- @param message string
    --- @param title string?
    fn = function(ctx, userid, message, title)
        PEARL.ServerNetwork:DisplayPopupFor(userid, title, message)

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTIFY.ON_SUCCESS)
    end
})

AddAsyncCommand("pair", {
    permission = COMMAND_PERMISSION.USER,
    console = false, -- Needs a valid user
    options = { {name = "id"} },

    --- @param ctx CommandContext
    --- @param id string
    fn = function(ctx, id)
        local bindtype = PEARL.AccountBindings.BINDING_TYPE.DISCORDID
        local userid = ctx.author.userid or id
        local discordid = ctx.author.discordid or id

        if not PEARL.DB:HasRecordFile(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.NOT_PLAYED)
        end

        if PEARL.AccountBindings:Exists(userid, discordid, bindtype) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.ALREADY_PAIRED)
        end

        local request = PEARL.KleiAccounts:QueryLinkValidation(
            userid, PEARL.KleiAccounts.PLATFORM.DISCORD, discordid
        )
        if not request then
            error("Failed to encode verification json data!")
        end

        request:AddOnComplete(function(data)
            if not request.ok then
                if not request:IsRetryable() then
                    ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.KLEI_SERVERS_UNREACHABLE)
                end

                return
            end

            if data.Error ~= false then
                error("Verification request failed!")
            end

            if data.Linked then
                PEARL.AccountBindings:AddBinding(userid, discordid, bindtype)
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.ON_SUCCESS, PEARL.ICONS.SYNC)
            end

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.NOT_PAIR_OFFICIALLY)
        end)
        request:Send()
    end,
})

AddCommand("unpair", {
    permission = COMMAND_PERMISSION.USER,
    console = false, -- Needs a valid user

    --- @param ctx CommandContext
    fn = function(ctx)
        local bindtype = PEARL.AccountBindings.BINDING_TYPE.DISCORDID
        local userid = ctx.author.userid
        local discordid = ctx.author.discordid
        if userid and not discordid then
            discordid = PEARL.AccountBindings:MapUserIDToBindValue(userid, bindtype)
        elseif discordid and not userid then
            userid = PEARL.AccountBindings:MapDiscordID(discordid)
        end

        if not userid or not discordid or not PEARL.AccountBindings:Exists(userid, discordid, bindtype) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.NOT_PAIRED)
        end

        PEARL.AccountBindings:RemoveBinding(userid, discordid, bindtype)
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.ON_SUCCESS, PEARL.ICONS.UNSYNC)
    end,
})

AddCommand("blockmod", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    options = {
        {name = "id"},
    },

    --- @param ctx CommandContext
    --- @param modid string
    fn = function(ctx, modid)
        PEARL.CONFIG.MOD_BLOCKLIST = PEARL.CONFIG.MOD_BLOCKLIST or {}
        if table.contains(PEARL.CONFIG.MOD_BLOCKLIST, modid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.MOD_ALREADY_BLOCKED)
        end

        table.insert(PEARL.CONFIG.MOD_BLOCKLIST, modid)
        if PEARL.CONFIG.MOD_ALLOWLIST and table.removearrayvalue(PEARL.CONFIG.MOD_ALLOWLIST, modid) then
            PEARL.ClusterPersistence:SetFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, PEARL.CONFIG.MOD_ALLOWLIST)
        end

        PEARL.ClusterPersistence:SetFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, PEARL.CONFIG.MOD_BLOCKLIST)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.ON_SUCCESS)
    end
})

AddCommand("note", {
    permission = COMMAND_PERMISSION.ADMIN,
    private = true,
    privateresponse = true,
    options = {
        PARAMS.PLAYER,
        {name = "note", optional = true},
    },

    --- @param ctx CommandContext
    --- @param userid string
    --- @param note string?
    fn = function(ctx, userid, note)
        if PEARL.DB:GetField(userid, "modnote") == note then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTE.NO_CHANGES)
        end

        if PEARL.DB:SetField(userid, "modnote", note) then
            if note ~= nil then
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTE.ON_ADDED)
            else
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTE.ON_REMOVED)
            end
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTE.ON_FAILURE)
    end
})

------------------------------------
-- These should be safe.
-- They are here for debugging and special case handling purposes.

AddCommand("exec", {
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.NONE, -- We do the routing ourselves
    console = false,
    slash = false, -- Admins can use the console right away from the game.
    options = {{name = "command"}, PARAMS.SHARD{optional = true}},

    --- @param ctx CommandContext
    --- @param command string
    --- @param shardid? string
    fn = function(ctx, command, shardid)
        local fn, errmsg = loadstring(command)
        if type(fn) == "function" then
            return PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, shardid, command)
        end

        if errmsg then
            return ctx:Reply(MARKDOWN.codeblock(errmsg, "lua"))
        end

        ctx:ReplyError(STRINGS.PEARL.UI.BUILTINCOMMANDS.EXEC.ON_INVALID_COMMAND)
    end
})

AddCommand("setdbfield", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    options = {
        PARAMS.PLAYER,
        {name = "field"},
        {name = "value", optional = true} -- So we can "nil" the field
    },

    --- @param ctx CommandContext
    --- @param userid string
    --- @param field string
    --- @param value any
    fn = function(ctx, userid, field, value)
        if not PEARL.DB:IsEnabled() then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.DB_DISABLED)
        end

        if not PEARL.DB:HasRecordFile(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        local old = PEARL.DB:GetField(userid, field)
        local old_type, _ = type(old), nil
        if value ~= nil and old ~= nil and old_type ~= type(value) then
            _, value = PEARL.TryConvertToType(value, old_type)
        end

        if value == old then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_INFO.NO_CHANGES)
        end

        if PEARL.DB:SetField(
            userid, field, value
        ) and PEARL.DB:SaveRecordFor(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SETDBFIELD.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SETDBFIELD.ON_FAILURE)
    end
})

AddCommand("setrarity", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    options = {
        PARAMS.PREFAB,
        {name = "value", type = OPTION_TYPE.NUMBER}
    },

    --- @param ctx CommandContext
    --- @param prefab string
    --- @param value number
    fn = function(ctx, prefab, value)
        if not PEARL.CONFIG.INVENTORY_REPORTER.ENABLED then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_RARITY.ON_DISABLED)
        end

        PEARL.EventProcessor:HandleEvent("set_item_rarity", prefab, value)
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_RARITY.ON_SUCCESS)
    end
})

AddCommand("setslots", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.ALL, -- Sync between all shards.
    options = {
        {name = "count", type = OPTION_TYPE.NUMBER, min_value = 1}
    },

    --- @param ctx CommandContext
    --- @param count number
    fn = function(ctx, count)
        if count < PEARL.ServerNetwork:GetConnectedClientsCount() then
            return ctx:ReplyError(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_COUNT_TOO_LOW)
        end

        if count == TheNet:GetDefaultMaxPlayers() then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.NO_CHANGES)
        end

        -- This prints some weird error at first use. But the count is actually set.
        TheNet:SetDefaultMaxPlayers(tostring(count))

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_SUCCESS)
    end
})

AddCommand("show", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    options = {PARAMS.PLAYER},

    --- @param ctx CommandContext
    --- @param userid string
    fn = function(ctx, userid)
        local record = PEARL.DB:GetRecordFor(userid)
        if not record then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        local str = DataDumper(record:GetData(), nil, false, 2)
        str = str:gsub("return ", ""):gsub("    ", ""):gsub("\t", "")
        if ctx.type == CommandContext.TYPE.DISCORD then
            str = MARKDOWN.codeblock(str, "lua")
        end

        return ctx:Reply(str)
    end
})

AddCommand("ls", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    discord = false,

    --- @param ctx CommandContext
    fn = function(ctx)
        -- Everyone has a binding with steam!
        local ids = PEARL.DB:GetBindings(PEARL.AccountBindings.BINDING_TYPE.STEAMID)
        table.dump(ids)
    end
})

AddAsyncCommand("sync", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash      = false,

    --- @param ctx CommandContext
    fn = function(ctx)
        PEARL.DiscordProxy:SyncCommands()
            :AddOnSuccess(function()
                ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SYNC.ON_SUCCESS)
            end)
            :AddOnError(function()
                ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SYNC.ON_FAILURE)
            end)
    end
})

-------------------------------------------
-- Command Post Inits
-------------------------------------------

UserCommands.CustomizeCommand("stopvote", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE
    command.remote  = true -- Redirect these to master.

    local localfn  = command.localfn
    command.localfn = nil
    command.fn = function(ctx)
        localfn(ctx.params, ctx.author) -- Run the original handler
        -- Implicit response via logger.
    end
end)

UserCommands.CustomizeCommand("rescue", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE
    command.params = command.params or {}
    command.paramsoptional = command.paramsoptional or {}
    command.activeinstrequired = true
    command.targetselfbydefault = true

    table.insert(command.params, PARAMS.PLAYER.name)
    table.insert(command.paramsoptional, true)

    local serverfn  = command.serverfn
    command.fn = function(ctx, player)
        serverfn(ctx.params, player) -- Run the original handler

        if player:HasTag("playerghost") and player.userid == ctx.author.userid then
            -- People often confuse this command as a revive command.
            if GetPortalRez() then
                ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.RESCUE.ON_DEATH)
            else
                ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.RESCUE.NO_REVIVE)
            end
        end
    end
end)

UserCommands.CustomizeCommand("rollback", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE

    command.params = command.params or {"numsaves"}
    command.paramsoptional = command.paramsoptional or {true}

    -- table.insert(command.params, "days")
    -- table.insert(command.paramsoptional, true)

    table.insert(command.params, "after")
    table.insert(command.paramsoptional, true)

    command.serverfn = nil -- Ensure that we are using our custom handler
    command.fn = function(ctx, numsaves, after)
        after = after or DEFAULT_ROLLBACK_DELAY

        --- @TODO:
        -- local days = ctx.params.days ~= nil and tonumber(ctx.params.days)
        -- if days and days >= 0 then
        --     return PEARL.RollbackByDays(days, nil, after)
        -- end

        local snapshots = numsaves or 1
        TheNet:Announce(STRINGS.PEARL.LOGS.ROLLBACK_AFTER:format(snapshots, after))
        ctx:ExecuteAfter(after, function()
            -- Starting from zero
            TheNet:SendWorldRollbackRequestToServer(snapshots - 1)
        end)
    end
end,
function(command)
    local numsaves = table.find(command.options, function(_, option)
        return option.name == "numsaves"
    end)

    if numsaves then
        numsaves.type = OPTION_TYPE.INTEGER
        numsaves.min_value = 0
    end

    local after = table.find(command.options, function(_, option)
        return option.name == "after"
    end)

    if after then
        after.min_value = MIN_ROLLBACK_DELAY
        after.max_value = MAX_ROLLBACK_DELAY
        after.type      = OPTION_TYPE.INTEGER
    end
end)

UserCommands.CustomizeCommand("regenerate", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE
    command.params = command.params or {}
    command.paramsoptional = command.paramsoptional or {}
    command.paramtypes = {["seed"] = "number"}
    command.aliases = command.aliases or {}

    table.insert(command.params, PARAMS.SHARD.name)
    table.insert(command.paramsoptional, true)

    table.insert(command.params, "seed")
    table.insert(command.paramsoptional, true)

    table.insert(command.aliases, "regen")

    command.exectime = 0
    command.serverfn = nil -- Ensure that we are using our custom handler
    command.fn = function(ctx, shardid, seed)
        if seed then
            local wf = io.open(SEED_PATH, "w")
            if wf then
                wf:write(seed)
                wf:close()
            end
        end

        if shardid == nil then
            return c_regenerateworld()
        end

        if shardid == PEARL.SHARDID then
            return PEARL.RegenerateShard()
        end

        PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, shardid, "PEARL.RegenerateShard()")
    end
end)

UserCommands.CustomizeCommand("kick", function(command)
    -- Migrate all the logic to the server.
    command.remote = true
    command.localfn = nil
    command.routing = UserCommands.SHARD_ROUTING.NONE
    command.params = command.params or {PARAMS.USER.name, "seconds"}
    command.paramsoptional = command.paramsoptional or {false, true}

    table.insert(command.params, "reason")
    table.insert(command.paramsoptional, true)

    command.fn = function(ctx, userid, seconds, reason)
        -- In case we have passed only the reason parameter.
        if type(seconds) == "string" and reason == nil and seconds == nil then
            reason = seconds
        end

        TheNet:Kick(userid, reason, seconds, ctx.author.userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.KICK.ON_SUCCESS)
    end
end)

UserCommands.CustomizeCommand("ban", function(command)
    -- Supporting the old API
    command.params = command.params or {PARAMS.USER.name, "seconds"}
    command.paramsoptional = command.paramsoptional or {false, true}

    -- Migrate all the logic to the server.
    command.remote = true
    command.localfn = nil
    command.routing = UserCommands.SHARD_ROUTING.NONE
    command.paramsnovalidate = {true} -- We can ban any userids!

    table.insert(command.params, "reason")
    table.insert(command.paramsoptional, true)

    command.fn = function(ctx, userid, seconds, reason)
        if PEARL.BlackList:Contains(userid) and not PEARL.ServerNetwork:IsClientConnectedAny(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ALREADY_BANNED)
        end

        -- In case we have passed only the reason parameter.
        if type(seconds) == "string" and reason == nil then
            reason = seconds
        end

        TheNet:BanForTime(userid, seconds, reason, ctx.author.userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ON_SUCCESS)
    end
end)
