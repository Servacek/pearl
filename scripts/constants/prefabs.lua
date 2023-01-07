--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-- Prefab names of some important entities we care of

return {
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
			["glommer"] = true,
			["hutch"] = true,
			["chester"] = true,
			["friendlyfruitfly"] = true,
			["eyeturret"] = true,
		},

		-- table<prefab, pop_threshold>
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
		--["waxwelljournal"] 	= 1,
		["skeletonhat"] 		= 1,
		["armorskeleton"] 		= 1,
		["krampus_sack"] 		= 1,
		["eyeturret_item"] 		= 1,

		["moonrockseed"] 		= 0,
		["mandrake"]	 		= .7,
		["yellowstaff"] 		= .7,
		["chester_eyebone"] 	= 0,
		["glommerflower"] 		= 0,
		["hutch_fishbowl"] 		= 0,
		["panflute"] 			= .8,
		--- @TODO For rare blueprints this should be * 2
		["blueprint"] 			= .5,
		["hivehat"] 			= .8,
		["yellowamuletlight"] 	= .8,
		["greenamulet"] 		= .8,
		["orangeamulet"] 		= .8,
		["icepack"] 			= .8,
		["ruinshat"] 			= .8,
		["ruins_bat"] 			= .8,
		["armorruins"] 			= .8,
		["thulecite"] 			= .3,
		["greenstaff"]			= .8,
		["orangestaff"]			= .8,
		["walrushat"]			= .4,
		["walrus_tusk"]			= .3,
	},

	AREA_RANGED_STAFFS = {
		["staff_tornado"] = true,
		["yellowstaff"] = true,
		["firestaff"] = true,
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

	-- table of character specific items
	-- {'<item.prefab>' = {character_prefabs}}
	-- CHARACTER_ITEMS = {

	-- },

	FOOD = {
		deerclops_eyeball = 6,
		gears = 2,
		minotaurhorn = 6,
		mandrake = 6,
		cookedmandrake = 4,
		mandrakesoup = 3,
	},

	--- @deprecated Use tag "weapon" instead
	-- WEAPONS = {
	-- 	"firestaff",
	-- 	"torch",
	-- 	"lighter",
	-- 	"blowdart_fire",
	-- 	"staff_tornado",
	-- -- greenstaff",
	-- },
}
