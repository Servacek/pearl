--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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


-- AddGlobalDebugKey(KEY_G, function()
--     if TheInput:IsKeyDown(KEY_CTRL) then
--         TheSim:ResetError()
--         DoRestart(true)
--     end
-- end)

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

function PEARL.AddDebugRecord(userid, name, reputation, netid)
    local record = PEARL.DB:CreateRecordFor(userid, netid)
    if not record then
        return
    end

    record.username = name or "UNKNOWN"

    PEARL.Reputation:SetFor(userid, reputation or 100)

    if not netid then
        PEARL.AccountBindings:AddBinding(userid, userid, PEARL.AccountBindings.BINDING_TYPE.STEAMID)
    end

    PEARL.DB:SaveRecordFor(userid, record)

    return record
end

function PEARL.AddBasicDebugRecords()
    PEARL.AddDebugRecord("KU_12345671", "Borb", 212)
    PEARL.AddDebugRecord("KU_12345672", "Gertruda", 102)
    PEARL.AddDebugRecord("KU_12345673", "Škleb", 132)
    PEARL.AddDebugRecord("KU_12345674", "Tonda", 290)
    PEARL.AddDebugRecord("KU_12345675", "Xi", 76)
end

function PEARL.DebugBuiltDoer()
    local CHEST = c_findnext("treasurechest") or c_spawn("treasurechest")
    if not CHEST.components.built then
        CHEST:AddComponent("built")
    end
    CHEST.components.built:SetBuilderData("KU_12345678", "Fi7iP")

    c_save()

    PEARL.GameInstParams:SetModParam("codetorun", [[
        PEARL.AddGamePostInit(function()
            -- Make sure everything is loaded
            PEARL.WallScheduler:ExecuteInTime(0, function()
                local CHEST = c_findnext("treasurechest")
                CHEST.components.burnable:Ignite()
                CHEST.components.burnable.task.fn(CHEST, CHEST.components.burnable)
            end)
        end)
    ]])

    c_reset()
end

function PEARL.OnNewMonth()
    PEARL.EventProcessor:HandleEvent(
        "newmonth", PEARL.TimestampToTable(os.time()), PEARL.TimestampToTable(os.time())
    )
end

function PEARL.OnNewDay()
    PEARL.EventProcessor:HandleEvent(
        "newday", PEARL.TimestampToTable(os.time()), PEARL.TimestampToTable(os.time())
    )
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
        ):SetDecodeResponse(false):Send()
    end
end

--------------------------------
-- [[ Emoji Tests ]]
--------------------------------

function PEARL.TESTS.GameEmoteTest()
    local result = ""
    for name, val in pairs(PEARL.EMOJIS.GAME) do
        result = result.."\n"..tostring(name).." -> "..(PEARL.EMOJIS.UTF_TO_DISCORD[val] or "MISSING")
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

local ICON_SET_SKIP_LIST = {["INVENTORY"] = true}
function PEARL.TESTS.IconTest()
    local result = ""

    local function traverse_icons(t)
        for name, icon in pairs(t) do
            if not ICON_SET_SKIP_LIST[name] then
                if type(icon) == "table" then
                traverse_icons(icon)
                elseif type(icon) == "string" then
                    result = result.."\n"..icon.." -> "..name
                end
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
    PEARL.BlackList:DisplayDebugInfo()
    PEARL.info("---- AddPlayerByID ---")
    PEARL.BlackList:Add(userid)
    assert(PEARL.BlackList:Contains(userid))
    PEARL.BlackList:DisplayDebugInfo()
    table.foreach(PEARL.BlackList:GetBanRecordByID(userid), print)
    PEARL.info("---- RemovePlayerById ---")
    PEARL.BlackList:Remove(userid)
    PEARL.BlackList:DisplayDebugInfo()
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
    local f = io.open(MODROOT..""..PEARL.DATA_DIR_NAME.."/test.json")
    _G.RawRequest(cb, "POST", f:read())
end

