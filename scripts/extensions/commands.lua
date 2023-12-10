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

local Colour = PEARL.loadfile("libraries/colour")

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
    routingfallback = UserCommands.SHARD_ROUTINGFALLBACK.ALL,

    --- @param ctx CommandContext
    fn = function(ctx)
        local pt_postfix = ctx.author.userid and "_DOER" or ""

        if ctx.params.player then
            local player = UserToPlayer(ctx.params.player)
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
    routingfallback = UserCommands.SHARD_ROUTINGFALLBACK.ALL,

    --- @param ctx CommandContext
    fn = function(ctx)
        local pt_postfix = ctx.author.userid and "_DOER" or ""

        if ctx.params.player then
            local player = UserToPlayer(ctx.params.player)
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
    slash = true,
    params = {"player"},
    paramsoptional = { false },
    routing = UserCommands.SHARD_ROUTING.NONE, --- @TODO: Maybe to ALL?

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        if PEARL.BlackList:Remove(userid) then
            PEARL.info("Successfully removed", userid, "from the blocklist!")
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_SUCCESS)
        end

        PEARL.info("Attempt to unban", userid, "failed.")
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.ON_NOTFOUND)
    end,
})

AddCommand("grant", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"},
    paramsoptional = { false },
    routing = UserCommands.SHARD_ROUTING.ALL, -- We want all shards up-to-date

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        if PEARL.BlackList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_BANNED)
        end

        if PEARL.AllowList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_ALREADY_WHITELISTED)
        end

        PEARL.AllowList:Add(userid)
        if PEARL.AllowList:Save() then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_SUCCESS:format(userid))
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_ADD.ON_FAILURE:format(userid))
    end,
})

AddCommand("revoke", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"}, -- Net/Klei ID
    paramsoptional = { false },
    routing = UserCommands.SHARD_ROUTING.ALL, -- We want all shards up-to-date

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        if not PEARL.AllowList:Contains(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_NOTFOUND)
        end

        PEARL.AllowList:Remove(userid)
        TheNet:Kick(userid)

        if PEARL.AllowList:Save() then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_SUCCESS:format(userid))
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.ALLOWLIST_REMOVE.ON_FAILURE)
    end,
})

AddCommand("inv", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = {"player"}, -- Net/Klei ID
    paramsoptional = { false },

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        if not PEARL.ServerNetwork:UserSessionExists(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

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

    --- @param ctx CommandContext
    fn = function(ctx)
        local item_owners = {}
        for _, player in ipairs(AllPlayers) do
            local items = player.components.inventory:FindItems(function(item)
                return item.prefab == ctx.params.prefab
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
            ctx.params.prefab, #item_owners
        ))
        for i = math.min(#item_owners, 5), 1, -1 do
            local player_reference = PEARL.GetPlayerMetadataFor(item_owners[i].player.userid)
            local embed = EMBEDS.Inventory(player_reference, {ctx.params.prefab})
            if not message:AddEmbed(embed) then
                break -- The message is full and doesn't accept any more embeds
            end
        end

        ctx:ReplyDiscordMessage(message)
        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.ON_SUCCESS:format(
            #item_owners
        ))
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
    params = { "message" },
    paramsoptional = { true },

    -- Called only for slash commands
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

AddCommand("mods", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    params = { "player" }, -- Do not use "user" for offline support
    paramsoptional = { false },

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        -- First try to get the mods from the CFD since that's faster
        local cfd = PEARL.ServerNetwork:GetCachedCFDFor(userid)
        local mods = cfd and cfd.enabled_mods
        if not mods then
            -- If that didn't work, look in the DB.
            mods = PEARL.DB:GetField(userid, "lastmods")
        end

        -- Using table.size even though this should be an array for additional safety and flexibility.
        if type(mods) ~= "table" or type(mods.list) ~= "table" or table.size(mods.list) <= 0 then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.NO_MODS)
        end

        ctx:ReplyDiscordMessage(MESSAGES.ModsReport(userid, mods))
    end,
})

