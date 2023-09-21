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

local FLAGGED_SUSPICION = .9

local DROP_DEPOS = {
    "firepit"
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

local FEEDBACK_WEIGHT = 0.1

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

--- @TODO: Debug
local function CheckPlayersInventory(world, player)
    local pd = player.components.inventory.legality:Predict(_weights)
    if pd.prediction ~= 1 then
        return -- This inventory is not flagged.
    end

    print("SENDING REPORT TO THE SERVER:")

    local player_meta = PEARL.GetPlayerMetadataFor(player.userid)
    player_meta:SetInventory(player.components.inventory)

    local drop_rare_under_age = PEARL.CONFIG.INVENTORY_REPORTER.DROP_RARE_UNDER_AGE
    local drop_under_age = PEARL.CONFIG.INVENTORY_REPORTER.DROP_RARE_UNDER_AGE
    -- Do not drop in the first days since none is able to have the required age.
    -- Also there is not much rare stuff around in the early game anyway.
    local no_drop_cycles = math.max(drop_rare_under_age, drop_under_age)

    local drop_type = DROP_TYPE.NONE
    if world.state.cycles > no_drop_cycles then
        local age = player_meta:GetAge()
        if age < PEARL.CONFIG.INVENTORY_REPORTER.DROP_UNDER_AGE then
            PEARL.info("Dropping player's inventory...")
            -- Doesn't support depos :(
            player.components.inventory:DropEverything()

            drop_type = DROP_TYPE.ALL
        elseif age < PEARL.CONFIG.INVENTORY_REPORTER.DROP_RARE_UNDER_AGE then
            local depo = next(_depos)
            -- If no depo is available we will drop the items under the player.
            local depo_pos = depo and depo.Transform and depo.Transform:GetWorldPosition()

            PEARL.info("Dropping rare items from player's inventory...", depo)
            player.components.inventory:DropRareItems(0.4, nil, depo_pos)

            drop_type = DROP_TYPE.RARE
        end
    end

    if PEARL.CONFIG.INVENTORY_REPORTER.SEND_REPORT and PEARL.DiscordReporter:IsEnabled() then
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
    if type(player) ~= "table" then
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
    if _depos[inst.GUID] then
        _depos[inst.GUID] = nil
    end
end

local function OnDepoInit(inst)
    _depos[inst.GUID] = inst
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

for _, depo_prefab in ipairs(DROP_DEPOS) do
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
