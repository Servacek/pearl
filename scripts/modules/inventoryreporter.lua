--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
    Checks the content of an inventory when it's owner despawns.
    Logs suspicious intentories to discord.
--]]

local Message = PEARL.loadfile("libraries/discordapi/models/message")
local EMBEDS = PEARL.loadfile("utils/embeds")

local ItemDepositor = PEARL.loadfile("libraries/itemdepositor")

-------------------------------
-- [[ Constants ]]
-------------------------------

-- custom_id is expected to be string
local BUTTONS = {
    FEEDBACK_POSTIVE = "1",
    FEEDBACK_NEGATIVE = "0",
}

local BUTTONS_DATA = {
    [BUTTONS.FEEDBACK_NEGATIVE] = {
        type = "button",
        emoji = PEARL.ICONS.X,
        style = 4,
        custom_id = BUTTONS.FEEDBACK_NEGATIVE,
    },
    [BUTTONS.FEEDBACK_POSTIVE] = {
        type = "button",
        emoji = PEARL.ICONS.CHECK,
        style = 3,
        custom_id = BUTTONS.FEEDBACK_POSTIVE,
    },
}

local DROP_TYPE = {
    NONE = 0,
    ALL = 1,
    RARE = 2,
}

local PREDICTION = {
    ILLEGAL = 1,
    LEGAL   = 0,
}

local REPORT_THRESHOLD = 3
local DROP_THRESHOLD = 5
local RARITY_THRESHOLD = 0.5
local LEARNING_RATE = 0.1
local MAX_LEARNED_WEIGHT = 1.5
local MAX_STACK_EVIDENCE = 10

-- Determines the maximal bias for players with age 1.
local MAX_AGE_BIAS              = 0.2 -- Age bias for 100%
local AGE_THRESHOLD             = 15 -- Age where the bias is 0

local ROOT = PEARL.ModPersistance:GetRootDirectoryPath()
local WEIGHTS_FILE_PATH = ROOT.."/item_weights.json"
local BIASES_FILE_PATH  = ROOT.."/item_weight_biases.json"

--- @type REPUTATION_TABLES
local REPUTATIONS = PEARL.CONSTS.REPUTATION_TABLES

-------------------------------
-- [[ Declarations ]]
-------------------------------

local OnPredictionMessageReceived

-------------------------------
-- [[ Locals ]]
-------------------------------

local _weights = {}
local _biases  = {}
local _predictions = {}

-------------------------------
-- [[ Helper Functions ]]
-------------------------------

local function SavePredictionData()
    json.dump(_weights, WEIGHTS_FILE_PATH)
    json.dump(_biases, BIASES_FILE_PATH)
end

local function ValidateLoadedWeightsData(weights)
    for prefab, weight in pairs(PEARL.PREFABS.RARE_ITEMS) do
        if weights[prefab] == nil then
            weights[prefab] = weight
        end
    end
end

local function LoadSavedPredictionData()
    local requires_saving = false
    local weights = json.load(WEIGHTS_FILE_PATH)
    if type(weights) == "table" then
        _weights = weights

        ValidateLoadedWeightsData(_weights)
    else
        _weights = shallowcopy(PEARL.PREFABS.RARE_ITEMS)
        requires_saving = true
    end

    local biases = json.load(BIASES_FILE_PATH)
    if type(biases) == "table" then
        _biases = biases
    else
        _biases = shallowcopy(PEARL.CONSTS.ITEM_WEIGHT_BIAS)
        requires_saving = true
    end

    if requires_saving then
        SavePredictionData()
    end
end

-- Retrieve contributions in percent for each item.
local function GetContributions(weights, normalized_value)
    local contributions = {}
    if normalized_value <= 0 then
        return contributions
    end

    for prefab, normalized_weight in pairs(weights) do
        contributions[prefab] = normalized_weight / normalized_value
    end

    return contributions
end

local function ApplyFeedbackWeight(pd, positive)
    local mult = positive and 1 or -1
    -- Use the actual weights used by the prediction
    local contributions = GetContributions(pd.weights, pd.normalized_value)
    for prefab, contribution in pairs(contributions) do
        local weight = (_weights[prefab] or 0) + (LEARNING_RATE * contribution * mult)
        _weights[prefab] = math.max(0, math.min(MAX_LEARNED_WEIGHT, weight))
    end
