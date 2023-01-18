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


local table, string = table, string

-- We don't care about some punctuation or space characters around the letters
-- of the filtered word.
local IGNORE_NON_LETTERS = "[%p%s]*"--"[^%l%dřť]*"

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function AddPattern(self, word)
    if not self.patterns then
        self.patterns = {}
    end

    -- 'word' should contain always just letters (no spaces or digits)
    local i = 0
    word = word:gsub("%S", function(char)
        i = i + 1

        if i < #word then
            return char..IGNORE_NON_LETTERS
        end

        return char
    end)

    table.insert(self.patterns, word)
end

local function OnGamePostInit(self)
    for _, dict in pairs(self.dictionaries) do
        if type(dict.loose_match) == "table" then
            -- These are already decoded
            for _, word in ipairs(dict.loose_match) do
                AddPattern(self, word)
            end
        end
    end
end

----------------------------------
-- [[ Initialization ]]
----------------------------------

-- Load this after game init since some of the dictionaries are not loaded yet.
AddGamePostInit(function()
    if not ProfanityFilter then
        return
    end

    --- @TODO: Add option to add custom filters.
    ProfanityFilter:AddDictionary("czech", PEARL.loadfile("languages/filters/czech"))
    OnGamePostInit(ProfanityFilter)

    function ProfanityFilter:Apply(input)
        if input == nil or input == "" then
            return input
        end

        input = string.lower(input)

        -- Replace profanity with asterisks
        for _, pattern in ipairs(self.patterns) do
            input = input:gsub(pattern, function(match)
                return string.rep("*", #match)
            end)
        end

        return input
    end
end)
