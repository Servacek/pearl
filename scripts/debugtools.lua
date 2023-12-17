--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



---@diagnostic disable: deprecated, need-check-nil

--- @TODO Move the tests to the tests folder...


require("debugkeys")

local CommandContext = PEARL.loadfile("models/commandcontext")
local UserCommands = require("usercommands")

local Embed = PEARL.loadfile('libraries/discordapi/models/embed')
local Message = PEARL.loadfile('libraries/discordapi/models/message')

local EMBEDS = PEARL.loadfile("utils/embeds")

local ActionLog = PEARL.loadfile("libraries/actionlog")
local QueuedLogAction = PEARL.loadfile("models/queuedlogaction")


AddGlobalDebugKey(KEY_G, function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        TheSim:ResetError()
        DoRestart(true)
    end
end)

function PEARL.DisplayLoadingTips()
    local types = {
        STRINGS.UI.LOADING_SCREEN_SURVIVAL_TIPS,
        STRINGS.UI.LOADING_SCREEN_LORE_TIPS,
        STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS,
        STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS_CONSOLE,
        STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS_NOT_CONSOLE,
        STRINGS.UI.LOADING_SCREEN_OTHER_TIPS,
        -- Loadings tips for new players.
        STRINGS.UI.LOADING_SCREEN_OTHER_TIPS,
    }
    for _, t in ipairs(types) do
        table.dump(t)
    end
end

function PEARL.PrintTests()
    local i = 1
    for name, func in pairs(PEARL.TESTS) do
        PEARL.info(i..".", name, "("..tostring(func)..")")

        i = i + 1
    end
end

PEARL.TESTS = setmetatable({}, {
    __index = function()
        PEARL.PrintTests()
    end,

    __call = function(self, filename)
        PEARL.EXT(filename)
    end
})

function PEARL.ResetError()
    TheSim:ResetError()
    c_reset()
end

local fake_player
fake_player = {
    userid = "KU_TEST",
    name = "Fi7iP",
    prefab = "willow",
    GetDisplayName = function()
        return fake_player.name
    end,
}
fake_player.player = fake_player

local function make_event_test(src, event, ...)
    PEARL.debug(event, "TEST")
    print(src:SafePushEvent(event, ...))
end

local function make_mod_event_test(src, event, ...)
    PEARL.debug(event, "TEST")
    src:PushModEvent(event, ...)
end

local function make_player_event_test(src, event, ...)
    PEARL.debug(event, "SAFE TEST")
    print(src:SafePushEvent(event, fake_player, ...))
end

function PEARL.testassert(condition)
    assert(condition)

    PEARL.debug("TEST SUCCESSED!")
end

function PEARL.DebugConnectionFilter(filterfn, userid, expected_result, data)
    filterfn(userid, data, function(allowed)
        if expected_result ~= nil then
            PEARL.testassert(allowed == expected_result)
        end
    end)
end

function PEARL.AddDebugRecord(userid, name, reputation)
    local record = PEARL.DB:CreateRecordFile(userid)
    if not record then
        return
    end

    record.username = name or "UNKNOWN"

    PEARL.Reputation:InitializeFor(userid)
    PEARL.Reputation:SetFor(userid, reputation)

    PEARL.DB:AddBinding(userid, userid, PEARL.DB.BINDING_TYPE.STEAM)
    PEARL.DB:SaveRecordFor(userid, record)
end

--------------------------------
-- [[ Discord Webhook Tests ]]
--------------------------------

-- Lhook print
function _G.LPrint(...)
    PEARL.DiscordLogger:LogString(...)
end

--------------------------------
-- [[ Requester Tests ]]
--------------------------------

function PEARL.TESTS.TestRequesterQueue()
    for _ = 1, 5 do
        PEARL.HTTPClient:GET(
            "https://google.com"
        ):SetIsRaw(true):Send()
    end
end

function PEARL.TESTS.TestRequesterShutdown()
    PEARL.TESTS.TestRequesterQueue()
    PEARL.HTTPClient:OnShutdown()
end

--------------------------------
-- [[ Emoji Tests ]]
--------------------------------

function PEARL.TESTS.GameEmoteTest()
    local result = ""
    for name, val in pairs(PEARL.EMOTES.GAME) do
        result = result.."\n"..tostring(name).." -> "..(PEARL.EMOTES.MAP_DISCORD[val] or "MISSING")
    end

    if string.len(result) <= 0 then
        return PEARL.error("No results!")
    end

    -- The message is being cropped because it's too long.
    return PEARL.DiscordLogger:LogStringRaw(result)
