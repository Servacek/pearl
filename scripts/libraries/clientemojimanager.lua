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
        frequently_used_emojis = {}
    },

    _frequently_used_cat = {},

    _encode_save_data = not PEARL.CONFIG.DEBUG_MODE,

    _emoji_names_map = nil,
}

-------------------------------------
-- [[ Static ]]
-------------------------------------

ClientEmojiManager.CATEGORIES_ORDERED = {
    {
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.FREQUENTLY_USED,
        emojis = ClientEmojiManager._frequently_used_cat,
    },
    {
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.VANILLA,
        emojis = table.keys(PEARL.EMOJIS.GetOwnedVanillaEmojis(TheNet:GetUserID()), true),
    },
}

if PEARL.CONFIG.CUSTOM_EMOJIS then
    -- Custom emojis should be right after the frequently used ones
    -- (similiar to how discord implements this)
    table.insert(ClientEmojiManager.CATEGORIES_ORDERED, 2, {
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.DISCORD,
        emojis = table.keys(PEARL.EMOJIS.DISCORD, true),
    })
end

ClientEmojiManager.BASIC_CATEGORY = {
    -- Display frequently used emojis on the top.
    FREQUENTLY_USED = ClientEmojiManager.CATEGORIES_ORDERED[1],
}

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

function ClientEmojiManager:GetEmojiData(name, emoji)
    for i, emoji_data in ipairs(self._persistdata.frequently_used_emojis) do
        -- In case we have added a new alias to this emoji. We need to find it.
        if emoji_data.emoiji == emoji then
            return i, emoji_data
        end

        for _, emoji_name in ipairs(emoji_data.names) do
            if emoji_name == name then
                return i, emoji_data
            end
        end
    end
end

function ClientEmojiManager:GetRandomEmoji()
    return PEARL.EMOJIS.ALL[GetRandomItem(GetRandomItem(ClientEmojiManager.CATEGORIES_ORDERED).emojis)]
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

        for _, emoji_data in ipairs(self._persistdata.frequently_used_emojis) do
            self._frequently_used_cat[#self._frequently_used_cat + 1] = emoji_data.names[1]
        end

        table.dump(self._persistdata)
    end
end

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

function ClientEmojiManager:OnEmojiUsed(emoji, name)
    local i, emoji_data = self:GetEmojiData(emoji, name)
    emoji_data = emoji_data or {
        names = self:GetAllNamesFromEmoji(emoji),
        emoji = emoji,
        count = 0,
    }

    emoji_data.count = (emoji_data.count or 0) + 1

    if i ~= nil then
        table.remove(self._persistdata.frequently_used_emojis, i)
    end

    local index = table.insort(self._persistdata.frequently_used_emojis, emoji_data, compare_emoji)
    -- Since the indexes should be synced.
    table.insert(self._frequently_used_cat, index, emoji_data.names[1])
end

-------------------------------------
-- [[ Setup ]]
-------------------------------------

ClientEmojiManager:LoadPersistentData()

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ClientEmojiManager
