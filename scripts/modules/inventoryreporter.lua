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

local ILLEGALITY_THRESHOLD = 3
local RARITY_THRESHOLD = 0.5
local LEARNING_RATE = 0.1

local ITEM_WEIGHT_BIAS = PEARL.CONSTS.ITEM_WEIGHT_BIAS

-- Determines the maximal bias for players with age 1.
local MAX_AGE_BIAS              = 0.2 -- Age bias for 100%
local AGE_THRESHOLD             = 15 -- Age where the bias is 0

local WEIGHTS_FILE_PATH = PEARL.MODROOT.."data/item_weights.json"
local BIASES_FILE_PATH  = PEARL.MODROOT.."data/item_weight_biases.json"

--- @TODO: FOR DEBUGGING
local MESSAGE_QUERY_URL = "http://localhost:10997/dst/proxy/message"

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

local function LoadSavedPredictionData()
    local requires_saving = false
    local weights = json.load(WEIGHTS_FILE_PATH)
    if type(weights) == "table" then
        _weights = weights
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
    for prefab, normalized_weight in pairs(weights) do
        contributions[prefab] = normalized_weight / normalized_value
    end

    table.dump(contributions)
    print("MAX CONTRIBUTOR:", table.max(contributions))

    return contributions
end

local function ApplyFeedbackWeight(pd, positive)
    local mult = positive and 1 or -1
    -- Use the actual weights used by the prediction
    local contributions = GetContributions(pd.weights, pd.normalized_value)
    for prefab, contribution in pairs(contributions) do
        -- Items that contributed the most will be affected the most as well.
        _weights[prefab] = (_weights[prefab] or 0) + (LEARNING_RATE * contribution * mult)
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
    local messagedata = message:ToTable()
    messagedata.components = {
        BUTTONS_DATA[BUTTONS.FEEDBACK_POSTIVE],
        BUTTONS_DATA[BUTTONS.FEEDBACK_NEGATIVE],
    }

    local data = {
        message = messagedata,
        channel = channel_id,
    }

    return PEARL.HTTPClient:POST(
        MESSAGE_QUERY_URL, nil, data
    ):SetIsRaw(true):Send()
end

local function ReportInventoryWithFeedback(message, pd)
    PEARL.debug("ReportInventoryWithFeedback")

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

-- Returns the total predicted weight for the item with all the biases applied.
local function CalculateBiasFor(item, stacksize)
    local bias = 0

    -- Negative bias for renewable items.
    if item:HasTag("renewable") then
        bias = bias + _biases.RENEWABLE * stacksize
    end

    -- Bias for higher nutrition food
    if item.components.edible and item.components.edible:FulfillsDiet(FOODGROUP.OMNI) then
        local food_val = item.components.edible:GetFoodValue()
        if food_val > 0 then
            local mult = item:HasTag("preparedfood") and ITEM_WEIGHT_BIAS.PER_FOOD_POINT or ITEM_WEIGHT_BIAS.PER_FOOD_POINT_RAW

            bias = bias + (food_val * mult) * stacksize
        end
    end

    -- Bias for less worn items.
    if item.components.finiteuses then
        -- If this item does not have durability (e. g. Walking Cane) we count it as
        -- if it had 100%.
        local finituse_percent = item.components.finiteuses:GetPercent() or 1
        bias = bias * finituse_percent
    end

    print(item.prefab, bias)

    return bias
end

local function GetWeightFor(prefab)
    return _weights[prefab] or PEARL.CONSTS.DEFAULT_ITEM_WEIGHT
end

-- local function GetWeightForRecipe(recipe, stacksize)
--     local weight, normalized_weight = 0, 0

--     -- For crafted items consider their ingredients
--     for _, ingredient in ipairs(recipe.ingredients) do
--         local ing_weight = GetWeightFor(ingredient.type)
--         if _weights[ingredient.type] and _weights[ingredient.type] > 0 then
--             weight = weight + (ing_weight * ingredient.amount) * (stacksize / recipe.numtogive)
--             normalized_weight = normalized_weight + ing_weight
--         end
--     end

--     return weight, normalized_weight
-- end

