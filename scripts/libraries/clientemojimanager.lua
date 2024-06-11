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

--- Using the ID variable in the name wasn't the luckiest idea indeed...
local PERSISTENT_DATA_FILEPATH = "3122299418_emoji_data"

local DELIM = PEARL.CONSTS.DELIMS.EMOJI
local EMOJI_ALIAS_FORMAT = DELIM.."%s"..DELIM

local MAX_ALIAS_LEN = 32

local MAX_FU_EMOJIS = 32

--- An emoji is considered new when it was created within a month
--- and was not already displayed.
local NEW_MAX_TIME = 30 * 24 * 60 * 60

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class ClientEmojiManager
local ClientEmojiManager = {
    _persistdata = {
        frequently_used = {},
        favourites      = {},
        displayed       = {},
    },

    _encode_save_data = not PEARL.CONFIG.DEBUG_MODE,
    _unsaved_changes = false,
}

-------------------------------------
-- [[ Static ]]
-------------------------------------

ClientEmojiManager.CATEGORIES_ORDERED = {
    {
        id = "FAVORITES",
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.FAVORITES,
        emojis = {},
        loadfn = function(self, data)
            local favourites_ids = table.keys(data.favourites)
            table.join(table.iclear(self.emojis), favourites_ids)
        end,
    },

    {
        id = "FREQUENTLY_USED",
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.FREQUENTLY_USED,
        emojis = {}, -- Has to be loaded
        --searchable = false, -- Do not allow the emojis in this category to be searchable since they are dupes.
        maxrows = 2,
        validatefn = function(self, data)
            table.limit(data.frequently_used, MAX_FU_EMOJIS)

            for k, v in pairs(data.frequently_used) do
                if PEARL.EMOJIS.DATA[k] == nil then
                    data.frequently_used[k] = nil -- Rmeove invalid emojis or non-existent emojis.
                end

                if type(v) == "table" then -- For compatibility with older saves
                    data.frequently_used[k] = v.count
                end
            end
        end,
        sortfn = function(id_a, id_b)
            local frequently_used = ClientEmojiManager._persistdata.frequently_used
            return frequently_used[id_a] > frequently_used[id_b]
        end,
        loadfn = function(self, data)
            local frequently_used_ids = table.keys(data.frequently_used)
            table.sort(frequently_used_ids, self.sortfn)
            table.iclear(self.emojis)
            table.join(self.emojis, frequently_used_ids)
        end,
    },

    {
        id = "DISCORD",
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

function ClientEmojiManager:_ValidatePersistentData(data)
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

function ClientEmojiManager:IsEmojiNew(emoji_id)
    local emoji_data = PEARL.EMOJIS.DATA[emoji_id]
    return self:IsEmojiAvailable(emoji_id) and not self:WasEmojiAlreadyDisplayed(emoji_id)
        and (not emoji_data.timecreated or (os.time() - emoji_data.timecreated) < NEW_MAX_TIME)
end

--- @param category ClientEmojiManager.CATEGORY
function ClientEmojiManager:HasCategoryAnyAvailableEmojis(category)
    for _, emoji_id in pairs(category.emojis) do
        if self:IsEmojiAvailable(emoji_id) then
            return true
        end
    end

    return false
end

function ClientEmojiManager:HasAnyAvailableEmojis()
    for _, category in pairs(ClientEmojiManager.CATEGORIES_ORDERED) do
        if self:HasCategoryAnyAvailableEmojis(category) then
            return true
        end
    end

    return false
end

function ClientEmojiManager:HasAnyNewEmojis()
    for _, emoji_data in pairs(PEARL.EMOJIS.DATA) do
        if self:IsEmojiNew(emoji_data.emoji_id) then
            return true
        end
    end

    return false
end

function ClientEmojiManager:HasAnyUnsavedChanges()
    return self._unsaved_changes == true
end

function ClientEmojiManager:WasEmojiAlreadyDisplayed(emoji_id)
    return self._persistdata.displayed[emoji_id] == true
end

function ClientEmojiManager:IsEmojiFavorite(emoji_id)
    return self._persistdata.favourites[emoji_id] == true
end

function ClientEmojiManager:IsEmojiAvailable(emoji_id)
    return PEARL.EMOJIS.IsEmojiAvailable(emoji_id)
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

--- @return boolean
function ClientEmojiManager:SavePersistentData()
    PEARL.ClusterPersistence:SetFileContent(
        PERSISTENT_DATA_FILEPATH, ZipAndEncodeString(self._persistdata), self._encode_save_data
    ) then
        self._unsaved_changes = false
        return true
    end

    return false
end

--- @return boolean
function ClientEmojiManager:LoadPersistentData()
    local datastr = PEARL.ClusterPersistence:GetFileContent(PERSISTENT_DATA_FILEPATH, true)
    local data = DecodeAndUnzipString(datastr)
    if type(data) == "table" then
         -- Load up in the existing table in case it is being referenced somewhere already.
        table.update(self._persistdata, data)

        self:_ValidatePersistentData(self._persistdata)
    end
end

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

function ClientEmojiManager:OnEmojiUsed(emoji_id)
    PEARL.debug("ClientEmojiManager:OnEmojiUsed", emoji_id)

    local category = ClientEmojiManager.CATEGORY.FREQUENTLY_USED
    self._persistdata.frequently_used[emoji_id] = (self._persistdata.frequently_used[emoji_id] or 0) + 1
    table.reinsort(category.emojis, emoji_id, category.sortfn)
end

function ClientEmojiManager:OnEmojiFavoriteToggled(emoji_id)
    PEARL.debug("OnEmojiFavoriteToggled", emoji_id)

    if self:IsEmojiFavorite(emoji_id) then
        self._persistdata.favourites[emoji_id] = nil
        table.removearrayvalue(ClientEmojiManager.CATEGORY.FAVORITES.emojis, emoji_id)
    else
        self._persistdata.favourites[emoji_id] = true
        --- Simply add it to the end of the list.
        table.insert(ClientEmojiManager.CATEGORY.FAVORITES.emojis, emoji_id)
    end

    self._unsaved_changes = true

    return self:IsEmojiFavorite(emoji_id)
end

function ClientEmojiManager:OnEmojiDisplayed(emoji_id)
    --PEARL.debug("OnEmojiDisplayed", emoji_id)

    if self._persistdata.displayed[emoji_id] == nil then
        self._persistdata.displayed[emoji_id] = true
        self._unsaved_changes = true
    end
end

-------------------------------------
-- [[ Setup ]]
-------------------------------------

ClientEmojiManager:LoadPersistentData()

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ClientEmojiManager
