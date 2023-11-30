--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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

-------------------------------
-- [[ Constants ]]
-------------------------------

--- <item_name>: <priority>
local DROP_DEPOS = {
    ["firepit"]         = 1,
    ["treasurechest"]   = 2,
    ["dragonflychest"]  = 3,
}

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
    LEGAL = 1,
    ILLEGAL = 0,
}

local FEEDBACK_WEIGHT = 0.1
local LEGALITY_THRESHOLD = .8
local RARITY_THRESHOLD = 0.5
local WEIGHT_FACTOR = 0.5

local WEIGHTS_FILE_PATH = PEARL.MODROOT.."data/item_weights.json"

--- @TODO: FOR DEBUGGING
local MESSAGE_QUERY_URL = "http://localhost:10997/dst/proxy/message"

-------------------------------
-- [[ Declarations ]]
-------------------------------

local OnPredictionMessageReceived

-------------------------------
-- [[ Locals ]]
-------------------------------

local _depos = {}
local _weights = {}
local _predictions = {}

local _sorted = false

-------------------------------
-- [[ Sorters ]]
-------------------------------

local function sort_by_priority(a, b)
    return (DROP_DEPOS[a.prefab] or 0) < (DROP_DEPOS[b.prefab] or 0)
end

-------------------------------
-- [[ Helper Functions ]]
-------------------------------

local function SaveItemWeights()
    local wf = io.open(WEIGHTS_FILE_PATH, "w")
    if not wf then
        return PEARL.error("Failed to load the weights file!")
    end

    wf:write(json.encode(_weights))
    wf:close()
end

local function LoadItemWeights()
    if not io.exists(WEIGHTS_FILE_PATH) then
        _weights = shallowcopy(PEARL.PREFABS.RARE_ITEMS)
        SaveItemWeights()
        return
    end

    local rf = io.open(WEIGHTS_FILE_PATH, "r")
    if not rf then
        return PEARL.error("Failed to load the weights file!")
    end

    local content = rf:read("*a")
    rf:close()

    local success, data = pcall(json.decode, content)
    if not success or type(data) ~= "table" then
        return PEARL.error("Failed to decode the item weights json!")
    end
end

-- Retrieve contributions in percent for each item.
local function GetContributions(weights, normalized_value)
    local contributions = {}
    for prefab, normalized_weight in pairs(weights) do
        contributions[prefab] = normalized_weight / normalized_value
    end

    --assert(table.sum(contributions) == 1)

    return contributions
end

-- TODO: Apply feedback according to condfidence?
-- Confidence calculations are to inacurate for that...
local function ApplyFeedbackWeight(pd, positive)
    local mult = positive and 1 or -1
    local contributions = GetContributions(pd.weights, pd.normalized_value)
    for prefab, contribution in pairs(contributions) do
        -- The weight should be always between 0 and 1.
        -- _weights[prefab] = math.min(
        --     (_weights[prefab] or 0) + (FEEDBACK_WEIGHT * contribution * mult), 1
        -- )

        -- Lets try to keep the weight growing as it needs to
        _weights[prefab] = (_weights[prefab] or 0) + (FEEDBACK_WEIGHT * contribution * mult)
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
    message.components = {
        BUTTONS_DATA[BUTTONS.FEEDBACK_POSTIVE],
        BUTTONS_DATA[BUTTONS.FEEDBACK_NEGATIVE],
    }

    local data = {
        message = message,
        channel = channel_id,
    }

    return PEARL.HTTPClient:POST(
        MESSAGE_QUERY_URL, nil, data
    ):SetIsRaw(true):Send()
end

local function ReportInventoryWithFeedback(message, pd)
    local channel_id = PEARL.DiscordReporter._webhook.channel_id or PEARL.CONFIG.INVENTORY_REPORTER.REPORT_CHANNEL
    if channel_id ~= nil then
        local request = SendProxyFeedbackMessage(channel_id, message)
        if request ~= nil then
            request:SetOnSuccess(OnPredictionMessageReceived, pd)
            return
        end

        PEARL.error("Failed to send the feedback proxy report message! Sending a normal one.")
    else
        PEARL.error("No report channel set for Inventory Reporter, using default prediction...")
    end
end

local function SortDepos()
    table.sort(_depos, sort_by_priority)

    _sorted = true
