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

local MAX_FU_EMOJIS = 32

--- An emoji is considered new when it was created within a month
--- and was not already displayed.
local NEW_MAX_TIME = 30 * 24 * 60 * 60

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

--- @TODO: Move this to the table lib extension
local function ensure_boundaries(t, limit)
    while #t > limit do
        t[#t] = nil
    end
end

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
            ensure_boundaries(data.frequently_used, MAX_FU_EMOJIS)

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
        emojis = {},
        optional = true,
        loadfn = function(self) -- Make sure this is loaded only after all the modules.
            for _, pack_name in pairs(PEARL.EMOJIS.PACKS.DISCORD) do
                -- Load these emojis only if their pack is enabled.
                if PEARL.EMOJIS.IsEmojiPackAvailable(pack_name) then
                    print("ENABLING PACK", pack_name)
                    table.join(self.emojis, table.keys(PEARL.EMOJIS.PACK_CHAR_MAP[pack_name]))
                end
            end
        end,
    },

    {
        id = "VANILLA",
        name = STRINGS.PEARL.UI.EMOJI_CATEGORIES.VANILLA,
        emojis = table.values(PEARL.EMOJIS.INPUTNAME_TO_ID, true),
    },
}

--- A category is represented as a table containing some data associated to the specific emoji category.
--- It also contains a list of emoji ids that are specific to this category.
--- Mapped by ID not by order.
--- @enum ClientEmojiManager.CATEGORY
ClientEmojiManager.CATEGORY = {}
for i, category in ipairs(ClientEmojiManager.CATEGORIES_ORDERED) do
    if category.available ~= false then
        --- Make sure every category has the index field (useful for sorting).
        category.index = i
        -- Custom emojis should be right after the frequently used ones
        -- (similiar to how discord implements this)
        ClientEmojiManager.CATEGORY[category.id] = category
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
    if PEARL.ClusterPersistance:SetFileContent(
        PERSISTENT_DATA_FILEPATH, ZipAndEncodeString(self._persistdata), self._encode_save_data
    ) then
        self._unsaved_changes = false
        return true
    end

    return false
end

--- @return boolean
function ClientEmojiManager:LoadPersistentData()
    local _, datastr = PEARL.ClusterPersistance:GetFileContent(PERSISTENT_DATA_FILEPATH, true)
    local data = DecodeAndUnzipString(datastr)
    if type(data) == "table" then
         -- Load up in the existing table in case it is being referenced somewhere already.
        table.update(self._persistdata, data)

        -- Load up all the categories that require loading.
        for _, category in pairs(ClientEmojiManager.CATEGORY) do
            if category.validatefn then
                category:validatefn(self._persistdata)
            end

            if category.loadfn then
                category:loadfn(self._persistdata)
            end
        end
        return true
    end
    return false
end

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

function ClientEmojiManager:OnEmojiUsed(emoji_id)
    PEARL.debug("ClientEmojiManager:OnEmojiUsed", emoji_id)

    local category = ClientEmojiManager.CATEGORY.FREQUENTLY_USED
    self._persistdata.frequently_used[emoji_id] = (self._persistdata.frequently_used[emoji_id] or 0) + 1
    table.reinsort(category.emojis, emoji_id, category.sortfn)

    --- We do not have to update the GUI emojis right now, it will eventually be reloaded anyway.
    -- ensure_boundaries(self._persistdata.frequently_used, MAX_FU_EMOJIS)
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

ClientEmojiManager:OnEmojiUsed("emoji_hunger")
ClientEmojiManager:OnEmojiUsed("emoji_hunger")
ClientEmojiManager:OnEmojiUsed("emoji_hunger")
ClientEmojiManager:OnEmojiUsed("emoji_hunger")
ClientEmojiManager:OnEmojiUsed("emoji_hunger")

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ClientEmojiManager
