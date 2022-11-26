-- local UserCommands = require("usercommands")
--- @TODO
local PEARL = PEARL
local TheNet = TheNet

-------------------------------------
-- Contants
-------------------------------------

-- local REPAIR_RADIUS = 24

local SLASH_COMMANDS = {}

local SLASH_COMMAND_DELIM = "/"
local KLEI_ID_DELIM = "K"

-------------------------------------
-- Helpers
-------------------------------------

local function AddCommand(name, data, ...)
    AddUserCommand(name, data)

    if name and data.slash then
        table.insert(SLASH_COMMANDS, name)
    end
end

-- local function RepairStructuresNear(player)
--     local x,y,z = player.Transform:GetWorldPosition()
--     local burned_entities = TheSim:FindEntities(
--         x, y, z, REPAIR_RADIUS, {'burnt','structure'}, {'INLIMBO'}
--     )

--     for _,ent in ipairs(burned_entities) do
--         local orig_pos = ent:GetPosition()
--         ent:Remove()

--         local inst = SpawnPrefab(tostring(ent.prefab), tostring(ent.skinname), nil, player.userid)
--         if inst then
--             inst.Transform:SetPosition(orig_pos:Get())
--         end
--     end
-- end

-- local function UnbanPlayerCommand(player_id, caller_id)
--     if SUF.BlacklistManager.RemovePlayerByID(player_id) then
--         print("Successfuly removed player with ID", player_id, "from the list!")

--         ServerSendCommandResponse(caller_id, string.format(
--             STRINGS.UI.BUILTINCOMMANDS.UNBAN.ONSUCCESS, player_id
--         ))
--     else
--         print("Player was not found on the blacklist...")

--         ServerSendCommandResponse(caller_id, STRINGS.UI.BUILTINCOMMANDS.UNBAN.ONNOTFOUND)
--     end
-- end

------------------------------------
-- Slash commands
------------------------------------

AddCommand("fire", {
    aliases = {},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.FIRE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    usermenu = false,
    servermenu = true,
	menusort = 5,
    vote = false,
    params = {},

    serverfn = function(params, caller)
        PEARL.c_fire()

        if not caller then
            return
        end

        TheNet:Announce(caller:GetDisplayName().." uhasil ohne okolo hráčov!", caller.entity)
    end,
})

-- disabled
-- AddModUserCommand("server_utils", "repair", {
--     aliases = {},
--     prettyname = nil, --default to STRINGS.UI.BUILTINCOMMANDS.REPAIR.PRETTYNAME
--     desc = nil, --default to STRINGS.UI.BUILTINCOMMANDS.REPAIR.DESC
--     permission = COMMAND_PERMISSION.ADMIN,
--     slash = true,
--     usermenu = false,
--     servermenu = true,
-- 	menusort = 6,
--     vote = false,
--     params = {},

--     serverfn = function(params, caller)
--         if caller ~= nil then
--             for _, v in ipairs(AllPlayers) do
--                 RepairStructuresNear(v)
--             end

--             TheNet:Announce(caller:GetDisplayName().." opravil štruktúry okolo hráčov!")
--         end
--     end,

-- })

AddCommand("unban", {
    aliases = {},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.UNBAN.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    usermenu = false,
    servermenu = false,
    vote = false,
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },

    -- This is executed on the local shard
    serverfn = function(params, caller)
        if params == nil or caller == nil then
            return
        end

        if PEARL.c_unban(params.player_id) then
            print("Successfuly removed player with ID", params.player_id, "from the list!")

            PEARL.ServerSendCommandResponse(caller.userid, string.format(
                STRINGS.UI.BUILTINCOMMANDS.UNBAN.ON_SUCCESS, params.player_id
            ))
        else
            print("Player was not found on the blacklist...")

            PEARL.ServerSendCommandResponse(
                caller.userid, STRINGS.UI.BUILTINCOMMANDS.UNBAN.ON_NOTFOUND
            )
        end
    end,
})