end

function PEARL.TESTS.DefaultCharactersTest()
    local result = ""
    for _, prefab in ipairs(DST_CHARACTERLIST) do
        result = result.."\n"..PEARL.PrefabToName(prefab).." -> "..(PEARL.ICONS.PLAYER_PREFABS[prefab] or "MISSING")
    end

    if string.len(result) <= 0 then
        return PEARL.error("No results!")
    end

    return PEARL.DiscordLogger:LogStringRaw(result)
end

function PEARL.TESTS.AnnouncementIconTest()
    local result = ""
    for name, _ in pairs(ANNOUNCEMENT_ICONS) do
        result = result.."\n"..name.." -> "..(PEARL.ICONS.ANNOUNCEMENTS[name] or "MISSING")
    end

    if string.len(result) <= 0 then
        return PEARL.error("No results!")
    end

    return PEARL.DiscordLogger:LogStringRaw(result)
end

function PEARL.TESTS.IconTest()
    local result = ""

    local function traverse_icons(t)
        for name, icon in pairs(t) do
            if type(icon) == "table" then
               traverse_icons(icon)
            else
                result = result.."\n"..icon.." -> "..name
            end
        end
    end

    traverse_icons(PEARL.ICONS)

    return PEARL.DiscordLogger:LogStringRaw(result)
end

--------------------------------
-- [[ Profanity Filter Tests ]]
--------------------------------

local function _PFCheck(word, expec)
    local result = ProfanityFilter:Apply(word)
    PEARL.info(word, "|", result, "|", expec, "|", result == expec)

    return result == expec
end

local words = {}
function PEARL.TESTS.ProfanityFilter()
    -- local total = #PFchecks
    -- local passed = 0

    -- for _, check in ipairs(PFchecks) do
    --     if _PFCheck(check[1], check[2]) then
    --         passed = passed + 1
    --     end
    -- end

    -- PEARL.info("Tests passed", passed, "/", total)

    for _, word in ipairs(words) do
        PEARL.info(ProfanityFilter:Apply(word), ProfanityFilter:Detect(word))
    end
end

--------------------------------
-- [[ LogLine Tests ]]
--------------------------------
local LogLine = PEARL.loadfile("libraries/discordapi/models/logline")

function PEARL.TESTS.LogLineTestBuild()
    local logline = LogLine("Temporary Content")
    PEARL.debug("TEMP CONTENT:", logline:GetContent())
    logline:SetContent("Permanent Content")
    logline:SetHeader("TAG", "ICON")
    PEARL.debug("BUILD RESULT:", logline:Build())
    PEARL.debug("__tostring:", tostring(logline))
end

--------------------------------
-- [[ Message Tests ]]
--------------------------------

function PEARL.TESTS.MessageTestToTable()
    local message = Message()
    message:AddLogLine(LogLine("Hello world!"))
    message:AddLogLine(
        LogLine("Just another logline object.")
            :SetHeader("TAG!", "ICON!")
    )

    PEARL.debug(message:ToJson())
end

--------------------------------
-- [[ BlackList Tests ]]
--------------------------------

function PEARL.TESTS.BlacklistMethodTest()
    local userid = "KU_TEST"

    PEARL.info("---- Init ---")
    PEARL.BlackList:PrintDebugInfo()
    PEARL.info("---- AddPlayerByID ---")
    PEARL.BlackList:Add(userid)
    assert(PEARL.BlackList:Contains(userid))
    PEARL.BlackList:PrintDebugInfo()
    table.foreach(PEARL.BlackList:GetPlayerByID(userid), print)
    PEARL.info("---- RemovePlayerById ---")
    PEARL.BlackList:Remove(userid)
    PEARL.BlackList:PrintDebugInfo()
end

--------------------------------
-- [[ Logger - World Tests ]]
--------------------------------