function _G.DSay(message, whisper, prefab, state, name)
    prefab = prefab or "wilson"

    local player
    if type(state) == "number" and state > 0 then
        player = c_spawn(prefab)
    end

    local guid = player and player.GUID or 123
    prefab = player and player.prefab or "wilson"
    Networking_Say(guid, "KU_TEST", name,
        prefab, message, WHITE, whisper or false,
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

    local filename = MODROOT..""..PEARL.DATA_DIR_NAME.."/"..name:lower()..".txt"
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
        MODROOT..""..PEARL.DATA_DIR_NAME.."/"..name.."_profiled.txt", "w"
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


function PEARL.DumpZip(path)
    path = path or "databundles/scripts.zip"
    local count = 0
    local zipf, errmsg = io.open(path, "rb")
    if not zipf then return error(errmsg) end

    for line in zipf:lines(path, "rb") do
        if count == 10 then
            break
        end

        print(string.byte(line, 1, #line))
        count = count + 1

        print(TheSim:DecodeAndUnzipString(line))
    end
end

function PEARL.SearchGlobals(input, tp)
    table.foreach(_G, function(k, v)
        if input and not k:lower():find(input) and (type(v) ~= "string" or not v:lower():find(input)) then
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

    d_test_skins_announce() -- birdcage (item based)
    d_test_skins_announce("waxwell_vampire") -- character based
    d_test_skins_announce("puppy_winter") -- marketable
    d_test_skins_announce("feet_loafers_tan_khaki") -- No base_prefab
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
    PEARL.DiscordLogger:LogEmbed(EMBEDS.ServerInfo())
    PEARL.DiscordLogger:LogEmbed(EMBEDS.ServerInfo(true))
    PEARL.DiscordLogger:LogEmbed(EMBEDS.WorldInfo())
    PEARL.DiscordLogger:LogEmbed(EMBEDS.WorldInfo(nil, nil, true))

    PEARL.DiscordLogger:LogEmbed(EMBEDS.ClientMods({[1] = {private = true,id = "",allowed = false,fancyname = "Chat Machine Translation",},[2] = { private = false,id = "343",allowed = true,fancyname = "Status Announcements",},[3] = {private = false, id = "842702425",allowed = true,fancyname = "Minimap HUD Customizable",}}, "KU_ZC24p91Q"))
end

--------------------------------
-- [[ Queue ]]
--------------------------------
--- Maybe replace the Queue with a normal table instead of the userdata?
local Queue = PEARL.loadfile("libraries/datastructures/queue")
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

local charset = "%d%a"
function PEARL.GenerateRandomKleiID()
    return "KU_"..string.random(8, charset)
end

--- from debugkeys.lua
function PEARL.SpawnBase()
    -- Spawn a ready-made base!
    local pos = ThePlayer:GetPosition()
    local topleft = Vector3(pos.x - 15, 0, pos.z - 15)
    local bottomright = Vector3(pos.x + 15, 0, pos.z + 15)
    local width = bottomright-topleft
    for i=0,width.x do
        if i < width.x/2-1 or i > width.x/2+1 then
            local wall = SpawnPrefab("wall_stone")
            wall.Transform:SetPosition(topleft.x + i, 0, topleft.z)
            wall = SpawnPrefab("wall_stone")
            wall.Transform:SetPosition(bottomright.x - i, 0, bottomright.z)
        end
    end
    for i=0,width.z do
        if i < width.z/2-1 or i > width.z/2+1 then
            local wall = SpawnPrefab("wall_wood")
            wall.Transform:SetPosition(topleft.x, 0, topleft.z + i)
            wall = SpawnPrefab("wall_hay")
            wall.Transform:SetPosition(bottomright.x, 0, bottomright.z - i)
        end
    end

    local items = {
        "treasurechest",
        "treasurechest",
        "treasurechest",
        "researchlab",
        "researchlab",
        "researchlab2",
        "firepit",
        "slow_farmplot",
        "slow_farmplot",
        "slow_farmplot",
        "fast_farmplot",
        "fast_farmplot",
        "fast_farmplot",
        "meatrack",
        "meatrack",
        "meatrack",
        "meatrack",
        "cookpot",
        "cookpot",
        "cookpot",
        "cookpot",
        "pighouse",
        "birdcage",
        "firesuppressor",
    }
    for i,v in ipairs(items) do
        local pos = topleft + Vector3(width.x*math.random(), 0, width.z*math.random())
        SpawnPrefab(items[i]).Transform:SetPosition(pos.x, pos.y, pos.z)
    end
    local group_items = {
        "grass",
        "berrybush",
        "sapling",
        "evergreen",
        "evergreen",
    }
    for i,v in ipairs(group_items) do
        local pos = topleft + Vector3(width.x*math.random(), 0, width.z*math.random())
        for z=-2,2 do
            for x=-2,2 do
                local sub_pos = Vector3(pos.x + x, 0, pos.z + z)
                SpawnPrefab(group_items[i]).Transform:SetPosition(sub_pos.x, sub_pos.y, sub_pos.z)
            end
        end
    end
    ConsoleCommandPlayer().components.inventory:Equip( c_spawn("backpack") ) -- do this first so other things can get put in it
    ConsoleCommandPlayer().components.inventory:Equip( c_spawn("axe") )
    ConsoleCommandPlayer().components.inventory:Equip( c_spawn("flowerhat") )
    local invitems = {
        carrot = 20,
        berries = 20,
        twigs = 20,
        cutgrass = 20,
        flint = 20,
        rocks = 40,
        log = 40,
        spear = 2,
        armorwood = 2,
        footballhat = 1,
        torch = 2,
        axe = 1,
        pickaxe = 1,
        shovel = 1,
        silk = 10,
        spidergland = 5,
        smallmeat = 8,
        meat = 4,
        meatballs = 4,
    }
    for k,v in pairs(invitems) do
        c_give(k, v)
    end
end

--- When viewing this file with a celever editor, you can find globals defined only by the engine.
local wf = GLOBAL.io.open(MODROOT.."data/globals.lua", "w")
wf:write("return {\n")
for name, value in pairs(GLOBAL) do
    wf:write("    ", "print(", tostring(name), "), -- ", tostring(value), "\n")--, " = \"", tostring(value), "\",\n")
end
wf:write("}")
wf:close()

local codetorun = PEARL.GameInstParams:GetModParam("codetorun")
if codetorun then
    PEARL.debug("Running game instance parameter code!")
    PEARL.debug(pcall(loadstring(codetorun)))
end
