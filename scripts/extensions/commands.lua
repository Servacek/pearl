--[[====================================================[==[
    The "Pearl" - modification software for
    the game "Don"t Starve Together" by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the "Pearl" software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd & BackEnd

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

local MESSAGES = PEARL.loadfile("utils/messages")
local EMBEDS = PEARL.loadfile("utils/embeds")

local MARKDOWN = PEARL.loadfile("libraries/markdown")

-------------------------------------
-- Localization
-------------------------------------

local TheNet = TheNet
local AddCommand = UserCommands.AddCustomCommand

-------------------------------------
-- Constants
-------------------------------------

local DAYSBACK_DELAY = 3
local ROLLBACK_DELAY = 3

local GIVEREP_AMOUNT = 25

local SEED_PATH = MODROOT.."data/seed.txt"

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

    return count --- @TODO: Add the count to the announcement
end

AddCommand("fire", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {true},
    routingfallback = UserCommands.SHARD_ROUTINGFALLBACK.ALL,

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        local pt_postfix = ctx.author.userid and "_DOER" or ""

        if userid then
            local player = LookupPlayerInstByUserID(userid)
            if player ~= nil then
                extinguish_near(player:GetPosition(), PEARL.CONSTS.EXTINGUISH_RADIUS)

                -- Keep it global
                TheNet:Announce(STRINGS.PEARL.LOGS["EXTINGUISH_NEAR"..pt_postfix]:format(
                    ctx.author.name or player.name, player.name
                ), player.entity)

                return
            end

            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        extinguish_near({x = 0, y = 0, z = 0}, WORLD_TILES_OCEAN_SIZE)

        PEARL.ServerNetwork:AnnounceFor(PEARL.ServerNetwork:GetConnectedClientIDs(),
         STRINGS.PEARL.LOGS["EXTINGUISH"..pt_postfix]:format(
            ctx.author.name or "Shenanigans"
        ), nil, ctx.author.colour)
    end,
})

local function repair_near(pos, radius)
    local burned_entities = TheSim:FindEntities(
        pos.x, pos.y, pos.z, radius, {"burnt","structure"}, {"INLIMBO"}
    )

    local count = 0
    for _, ent in ipairs(burned_entities) do
        if ent.components.workable and ent.components.workable:HasBuilder() then
            -- Inherit the builder for player-made structures.
            local builder = ent.components.workable and ent.components.workable:GetBuilder()
            local inst = ReplacePrefab(ent, ent.prefab, ent.skinname, ent.skin_id)
            if inst then
                count = count + 1

                if inst.components.workable then
                    inst.components.workable:SetBuilder(builder)
                end
            end
        end
    end

    return count
end

AddCommand("repair", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.REPAIR.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.REPAIR.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {true},
    routingfallback = UserCommands.SHARD_ROUTINGFALLBACK.ALL,

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        local pt_postfix = ctx.author.userid and "_DOER" or ""

        if userid then
            local player = LookupPlayerInstByUserID(userid)
            if player ~= nil then
                repair_near(player:GetPosition(), PEARL.CONSTS.REPAIR_RADIUS)

                -- Keep it global.
                TheNet:Announce(STRINGS.PEARL.LOGS["REPAIR_NEAR"..pt_postfix]:format(
                    ctx.author.name or "Shenanigans", (player.name or STRINGS.PEARL.LOGS.UNKNOWN)
                ), player.entity)

                return
            end

            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        repair_near({x = 0, y = 0, z = 0}, WORLD_TILES_OCEAN_SIZE)

        PEARL.ServerNetwork:AnnounceFor(PEARL.ServerNetwork:GetConnectedClientIDs(),
         STRINGS.PEARL.LOGS["REPAIR_ALL"..pt_postfix]:format(
            ctx.author.name or "Shenanigans"
        ), nil, ctx.author.colour)
    end,
})

AddCommand("unban", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {false},
    paramsraw = {true},
    routing = UserCommands.SHARD_ROUTING.NONE, --- @TODO: Maybe to ALL?

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        if PEARL.BlackList:Remove(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_NOTFOUND)
    end,
})

AddCommand("grant", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {false},
    paramsraw = {true},
    routing = UserCommands.SHARD_ROUTING.NONE,

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        if PEARL.BlackList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_BANNED)
        end

        if PEARL.WhiteList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_ALREADY_WHITELISTED)
        end

        PEARL.WhiteList:Add(userid)
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_SUCCESS:format(userid))
    end,
})

