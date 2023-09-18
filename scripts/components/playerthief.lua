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
    Detects movements with rare items caused by a player. This is an internal component.
    It doesn't provide basically any useful function to the outside. It uses event's
    for broadcasting information.

    KNOWN BUGS:
    - Taking just a part of a rare item's stack will not be announced.
    - Moving an item to another stack in player's inventory will not be announced.
--]]

--------------------------------------------------------------------------
--[[ Class Declaration - PlayerThief ]]
--------------------------------------------------------------------------

--- @class PlayerThief
return Class(function(self, inst)
    local _inst = inst

    local _ac_items_cache = {}
    local _ac_container = nil

    --------------------------------------------------------------------------
    --[[ Private Atrributes and Methods ]]
    --------------------------------------------------------------------------

    local ClearActiveContainerCache, CacheActiveContainerItems, GetStolenItems

    local function onclosecontainer(doer, container)
        -- Only clean up if we have closed the active container
        if not container or container ~= _ac_container then
            return
        end

        local stolen_items = GetStolenItems()
        if stolen_items and #stolen_items > 0 then
            doer:PushModEvent("finishedlooting", {
                items = stolen_items,
                container = container,
            })
        end

        ClearActiveContainerCache()
    end

    local function onopencontainer(doer, data)
        if not (doer and data and data.container and not data.container:IsInLimbo()) then
            return
        end

        -- Cache all items in the newly opened container
        CacheActiveContainerItems(data.container)
    end

    local function onpickupitem(doer, data)
        if not (doer and data and data.item) then
            return
        end

        if data.item.components.container then
            local rare_items = {}
            for _, item in ipairs(data.item.components.container:GetRareItems()) do
                if not (
                    item.components.inventoryitem:IsLastPlayerOwner(doer) or
                    item.components.inventoryitem:IsLastPicker(doer)
                ) then
                    item.components.inventoryitem:SetLastPicker(doer)

                    rare_items[#rare_items + 1] = item
                end
            end

            if #rare_items > 0 then
                return _inst:PushModEvent("tookrarecontainer", {
                    container = data.item,
                    items = rare_items
                })
            end
        end

        if not data.item.components.inventoryitem:IsRare() then
            return
        end

        _inst:PushModEvent("tookrareitem", data.item)

        data.item.components.inventoryitem:SetLastPicker(_inst)
    end

    local function onplayerdespawned(player)
        onclosecontainer(player, _ac_container)
    end

    --------------------------------

    local function RegisterListeners()
        if not _inst then
            return
        end

        --> Do not use itemget and itemlose events for this since they are used by the Frontend
        --> Use the default ListenForEvent because we remove these events.
        _inst:ListenForEvent("onpickupitem", onpickupitem)
        _inst:ListenForEvent("opencontainer", onopencontainer)
        _inst:ListenForEvent("player_despawn", onplayerdespawned)

        --> Use "closedcontainer" instead of the built-in "closecontainer" event because
        --> that is for some reason called only when closing a container by clicking on it.
        _inst:ListenForModEvent("closedcontainer", onclosecontainer)
    end

    --------------------------------
    -- [[ Setters ]]
    --------------------------------

    CacheActiveContainerItems = function(container)
        if not container.components.container then
            return
        end

        -- We have still an active container! Close it.
        if _ac_container then
            onclosecontainer(_inst, _ac_container)
        end

        _ac_container = container

        container.components.container:ForEachItem(function(item)
            if item.components.inventoryitem:IsRare() then
                _ac_items_cache[#_ac_items_cache + 1] = item
            end
        end)
    end

    ClearActiveContainerCache = function()
        _ac_container = nil

        if _ac_items_cache then
            for i, _ in ipairs(_ac_items_cache) do
                _ac_items_cache[i] = nil
            end
        end
    end

    --------------------------------
    -- [[ Getters ]]
    --------------------------------

    GetStolenItems = function(container)
        local stolen_items = {
            rare = false
        }

        -- Items can be invalid here
        for _, cached_item in ipairs(_ac_items_cache) do
            if cached_item.components.inventoryitem and
                cached_item.components.inventoryitem:IsHeldBy(_inst) and
                not cached_item.components.inventoryitem:IsLastPicker(_inst)
            then
                cached_item.components.inventoryitem:SetLastPicker(_inst)

                stolen_items[#stolen_items + 1] = cached_item

                if cached_item.components.inventoryitem:IsVeryRare() then
                    stolen_items.rare = true
                end
            end
        end

        return stolen_items
    end

    --------------------------------
    -- [[ Handlers ]]
    --------------------------------

    function self:OnRemoveFromEntity()
        if _inst then
            _inst:RemoveModEventCallback("closedcontainer", onclosecontainer)
            _inst:RemoveEventCallback("openedcontainer", onopencontainer)
            _inst:RemoveEventCallback("onpickupitem", onpickupitem)
            _inst:RemoveEventCallback("player_despawn", onplayerdespawned)
        end

        ClearActiveContainerCache()
    end

    --------------------------------
    -- [[ Setup ]]
    --------------------------------

    RegisterListeners()

    --------------------------------------------------------------------------
    --[[ End ]]
    --------------------------------------------------------------------------

end)