AddCommand("whitelist-add", {
    aliases = {},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.WHITELIST_ADD.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.WHITELIST_ADD.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    usermenu = false,
    servermenu = false,
    vote = false,
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if params == nil or caller == nil then return end

        if PEARL.CONFIG.WHITELIST_ENABLED then
            return PEARL.ServerSendCommandResponse(caller.userid,
                STRINGS.UI.BUILTINCOMMANDS.WHITELIST_ADD.ON_DISABLED
            )
        end

        if PEARL.Blacklist.IsUserBlacklisted(params.player_id) then
            return PEARL.ServerSendCommandResponse(caller.userid,
                STRINGS.UI.BUILTINCOMMANDS.WHITELIST_ADD.ON_BANNED
            )
        end

        if TheNet:IsWhiteListed(params.player_id) then
            return PEARL.ServerSendCommandResponse(caller.userid,
                STRINGS.UI.BUILTINCOMMANDS.WHITELIST_ADD.ON_ALREADY_WHITELISTED
            )
        end

        TheNet:AddToWhiteList(params.player_id)
        PEARL.ServerSendCommandResponse(caller.userid, string.format(
            STRINGS.UI.BUILTINCOMMANDS.WHITELIST_ADD.ON_SUCCESS,
            params.player_id
        ))
    end,
})

AddCommand("whitelist-remove", {
    aliases = {},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.WHITELIST_REMOVE.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.WHITELIST_REMOVE.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    usermenu = false,
    servermenu = false,
    vote = false,
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if params == nil or caller == nil then return end

        if PEARL.Whitelist == nil then
            if not PEARL.CONFIG.WHITELIST_ENABLED then
                return PEARL.ServerSendCommandResponse(caller.userid,
                    STRINGS.UI.BUILTINCOMMANDS.WHITELIST_REMOVE.ON_DISABLED
                )
            end

            return
        end

        if not PEARL.Whitelist:Contains(params.player_id) then
            return PEARL.ServerSendCommandResponse(caller.userid,
                STRINGS.UI.BUILTINCOMMANDS.WHITELIST_REMOVE.ON_NOTFOUND
            )
        end

        PEARL.Whitelist:Remove(params.player_id)
        TheNet:Kick(params.player_id)

        if PEARL.Whitelist:Save() then
            return PEARL.ServerSendCommandResponse(caller.userid, string.format(
                    STRINGS.UI.BUILTINCOMMANDS.WHITELIST_REMOVE.ON_SUCCESS,
                    params.player_id
                )
            )
        end

        return PEARL.ServerSendCommandResponse(caller.userid,
            STRINGS.UI.BUILTINCOMMANDS.WHITELIST_REMOVE.ON_FAILURE
        )
    end,
})

AddCommand("inv", {
    aliases = {},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    usermenu = false,
    servermenu = false,
    vote = false,
    params = {"player_id"}, -- Net/Klei ID
    params_optional= { false },

    serverfn = function(params, caller)
        if params == nil or caller == nil then return end

        if not PEARL.CONSTS.DISCORD_LOGS_ENABLED then
            return PEARL.ServerSendCommandResponse(caller.userid,
                STRINGS.UI.BUILTINCOMMANDS.ERRORS.DISCORD_LOGS_DISABLED
            )
        end

        if PEARL.c_inventory(params.player_id) then
            return PEARL.ServerSendCommandResponse(caller.userid,
                STRINGS.UI.BUILTINCOMMANDS.INV.ON_SUCCESS
            )
        end

        return PEARL.ServerSendCommandResponse(caller.userid,
            STRINGS.UI.BUILTINCOMMANDS.INV.ON_NOTFOUND
        )
    end,
})

AddCommand("inv-find", {
    aliases = {},
    prettyname = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.PRETTYNAME,
    desc = STRINGS.PEARL.UI.BUILTINCOMMANDS.INV_FIND.DESC,
    permission = COMMAND_PERMISSION.ADMIN,
    slash = true,
    usermenu = false,
    servermenu = false,
    vote = false,
    params = {"item_prefab"},
    params_optional= { false },

    serverfn = function(params, caller)
        if not (params and caller and params.item_prefab) then
            return
        end

        local item_owners = {}
        for _, player in ipairs(AllPlayers) do
            local item_count = player.components.inventory:GetItemByName(params.item_prefab, nil, true)
            if item_count and item_count > 0 then
                item_owners[#item_owners + 1] = {
                    player = player,
                    item_count = item_count,
                }
            end
        end

        if #item_owners <= 0 then
            return PEARL.info("No results")
        end

        table.sort(item_owners, function(k1, k2)
            return item_owners[k1].item_count > item_owners[k2].item_count
            and item_owners[k1].player.components.age:GetAge() < item_owners[k1].player.components.age:GetAge()
        end)

        -- Anounce first 5 inventories reversed
        -- so the first one is on the bottom of the chat.
        for i = 5, 1, -1 do
            local player = item_owners[i].player

            local inventory, prefab, name = PEARL.GetInventoryTabelFor(player.userid, player)
            local embed = PEARL.InventoryToEmbed(inventory, prefab, player.name or name, player.userid)
            PEARL.Logger:LogEmbed(embed)
        end
    end,
})

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