AddCommand("save", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.MODS.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
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
    params = {"player", "value"},
    paramsoptional = {false, false},
    slash = true,
    console = true,

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        if PEARL.Reputation:SetTo(userid, tonumber(ctx.params.value)) then
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
    params = {"player"},
    paramsoptional = {false},
    slash = true,
    discord = false, -- No discord support until we have some authentication system.
    console = false, -- This is meant to be a user-only command.
    cantargetself = false,

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        if ctx.author.userid == userid and not PEARL.CONFIG.DEBUG_MODE then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.ON_SELF)
        end

        if PEARL.Reputation:GiveTo(userid, GIVEREP_AMOUNT) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.GIVEREP.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
    end,
})

AddCommand("borrowed", {
    permission = COMMAND_PERMISSION.ADMIN,
    params = {"player"},
    paramsoptional = {false},
    slash = false,
    discord = true,
    console = true,
    routing = UserCommands.SHARD_ROUTING.NONE, -- No need for routing in this case

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
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
    slash = true,
    console = true,

    fn = c_reset,
})

AddCommand("count", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = true,
    params = {"prefab"},
    paramsoptional = {false},
    routing = UserCommands.SHARD_ROUTING.ALL, -- Count on all connected shards.

    --- @param ctx CommandContext
    fn = function(ctx)
        local prefab = ctx.params.prefab
        local count = PEARL.CountPrefabs(prefab)

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.COUNT.ON_SUCCESS:format(
            count, prefab, PEARL.GetShardFancyName()
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
    params = {"player"},
    paramsoptional = {false},
    --slash = false,  -- Doesn't make much sense

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player or ctx.author.discordid or ctx.author.userid)
        local commandpermission = UserCommands.GetPermissionLevel(ctx.command.permission)
        local authorpermission = UserCommands.GetPermissionLevel(ctx.author.permission)
        if ctx.params.player ~= nil and ctx.params.player ~= ctx.author.userid and authorpermission < commandpermission then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.PROFILE.MISSING_PERMISSION)
        end

        local record = userid and PEARL.DB:GetRecordFor(userid)
        if not record then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        return ctx:ReplyDiscordEmbed(EMBEDS.ClientProfile(userid, record))
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

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        ctx.params.count = tonumber(ctx.params.count)

        local item
        local prefab = string.lower(ctx.params.prefab)
        local count_left = math.max(type(ctx.params.count) == "number" and ctx.params.count or 1, 1)
        local count = count_left
        while count_left > 0 do
            item = SpawnPrefab(prefab)
            if not item or not item.components.inventoryitem then
                if item then
                    item:Remove()
                end

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
    slash = true,
    console = true,
    params = {"player", "prefab", "count"},
    paramsoptional = {false, false, true},

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        local prefab = string.lower(ctx.params.prefab)
        ctx.params.count = tonumber(ctx.params.count)

        -- Take all items by default.
        local count = type(ctx.params.count) == "number" and ctx.params.count or math.huge
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
    slash = true,
    console = true,
    params = {"player", "prefab", "count"},
    paramsoptional = {false, true, true},

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player or not player.components.inventory then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        -- If no item specified, drop everything.
        if type(ctx.params.prefab) ~= "string" then
            player.components.inventory:DropEverything()

            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DROP.DROP_ALL:format(
                player.name
            ))
        end

        local prefab = string.lower(ctx.params.prefab)
        ctx.params.count = tonumber(ctx.params.count)

        -- Take all items by default.
        local count = type(ctx.params.count) == "number" and ctx.params.count or math.huge
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