end

local function StorePrediction(id, prediction)
    _predictions[id] = prediction
end

local function RemovePrediction(id)
    if _predictions[id] ~= nil then
        _predictions[id] = nil
    end
end

local function SendProxyFeedbackMessage(channel_id, message)
    return PEARL.DiscordProxy:PostMessage(message, channel_id)
end

local function CreateFeedbackMessage(message)
    return message
        :AddComponent(BUTTONS_DATA[BUTTONS.FEEDBACK_POSTIVE])
        :AddComponent(BUTTONS_DATA[BUTTONS.FEEDBACK_NEGATIVE])
end

--- @return boolean success
local function ReportInventoryWithFeedback(message, pd)
    PEARL.debug("ReportInventoryWithFeedback")

    local channel_id = PEARL.DiscordReporter._webhook.channel_id or PEARL.CONFIG.INVENTORY_REPORTER.REPORT_CHANNEL
    if channel_id ~= nil then
        local request = SendProxyFeedbackMessage(channel_id, CreateFeedbackMessage(message))
        if request ~= nil then
            request:AddOnSuccess(function(response)
                OnPredictionMessageReceived(response, pd)
            end)

            return true
        end

        PEARL.error("Failed to send the feedback proxy report message! Sending a normal one.")
    else
        PEARL.error("No report channel set for Inventory Reporter, using default prediction...")
    end

    return false
end

local function GetItemEvidence(item, owner)
    local inventoryitem = item.components.inventoryitem
    if not inventoryitem then
        return 0, false
    end

    local rarity = math.max(0, _weights[item.prefab] or PEARL.PREFABS.RARE_ITEMS[item.prefab] or 0)
    if rarity <= 0 then
        return 0, false
    end

    local stacksize = math.min(MAX_STACK_EVIDENCE, PEARL.GetStackSize(item))
    local evidence = rarity * (0.5 + (stacksize * 0.1))
    local provenance = false

    local last_player_owner = inventoryitem:GetLastPlayerOwner()
    if last_player_owner and last_player_owner ~= owner then
        evidence = evidence + 2.5
        provenance = true
    end

    local last_picker = inventoryitem:IsLastPicker(owner)
    if not last_picker and inventoryitem._last_picker then
        evidence = evidence + 1.5
        provenance = true
    end

    if item.components.built and item.components.built.doer == owner then
        evidence = evidence * 0.5
    end

    return evidence, provenance
end

local function DoLegalityPrediction(inventory, age)
    local pd = {
        weights = {},
        prediction = PREDICTION.LEGAL, -- Either 1 if flagged or 0 if not.
        confidence = 0,
        weight = 0,
        normalized_value = 0,
        prefabs = {},
        provenance = false,
        rare_item_count = 0,
    }
    if inventory:IsEmpty() then
        return pd
    end

    for _, item in ipairs(inventory:ReferenceAllItems()) do
        local evidence, provenance = GetItemEvidence(item, inventory.owner)
        if evidence > 0 then
            pd.rare_item_count = pd.rare_item_count + 1
            pd.weight = pd.weight + evidence
            pd.weights[item.prefab] = (pd.weights[item.prefab] or 0) + evidence
            pd.normalized_value = pd.normalized_value + evidence
            pd.prefabs[item.prefab] = true
            pd.provenance = pd.provenance or provenance
        end
    end

    -- Apply age bias
    local age_bias_percent = math.max(0, math.min(1, (-age + AGE_THRESHOLD) / AGE_THRESHOLD))
    pd.weight = pd.weight + (MAX_AGE_BIAS * age_bias_percent)

    -- Valuable items alone are not enough. Require provenance or several rare
    -- items so normal boss loot does not trigger theft handling.
    local independent_evidence = pd.rare_item_count >= 2
    pd.prediction = (
        pd.weight >= REPORT_THRESHOLD and (pd.provenance or independent_evidence)
    ) and PREDICTION.ILLEGAL or PREDICTION.LEGAL
    pd.confidence = math.min(pd.weight / DROP_THRESHOLD, 1)

    return pd
end