AddCommand("revoke", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {false},
    paramsraw = {true},
    routing = UserCommands.SHARD_ROUTING.NONE,

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        if not PEARL.WhiteList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_NOTFOUND)
        end

        PEARL.WhiteList:Remove(userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_SUCCESS:format(userid))
    end,
})

AddCommand("inv", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {false},

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        local reference = PEARL.GetPlayerMetadataFor(userid)
        if table.empty(reference:GetInventory()) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_NOTFOUND)
        end

        local request = ctx:ReplyDiscordMessage(MESSAGES.InvReport(userid, reference))
        if request then
            request:SetOnComplete(function(response, success)
                if success then
                    return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_SUCCESS)
                end

                ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.ON_FAILURE)
            end)
        end
    end,
})

AddCommand("invf", {
    aliases = {"inv-find"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"prefab"},
    paramsoptional = {false},
    routing = UserCommands.SHARD_ROUTING.ALL,

    --- @param ctx CommandContext
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
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_FAILURE)
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
            prefab, #item_owners
        ))
        for i = math.min(#item_owners, 5), 1, -1 do
            local player_reference = PEARL.GetPlayerMetadataFor(item_owners[i].player.userid)
            local embed = EMBEDS.Inventory(player_reference, {prefab})
            if not message:AddEmbed(embed) then
                break -- The message is full and doesn"t accept any more embeds
            end
        end

        ctx:ReplyDiscordMessage(message)

        if ctx.type ~= CommandContext.TYPE.DISCORD then
            ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_SUCCESS:format(
                #item_owners
            ))
        end
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
--     paramsoptional = { false },

--     --- @param ctx CommandContext
    -- fn = function(ctx)
--         if not (ctx.params and ctx.author and ctx.params.days) then
--             return
--         end

--         PEARL.RollbackByDays(tonumber(ctx.params.days), function(success, result)
--             if success then
--                 return TheNet:Announce(result)
--             end

--             PEARL.ServerNetwork:SendCommandResponse(ctx.author.userid, result)
--         end, DAYSBACK_DELAY)
--     end,
-- })

-- Slash commands only
AddCommand("admins", {
    aliases = {"staff", "sos"},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SOS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SOS.DESC,
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

    -- Handle"s the cooldown locally
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
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER}, -- Do not use UserCommands.STD_PARAMS.USER for offline support
    paramsoptional = {false},

    --- @param ctx CommandContext
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
    permission = COMMAND_PERMISSION.USER,
    console = false,
    slash = false,

    --- @param ctx CommandContext
    fn = function(ctx)
        ctx:ReplyDiscordEmbed(EMBEDS.ServerInfo())
    end
})

AddCommand("players", {
    permission = COMMAND_PERMISSION.USER,
    console = false,
    slash = false,

    --- @param ctx CommandContext
    fn = function(ctx)
        ctx:ReplyDiscordEmbed(EMBEDS.PlayerInfo())
    end,
})

AddCommand("world", {
    permission = COMMAND_PERMISSION.USER,
    console = false,
    slash = false,
    params = {UserCommands.STD_PARAMS.SHARD},
    paramsoptional = {true}, -- Display master info as default.
    routing = UserCommands.SHARD_ROUTING.AUTO, -- Let the API do the routing for us.

    --- @param ctx CommandContext
    fn = function(ctx)
        ctx:ReplyDiscordEmbed(EMBEDS.WorldInfo())
    end,
})

AddCommand("save", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SAVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SAVE.DESC,
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

    fn = function()
        PEARL.Reboot()
    end
})

AddCommand("shutdown", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false, -- already implemented by the game

    fn = function()
        -- Make sure the world is being saved before shutdown!
        c_shutdown(true)
    end
})

AddCommand("setrep", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SETREP.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER, "value"},
    paramsoptional = {false, false},
    paramtypes = {["value"] = "number"},

    --- @param value number
    --- @param ctx CommandContext
    fn = function(ctx, userid, value)
        if PEARL.Reputation:SetTo(userid, value) then
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
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {false},
    console = false, -- This is meant to be a user-only command.
    cantargetself = false,

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        if ctx.author.userid == userid then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.ON_SELF)
        end

        if PEARL.Reputation:GiveTo(userid, GIVEREP_AMOUNT) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
    end,
})