AddCommand("kill", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.KILL.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.KILL.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    console = true,
    params = {"player"},
    paramsoptional = {true},

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
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
    slash = true,
    console = true,
    params = {"player"},
    paramsoptional = {true},

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        userid = userid or ctx.author.userid or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        player:PushEvent("respawnfromghost", {})

        -- Implicit response via the announcement
        --return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.REVIVE.ON_SUCCESS
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
    slash = true,
    console = true,

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
    slash = true,
    console = false, -- Already built in
    params = {"player"},
    paramsoptional = {true},

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        userid = userid or ctx.author.userid or (ThePlayer and ThePlayer.userid)
        local player = userid and LookupPlayerInstByUserID(userid)
        if not player then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        -- Make sure we drop the inventory before it's too late.
        if player.components.inventory then
            player.components.inventory:DropEverything()
        end

        TheWorld:PushEvent("ms_playerdespawnanddelete", player)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.DESPAWN.ON_SUCCESS)
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

    fn = function()
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

    fn = function()
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

    --- @param ctx CommandContext
    fn = function(ctx)
        TheNet:Announce(ctx.params.message)
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

    --- @param ctx CommandContext
    fn = function(ctx)
        local target = UserCommands.InputToClientTable(ctx.params.player)
        if not target or not target.name or not target.userid then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        --- @type ChatMessage
        local message = ChatMessage(ctx.params.message)
        message:SetColour(WHISPER_COLOR)
        message:SetReceiver(target.name)

        local icon
        local name = ctx.author.name
        if ctx.type == CommandContext.TYPE.DISCORD then
            icon = PEARL.CONSTS.PROFILE_FLAIRS.DISCORD
        else
            local client = ctx.author.userid and TheNet:GetClientTableForUser(ctx.author.userid)
            icon = client and GetRemotePlayerVanityItem(client.vanity or {}, "profileflair")
        end

        local player = LookupPlayerInstByUserID(ctx.author.userid)
        message:SetAuthor(name, ctx.author.colour, ctx.author.userid, ctx.author.netid, player.prefab, player.GUID)
        message:SetIcon(icon)

        -- Author can send DM to himself.
        local receivers = (
            (ctx.author.userid ~= target.userid and {target.userid, ctx.author.userid}) or
            target.userid
        )

        PEARL.ServerNetwork:DisplayChatMessageFor(
            -- Display the direct message for the target user as well as the ctx.author.
            receivers, message
        )
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

    --- @param ctx CommandContext
    fn = function(ctx)
        TheNet:SystemMessage(ctx.params.message)
    end
})

AddCommand("notify", {
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.SYSTEM.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.SYSTEM.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    console = true,
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,
    params = { "player", "message", "title" },
    paramsoptional = { false, false, true },

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
        if not PEARL.ServerNetwork:IsClientConnected(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        PEARL.ServerNetwork:DisplayPopupFor(userid, ctx.params.title, ctx.params.message)

        ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.NOTIFY.ON_SUCCESS)
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
    routing = UserCommands.SHARD_ROUTING.NONE, -- No need for routing here

    --- @param ctx CommandContext
    fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.player)
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
    console = false,
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,
    params = { "id" },
    paramsoptional = { false },

    --- @param ctx CommandContext
    fn = function(ctx)
        local bindtype = PEARL.DB.BINDING_TYPE.DISCORD
        local userid = ctx.author.userid or ctx.params.id
        local discordid = ctx.author.discordid or ctx.params.id

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
    console = false,
    discord = true,
    slash = true,
    usermenu = false,
    servermenu = false,

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
    console = true,
    slash = true,
    params = {"id"},
    paramsoptional = {false},

    --- @param ctx CommandContext
    fn = function(ctx)
        local modid = tostring(ctx.params.id)
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
    slash = false,
    usermenu = false,
    servermenu = false,
    params = {"command", "shard"},
    paramsoptional = {false, true},

    fn = function(ctx)
        if ctx.params.shardid ~= nil and ctx.params.shardid ~= SHARDID.MASTER and not PEARL.ServerNetwork:IsShardConnected(ctx.params.shardid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.SHARD_NOT_FOUND)
        end

        PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, ctx.params.shardid, ctx.params.command)
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

    --- @param ctx CommandContext
    fn = function(ctx)
        if not PEARL.DB:IsEnabled() then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.DB_DISABLED)
        end

        local userid = UserCommands.InputToUserID(ctx.params.player)
        if not userid or not PEARL.DB:HasRecordFile(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        if PEARL.DB:SetField(
            userid, ctx.params.field, ctx.params.value
        ) and PEARL.DB:SaveRecordFor(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_DB_FIELD.ON_SUCCESS)
        end

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_DB_FIELD.ON_FAILURE)
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

    --- @param ctx CommandContext
    fn = function(ctx)
        if not PEARL.CONFIG.INVENTORY_REPORTER.ENABLED then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_RARITY.ON_DISABLED)
        end

        PEARL.EventProcessor:HandleEvent("set_item_rarity", ctx.params.prefab, tonumber(ctx.params.value))
        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_RARITY.ON_SUCCESS)
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

    --- @param ctx CommandContext
    fn = function(ctx)
        local count = tonumber(ctx.params.count)
        if type(count) ~= "number" or count <= 0 then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.SET_SLOTS.ON_INVALID_INPUT)
        end

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