local function LogPrediction(player, pd, age)
    local player_name = player.name or player.userid or "unknown"
    PEARL.info(
        "Inventory Reporter:",
        player_name,
        "("..tostring(player.userid)..")",
        "age="..tostring(age),
        "score="..string.format("%.2f", pd.weight),
        "threshold="..string.format("%.2f", REPORT_THRESHOLD),
        "confidence="..string.format("%.0f%%", pd.confidence * 100),
        "rare_items="..tostring(pd.rare_item_count),
        "provenance="..tostring(pd.provenance),
        "prediction="..(pd.prediction == PREDICTION.ILLEGAL and "ILLEGAL" or "LEGAL")
    )

    for prefab, weight in pairs(pd.weights) do
        PEARL.info(
            "Inventory Reporter evidence:",
            prefab,
            PEARL.PrefabToName(prefab),
            "weight="..string.format("%.2f", weight)
        )
    end
end

--- @param player_meta PlayerMetadata
local function ReportPlayerInventory(player_meta, pd, drop_type, sorted_items)
    player_meta:SetInventoryIterator(function(inventory)
        local i
        local used = {}
        return function()
            local item
            while item == nil or used[item.prefab] == true or not inventory[item.prefab] do
                i, item = next(sorted_items, i)
                if i == nil or item == nil then
                    return
                end
            end

            used[item.prefab] = true
            return item.prefab, inventory[item.prefab]
        end
    end)

    local embed = EMBEDS.SuspiciousInventory(player_meta)
    if drop_type ~= DROP_TYPE.NONE then
        embed:AddField("", PEARL.ICONS.PLAYER_STATE.DROP_ITEMS.." "..(
            drop_type == DROP_TYPE.ALL and STRINGS.PEARL.LOGS.INV_REPORT_DROPPED or STRINGS.PEARL.LOGS.INV_RARE_ITEMS_DROPPED
        ))
        -- embed:SetDescription(embed.description..(
        --     "\n\n"..PEARL.ICONS.PLAYER_STATE.DROP_ITEMS.." "..(
        --         drop_type == DROP_TYPE.ALL and STRINGS.PEARL.LOGS.INV_REPORT_DROPPED or STRINGS.PEARL.LOGS.INV_RARE_ITEMS_DROPPED
        --     )
        -- ))
    end

    local message = Message():AddEmbed(embed)
    if PEARL.CONFIG.INVENTORY_REPORTER.USE_AI and PEARL.DiscordProxy:IsRunning() then
        if ReportInventoryWithFeedback(message, pd) == true then
            return
        end
    end

    PEARL.DiscordReporter:SendRawReportMessage(message)
end

local function CheckPlayersInventory(world, player)
    local inventory = player.components.inventory
    if not inventory or inventory:IsEmpty() then
        return
    end

    local age = player.components.age and player.components.age:GetAgeInDays() or 1
    local pd = DoLegalityPrediction(inventory, age)
    if player.components.playerthief then
        for prefab in pairs(pd.prefabs) do
            if player.components.playerthief:WasRecentlyStolen(prefab) then
                pd.provenance = true
                pd.weight = pd.weight + 2.5
                break
            end
        end
    end

    pd.prediction = (
        pd.weight >= REPORT_THRESHOLD and (pd.provenance or pd.rare_item_count >= 2)
    ) and PREDICTION.ILLEGAL or PREDICTION.LEGAL
    pd.confidence = math.min(pd.weight / DROP_THRESHOLD, 1)
    LogPrediction(player, pd, age)

    if pd.prediction == PREDICTION.LEGAL then
        PEARL.info("Inventory Reporter: inventory was not flagged.")
        return -- This inventory is not flagged.
    end

    PEARL.Reputation:EarnFor(player.userid, REPUTATIONS.LEFT_WITH_BAD_INV)

    -- Initialize the meta data here so it uses the old untouched inventory for reference.
    local player_meta = PEARL.GetPlayerMetadataFor(player.userid)

    local sorted_items
    local drop_type = DROP_TYPE.NONE
    if world.state.cycles > PEARL.CONFIG.INVENTORY_REPORTER.DROP_AFTER_CYCLE or PEARL.CONFIG.DEBUG_MODE then
        local reputation = PEARL.Reputation:GetOf(player.userid)
        if pd.provenance and pd.weight >= DROP_THRESHOLD and reputation < PEARL.CONFIG.INVENTORY_REPORTER.DROP_ALL_UNDER_REP then
            sorted_items = ItemDepositor:DepositAllItems(inventory)
            drop_type = DROP_TYPE.ALL
        elseif pd.provenance and pd.weight >= DROP_THRESHOLD and reputation < PEARL.CONFIG.INVENTORY_REPORTER.DROP_RARE_UNDER_REP then
            sorted_items = ItemDepositor:DepositRareItems(inventory, RARITY_THRESHOLD)
            drop_type = DROP_TYPE.RARE
        end

        PEARL.info(
            "Inventory Reporter:",
            drop_type == DROP_TYPE.ALL and "dropped all items"
                or drop_type == DROP_TYPE.RARE and "dropped rare items"
                or "did not drop items"
        )

        -- Save the deposited items in case of a restart or rollback
        --if #AllPlayers == 0 then
            TheWorld:PushEvent("ms_save")
        --end
    end

    -- Anounce this after dropping so we have the info
    if PEARL.CONFIG.INVENTORY_REPORTER.SEND_REPORT and PEARL.DiscordReporter:IsEnabled() then
        ReportPlayerInventory(
            player_meta, pd, drop_type, sorted_items or inventory:GetAllItemsSorted(
                ItemDepositor.SORTBY.PRIORITY
            )
        )
    else
        PEARL.info("Inventory Reporter: report sending is disabled or Discord reporter is unavailable.")
    end