AddCommand("borrowed", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.NONE, -- No need for routing in this case
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {false},
    paramsraw = {true},

    --- @param ctx CommandContext
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
    params = {UserCommands.STD_PARAMS.SHARD},
    paramsoptional = {true},

    --- @param ctx CommandContext
    fn = function(ctx)
        PEARL.ReloadShard()
    end,
})

AddCommand("count", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"prefab"},
    paramsoptional = {false},
    routing = UserCommands.SHARD_ROUTING.ALL, -- Count on all connected shards.

    --- @param ctx CommandContext
    fn = function(ctx, prefab)
        local count = PEARL.CountPrefabs(prefab)
        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.ON_SUCCESS:format(
            count, PEARL.PrefabToName(prefab), PEARL.GetShardFancyName()
        ))
    end,
})

AddCommand("boost", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    console = false,

    --- @param ctx CommandContext
    fn = function(ctx)
        local task = PEARL.WallScheduler:GetTask(PEARL.CONSTS.TASK_ID.INPUTPROXY_FETCH)
        if not task then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BOOST.ON_FAILURE)
        end

        local _time = task:gettime()
        task:settime(PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL_FAST)
        task:restart()

        PEARL.WallScheduler:ExecuteInTime(PEARL.CONFIG.DISCORD.PROXY.BOOST_DELAY, function()
            task:settime(_time or PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL)
            task:restart()

            PEARL.DiscordLogger:LogString(STRINGS.PEARL.UI.BUILTINCOMMANDS.BOOST.ON_TIMEOUT)
        end)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BOOST.ON_SUCCESS)
    end,
})

AddCommand("profile", {
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {true},
    slash = false,  -- Doesn"t make much sense

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        local commandpermission = UserCommands.GetPermissionLevel(ctx.command.permission)
        local authorpermission = UserCommands.GetPermissionLevel(ctx.author.permission)
        if ctx.params.player ~= nil and ctx.params.player ~= ctx.author.userid and authorpermission < commandpermission then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PROFILE.MISSING_PERMISSION)
        end

        local playerid = userid or ctx.author.userid
        local record = playerid and PEARL.DB:GetRecordFor(playerid)
        if not record then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        return ctx:ReplyDiscordEmbed(EMBEDS.ClientProfile(playerid, record))
    end,
})

--- @TODO: Maybe make these for offline players by simulating the inventory?
AddCommand("give", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = false, -- Already implemented for console by the game.
    params = {UserCommands.STD_PARAMS.PLAYER, "prefab", "count"},
    paramsoptional = {false, false, true},
    paramtypes = {["count"] = "number"},

    --- @param count number
    --- @param ctx CommandContext
    fn = function(ctx, userid, prefab, count)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        local item
        local count_left = math.max(count or 1, 1)
        count = count_left
        while count_left > 0 do
            if not PEARL.PrefabExists(prefab) then
                return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.ITEM_PREFAB_INVALID)
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

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVE.ON_SUCCESS:format(
            count, item:GetBasicDisplayName(), player.name
        ))
    end,
})

AddCommand("take", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.TAKE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.TAKE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER, "prefab", "count"},
    paramsoptional = {false, false, true},
    paramtypes = {["count"] = "number"},

    --- @param count number
    --- @param ctx CommandContext
    fn = function(ctx, userid, prefab, count)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

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

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.TAKE.ON_SUCCESS:format(
            total_count, item_name or "UNKNOWN", player.name
        ))
    end,
})

AddCommand("drop", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER, "prefab", "count"},
    paramsoptional = {false, true, true},
    paramtypes = {["count"] = "number"},

    --- @param count number
    --- @param ctx CommandContext
    fn = function(ctx, userid, prefab, count)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        -- If no item specified, drop everything.
        if not prefab then
            player.components.inventory:DropEverything()

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.DROP_ALL:format(
                player.name
            ))
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
            player.components.inventory:DropItem(item, true)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.DROP:format(
            total_amount, item_name or "UNKNOWN", player.name
        ))
    end,
})

