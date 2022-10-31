setfenv(1, _G.SUB.env)
local Embed = require("models/embed")

local TheSim, TheShard, TheNet = TheSim, TheShard, TheNet
local SUB = SUB
local toarrayornil, ParseUserSessionData = toarrayornil, ParseUserSessionData
local os, string, table = os, string, table


---------------------------
-- [[ String Utils ]]
---------------------------

local ESCAPE_CHAR = "\\"

function string:escape(target_char)
    if not self or not target_char or string.len(target_char) ~= 1 then return self end

    local last_char
    return self:gsub("%"..target_char, function(char)
        if char and last_char ~= ESCAPE_CHAR then
            return ESCAPE_CHAR..char
        end

        last_char = char
    end)
end

-- DDF = Disable Discord Formatting
function string:DDF()
    if self then
        for _, char in pairs(SUB.CONSTANTS.FORMAT_CHARS) do
            self = self:escape(char)
        end
    end

    return self
end

function string:packin(char, escape)
    if not self or not char then return self end
    if escape then
        self = string.escape(self, char)
    end

    return string.format("%s%s%s", char, self, char)
end

--- Converts the first letter of the given string to uppercase
--- @return string result The formatted result string
function string:capitalize()
    return self and (self:gsub("^%l", string.upper)) or self
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

--- Formats a string to the codeline format using the discord markdown characters
--- @return string result The formatted string
function string:codeline()
    if self then
        self = self:gsub("`", "'")
    end

    return string.packin(self, "`")
end

--- Formats a string to the codeblock format using the discord markdown characters
--- @return string result The formatted string
function string:codeblock()
    return string.packin(string.escape(self, "`"), "```")
end

--- Formats a string to the italic format using the discord markdown characters
--- @return string result The formatted string
function string:italic()
    return string.packin(self, "*", true)
end

--- Formats a string to the bold format using the discord markdown characters
--- @return string result The formatted string
function string:bold()
    return string.packin(string.escape(self, "*"), "**")
end

--- Adds a fancy discord formatted timestamp at the start of the given string
--- @param str string The string to which the timestamp should be added
--- @param timestamp integer? The timestamp to add to the given string
--- if this is not provided then a new timestamp will be created via os.time()
--- @return string result The formatted string
function string.timestampize(str, timestamp)
    if str ~= nil then
        timestamp = timestamp or os.time()

        return string.bold(string.codeline("["..os.date("%H:%M:%S", os.time()).."]:")).." "..str
    end
end

function string.iconize(str, icon)
    if str ~= nil and icon ~= nil then
        return icon.." "..str
    end

    return str
end

-- Prevents the given link from creating an embed when posted
function string.dislink(link)
    return "<"..link..">"
end

function string.hyperlink(str, link)
    if not str or not link then
        return str
    end

    -- A string containing these brackets could broke the hyperlink
    return "["..str:gsub("%[", "%("):gsub("%]", "%)").."]".."("..link..")"
end

function string:center(count, char)
    if not count then return self end
    char = char or " "

    return string.rep(char, count)..self..string.rep(char, count)
end

--- Checks if string starts with the given prefix
--- @param prefix boolean The prefix we are looking for
--- @return boolean result Whether the prefix was found
function string:startswith(prefix)
    return prefix and self:sub(1, prefix:len()) == prefix
end

--- Checks if string ends with the given suffix
--- @param suffix boolean The suffix we are looking for
--- @return boolean result Whether the suffix was found
function string:endswith(suffix)
    return suffix and suffix:sub(-suffix:len()) == suffix
end

----------------------------------------------

function table.filterarray(tab, checkfn)
    local result = {}
    for _, val in pairs(tab) do
        if checkfn(val) then
            table.insert(result, val)
        end
    end

    return result
end

----------------------------------------------
-- Logging

