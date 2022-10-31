-- Prefab names of some important entities we care of

GLOBAL.SUB.PREFABS = {
	-- PLANTS = {
	-- 	cactus = 1,
	-- 	oasis_cactus=1,
	-- 	reeds=1,
	-- 	grass=1,
	-- 	sapling=1,
	-- 	berrybush=1,
	-- 	berrybush_juice=1,
	-- 	berrybush2=1,
	-- 	red_mushroom=1,
	-- 	green_mushroom=1,
	-- 	blue_mushroom=1,
	-- 	farm_plant_eggplant=1,
	-- 	farm_plant_watermelon=1,
	-- 	farm_plant_durian=1,
	-- 	farm_plant_pomegranate=1,
	-- 	farm_plant_corn=1,
	-- 	farm_plant_carrot=1,
	-- ---------------------------
	-- 	-- dug_grass",
	-- 	-- dug_sapling",
	-- 	-- dug_berrybush",
	-- 	-- dug_berrybush2",
	-- 	-- dug_berrybush_juicy",
	-- },

	-- STRUCTURES = {
	-- -- TOOLS	                         -- basic list of structures for protection
	-- 	saltlick=1,
	-- -- LIGHT
	-- 	coldfirepit=1,
	-- 	firepit=1,
	-- 	mushroom_light2=1,
	-- 	mushroom_light=1,
	-- -- SURVIVAL
	-- 	siestahut=1,
	-- 	tent=1,
	-- -- FARM
	-- 	beebox=1,
	-- 	compostingbin=1,
	-- 	cookpot=1,
	-- 	fast_farmplot=1,
	-- 	icebox=1,
	-- 	meatrack=1,
	-- 	mushroom_farm=1,
	-- 	slow_farmplot=1,
	-- 	saltbox=1,
	-- -- SCIENCE
	-- 	cartographydesk=1,
	-- 	firesuppressor=1,
	-- 	lightning_rod=1,
	-- 	madscience_lab=1,
	-- 	rainometer=1,
	-- 	researchlab2=1,
	-- 	researchlab=1,
	-- 	sculptingtable=1,
	-- 	seafaring_prototyper=1,
	-- 	winterometer=1,
	-- -- STRUCTURES
	-- 	mermhouse_crafted=1,
	-- 	mermwatchtower=1,
	-- 	mermthrone_construction=1,
	-- 	mermthrone=1,
	-- 	arrowsign_post=1,
	-- 	birdcage=1,
	-- 	dragonflychest=1,
	-- 	dragonflyfurnace=1,
	-- 	endtable=1,
	-- 	homesign=1,
	-- 	perdshrine=1,
	-- 	pighouse=1,
	-- 	pigshrine=1,
	-- 	rabbithouse=1,
	-- 	sisturn=1,
	-- 	scarecrow=1,
	-- 	treasurechest=1,
	-- 	tacklestation=1,
	-- 	table_winters_feast=1,
	-- 	trophyscale_oversizedveggies=1,
	-- 	trophyscale_fish=1,
	-- 	turfcraftingstation=1,
	-- 	wardrobe=1,
	-- 	wargshrine=1,
	-- 	winter_treestand=1,
	-- 	wintersfeastoven=1,
	-- 	yotc_carratshrine=1,
	-- -- MAGIC
	-- 	eyeturret=1,
	-- 	moondial=1,
	-- 	nightlight=1,
	-- 	researchlab3=1,
	-- 	researchlab4=1,
	-- 	resurrectionstatue=1,
	-- 	sentryward=1,
	-- 	telebase=1,
	-- 	townportal=1,
	-- -- ENGINEERING
	-- 	winona_catapult=1,
	-- 	winona_spotlight=1,
	-- 	winona_battery_low=1,
	-- 	winona_battery_high=1,
	-- -- SEAFARING
	-- 	anchor=1,
	-- 	fish_box=1,
	-- 	mast=1,
	-- 	mast_malbatross=1,
	-- 	steeringwheel=1,
	-- 	waterpump=1,
	-- 	winch=1,
	-- -- UNCRAFTABLE
	-- 	catcoonden=1,
	-- 	mermhouse=1,
	-- },

	-- PREFAB_BLACKLIST = {
	-- 	evergreen = 1,
	-- },

	-- Deprecated
	-- MOBS = {
	-- 	antlion=1,
	-- 	babybeefalo=1,
	-- 	bearger=1,
	-- 	beefalo=1,
	-- 	beequeen=1,
	-- 	chester=1,
	-- 	crabking=1,
	-- 	deerclops=1,
	-- 	dragonfly=1,
	-- 	glommer=1,
	-- 	hutch=1,
	-- 	klaus=1,
	-- 	leif=1,
	-- 	leif_sparse=1,
	-- 	lightninggoat=1,
	-- 	malbatross=1,
	-- 	minotaur=1,
	-- 	moose=1,
	-- 	shadow_bishop=1,
	-- 	shadow_knight=1,
	-- 	shadow_rook=1,
	-- 	spat=1,
	-- 	spiderqueen=1,
	-- 	stalker=1,
	-- 	stalker_atrium=1,
	-- 	toadstool=1,
	-- 	toadstool_dark=1,
	-- 	walrus=1,
	-- 	warg=1,
	-- },

	MOBS = {
		COMPANIONS = {
			glommer=1,
			hutch=1,
			chester=1,
			friendlyfruitfly=1,
		},

		MONITOR_POPULATION = {
			beefalo=1,
		},

		FIRE_SPREADERS = { -- Especially after death
			firehound=1,
			lavae=1,
		}
	},

	MONITOR_PICKUP = {
		deerclops_eyeball = 1,
		dragon_scales = 1,
		bearger_fur = 1,
		minotaurhorn = 1,
		atrium_key = 1,
		shroom_skin = 1,
		moonrockseed = 1,
		mandrake = 1,
		yellowstaff = 1,
		waxwelljournal = 1,
		chester_eyebone = 1,
		glommerflower = 1,
		hutch_fishbowl = 1,
	},

	AREA_RANGED_STAFFS = {
		staff_tornado = 1,
		yellowstaff = 1,
		firestaff = 1,
	},

	FIRE_SOURCES = {
		campfire = 1,
	},

	-- table of character specific items
	-- {'<item.prefab>' = {character_prefabs}}
	-- CHARACTER_ITEMS = {

	-- },

	-- prefabs.cant_respawn_animals = {
	--     beefalo",
	--     voltgoat",
	-- }

	-- prefabs.cant_respawn_structures = {
	--     catcoonden",
	--     beehive",
	-- }

	FOOD = {
		deerclops_eyeball=1,
		gears=1,
		minotaurhorn=1,
		mandrake=1,
		cookedmandrake=1,
		mandrakesoup=1,
	},

	-- WEAPONS = {
	-- 	"firestaff",
	-- 	"torch",
	-- 	"lighter",
	-- 	"blowdart_fire",
	-- 	"staff_tornado",
	-- -- greenstaff",
	-- },
}