AddCommand("spawn", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SPAWN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SPAWN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER, "prefab", "count"},
    paramsoptional = {false, false, true},
    paramtypes = {["count"] = "number"},
    console = false, -- Already implemented

    --- @param count number
    --- @param ctx CommandContext
    fn = function(ctx, userid, prefab, count)
        local player = userid and LookupPlayerInstByUserID(userid)
        local position = player and player:GetPosition()
        if not player or not position then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        local spawned = 0
        for _ = 1, math.max(count or 1, 1) do
            local entity = SpawnPrefab(prefab)
            if entity and entity.Transform then
                entity.Transform:SetPosition(position:Get())

                spawned = spawned + 1
            end
        end

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SPAWN.ON_SUCCESS:format(
            spawned, PEARL.PrefabToName(prefab)
        ))
    end,
})

AddCommand("removeall", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.REMOVEALL.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.REMOVEALL.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"prefab", "count"},
    paramsoptional = {false, true},
    routing = UserCommands.SHARD_ROUTING.ALL, -- Run on all shards.
    paramtypes = {["count"] = "number"},
    console = false, -- Already implemented

    --- @param ctx CommandContext
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
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.KILL.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.KILL.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {true},

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        userid = userid or ctx.author.userid or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.health then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        player:PushEvent("death", {cause = ctx.author.name})
    end,
})

AddCommand("revive", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.REVIVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.REVIVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {true},

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        userid = userid or ctx.author.userid or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        player:PushEvent("respawnfromghost", {})
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

--     --- @TODO:
--     --- @param ctx CommandContext
--    fn = function(ctx)
--      -- Looks like you cannot pause an empty server.
--     -- TheNet:IsServerPaused()
--         SetServerPaused() -- Implicit Response!
--     end
-- })

AddCommand("permissive", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    routing = UserCommands.SHARD_ROUTING.ALL, -- All shards need to be effected

    --- @param ctx CommandContext
    fn = function(ctx)
        PEARL.CONFIG.PERMISSIVE_MODE = not PEARL.CONFIG.PERMISSIVE_MODE
        if PEARL.CONFIG.PERMISSIVE_MODE == true then
            -- implicit reply via public announcement
            TheNet:Announce(STRINGS.PEARL.LOGS.PERMISSIVE_MODE_WARNING)

            -- Save it for next game instance.
            PEARL.GameInstParams:SetModParam(PEARL.INSTANCE_PARAMS.PERMISSIVE_MODE, PEARL.CONFIG.PERMISSIVE_MODE)
        else
            ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PERMISSIVE.ON_TURN_OFF)
        end
    end
})

AddCommand("despawn", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = false, -- Already built in
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {true},

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        userid = userid or ctx.author.userid or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        -- Make sure we drop the inventory before it"s too late.
        if player.components.inventory then
            player.components.inventory:DropEverything()
        end

        TheWorld:PushEvent("ms_playerdespawnanddelete", player)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.ON_SUCCESS)
    end,
})

--- @TODO: Add discord support
-- This is here mainly for debugging purposes
AddCommand("skip", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SKIP.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SKIP.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    usermenu = false,
    servermenu = false,

    fn = function()
        -- Implicit response
        TheWorld:PushEvent("ms_nextphase")
    end
})

AddCommand("announce", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ANNOUNCE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ANNOUNCE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = false, -- Already implemented for console.
    params = {"message"},
    paramsoptional = {false},

    --- @param ctx CommandContext
    fn = function(ctx, message)
        TheNet:Announce(message)
    end
})

AddCommand("dm", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.DM.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.DM.DESC,
    permission = COMMAND_PERMISSION.USER,
    params = {UserCommands.STD_PARAMS.PLAYER, "message"},
    paramsoptional = {false, false},

    --- @param ctx CommandContext
    fn = function(ctx, userid, message)
        local target = UserCommands.InputToClientTable(userid)
        if not target or not target.name then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

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
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SYSTEM.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SYSTEM.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"message"},
    paramsoptional = {false},

    --- @param ctx CommandContext
    fn = function(ctx, message)
        TheNet:SystemMessage()
    end
})

AddCommand("notify", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTIFY.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTIFY.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER, "message", "title"},
    paramsoptional = {false, false, true},

    --- @param ctx CommandContext
    fn = function(ctx, userid, message, title)
        PEARL.ServerNetwork:DisplayPopupFor(userid, title, message)

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTIFY.ON_SUCCESS)
    end
})

