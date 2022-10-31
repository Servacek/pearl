setfenv(1, _G.SUB.env)
local TheSim, TheShard, TheNet = TheSim, TheShard, TheNet
local SUB = SUB
local toarrayornil, ParseUserSessionData = toarrayornil, ParseUserSessionData
local os, string, table = os, string, table


-- Disable Discord Formatting
function string.DDF(str)
    if str ~= nil then
        for _, char in ipairs(SUB.CONSTANTS.FORMAT_CHARS) do
            str = str:gsub("%"..char, "%\\"..char)
        end
    end

    return str
end

-- Make the first letter upper case
function string.capitalize(str)
    return (tostring(str):gsub("^%l", string.upper))
end

-- Replaces all known dst emoticons in a string with discord emojis
function string.emojify(str)
    for utf8_str, emoji in pairs(SUB.ICONS.DISCORD_EMOTES) do
        str = str:gsub("%"..utf8_str, "%"..emoji)
    end

    return str
end

-- Returns a discord emoji string or the input string if no result was found
function string.to_emoji(utf8_icon)
    return SUB.ICONS.DISCORD_EMOTES[utf8_icon] or utf8_icon
end

function string.codeblock(str)
    return "`"..str:gsub("`", "'").."`"
end

function string.italic(str)
    return "*"..str:gsub("*", "\\*").."*"
end

function string.bold(str)
    return "**"..str:gsub("*", "\\*").."**"
end

function string.timestampize(str)
    if str ~= nil then
        return string.codeblock("["..os.date("%H:%M:%S", os.time()).."]:").." "..str
    end
end

function string.iconize(str, icon)
    if str ~= nil and icon ~= nil then
        return icon.." "..str
    end

    return str
end

----------------------------------------------
-- Logging

function SUB.log(level, class, ...)
    local args = toarrayornil(...)
    if not args then return end

    level = level and "["..string.capitalize(tostring(level)).."] " or ""
    class = class and tostring(class)..": " or ""

    TheSim:LuaPrint("[SUB] "..level..""..class..""..table.concat(args, " "))
end

function SUB.debug(class, ...)
    if not SUB.CONSTANTS.DEBUG_MODE_ENABLED then
        return
    end

    return SUB.log("debug", class, ...)
end

function SUB.info(class, ...)
    return SUB.log(nil, class, ...)
end

function SUB.error(class, ...)
    return SUB.log("error", class, ...)
end

---------------------------------

-- Note: The result contains the center entity
function SUB.GetEntitiesNear(center, radius, musttags, canttags, mustoneoftags)
    local x, y, z = center.Transform:GetWorldPosition()
    if x == nil or y == nil or z == nil then return {} end

    return TheSim:FindEntities(x, y, z, radius, musttags, canttags, mustoneoftags) or {}
end

function SUB.GetShardName()
    if TheShard:IsMaster() then
        return "Master"
    end

    return "Caves"
end

function SUB.PrefabToName(prefab)
    return STRINGS.NAMES[string.upper(prefab)] or "MISSING_NAME"
end

function SUB.EntitiesToString(entities, center)
    local counted = {}
    local length = 0

    if entities ~= nil then
        for _, ent in ipairs(entities) do
            if ent ~= center then
                if counted[ent.prefab] == nil then
                    counted[ent.prefab] = 1
                    length = length + 1
                else
                    counted[ent.prefab] = counted[ent.prefab] + 1
                end
            end
        end
    end

    local result = ""
    local sep = ", "
    for prefab, count in pairs(counted) do
        local name = SUB.PrefabToName(prefab)

        if length == 2 or length == 1 then -- if we are one tile before end
            sep = ""
        end

        if length == 1 and #result > 0 then -- If we are on end of the list
            result = result.." a "
        end

        if count > 1 then
            result = result..count.."x "..name..sep
        else
            result = result..name..sep
        end

        length = length - 1
    end

    return result
end

function SUB.IsMonitored(entity)
    return entity ~= nil and entity:IsValid()
    and (entity:HasTag("structure") or entity:HasTag("plant"))
end

function SUB.IsBurnable(inst)
    return inst ~= nil and inst.components ~= nil and inst.components.burnable ~= nil
end

function SUB.ArrayContainsEntityWithTag(entities, tag, checkfn)
    if entities == nil or tag == nil then
        return false
    end

    for i, v in ipairs(entities) do
        if v:HasTag(tag) and (checkfn == nil or checkfn(v)) then
            return true
        end
    end

    return false
end

function SUB.ExtinguishFiresNear(x, y, z)
    if x ~= nil and y ~= nil and z ~= nil then
        local fire_entities = TheSim:FindEntities(
            x, y, z, SUB.CONSTANTS.EXTINGUISH_RADIUS,
            nil, -- must-have tags
            {'wildfireprotected', 'campfire', 'NOCLICK', 'FX','DECOR','INLIMBO','burnt'}, -- cant-have tags
            {'fire','smolder'} -- must-have-one tags
        )

        for _, ent in ipairs(fire_entities) do
            if ent.components.burnable then
                ent.components.burnable:Extinguish()
            end
        end
    end