end

-------------------------------
-- [[ Query Handlers ]]
-------------------------------

OnPredictionMessageReceived = function(response, pd)
    -- Store the message ID so we can identify the response.
    StorePrediction(response, pd)
end

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

local function OnPlayerDespawn(world, player)
    if type(player) ~= "table" or PEARL.CONFIG.PERMISSIVE_MODE == true then
        return
    end

    if not PEARL.CONFIG.DEBUG_MODE and (PEARL.ServerNetwork:IsAdmin(player.userid) or (player.components.age and player.components.age:IsTrustworthy())) then
        return
    end

    -- There is no point in announcing the inventory if we drop everything anyway.
    if (GetGameModeProperty("drop_everything_on_despawn") or TUNING.DROP_EVERYTHING_ON_DESPAWN) then
        return
    end

    CheckPlayersInventory(world, player)
end

local function OnPredictionFeedback(id, positive)
    local prediction = _predictions[id]
    if not prediction then
        return PEARL.error("Received feedback for invalid prediction!")
    end

    ApplyFeedbackWeight(prediction, positive)
    RemovePrediction(id)
    SavePredictionData()
end

local function OnInputProxyEvent(event)
    if event.name ~= "button_pressed" or not event.message_id then
        return
    end

    local custom_id = tostring(event.button_id)
    local positive = custom_id == BUTTONS.FEEDBACK_POSTIVE or custom_id == BUTTONS.FEEDBACK_NEGATIVE or nil
    if positive == nil then
        return
    end

    -- Not really needed
    -- local id = event.application_id
    -- /webhooks/{application.id}/{interaction.token}
    -- print(PEARL.HTTPClient:POST(
    --     ("https://discord.com/api/v10/webhooks/%s/%s"):format(
    --         id, event.interaction_token
    --     ), nil, {
    --         content = "Feedback Received!"
    --     }):Send().url)
    -- --PEARL.DiscordReporter:SendRawReportString("Feedback recevied!")

    OnPredictionFeedback(tostring(event.message_id), positive)
end

local function OnItemRaritySet(prefab, value)
    if not _weights or table.empty(_weights) then
        LoadSavedPredictionData()
    end

    _weights[prefab] = value

    SavePredictionData()
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddWorldPostInit(function(inst)
    -- Question is, if this is being called on migration or not.
    inst:SafeListenForEvent("ms_playerdespawn", OnPlayerDespawn)
end)

PEARL.EventProcessor:AddSafeEventHandler("input_proxy_event", OnInputProxyEvent)
PEARL.EventProcessor:AddSafeEventHandler("set_item_rarity", OnItemRaritySet)

if PEARL.CONFIG.DEBUG_MODE then
    PEARL.EventProcessor:AddSafeEventHandler("d_ms_playerdespawn", OnPlayerDespawn)
end

-------------------------------
-- [[ Setup ]]
-------------------------------

if PEARL.CONFIG.INVENTORY_REPORTER.USE_AI then
    LoadSavedPredictionData()
end -- Else use the default ones
