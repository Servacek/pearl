--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Constants ]]
-------------------------------------

local PERSISTENT_DATA_FILEPATH = PEARL.MODID.."_emoji_data"

local DELIM = PEARL.CONSTS.DELIMS.EMOJI
local EMOJI_ALIAS_FORMAT = DELIM.."%s"..DELIM

local MAX_ALIAS_LEN = 32

local MAX_FU_EMOJIS = 32

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

local function compare_emoji(e1, e2)
    return (e1.count or 1) > (e2.count or 1)
end

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class ClientEmojiManager
local ClientEmojiManager = {
    _persistdata = {
        frequently_used = {}
    },

    _encode_save_data = not PEARL.CONFIG.DEBUG_MODE,
}

-------------------------------------
-- [[ Static ]]
-------------------------------------

ClientEmojiManager.CATEGORY = {
    FREQUENTLY_USED = {
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.FREQUENTLY_USED,
        emojis = ClientEmojiManager._persistdata.frequently_used,
        searchable = false, -- Do not allow the emojis in this category to be searchable since they are dupes.
        maxrows = 2,
    },

    VANILLA = {
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.VANILLA,
        emojis = table.keys(PEARL.EMOJIS.GetOwnedVanillaEmojis(TheNet:GetUserID()), true),
    },

    DISCORD = {
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.DISCORD,
        emojis = table.keys(PEARL.EMOJIS.DISCORD, true),
    },
}

ClientEmojiManager.CATEGORIES_ORDERED = {
    ClientEmojiManager.CATEGORY.FREQUENTLY_USED,
    ClientEmojiManager.CATEGORY.VANILLA,
}

ClientEmojiManager.ALL_EMOJIS = deepcopy(ClientEmojiManager.CATEGORY.VANILLA.emojis)
if PEARL.CONFIG.CUSTOM_EMOJIS then
    ConcatArrays(ClientEmojiManager.ALL_EMOJIS, ClientEmojiManager.CATEGORY.DISCORD.emojis)

    -- Custom emojis should be right after the frequently used ones
    -- (similiar to how discord implements this)
    table.insert(
        ClientEmojiManager.CATEGORIES_ORDERED, 2, ClientEmojiManager.CATEGORY.DISCORD
    )
end

-- Use just one list of choices so all emojis have the same probability.
ClientEmojiManager.RANDOM_EMOJI_CHOICES = deepcopy(ClientEmojiManager.ALL_EMOJIS)

-------------------------------------
-- [[ Private Methods ]]
-------------------------------------

function ClientEmojiManager:_EnsureBounderies(t, limit)
    while #t > limit do
        t[#t] = nil
    end
end

function ClientEmojiManager:_ValidatePersistantData(data)
    self:_EnsureBounderies(data.frequently_used, MAX_FU_EMOJIS)

    local names = {}
    for i, emoji_data in ipairs(data.frequently_used) do
        local emoji_names = {}
        for ii, emoji_name in ipairs(emoji_data.names) do
            if emoji_names[emoji_name] then
                -- This emoji name is already contained on the the list of names.
                table.remove(emoji_data.names, ii)
            elseif names[emoji_name] then
                -- Emoji with this name already on the emoji list.
                table.remove(data.frequently_used, i)
            end

            emoji_names[emoji_name] = true
            names[emoji_name] = true
        end
    end
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function ClientEmojiManager:GetEmojiNamesMap(reload)
    if self._emoji_names_map and not reload then
        return self._emoji_names_map
    end

    self._emoji_names_map = self._emoji_names_map or {}
    table.clear(self._emoji_names_map)

    for _, category in ipairs(ClientEmojiManager.CATEGORIES_ORDERED) do
        for alias, emoji in pairs(category.emojis) do
            local alias_full = EMOJI_ALIAS_FORMAT:format(alias)
            if not self._emoji_names_map[emoji] or self._emoji_names_map[emoji]:len() < MAX_ALIAS_LEN then
                if self._emoji_names_map[emoji] ~= nil then
                    self._emoji_names_map[emoji] = self._emoji_names_map[emoji].." "..alias_full
                else
                    self._emoji_names_map[emoji] = alias_full
                end
            end
        end
    end

    return self._emoji_names_map
end

function ClientEmojiManager:GetNameFromEmoji(emoji)
    return table.getkey(PEARL.EMOJIS.ALL, emoji)
end

function ClientEmojiManager:GetAllNamesFromEmoji(emoji)
    return table.getallkeys(PEARL.EMOJIS.ALL, emoji)
end

function ClientEmojiManager:HasAnyEmojis()
    for _, set in pairs(ClientEmojiManager.CATEGORIES_ORDERED) do
        if table.empty(set) == false then
            return true
        end
    end

    return false
end

function ClientEmojiManager:GetEmojiData(emoji, name)
    for i, emoji_data in ipairs(self._persistdata.frequently_used) do
        -- In case we have added a new alias to this emoji. We need to find it.
        if emoji_data.emoji == emoji then
            return i, emoji_data
        end

        for _, emoji_name in ipairs(emoji_data.names) do
            if emoji_name == name then
                return i, emoji_data
            end
        end
    end
end

local last_random_emoji_name
function ClientEmojiManager:GetRandomEmoji()
    local choices = ClientEmojiManager.RANDOM_EMOJI_CHOICES
    if last_random_emoji_name ~= nil then
        -- Do not make the last random emoji a choice.
        table.removearrayvalue(choices, last_random_emoji_name)
    end

    local new_random_name = GetRandomItem(choices)
    if last_random_emoji_name ~= nil then
        table.insert(ClientEmojiManager.RANDOM_EMOJI_CHOICES, last_random_emoji_name)
    end

    last_random_emoji_name = new_random_name

    return PEARL.EMOJIS.ALL[new_random_name]
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

function ClientEmojiManager:SavePersistentData()
    PEARL.ClusterPersistance:SetFileContent(
        PERSISTENT_DATA_FILEPATH, ZipAndEncodeString(self._persistdata), self._encode_save_data
    )
end

function ClientEmojiManager:LoadPersistentData()
    local _, datastr = PEARL.ClusterPersistance:GetFileContent(PERSISTENT_DATA_FILEPATH, true)
    local data = DecodeAndUnzipString(datastr)
    if type(data) == "table" then
        table.update(self._persistdata, data)

        self:_ValidatePersistantData(self._persistdata)

        table.dump(self._persistdata)
    end
end

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

function ClientEmojiManager:OnEmojiUsed(emoji, name)
    PEARL.debug("ClientEmojiManager:OnEmojiUsed", emoji, name)

    local i, emoji_data = self:GetEmojiData(emoji, name)
    emoji_data = emoji_data or {
        names = self:GetAllNamesFromEmoji(emoji),
        emoji = emoji,
        count = 0,
    }

    emoji_data.count = (emoji_data.count or 0) + 1

    if i ~= nil then
        table.remove(self._persistdata.frequently_used, i)
    end
    table.insort(self._persistdata.frequently_used, emoji_data, compare_emoji)

    self:_EnsureBounderies(self._persistdata.frequently_used, MAX_FU_EMOJIS)
end

-------------------------------------
-- [[ Setup ]]
-------------------------------------

ClientEmojiManager:LoadPersistentData()

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ClientEmojiManager