AddCommand("gameowner", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {UserCommands.STD_PARAMS.PLAYER},
    paramsoptional = {false},
    routing = UserCommands.SHARD_ROUTING.NONE, -- No need for routing here

    --- @param ctx CommandContext
    fn = function(ctx, userid)
        local request = PEARL.KleiAccounts:QueryGameOwner(
            userid, PEARL.KleiAccounts.GAME.DST, function(rootid)
                local result = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.ON_FAILURE
                if type(rootid) == "string" and #rootid > 2 then
                    result = STRINGS.PEARL.UI.BUILTINCOMMANDS.BORROWED.ON_SUCCESS:format(rootid)
                end

                return ctx:Reply(result)
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
    console = false, -- Needs a valid user
    params = {"id"},
    paramsoptional = {false},

    --- @param ctx CommandContext
    fn = function(ctx, id)
        local bindtype = PEARL.DB.BINDING_TYPE.DISCORD
        local userid = ctx.author.userid or id
        local discordid = ctx.author.discordid or id

        if not PEARL.DB:HasRecordFile(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.NOT_PLAYED)
        end

        if PEARL.DB:BindingExists(userid, discordid, bindtype) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.ALREADY_PAIRED)
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
                    ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.KLEI_SERVERS_UNREACHABLE)
                end

                return
            end

            if data.Error ~= false then
                error("Verification request failed!")
            end

            if data.Linked then
                PEARL.DB:AddBinding(userid, discordid, bindtype)
                return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.ON_SUCCESS, PEARL.ICONS.SYNC)
            end

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PAIR.NOT_PAIR_OFFICIALLY)
        end)
        request:Send()
    end,
})

AddCommand("unpair", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.DESC,
    permission = COMMAND_PERMISSION.USER,
    console = false, -- Needs a valid user

    --- @param ctx CommandContext
    fn = function(ctx)
        local bindtype = PEARL.DB.BINDING_TYPE.DISCORD
        local userid = ctx.author.userid
        local discordid = ctx.author.discordid
        if userid and not discordid then
            discordid = PEARL.DB:MapUserIDToType(userid, bindtype)
        elseif discordid and not userid then
            userid = PEARL.DB:MapDiscordID(discordid)
        end

        if not userid or not discordid or not PEARL.DB:BindingExists(userid, discordid, bindtype) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.NOT_PAIRED)
        end

        PEARL.DB:RemoveBinding(userid, discordid, bindtype)
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNPAIR.ON_SUCCESS, PEARL.ICONS.UNSYNC)
    end,
})

AddCommand("blockmod", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"id"},
    paramsoptional = {false},

    --- @param ctx CommandContext
    fn = function(ctx, modid)
        PEARL.CONFIG.MOD_BLOCKLIST = PEARL.CONFIG.MOD_BLOCKLIST or {}
        if table.contains(PEARL.CONFIG.MOD_BLOCKLIST, modid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.MOD_ALREADY_BLOCKED)
        end

        table.insert(PEARL.CONFIG.MOD_BLOCKLIST, modid)
        if PEARL.CONFIG.MOD_ALLOWLIST and table.removearrayvalue(PEARL.CONFIG.MOD_ALLOWLIST, modid) then
            PEARL.ClusterPersistance:SetFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, PEARL.CONFIG.MOD_ALLOWLIST)
        end

        PEARL.ClusterPersistance:SetFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, PEARL.CONFIG.MOD_BLOCKLIST)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BLOCK_MOD.ON_SUCCESS)
    end
})

------------------------------------
-- These should be safe.
-- They are here for debugging and special case handling purposes.

AddCommand("exec", {
    permission = COMMAND_PERMISSION.ADMIN,
    console = false,
    slash = false, -- Admins can use the console right away from the game.
    params = {"command", UserCommands.STD_PARAMS.SHARD},
    paramsoptional = {false, true},
    routing = UserCommands.SHARD_ROUTING.NONE,

    fn = function(ctx, command, shardid)
        PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, shardid, command)
    end
})