local function DoLegalityPrediction(inventory, age)
    local pd = {
        weights = {},
        prediction = PREDICTION.LEGAL, -- Either 1 if flagged or 0 if not.
        confidence = 0,
        weight = 0,
        normalized_value = 0,
        prefabs = {},
    }
    if inventory:IsEmpty() then
        return pd
    end

    for _, item in ipairs(inventory:ReferenceAllItems()) do
        local prefab = item.prefab
        local stacksize = PEARL.GetStackSize(item)
        local bias = CalculateBiasFor(item, stacksize)
        local weight = GetWeightFor(prefab)

        --- @TODO: Check the recipes only for items we have guranteed were built.
        --- Also some items may have multiple recipes so store the one used.
        --- And check the crafter as well.
        -- local recipe_weight, nrecipe_weight = 0, 0
        -- local recipe = AllRecipes[prefab]
        -- if recipe then
        --     recipe_weight, nrecipe_weight = GetWeightForRecipe(recipe, stacksize)
        -- end

        -- if recipe_weight > weight then
        --     weight = nrecipe_weight
        --     pd.weight = recipe_weight

        --     for _, ingredient in ipairs(recipe.ingredients) do
        --         pd.weights[ingredient.type] = math.max((pd.weights[ingredient.type] or 0), weight)
        --     end
        -- else
            -- Store highest normalized weight for this item.
            pd.weights[item.prefab] = math.max((pd.weights[item.prefab] or 0), weight)
            pd.weight = pd.weight + (weight * stacksize) + bias
        -- end

        pd.normalized_value = pd.normalized_value + weight
        print("BIAS", bias, "WEIGHT", weight, "STACKSIZE", stacksize)
        print("FINAL WEIGHT:", pd.weight)
    end

    local unique_item_count = inventory:CountItemPrefabs()
    pd.weight = pd.weight + pd.weight / math.max(unique_item_count, 1)^2

    -- Apply age bias
    local age_bias_percent = (-age + AGE_THRESHOLD) / AGE_THRESHOLD
    local age_bias = MAX_AGE_BIAS * age_bias_percent
    pd.weight = pd.weight + age_bias_percent
    print("AGE BIAS", age_bias_percent, age_bias)

    -- local wpercent = pd.weight / worst_scenario
    pd.prediction = pd.weight > ILLEGALITY_THRESHOLD and PREDICTION.ILLEGAL or PREDICTION.LEGAL
    print("VALUE:", pd.weight)
    print("PREDICTION:", pd.prediction)

    GetContributions(pd.weights, pd.normalized_value)

    return pd
end

local function CheckPlayersInventory(world, player)
    local inventory = player.components.inventory
    if not inventory or inventory:IsEmpty() then
        return
    end

    local age = player.components.age and player.components.age:GetAgeInDays() or 1
    local pd = DoLegalityPrediction(inventory, age)
    table.dump(pd)
    if pd.prediction == PREDICTION.LEGAL then
        print("INVENTORY IS LEGAL")
        return -- This inventory is not flagged.
    end

    PEARL.Reputation:EarnFor(player.userid, REPUTATIONS.LEFT_WITH_BAD_INV)

    print("SENDING REPORT TO THE SERVER:")

    -- Initialize the meta data here so it uses the old untouched inventory for reference.
    local player_meta = PEARL.GetPlayerMetadataFor(player.userid)

    local drop_type = DROP_TYPE.NONE
    if world.state.cycles > PEARL.CONFIG.INVENTORY_REPORTER.DROP_AFTER_CYCLE or PEARL.CONFIG.DEBUG_MODE then
        local reputation = PEARL.Reputation:GetOf(player.userid)
        print("REP", reputation)
        if reputation < PEARL.CONFIG.INVENTORY_REPORTER.DROP_ALL_UNDER_REP then
            ItemDepositor:DepositAllItems(inventory)
            print("IS EMPTY AFTER DEPOSIT?", inventory:IsEmpty())
            print(inventory:GetDebugString())

            drop_type = DROP_TYPE.ALL
        elseif reputation < PEARL.CONFIG.INVENTORY_REPORTER.DROP_RARE_UNDER_REP then
            ItemDepositor:DepositRareItems(inventory, RARITY_THRESHOLD)

            drop_type = DROP_TYPE.RARE
        end

        -- If none is playing make sure to save the server in case of a restart.
        if #AllPlayers == 0 then
            TheWorld:PushEvent("ms_save")
        end
    end

    if PEARL.CONFIG.INVENTORY_REPORTER.SEND_REPORT and PEARL.DiscordReporter:IsEnabled() then
        print("SENDING THE REPORT TO DISCORD")
        local embed = EMBEDS.SuspiciousInventory(player_meta)
        if drop_type ~= DROP_TYPE.NONE then
            embed:SetDescription(embed.description..(
                "\n"..PEARL.ICONS.PLAYER_STATE.DROP_ITEMS.." "..(
                    drop_type == DROP_TYPE.ALL and STRINGS.PEARL.LOGS.INV_REPORT_DROPPED or STRINGS.PEARL.LOGS.INV_RARE_ITEMS_DROPPED
                )
            ))
        end

        local message = Message():AddEmbed(embed)
        if PEARL.CONFIG.INVENTORY_REPORTER.USE_AI and PEARL.DiscordProxy:IsRunning() then
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