function PEARL.TESTS.LoggerWorldTests()
    if not TheWorld then
        return PEARL.warn("TheWorld is nil!")
    end

    local listeners = TheWorld.listeners
    local event_listeners = TheWorld.event_listeners
    TheWorld.listeners = {}
    TheWorld.event_listeners = {}
    for _, cb in ipairs(PEARL.ENV.postinitfns.GamePostInit) do
        cb()
    end

    make_player_event_test(TheWorld, "ms_clientauthenticationcomplete")
    make_player_event_test(TheWorld, "ms_playerdespawnandmigrate")
    TheWorld.ismastershard = false
    make_player_event_test(TheWorld, "ms_playerdespawnandmigrate")
    TheWorld.ismastershard = true
    make_player_event_test(TheWorld, "ms_newplayerspawned")
    make_player_event_test(TheWorld, "ms_clientdisconnected")

    PEARL.debug("EXPECTED DISCONNECT TEST")
    TheWorld:PushEvent("ms_clientdisconnected", {
        userid = "KU_TEST",
        expected = true,
    })
    PEARL.debug("UNEXPECTED DISCONNECT TEST")
    TheWorld:PushEvent("ms_clientdisconnected", {
        userid = "KU_TEST",
        expected = false,
    })

    make_mod_event_test(TheWorld,"clientconnectionclosed", {
        userid = "KU_TEST",
        reason = "ID_DST_ITS_DEBUG_TIME",
    })

    make_event_test(TheWorld, "showworldreset")
    make_event_test(TheWorld, "hideworldreset")

    make_event_test(TheWorld, "ms_startvote", {
        starteruserid = "KU_STARTER",
        targetuserid = "KU_TARGET",
        commandhash = UserCommands.GetCommandFromName("kick").hash,
    })
    make_event_test(TheWorld, "ms_stopvote")

    make_mod_event_test(TheWorld, "world_reset")
    make_mod_event_test(TheWorld, "world_rollback", 3)

    TheWorld.listeners = listeners
    TheWorld.event_listeners = event_listeners
end

--------------------------------
-- [[ Altdentifier Tests ]]
--------------------------------

function PEARL.TESTS.AltDentifier()
    PEARL.info("=============== START ===============")
    --local init_request_count = PEARL.HTTPClient:GetSentRequestsCount()

    PEARL.info("=============== TEST BANNED VALID ROOT ===============")
    TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_ZC24p91Q")

    PEARL.WallScheduler:ExecuteInTime(10, function()
        PEARL.info("=============== TEST BANNED ROOT ===============")
        TheNet:Ban("KU_NujB7r1v")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_0Z4zp1dv")
    end)

    PEARL.WallScheduler:ExecuteInTime(20, function()
        PEARL.info("=============== TEST INVALID USERID ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_TEST")
    end)

    PEARL.WallScheduler:ExecuteInTime(30, function()
        PEARL.info("=============== TEST CACHED USERID ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_ZC24p91Q")
    end)

    -- Comment out "E_OWNERSHIP_MISSING" in DO_NOT_RETRY_ERRORS table
    -- in order for this to work.
    PEARL.WallScheduler:ExecuteInTime(40, function()
        PEARL.info("=============== TEST RETRY ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_ZC24p91X")
    end)

    PEARL.WallScheduler:ExecuteInTime(60, function()
        PEARL.info("=============== END ===============")
        --local current_requests_count = PEARL.HTTPClient:GetSentRequestsCount()
        --PEARL.info("Requests Sent:", current_requests_count - init_request_count)
    end)
end

--------------------------------
-- [[ Action Queue Tests ]]
--------------------------------

function PEARL.TESTS.ActionLogQueue()
    local log = c_spawn("log")
    log.components.stackable:SetStackSize(11)

    ActionLog:QueueEntAct("{doer} lit {target}!", "Fi7iP")
        :AddTarget(c_spawn("pigman"))
        :AddTarget(c_spawn("rocks"))
        :AddTarget(log)
        :AddTarget(c_spawn("log"))
        :AddTarget(c_spawn("pigman"))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.IGNITE)

    ActionLog:QueueAct("{target} burnt up!")
        :AddTarget(log)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)
end

function PEARL.TESTS.RawActionLogQueue()
    local log = c_spawn("log")
    log.components.stackable:SetStackSize(11)

    return ActionLog:QueueEntAct("{doer} lit {target}! Owner: {owner}", "Fi7iP",
        QueuedLogAction.STATIC_FIELDS.OWNER, "Franta")
        :AddTarget(c_spawn("rocks"))
        :AddTarget(log)
        :AddTarget(c_spawn("log"))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)

end

--------------------------------
-- [[ Server Tags ]]
--------------------------------

function _G.PrintModTags()
    table.foreach(KnownModIndex:GetEnabledModTags(), print)
end

function _G.DLog(message, ...)
    PEARL.DiscordLogger:LogString(message, ...)
end