AddCommand("setdbfield", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    params = {UserCommands.STD_PARAMS.PLAYER, "field", "value"},
    paramsoptional = {false, false, false},
    paramtypes = {["field"] = "string"},

    --- @param ctx CommandContext
    fn = function(ctx, userid, field, value)
        if not PEARL.DB:IsEnabled() then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.DB_DISABLED)
        end

        if PEARL.DB:HasRecordFile(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        if PEARL.DB:SetField(
            userid, field, value
        ) and PEARL.DB:SaveRecordFor(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_DB_FIELD.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_DB_FIELD.ON_FAILURE)
    end
})

AddCommand("setrarity", {
    permission = COMMAND_PERMISSION.ADMIN,
    slash = false,
    params = {"prefab", "value"},
    paramsoptional = {false, false},
    paramtypes = {["value"] = "number"},

    --- @param ctx CommandContext
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
    params = {"count"},
    paramsoptional = {false},
    paramtypes = {["count"] = "number"},

    --- @param ctx CommandContext
    fn = function(ctx, count)
        if count < PEARL.ServerNetwork:GetConnectedClientsCount() then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_COUNT_TOO_LOW)
        end

        -- This prints some weird error at first use. But the count is actually set.
        TheNet:SetDefaultMaxPlayers(tostring(count))

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_SUCCESS)
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

    table.insert(command.params, UserCommands.STD_PARAMS.PLAYER)
    table.insert(command.paramsoptional, true)

    local serverfn  = command.serverfn
    command.fn = function(ctx, userid)
        local target = ctx.author
        if userid ~= nil then
            target = LookupPlayerInstByUserID(userid)
            if not target then
                return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
            end
        end

        serverfn(ctx.params, target) -- Run the original handler

        if target and target:HasTag("playerghost") and target == ctx.author then
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
        after = after or ROLLBACK_DELAY

        --- @TODO:
        -- local days = ctx.params.days ~= nil and tonumber(ctx.params.days)
        -- if days and days >= 0 then
        --     return PEARL.RollbackByDays(days, nil, after)
        -- end

        local snapshots = numsaves or 1
        TheNet:Announce(STRINGS.PEARL.LOGS.ROLLBACK_AFTER:format(snapshots, after))
        PEARL.WallScheduler:ExecuteInTime(after, function()
            -- Starting from zero
            TheNet:SendWorldRollbackRequestToServer(snapshots - 1)
        end)
    end
end)

UserCommands.CustomizeCommand("regenerate", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE
    command.params = command.params or {}
    command.paramsoptional = command.paramsoptional or {}
    command.paramtypes = {["seed"] = "number"}
    command.aliases = command.aliases or {}

    table.insert(command.params, UserCommands.STD_PARAMS.SHARD)
    table.insert(command.paramsoptional, true)

    table.insert(command.params, "seed")
    table.insert(command.paramsoptional, true)

    table.insert(command.aliases, "regen")

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
    command.params = command.params or {UserCommands.STD_PARAMS.USER, "seconds"}
    command.paramsoptional = command.paramsoptional or {false, true}

    table.insert(command.params, "reason")
    table.insert(command.paramsoptional, true)

    command.fn = function(ctx, userid, seconds, reason)
        -- In case we have passed only the reason parameter.
        if type(seconds) == "string" and reason == nil and seconds == nil then
            reason = seconds
        end

        PEARL.ServerNetwork:KickUser(userid, reason, seconds, ctx.author.userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.KICK.ON_SUCCESS)
    end
end)

UserCommands.CustomizeCommand("ban", function(command)
    -- Supporting the old API
    command.params = command.params or {UserCommands.STD_PARAMS.USER, "seconds"}
    command.paramsoptional = command.paramsoptional or {false, true}

    -- Migrate all the logic to the server.
    command.remote = true
    command.localfn = nil
    command.routing = UserCommands.SHARD_ROUTING.NONE
    command.paramsraw = {true} -- We can ban any userids!

    table.insert(command.params, "reason")
    table.insert(command.paramsoptional, true)

    command.fn = function(ctx, userid, seconds, reason)
        if PEARL.BlackList:Contains(userid) and not PEARL.ServerNetwork:IsClientConnected(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ALREADY_BANNED)
        end

        -- In case we have passed only the reason parameter.
        if type(seconds) == "string" and reason == nil and seconds == nil then
            reason = seconds
        end

        PEARL.ServerNetwork:BanUser(userid, seconds, reason, ctx.author.userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ON_SUCCESS)
    end
end)

-- 1511 before standardization changes.
