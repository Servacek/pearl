--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category BackEnd

require("util/profanityfilter")

-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local type = type

local string = string
local lower = string.utf8lower
local len = string.utf8len

local strhash = smallhash

-------------------------------------
-- [[ Contants ]]
-------------------------------------

local DEFAULT_REPL_CHAR = "*"
-- Word is a sequence of visible characters.
-- Split at puncational characters as well.
local WORD_PATTERN = "[^%s%p%c%z]+"
local CAPITAL_SPLIT = "%u*[^%u.]+"

local FILTER_PATH = PEARL.SRCDIR.."languages/filters/%s.lua"
local FILTER_RPATH = "languages/filters/%s"

-------------------------------------
-- [[ Private ]]
-------------------------------------

local lose_patterns = {}
local exact_patterns = {}

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function addpattern(self, name)
    local dict = self.dictionaries[name]
    if type(dict) ~= "table" then
        return PEARL.error("Dictionary is invalid or not existent!")
    end

    if dict.loose_match then
        for i = 1, #dict.loose_match do
            -- Just to make sure all alphanumeric characters in the pattern are lower case.
            lose_patterns[#lose_patterns + 1] = lower(dict.loose_match[i])
        end
    end

    if dict.exact_match then
        for hash, _ in pairs(dict.exact_match) do
            exact_patterns[tonumber(hash)] = true
        end
    end
end

local function checkword(word)
    if exact_patterns[strhash(word)] then
        return true
    end

    for i = 1, #lose_patterns do
        if word:find(lose_patterns[i]) then
            return true
        end
    end
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

-- repl can be either a pattern for replacing the slur word or a character replacing it.
function ProfanityFilter:Apply(text, repl, pattern)
    if type(text) ~= "string" or #text <= 1 then
        return text
    end

    repl = repl or DEFAULT_REPL_CHAR
    text = text:gsub(WORD_PATTERN, function(word)
        -- No lowering or other changes here. Keep the word as is.
        if self:Detect(word) then
            if pattern == true then
                return repl:format(word)
            else
                return string.rep(repl, len(word))
            end
        end
    end)

    return text
end

-- We use our custom function for this since the default one doesn't support patterns.
function ProfanityFilter:Detect(text)
    if type(text) ~= "string" or #text <= 1 then
        return false
    end

    for word in text:gmatch(WORD_PATTERN) do
        local mcount = 0
        local capitals = word:gmatch(CAPITAL_SPLIT)
        if capitals then
            -- ForWordsInCamelCase
            for capital in capitals do
                mcount = mcount + #capital
                if checkword(capital:lower()) == true then
                    return true
                end
            end
        end

        if mcount ~= #word and checkword(word:lower()) == true then
            return true
        end
    end

    return false
end

function ProfanityFilter:CountSwears(text)
    if type(text) ~= "string" or #text <= 1 then
        return 0
    end

    local count = 0
    for word in lower(text):gmatch(WORD_PATTERN) do
        if exact_patterns[strhash(word)] then
            count = count + 1
        else
            for i = 1, #lose_patterns do
                if word:find(lose_patterns[i]) ~= nil then
                    count = count + 1
                    break -- There is just one possible profanity per word.
                end
            end
        end
    end

    return count
end

-------------------------------------
-- [[ Initialization ]]
-------------------------------------

-- Load this after sim init since some of the dictionaries load in frontend.
-- Also some dictionaries can be added by other mods, ignore them.
PEARL.AddSimPostInit(function()
    if PEARL.CONFIG.PROFANITY_FILTERS.default == true then
        addpattern(ProfanityFilter, "default")
    else
        ProfanityFilter:RemoveDictionary("default")
    end

    for _, pf in ipairs(PEARL.CONFIG.PROFANITY_FILTERS) do
        local path = FILTER_PATH:format(pf)
        if not io.exists(path) then
            PEARL.error("Filter", pf, "wasn't found!")
        else
            PEARL.debug("ProfanityFilter:AddDictionary", pf)
            local filter = PEARL.loadfile(FILTER_RPATH:format(pf))

            -- Ensure that the required fields are provided.
            filter.loose_match = filter.loose_match or {}
            filter.exact_match = filter.exact_match or {}

            ProfanityFilter:AddDictionary(
                pf, PEARL.loadfile(FILTER_RPATH:format(pf))
            )
            addpattern(ProfanityFilter, pf)
        end
    end
end)