function SUB.log(level, class, ...)
    local args = toarrayornil(...)
    if not args then
        if class then
            args = class
            class = nil
        else
            return
        end
    end

    level = level and "["..string.capitalize(tostring(level)).."] " or ""
    class = class and tostring(class)..": " or ""

    local content = ""
    if type(args) == "table" then
        for _, arg in pairs(args) do
            content = content..tostring(arg).." "
        end
    else
        content = tostring(args)
    end

    TheSim:LuaPrint("[SUB] "..level..""..class..""..content)
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

function SUB.GetEntitiesNear(center, radius, musttags, canttags, mustoneoftags)
    local x, y, z = center.Transform:GetWorldPosition()
    if x == nil or y == nil or z == nil then return {} end
    local entities = TheSim:FindEntities(x, y, z, radius, musttags, canttags, mustoneoftags) or {}

    return table.filterarray(entities, function(val)
        return val and center and val.GUID ~= center.GUID
    end)
end

function SUB.GetShardName()
    return TheShard:IsMaster() and "Master" or "Caves"
end

function SUB.PrefabToName(prefab)
    return STRINGS.NAMES[string.upper(prefab)] or prefab or "MISSING_NAME"
end

function SUB.IsEmoteCommand(cmd_name)
    return cmd_name and table.contains(SUB.EMOTES, cmd_name)
end

function SUB.IsCommandAllowed(cmd_name)
    return cmd_name and not table.contains(SUB.CONSTANTS.COMMAND_BLOCKLIST, cmd_name)
end

function SUB.EntitiesToString(entities, center)
    local counted = {}
    local length = 0

    if not entities then return end

    for _, ent in pairs(entities) do
        if ent ~= center then -- shouldn't be needed
            if not counted[ent.prefab] then
                counted[ent.prefab] = 1
                length = length + 1
            else
                counted[ent.prefab] = counted[ent.prefab] + 1
            end
        end
    end

    local result = ""
    for prefab, count in pairs(counted) do
        local sep = length > 1 and ", " or ""
        local name = SUB.PrefabToName(prefab)

        -- If we are on the penutlimate prefab
        if length == 2 then
            sep = " and "
        end

        if count and count > 1 then
            result = result..count.."x "..name..sep
        else
            result = result..name..sep
        end

        length = length - 1
    end

    return result
end

function SUB.SafeRun(func, ...)
    if not func then
        SUB.info("SafeRun", "[Warning] Tryed to run a non existing function!")
        return false
    end

    local success, result = pcall(func, ...)
    if not success and result then
        SUB.error("Catched an error while executing function", debug.getinfo(func, "n"), "\n"..tostring(result))

        SUB.Logger:OnError(result)
    end

    return success
end

function SUB.IsMonitored(entity)
    return entity ~= nil and entity:IsValid()
    and (entity:HasTag("structure") or entity:HasTag("plant"))
end

-- Used to determine wheter the client is connecting to the server for the first time
-- or just migrating between the server shards.
function SUB.IsClientMigrating(client)
    return client.prefab ~= "" and client.lobbycharacter == "" and client.playerage > 0
end

function SUB.IsBurnable(inst)
    return inst ~= nil and inst.components ~= nil and inst.components.burnable ~= nil
end

function SUB.ArrayContainsEntityWithTag(entities, tag, checkfn)
    if entities == nil or tag == nil then
        return false
    end

    for _, v in pairs(entities) do
        if v:HasTag(tag) and (checkfn == nil or checkfn(v)) then
            return true
        end
    end

    return false
end


