
local PEARL = PEARL

local MAX_COMMAND_LENGTH = 500

-------------------------------
-- [[ Handlers ]]
-------------------------------
--- @TODO

local function OnCommandExecuted(doer, fnstr)
    if not doer or doer.admin or not (type(fnstr) == "string" and #fnstr > 0) then
        return
    end

    if #fnstr > MAX_COMMAND_LENGTH then
        fnstr = fnstr:take(MAX_COMMAND_LENGTH).."..."
    end

    PEARL.Logger:LogStringRaw(STRINGS.PEARL.LOGS.CONSOLE_CMD:format(
        doer:GetDisplayName(), fnstr
    ), PEARL.ICONS.PLAYER_STATE.CMD_SEND)
end

local function OnTakeRareItem(doer, data)
    if not (doer and data and data.item) then
        return
    end

    PEARL.Announce(subfmt(STRINGS.PEARL.ACTIONS.TAKE_ITEM.GENERIC, {
        doer = doer:GetDisplayName(), count = (data.stacksize or 1), item = data.item:GetDisplayName()
    }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE, doer.entity)
end

local function OnFinishedLooting(doer, data)
    if not (doer and data and data.loot and data.container) then
        return
    end

    local loot_string = PEARL.FormatSortedPrefabs(data.loot)
    PEARL.Announce(subfmt(STRINGS.PEARL.ACTIONS.TAKE_ITEM.FROM, {
        doer = doer:GetDisplayName(), items = loot_string, target = data.container:GetDisplayName()
    }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE, doer.entity)
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

AddPlayerPostInit(function(player)
    if not player then
        return
    end

    player:ListenForEvent("ms_commandexecuted", OnCommandExecuted)

    -- @TODO
    -- player:AddComponent("thief")
    -- player:ListenForEvent("tookrareitem", OnTakeRareItem)
    -- player:ListenForEvent("finishedlooting", OnFinishedLooting)
end)
