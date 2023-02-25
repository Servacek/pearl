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
--- @TODO: Filter usernames containing profanity.

require("util/profanityfilter")

-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local type = type

local string = string
local lower = string.utf8lower
local len = string.utf8len

-------------------------------------
-- [[ Contants ]]
-------------------------------------

-- We don't care about some punctuation or space characters around the letters
-- of the filtered word.
-- local IGNORE_NON_LETTERS = "[%p%s]*"
local REPL_CHAR = "*"
local WORD_PATTERN = "%S+"

local FILTER_PATH = PEARL.SRCDIR.."languages/filters/%s.lua"
local FILTER_RPATH = "languages/filters/%s"

-------------------------------------
-- [[ Private ]]
-------------------------------------

local patterns = {}

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function normalize(s)
    return s:gsub("[%p%s]", "")
end

local function addpattern(self, name)
    local dict = self.dictionaries[name]
    if type(dict) ~= "table" or type(dict.loose_match) ~= "table" then
        return PEARL.error("Dictionary is invalid or not existent!")
    end

    for i = 1, #dict.loose_match do
        -- Just to make sure all alphanumeric characters in the pattern are lower case.
        patterns[#patterns + 1] = lower(dict.loose_match[i])
    end
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function ProfanityFilter:Apply(text)
    if type(text) ~= "string" or #text <= 1 then
        return text
    end

    -- Replace profanity with asterisks
    text = text:gsub(WORD_PATTERN, function(word)
        -- Plase no changes to the strings here except of censoring it.
        word = lower(word)
        for i = 1, #patterns do
            if word:find(patterns[i]) ~= nil then
                return string.rep(REPL_CHAR, len(word))
            end
        end
    end)

    return text
end

-- We use our custom function for this since the default one doesn't support patterns.
function ProfanityFilter:Detect(text)
    PEARL.debug("ProfanityFilter:Detect", text)

    if type(text) ~= "string" or #text <= 1 then
        return
    end

    text = normalize(lower(text))
    for i = 1, #patterns do
        if text:find(patterns[i]) ~= nil then
            return true
        end
    end

    return false
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

    --- @TODO: Add more words to the czech filter.
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


-------------------------------------
-- [[ Username Profanity Filter ]]
-------------------------------------

if PEARL.CONFIG.FILTER_USERNAMES then
    PEARL.ServerNetwork:AddClientConnectionFilter(function(userid, data)
        if type(data.username) ~= "string" then
            return
        end

        return not ProfanityFilter:Detect(data.username), "ID_DST_USERNAME_BLOCKED"
    end)
end