UserCommands.CustomizeCommand("rollback", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE

    if not command.params then
        command.params = {"numsaves"}
    end

    if not command.paramsoptional then
        command.paramsoptional = {true}
    end

    -- table.insert(command.params, "days")
    -- table.insert(command.paramsoptional, true)

    table.insert(command.params, "after")
    table.insert(command.paramsoptional, true)

    command.serverfn = nil -- Ensure that we are using our custom handler
    command.fn = function(ctx)
        local after = tonumber(ctx.params.after) or ROLLBACK_DELAY

        --- @TODO:
        -- local days = ctx.params.days ~= nil and tonumber(ctx.params.days)
        -- if days and days >= 0 then
        --     return PEARL.RollbackByDays(days, nil, after)
        -- end

        local snapshots = tonumber(ctx.params.numsaves) or 1
        TheNet:Announce(STRINGS.PEARL.LOGS.ROLLBACK_AFTER:format(snapshots, after))
        PEARL.WallScheduler:ExecuteInTime(after, function()
            -- Starting from zero
            TheNet:SendWorldRollbackRequestToServer(snapshots - 1)
        end)
    end
end)

UserCommands.CustomizeCommand("regenerate", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE

    if not command.params then
        command.params = {}
    end

    if not command.paramsoptional then
        command.paramsoptional = {}
    end

    table.insert(command.params, "shard")
    table.insert(command.paramsoptional, true)

    table.insert(command.params, "seed")
    table.insert(command.paramsoptional, true)

    if not command.aliases then
        command.aliases = {}
    end

    table.insert(command.aliases, "regen")

    command.serverfn = nil -- Ensure that we are using our custom handler
    command.fn = function(ctx)
        local seed = tonumber(ctx.params.seed)
        if seed then
            local wf = io.open(SEED_PATH, "w")
            if wf then
                wf:write(seed)
                wf:close()
            end
        end

        if ctx.params.shard == nil then
            return c_regenerateworld()
        end

        local shardid = tostring(ctx.params.shard)
        if shardid == SHARDID.MASTER then
            return c_regenerateshard()
        end

        PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, shardid, "c_regenerateshard()")
    end
end)

UserCommands.CustomizeCommand("kick", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE

    if not command.params then
        command.params = {"user", "seconds"}
    end

    if not command.paramsoptional then
        command.paramsoptional = {false, true}
    end

    table.insert(command.params, "reason")
    table.insert(command.paramsoptional, true)

    command.remote = true

    command.localfn = nil -- Migrate all the logic to the server.
    command.fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.user)
        if not PEARL.ServerNetwork:IsClientConnectedAny(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
        end

        local seconds = tonumber(ctx.params.seconds)
        local reason = ctx.params.reason
        -- In case we have passed only the reason parameter.
        if type(ctx.params.seconds) == "string" and reason == nil and seconds == nil then
            reason = ctx.params.seconds
        end

        PEARL.ServerNetwork:KickUser(userid, reason, seconds, ctx.author.userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.KICK.ON_SUCCESS)
    end
end)

UserCommands.CustomizeCommand("ban", function(command)
    command.routing = UserCommands.SHARD_ROUTING.NONE

    if not command.params then
        command.params = {"user", "seconds"}
    end

    if not command.paramsoptional then
        command.paramsoptional = {false, true}
    end

    table.insert(command.params, "reason")
    table.insert(command.paramsoptional, true)

    command.remote = true

    command.localfn = nil -- Migrate all the logic to the server.
    command.fn = function(ctx)
        local userid = UserCommands.InputToUserID(ctx.params.user)
        if PEARL.BlackList:Contains(userid) and not PEARL.ServerNetwork:IsClientConnected(userid) then
            return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ALREADY_BANNED)
        end

        local seconds = tonumber(ctx.params.seconds)
        local reason = ctx.params.reason
        -- In case we have passed only the reason parameter.
        if type(ctx.params.seconds) == "string" and reason == nil and seconds == nil then
            reason = ctx.params.seconds
        end

        PEARL.ServerNetwork:BanUser(userid, seconds, reason, ctx.author.userid)

        return ctx:Reply(STRINGS.PEARL.UI.BUILTINCOMMANDS.BAN.ON_SUCCESS)
    end
end)