function _G.RawRequest(cb, ...)
    cb = type(cb) == "function" or function(result, is_successful, http_code)
        PEARL.info("Request Executed!", result)
    end

    TheSim:QueryServer(PEARL.DiscordLogger._webhook.url, cb, ...)
end

function _G.RawLog(message, cb)
    _G.RawRequest(cb, "POST", json.encode_compliant({
        content = message
    }))
end

function _G.RawLogJSON(cb)
    local f = io.open(PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/test.json")
    _G.RawRequest(cb, "POST", f:read())
end

function _G.DSay(message, whisper, prefab, state)
    prefab = prefab or "wilson"

    local player
    if type(state) == "number" and state > 0 then
        player = c_spawn(prefab)
    end

    local guid = player and player.GUID or 123
    prefab = player and player.prefab or "wilson"
    Networking_Say(guid, "KU_TEST", "Fi8iP",
        prefab, message, nil, whisper or false,
        false, nil
    )

    if player then
        player:Remove()
    end
end

function _G.DEmbed(title, desc)
    return PEARL.DiscordLogger:LogEmbed(
        Embed()
        :SetTitle(title)
        :SetDescription(desc)
    )
end

function _G.DebugGlobalFunction(name)
    PEARL.AddGlobalFunctionPreCall(name, function(...)
        PEARL.debug(tostring(name), "CALLED FROM:", debug.getinfo(3, "n").name.." ARGS:", ...)
    end)
end

-- https://stackoverflow.com/a/56891062
function _G.GetFnParamsCount(fn)
    local s = string.dump(fn)
    local int_size = s:byte(8)
    local ptr_size = s:byte(9)
    local pos = 14 + ptr_size + (s:byte(7) > 0 and s:byte(13) or s:byte(12 + ptr_size)) + 2 * int_size
    return s:byte(pos), s:byte(pos + 1) > 0
end

function _G.ListFunctions(name, tbl)
    local object = rawget(tbl or _G, name)
    if type(object) == "userdata" then
        object = instrument_userdata(object)
    end

    if type(object) ~= "table" then
        return PEARL.error(name, "not found")
    end

    if IsTableEmpty(object) then
        return PEARL.info("No functions found in", name)
    end

    local filename = PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/"..name:lower()..".txt"
    local file, error_msg = io.open(filename, "w")
    if not file or error_msg then
        return PEARL.error(error_msg)
    end

    file:write(name..":\n")

    local functions = {}
    table.foreach(object, function(k, v)
        if type(v) ~= "function" then
            return
        end

        functions[#functions+1] = "\t"..tostring(k).."\n"
    end)

    if IsTableEmpty(functions) then
        return PEARL.info("No functions found in", name)
    end

    table.sort(functions)

    file:write(table.concat(functions, ""))

    local metatable = getmetatable(object)
    if type(metatable) == "table" and not IsTableEmpty(metatable) then
        file:write("\n"..name.." (meta):\n")

        table.foreach(metatable, function(k, v)
            if type(v) ~= "function" then
                return
            end

            file:write("\t"..tostring(k).."\n")
        end)
    end

    file:close()

    PEARL.info("Result saved to", filename)
end

--------------------------------
-- [[ Profilling ]]
--------------------------------
-- Saves the report to .../data/profiler.txt
function _G.ProfileFn(name, fn, ...)
    collectgarbage("collect")
	PEARL.Profiler:start()
    -- for i=1, 10^6 do
    fn(...)
    -- end
	PEARL.Profiler:stop()

    local outfile = io.open(
        PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/"..name.."_profiled.txt", "w"
    )
	outfile:write(PEARL.Profiler:report())
	outfile:close()

    PEARL.info("Profilling done!")
end

function PEARL.PrintLUAMemoryUsage()
    print("LUA memory usage: "..math.floor(
        collectgarbage("count") / 1024
    ).." MB")

    collectgarbage("collect")

    print("LUA memory usage: "..math.floor(
        collectgarbage("count") / 1024
    ).." MB")
end

function PEARL.SearchGlobals(input, tp)
    table.foreach(_G, function(k, v)
        if input and not k:lower():find(input) then
            return
        end

        if tp and type(v) ~= tp then
            return
        end

        print(k, v)
    end)
end

function PEARL.ListEngineObjects()
    local objects = {}
    table.foreach(_G, function(k, v)
        -- Meta classes are userdata objects as well.
        if type(v) == "userdata" and v._ctor == nil then
            objects[k] = v
        end
    end)

    return objects
end

function PEARL.ListEngineGlobals()
    local globals = {}
    table.foreach(_G, function(k, v)
        if type(v) == "function" then
            if debug.getinfo(v, "S").what == "C" then
                globals[k] = v
            end
        end
    end)

    return globals
end

function PEARL.FakeRunSlashCommand(name, params)
    local command = UserCommands.GetCommandFromName(name)
    local context = CommandContext(command, CommandContext.TYPE.SLASH, params, {
        userid = "KU_ZC24p91Q",
        name = "Fi7iP",
        GetDisplayName = function()
            return "Fi7iP"
        end
    })

    command.fn(context)
end

--------------------------------
-- [[ Slash Commands ]]
--------------------------------

function PEARL.TESTS.SlashCommands()
    PEARL.FakeRunSlashCommand("fire")
    PEARL.FakeRunSlashCommand("repair")

    PEARL.debug("\n\n/unban: TEST NOT FOUND")
    PEARL.FakeRunSlashCommand("unban")
    PEARL.debug("/unban: TEST SUCCESS")
    TheNet:Ban("KU_0Z4zp1dv")
    PEARL.FakeRunSlashCommand("unban", {player_id = "KU_0Z4zp1dv"})

    PEARL.debug("\n\n/allowlist-add: TEST BANNED")
    PEARL.FakeRunSlashCommand("allowlist-add", {player_id = "KU_NujB7r1v"})
    PEARL.debug("/allowlist-add: TEST CONTAINS")
    PEARL.FakeRunSlashCommand("allowlist-add", {player_id = "KU_ZC24p91Q"})
    PEARL.debug("/allowlist-add: TEST SUCCESS")
    PEARL.FakeRunSlashCommand("allowlist-add", {player_id = "KU_TEST"})

    -- Not found
    PEARL.debug("\n\n/allowlist-remove: TEST NOT FOUND")
    PEARL.FakeRunSlashCommand("allowlist-remove", {player_id = "KU_ZC291QK"})
    PEARL.debug("/allowlist-remove: SUCCESS")
    PEARL.FakeRunSlashCommand("allowlist-remove", {player_id = "KU_TEST"})

    PEARL.debug("\n\n/inv: TEST WEBHOOK DISABLED")
    PEARL.DiscordReporter:SetIsDisabled(true)
    PEARL.FakeRunSlashCommand("inv")
    PEARL.DiscordReporter:SetIsDisabled(false)
    PEARL.debug("\n\n/inv: TEST EMPTY OR NOT FOUND")
    PEARL.FakeRunSlashCommand("inv")

    PEARL.debug("\n\n/inv-find: TEST WEBHOOK DISABLED")
    PEARL.DiscordReporter:SetIsDisabled(true)
    PEARL.FakeRunSlashCommand("inv-find", {
        item_prefab = "axe"
    })
    PEARL.DiscordReporter:SetIsDisabled(false)
    PEARL.debug("/inv-find: TEST NOT FOUND")
    PEARL.FakeRunSlashCommand("inv-find", {
        item_prefab = "axe"
    })

    PEARL.debug("\n\n/daysback: TEST")
    PEARL.FakeRunSlashCommand("daysback", {
        days = 1,
    })
end

--------------------------------
-- [[ Logger ]]
--------------------------------

function PEARL.TESTS.TestChatLogs()
    -- SAY
    DSay(":wave: **Hello World!** @everyone", true)
    DSay("__Odkaz [tu](https://google.com)__")

    DSay("󰀜  󰀔")

    -- SLASH COMMAND
    ----- Default Emote
    Networking_SlashCmd(123, "KU_ZC24p91Q", "wave")
    ----- Weable Emote
    Networking_SlashCmd(123, "KU_ZC24p91Q", "carol")
    ----- Blocked Server
    Networking_SlashCmd(123, "KU_ZC24p91Q", "regenerate")

    -- ANNOUNCEMENTS
    Networking_Announcement("Základný oznam")

    -- SYSTEM
    Networking_SystemMessage("Správa servera")
end

function PEARL.TESTS.UTF8()
    DSay("Príjemný dobrý večer!") -- basic messages
    DSay("jsou poblíž pavouci") -- basic messages

    DSay("读写汉字 - 学中文") -- Some chinese characters
    DSay("\176") -- Degree symbol
    DSay("38 \176C") -- Degree symbol used by "Status Announcements" mod
    DSay("\176\186") -- Some invalid sequence
    DSay("\226\132\162") -- TM
end

--------------------------------
-- [[ Embeds ]]
--------------------------------

function PEARL.TESTS.TestEmbeds()
    local player_meta = PEARL.GetPlayerMetadataFor("KU_ZC24p91Q")
    PEARL.DiscordLogger:LogEmbed(EMBEDS.Inventory(player_meta))
    PEARL.DiscordLogger:LogEmbed(EMBEDS.SuspiciousInventory(player_meta))
    PEARL.DiscordLogger:LogEmbed(EMBEDS.ServerBoot())
    PEARL.DiscordLogger:LogEmbed(EMBEDS.WorldRegen())

    PEARL.DiscordLogger:LogEmbed(EMBEDS.ClientMods({[1] = {private = true,id = "",allowed = false,fancyname = "Chat Machine Translation",},[2] = { private = false,id = "343",allowed = true,fancyname = "Status Announcements",},[3] = {private = false, id = "842702425",allowed = true,fancyname = "Minimap HUD Customizable",}}, "KU_ZC24p91Q"))
end

--------------------------------
-- [[ Queue ]]
--------------------------------
--- Maybe replace the Queue with a normal table instead of the userdata?
local Queue = PEARL.loadfile("libraries/queue")
function PEARL.TESTS.Queue()
    local max = 5
    local queue = Queue(max)
    assert(queue:empty() == true)
    assert(queue:full() == false)
    assert(queue:len() == 0)
    assert(queue:take() == nil)
    assert(queue:first() == nil)
    assert(queue:last() == nil)
    for i = 1, max + 1 do
        assert(i == max + 1 or queue:full() == false)
        queue:push(i)
        assert(queue:len() == math.min(i, max))
        assert(queue:empty() == false)
    end

    assert(queue:empty() == false)
    assert(queue:full() == true)
    assert(queue:len() == max)
    assert(type(queue:first()) == "number")
    assert(type(queue:last()) == "number")
    assert(queue._list.first == 1, tostring(queue._list.first))
    assert(queue._list.last == max)

    for i = 1, max do
        assert(queue:take() ~= nil)
        assert(queue:empty() == (i == max), queue:len())
        assert(queue:len() == max - i)
    end

    for i = 1, max + 1 do
        queue:push(i)
    end

    local i = 0
    for item in queue:iter() do
        assert(type(item) == "number")
        i = i + 1
    end

    assert(i == queue:len())

    queue:clear()
    table.dump(queue)
    assert(queue:empty() == true)
    assert(queue:full() == false)
    assert(queue:len() == 0)
    assert(queue:take() == nil)
    assert(queue:first() == nil, queue:first())
    assert(queue:last() == nil)

    PEARL.info("All tests ran successfully!")
end

--------------------------------
-- [[ Localizer ]]
--------------------------------

--- @TODO

--------------------------------
-- [[ WallScheduler ]]
--------------------------------

function PEARL.TESTS.WallScheduler()

end

--------------------------------
-- [[ Game Announcements ]]
--------------------------------

function PEARL.TESTS.AnnouncementCategories()
    for name, type in pairs(PEARL.CONSTS.ANN_TYPE) do
        PEARL.AnnounceWithType(name, type)
    end
end

--------------------------------
-- [[ Formatting and Markdown ]]
--------------------------------

function PEARL.TESTS.MarkdownInChat()
    DSay("**test**")
end

function PEARL.TESTS.URLsInChat()
    DSay("Hey everyone, did you see this new cool server? https://discord.gg/RHzJxut")
end

function PEARL.TESTS.HyperlinksInChat()
    DSay("[Join our discord!](https://discord.gg/RHzJxut)")
end

--------------------------------
-- [[ Stack Debuging ]]
--------------------------------

local function getfiltersource(src)
    return (src == nil and "[?]")
        or (src:sub(1, 1) == "@" and src:sub(2))
        or src
end

local function getformatinfo(info)
    return info ~= nil
        and string.format("@%s%s in %s",
                getfiltersource(info.source),
                info.currentline ~= nil and (":"..info.currentline) or "",
                info.name or "?")
        or "**error**"
end

function PEARL.CalledFrom(level)
    local info = debug.getinfo(level or 3)
    return getformatinfo(info)
end

local charset = "%d%a"
function PEARL.GenerateRandomKleiID()
    return "KU_"..string.random(8, charset)
end