-- TODO: add support for all param
--- @param all any Whether campfires and staff lights should be removed too or not
function SUB.ExtinguishFiresNear(x, y, z, all)
    if x ~= nil and y ~= nil and z ~= nil then
        -- local mustoneoftags = {'fire','smolder'}
        -- if all then
        --     table.insert(mustoneoftags, "heater")
        -- end

        local fire_entities = TheSim:FindEntities(
            x, y, z, SUB.CONSTANTS.EXTINGUISH_RADIUS,
            nil, -- must-have tags
            {'wildfireprotected', 'campfire', 'NOCLICK', 'FX','DECOR','INLIMBO','burnt'}, -- cant-have tags
            {'fire','smolder'} -- must-have-one tags
        )

        for _, ent in pairs(fire_entities) do
            if ent.components.burnable then
                ent.components.burnable:Extinguish()
            end

            -- if all and ent:IsValid() and SUB.PREFABS.FIRE_SOURCES[ent.prefab] then
            --     ent:Remove()
            -- end
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

function SUB.EntityToStringSupportStacks(target)
    if not target then return "" end

    if target.components and target.components.stackable then
        local count = target.components.stackable:StackSize()
        return count.."x "..target:GetDisplayName()
    end

    return target:GetDisplayName() or target.name or ""
end

-- Returns a table with format {prefab=count}, owners prefab, name and age on success
-- otherwise -> nil
function SUB.GetInventoryTabelFor(ku_id, player)
    if ku_id == nil and player == nil then return end

    local target_prefab, target_name--, target_age
    local inventory = {}

    local function AddToInv(item)
        if not item then return end

        if item.prefab then
            if not inventory[item.prefab] then
                inventory[item.prefab] = 0
            end

            inventory[item.prefab] = inventory[item.prefab] + GetItemCount(item)
        end
    end

    local function ProcessInvItem(item)
        if not item then return end

        AddToInv(item)

        -- for bundles and gifts
        if item.components and item.components.unwrappable and item.components.unwrappable.itemdata then
            for _, v in pairs(item.components.unwrappable.itemdata) do
                AddToInv(v)
            end
        end
    end

    -- If the player is currently playing on the server
    player = player or LookupPlayerInstByUserID(ku_id)
    if player and player.components.inventory then
        local inv = player.components.inventory

        target_prefab = player.prefab
        target_name = player:GetDisplayName() or player.name

        -- we also want to check walter's woby
        if player.woby and player.woby.components and player.woby.components.container then
            player.woby.components.container:ForEachItem(ProcessInvItem)
        end

        --- [[ Main inventory ]] ---
        inv:ForEachItem(ProcessInvItem)

        return inventory, target_prefab, target_name--, target_age
    end

    -- The player is not online so we will try to get the saved inventory
    --print("Selected player is currently not playing on the server.")
    --print("Trying to load saved inventory for this player...")
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

                if not inv_data.equip then return end

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

function SUB.InventoryContainsRareItem(inventory)
    if inventory ~= nil then
        for prefab, _ in pairs(SUB.PREFABS.MONITOR_PICKUP) do
            if inventory[prefab] ~= nil then
                return true
            end
        end
    end

    return false
end

function SUB.InventoryToEmbed(inventory, target_prefab, name, userid)
    if inventory and not IsTableEmpty(inventory) and (userid or name) then
        name = name or userid or string.capitalize(target_prefab) or "Anonym"
        local icon = SUB.ICONS.PLAYER_PREFABS[target_prefab] or ""
        local title = icon.." "..string.bold(name).."'s inventory"

        local description = ""
        for prefab, count in pairs(inventory) do
            -- If the item is rare we want to make it bold
            if SUB.PREFABS.MONITOR_PICKUP[prefab] then
                description = description..string.bold(count.."x "..string.hyperlink(
                    SUB.PrefabToName(prefab), string.format(
                        SUB.CONSTANTS.WIKI_URL, prefab
                    )
                )).."\n"
            else
                description = description..string.codeline(count.."x").." "..string.hyperlink(
                    string.codeline(SUB.PrefabToName(prefab)), string.format(
                        SUB.CONSTANTS.WIKI_URL, prefab
                    )
                ).."\n"
            end
        end

        return Embed()
            :SetTitle(title)
            :SetDescription(description)
    end
end

-- function RGBToHex(r, g, b)
--     return string.format("#%02X%02X%02X", r, g, b)
-- end