--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-- Prefab names of some important entities we care of

--- @class PREFABS
local PREFABS = {
	ACTIVATABLE = {
		["terrarium"] = true,
	},

	OFFENSIVE_BOOKS = {
        ["book_tentacles"] = true,
        ["book_brimstone"] = true,
        ["book_moon"]      = true,
        ["book_rain"]      = true,
    },

	MOBS = {
		COMPANIONS = {
			--["glommer"] = true, -- Exclude glommer for now, cuz of Krampus farms...
			["hutch"] = true,
			["chester"] = true,
			["friendlyfruitfly"] = true,
			["eyeturret"] = true,
		},

		-- table<prefab, pop_threshold>
		-- The population number under which we will start to announce killing these.
		MONITOR_POPULATION = {
			["beefalo"] = 5,
			["lightninggoat"] = 1,
		},

		FIRE_SPREADERS = { -- Especially after death
			["firehound"] = true,
			["lavae"] = true,
		}
	},

	-- Values represent suspicioness in percents
	RARE_ITEMS = {
		-- Very Rare

		["deerclops_eyeball"] 	= 1,
		["dragon_scales"]		= 1,
		["bearger_fur"] 		= 1,
		["minotaurhorn"]	 	= 1,
		["atrium_key"] 			= 1,
		["shroom_skin"] 		= 1,
		["skeletonhat"] 		= .9,
		["armorskeleton"] 		= .9,
		["krampus_sack"] 		= .9,
		["eyeturret_item"] 		= 1,

        ["gears"]               = .5, -- Highly renewable
        ["fossil_piece"]        = .9, -- Non-renewable currently. Required for the final boss.

		["moonrockseed"] 		= 0,
		["mandrake"]	 		= .7,
		["cookedmandrake"]		= .5,
		["chester_eyebone"] 	= 0,
		["glommerflower"] 		= 0,
		["hutch_fishbowl"] 		= 0,
		["panflute"] 			= .8,
		["blueprint"] 			= .5,
		["hivehat"] 			= .8,
		["yellowamuletlight"] 	= .8,
		["greenamulet"] 		= .8,
		["orangeamulet"] 		= .8,
		["icepack"] 			= .8,
		["ruinshat"] 			= .8,
        ["yellowstaff"] 		= .8,
		["ruins_bat"] 			= .8,
		["armorruins"] 			= .8,
        ["nightmarefuel"]       = .005,
        ["horrorfuel"]          = .6,
        ["livinglog"]           = .005,
        ["purebrilliance"]      = .6,
		["thulecite"] 			= .3,
		["greenstaff"]			= .8,
		["orangestaff"]			= .8,
		["walrushat"]			= .4,
		["walrus_tusk"]			= .3,

        -- New staff
        ["alterguardianhat"]    = .9,
        ["sword_lunarplant"]    = .9,
        ["armor_lunarplant"]    = .9,
        ["thurible"]            = .9,
	},

	--- table<prefab, radius>
	AREA_DESTRUCTIVE_STAFFS = {
		["staff_tornado"] = 6,
	},

	-- The radius here is taken from the propagator component of the target if possible.
	-- The value here is used as a fallback.
	--- table<prefab, radius>
	AREA_IGNITE_STAFFS = {
		["yellowstaff"] = 4,
		["firestaff"] = 6,
        [STRINGS.PYROMANCY.FIRE_BALL] = 4,
        [STRINGS.PYROMANCY.FIRE_BURST] = 2,
	},

	-- These only affect the target.
	DESTRUCTION_ITEMS = {
		["greenstaff"] = true,
	},

	FIRE_SOURCES = {
		["campfire"] = true,
		["stafflight"] = true,
	},

	-- Actions like hammering or turning off will have additional
	-- checks for structures listed below. So we prevent griefers
	-- and untrusted players from removing them.
	EMERGENCY_STRUCTURES = {
		["firesuppressor"] = true,
	},

    -- Use Character STARTING ITEMS instead
	-- table of character specific items
	-- {'<item.prefab>' = {character_prefabs}}
	-- CHARACTER_ITEMS = {

	-- },

    DO_DIGUP = {
        ["forgetmelots"]        = true,
        ["pirate_stash"]        = true,
        ["mound"]               = true, -- Digging up graves.
        ["farm_soil_debris"]    = true,
    },

    DO_NOT_DIGUP_FOREST = {
        ["green_cap"]    = true,
        ["blue_cap"]     = true,
    },

    DO_NOT_CHOP = {
        ["oceantree_pillar"] = true,
    },

    DO_NOT_MINE = {
        ["statueglommer"]        = true,
        ["cave_entrance"]        = true, -- For the annoying bats...

        -- Announce mining stalagmites as well,
        -- since they are not renewable (the only source of fossils).
        ["stalagmite_full"]      = true,
        ["stalagmite_med"]       = true,
        ["stalagmite_low"]       = true,
        ["stalagmite_tall_full"] = true,
        ["stalagmite_tall_med"]  = true,
        ["stalagmite_tall_low"]  = true,
    },
}

return PREFABS