end

local function GetDepoForItem(item)
    local max_amount = -1
    local cache = {}

    return function()
        PEARL.debug("MAX_AMOUNT", max_amount)
        table.dump(cache)
        for _, depo in ipairs(_depos) do
            local amount = tonumber(cache[depo.GUID]) or nil
            if cache[depo.GUID] == nil then
                -- If not cached, calculate the amount and cache it.
                amount = depo.components.container and depo.components.container:CountItem(item.prefab)
                cache[depo.GUID] = amount
            end

            -- For non-container depos
            if amount == nil then
                cache[depo.GUID] = false

                return depo
            end

            if cache[depo.GUID] ~= false and amount and amount >= max_amount then
                max_amount = amount

                -- Mark the depo as "visited" in the cache.
                cache[depo.GUID] = false
                return depo
            end
        end

        -- End the iteration.
    end
end

local function DepositItem(inventory, item)
    item.components.inventoryitem:RemoveFromOwner()

    if not _sorted then
        print("SORTING DEPOS...")
        SortDepos()
    end

    for _, depo in ipairs(GetDepoForItem(item)) do
        if item == nil then
            return -- We have managed to add the whole item to the container.
        end

        print("CHECKING DEPO:", depo)
        local container = depo.components and depo.components.container
        if container and container:CanTakeItemInSlot(item) then
            local slot = depo.components.container:GetSpecificSlotForItem(item)
            print("GOT SLOT:", slot)
            local dest = depo.components.container:GetItemInSlot(slot)
            if dest and dest.components.stackable then
                print("Adding item to stack...")
                item = dest.components.stackable:Put(item)
            end
        elseif depo.Transform then
            print("Dropping the item at depo position")
            inventory:DropItem(item, true, true, depo.Transform:GetWorldPosition())
            item = nil
            return
        end
    end

    print("Dropping on the ground...")
    -- If no depo existed for this item.
    inventory:DropItem(item)
end

local function DepositAllItems(inventory)
    inventory:ForEachItem(function(item)
        DepositItem(inventory, item)
    end)
end

local function DepositRareItems(inventory, rarity_threshold)
    inventory:ForEachItem(function(item)
        local item_rarity = PEARL.PREFABS.RARE_ITEMS[item.prefab]
        if item_rarity and item_rarity > rarity_threshold then
            DepositItem(inventory, item)
        end
    end)
end

local function DoLegalityPrediction(inventory)
    local pd = {
        weights = {},
        prediction = PREDICTION.LEGAL, -- Either 1 if flagged or 0 if not.
        confidence = 0,
        items = 0,
        value = 0,
        normalized_value = 0,
    }
    if inventory:IsEmpty() then
        return pd
    end

    for _, item in ipairs(inventory:ReferenceAllItems()) do
        local stacksize = item.components.inventoryitem:GetStackSize()
        local stackweight = item.components.inventoryitem:GetTotalPredictedWeight(_weights)
        local itemweight = stackweight / stacksize

        -- Store highest normalized weight for this item.
        pd.weights[item.prefab] = math.max((pd.weights[item.prefab] or 0), itemweight)
        pd.normalized_value = pd.normalized_value + itemweight
        pd.value = pd.value + stackweight
        pd.items = pd.items + stacksize
    end

    if pd.value >= LEGALITY_THRESHOLD then
        pd.prediction = PREDICTION.LEGAL
    end

    local x = pd.prediction == PREDICTION.ILLEGAL and 1 / pd.value or pd.value
    pd.confidence = math.sigmoid(x * WEIGHT_FACTOR)

    print("CONFIDENCE:", pd.confidence * 100)
    print("VALUE:", pd.value)

    return pd
end