end


local function GetItemCount(item)
    if item.components and item.components.stackable then
        return item.components.stackable:StackSize()
    elseif item.data and item.data.stackable then
        return item.data.stackable.stack
    else
        return 1
    end
end

-- Returns a table with format {prefab=count}, owners prefab, name and age on success
-- otherwise -> nil
function SUB.GetInventoryTabelFor(ku_id)
    if ku_id == nil then
        return
    end

    local target_prefab, target_name--, target_age
    local inventory = {}

    local function AddToInv(item)
        if item ~= nil and item.prefab then
            if not inventory[item.prefab] then
                inventory[item.prefab] = 0
            end
            inventory[item.prefab] = inventory[item.prefab] + GetItemCount(item)
        end
    end

    -- If the player is currently playing on the server
    for _, player in pairs(AllPlayers) do
        if player.userid == ku_id and player.components.inventory then
            local inv = player.components.inventory

            -- if player.Network then
            --     target_age = player.Network:GetPlayerAge()
            -- else
            --     target_age = 0
            -- end
            target_prefab = player.prefab
            target_name = player:GetDisplayName() or player.name

            -- we also want to check walter's woby
            if player.woby and player.woby.components and player.woby.components.container.slots then
                for _, item in pairs(player.woby.components.container.slots) do
                    AddToInv(item)
                end
            end

            --- [[ Main inventory ]] ---
            if inv.maxslots then
                for i = 1, inv.maxslots do
                    local item = inv:GetItemInSlot(i)

                    if item ~= nil then
                        AddToInv(item)

                        -- for bundles and gifts
                        if item.components and item.components.unwrappable and item.components.unwrappable.itemdata then
                            for _, v in pairs(item.components.unwrappable.itemdata) do
                                AddToInv(v)
                            end
                        end
                    end
                end
            end

            --- [[ Equip Slots ]] ---
            if inv.equipslots then
                for _, item in pairs(inv.equipslots) do
                    AddToInv(item)
                end
            end

            --- [[ Backpack inventory ]] ---
            local container = inv:GetOverflowContainer()
            if container ~= nil then
                for _, item in pairs(container:ReferenceAllItems()) do
                    AddToInv(item)

                    -- for bundles inside a backpack
                    if item.components and item.components.unwrappable and item.components.unwrappable.itemdata then
                        for _, v in pairs(item.components.unwrappable.itemdata) do
                            AddToInv(v)
                        end
                    end
                end
            end

            return inventory, target_prefab, target_name--, target_age
        end
    end

    -- The player is not online so we will try to get the saved inventory
    print("Selected player is currently not playing on the server.")
    print("Trying to load saved inventory for this player...")
    local sessionid = TheNet:GetSessionIdentifier()
    local file = TheNet:GetUserSessionFile(sessionid, ku_id)
    if file ~= nil then
        TheNet:DeserializeUserSession(file, function(success, str)
            if success and str then
                local playerdata, _ = ParseUserSessionData(str)

                if not playerdata or not playerdata.data or not playerdata.data.inventory then
                    return
                end

                target_prefab = playerdata.prefab
                -- target_age = playerdata.age
                local inv_data = playerdata.data.inventory

                -- we also want to check walter's woby
                if playerdata.data.woby and playerdata.data.woby.data and playerdata.data.woby.data.container
                and playerdata.data.woby.data.container.items then
                    for _, v in pairs(playerdata.data.woby.data.container.items) do
                        AddToInv(v)
                    end
                end

                --- [[ Main Inventory ]] ---
                if inv_data.items then
                    for _, item in pairs(inv_data.items) do
                        AddToInv(item)

                        -- for bundles
                        if item.data and item.data.unwrappable and item.data.unwrappable.items then
                            for _, v in pairs(item.data.unwrappable.items) do
                                AddToInv(v)
                            end
                        end
                    end
                end

                if not inv_data.equip then
                    return
                end

                --- [[ Equip slots ]] ---
                local body_slot_item = inv_data.equip.body
                local hands_slot_item = inv_data.equip.hands
                local head_slot_item = inv_data.equip.head

                if hands_slot_item then
                    AddToInv(hands_slot_item)
                end

                if body_slot_item then
                    AddToInv(body_slot_item)

                    -- In case of a backpack
                    if body_slot_item.data and body_slot_item.data.container and body_slot_item.data.container.items then
                        for _, item in pairs(body_slot_item.data.container.items) do
                            AddToInv(item)

                            -- for bundles inside the backpack
                            if item.data and item.data.unwrappable and item.data.unwrappable.items then
                                for _, v in pairs(item.data.unwrappable.items) do
                                    AddToInv(v)
                                end
                            end
                        end
                    end
                end

                if head_slot_item then
                    AddToInv(head_slot_item)
                end
            end
        end)

        return inventory, target_prefab, target_name
    end
end

-- function RGBToHex(r, g, b)
--     return string.format("#%02X%02X%02X", r, g, b)
-- end