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
-- [[ Local Functions ]]
-------------------------------------

local function AddPatternsFromDict(self, name)
    if type(self.patterns) ~= "table" then
        self.patterns = {}
    end

    local dict = self.dictionaries[name]
    if type(dict) ~= "table" or type(dict.loose_match) ~= "table" then
        return PEARL.error("Dictionary is invalid or not existent!")
    end

    for i = 1, #dict.loose_match do
        self.patterns[#self.patterns + 1] = dict.loose_match[i]
    end
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function ProfanityFilter:Apply(text)
    if type(text) ~= "string" or not self.patterns then
        return text
    end

    -- Replace profanity with asterisks
    local n
    text = text:gsub(WORD_PATTERN, function(word)
        word = lower(word)
        n = len(word)
        for i = 1, #self.patterns do
            if word:find(self.patterns[i]) then
                return string.rep(REPL_CHAR, n)
            end
        end
    end)

    return text
end

-------------------------------------
-- [[ Initialization ]]
-------------------------------------

-- Load this after sim init since some of the dictionaries load in frontend.
-- Also some dictionaries can be added by other mods, ignore them.
PEARL.AddSimPostInit(function()
    if PEARL.CONFIG.PROFANITY_FILTERS.default == true then
        AddPatternsFromDict(ProfanityFilter, "default")
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
            ProfanityFilter:AddDictionary(
                pf, PEARL.loadfile(FILTER_RPATH:format(pf))
            )
            AddPatternsFromDict(ProfanityFilter, pf)
        end
    end
end)