--- @TODO: Debug
local function CheckPlayersInventory(world, player)
    local inventory = player.components.inventory
    if not inventory then
        return
    end

    local pd = DoLegalityPrediction(inventory)
    if pd.prediction ~= PREDICTION.LEGAL then
        return -- This inventory is not flagged.
    end

    print("SENDING REPORT TO THE SERVER:")

    local drop_type = DROP_TYPE.NONE
    if world.state.cycles > PEARL.CONFIG.INVENTORY_REPORTER.DROP_AFTER_CYCLE or PEARL.CONFIG.DEBUG_MODE then
        local reputation = PEARL.Reputation:GetOf(player.userid)
        print("REP", reputation)
        if reputation < PEARL.CONFIG.INVENTORY_REPORTER.DROP_ALL_UNDER_REP then
            DepositAllItems(inventory)

            drop_type = DROP_TYPE.ALL
        elseif reputation < PEARL.CONFIG.INVENTORY_REPORTER.DROP_RARE_UNDER_REP then
            DepositRareItems(inventory, RARITY_THRESHOLD)

            drop_type = DROP_TYPE.RARE
        end
    end

    if PEARL.CONFIG.INVENTORY_REPORTER.SEND_REPORT and PEARL.DiscordReporter:IsEnabled() then
        local player_meta = PEARL.GetPlayerMetadataFor(player.userid)
        player_meta:SetInventory(inventory)

        local embed = EMBEDS.SuspiciousInventory(player_meta, pd.confidence)
        if drop_type ~= DROP_TYPE.NONE then
            embed:SetDescription(embed.description..(
                "\n"..PEARL.ICONS.PLAYER_STATE.DROP_ITEMS.." "..(
                    drop_type == DROP_TYPE.ALL and STRINGS.PEARL.LOGS.INV_REPORT_DROPPED or STRINGS.PEARL.LOGS.INV_RARE_ITEMS_DROPPED
                )
            ))
        end

        local message = Message()
            :AddEmbed(embed)
            :ToTable()

        if PEARL.CONFIG.INVENTORY_REPORTER.USE_AI then
            ReportInventoryWithFeedback(message, pd)
        else
            PEARL.DiscordReporter:SendRawReportMessage(message)
        end
    end
end

-------------------------------
-- [[ Query Handlers ]]
-------------------------------

OnPredictionMessageReceived = function(response, request, pd)
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

local function OnDepoRemove(inst)
    for i = #_depos, 1, -1 do
        if _depos[i].GUID == inst.GUID then
            print("REMOVING A DEPO", inst)
            -- Keeps them sorted
            table.remove(_depos, i)
        end
    end
end

local function OnDepoInit(inst)
    print("NEW DEPO ADDED!", inst)
    _depos[#_depos+1] = inst

    _sorted = false
end

local function OnPredictionFeedback(id, positive)
    local prediction = _predictions[id]
    if not prediction then
        return PEARL.error("Received feedback for invalid prediction!")
    end

    ApplyFeedbackWeight(prediction, positive)
    RemovePrediction(id)
    SaveItemWeights()
end

local function OnInputProxyEvent(event)
    print("OnInputProxyEvent")
    if event.name ~= "button_pressed" or not event.message_id then
        return
    end

    local custom_id = tostring(event.button_id)
    local positive = custom_id == BUTTONS.FEEDBACK_POSTIVE or custom_id == BUTTONS.FEEDBACK_NEGATIVE or nil
    if positive == nil then
        return
    end

    PEARL.DiscordReporter:SendRawReportString("Feedback recevied!")
    OnPredictionFeedback(tostring(event.message_id), positive)
end

local function OnItemRaritySet(prefab, value)
    if not _weights or table.empty(_weights) then
        LoadItemWeights()
    end

    _weights[prefab] = value

    SaveItemWeights()
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddWorldPostInit(function(inst)
    -- Question is, if this is being called on migration or not.
    inst:SafeListenForEvent("ms_playerdespawn", OnPlayerDespawn)
end)

for depo_prefab, _ in pairs(DROP_DEPOS) do
    PEARL.AddPrefabPostInit(depo_prefab, function(inst)
        OnDepoInit(inst)

        inst:SafeListenForEvent("onremove", OnDepoRemove)
    end)
end

PEARL.EventProcessor:AddSafeEventHandler("input_proxy_event", OnInputProxyEvent)
PEARL.EventProcessor:AddSafeEventHandler("set_item_rarity", OnItemRaritySet)

if PEARL.CONFIG.DEBUG_MODE then
    PEARL.EventProcessor:AddSafeEventHandler("d_ms_playerdespawn", OnPlayerDespawn)
end

-------------------------------
-- [[ Setup ]]
-------------------------------

if PEARL.CONFIG.INVENTORY_REPORTER.USE_AI then
    LoadItemWeights()
end -- Else use the default ones
