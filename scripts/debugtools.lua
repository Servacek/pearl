---@diagnostic disable: deprecated, need-check-nil

local Embed = require('libraries/discordapi/models/embed')
local Message = require('libraries/discordapi/models/message')

local PEARL = PEARL
local string = string
local TheSim = TheSim

local json = json

PEARL.TESTS = {}

function PEARL.PrintTests()
    local i = 1
    for name, func in pairs(PEARL.TESTS) do
        PEARL.info(i..".", name, "("..tostring(func)..")")

        i = i + 1
    end
end

function PEARL.ResetError()
    TheSim:ResetError()
    c_reset()
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
        PEARL.RestClient:GET(
            "https://google.com"
        ):SetSkipOnDeadline(false):Send()
    end
end

function PEARL.TESTS.TestRequesterShutdown()
    PEARL.TESTS.TestRequesterQueue()
    PEARL.RestClient:OnShutdown()
end

--------------------------------
-- [[ Emoji Tests ]]
--------------------------------

function PEARL.TESTS.GameEmoteTest()
    local result = ""
    for name, val in pairs(PEARL.EMOTES.GAME) do
        result = result.."\n"..tostring(name).." -> "..(PEARL.EMOTES.DISCORD[val] or "MISSING")
    end

    if string.len(result) <= 0 then
        return PEARL.error("No results!")
    end

    print(string.len(result))
    return PEARL.DiscordLogger:LogString(result)
end

function PEARL.TESTS.DefaultCharactersTest()
    local result = ""
    for _, prefab in ipairs(DST_CHARACTERLIST) do
        result = result.."\n"..name.." -> "..(PEARL.ICONS.PLAYER_PREFABS[prefab] or "MISSING")
    end

    if string.len(result) <= 0 then
        return PEARL.error("No results!")
    end

    return PEARL.DiscordLogger:LogString(result)
end

function PEARL.TESTS.AnnouncementIconTest()
    local result = ""
    for name, _ in pairs(ANNOUNCEMENT_ICONS) do
        result = result.."\n"..name.." -> "..(PEARL.ICONS.ANNOUNCEMENTS[name] or "MISSING")
    end

    if string.len(result) <= 0 then
        return PEARL.error("No results!")
    end

    return PEARL.DiscordLogger:LogString(result)
end

--------------------------------
-- [[ Profanity Filter Tests ]]
--------------------------------

local function _PFCheck(word, should_censor)
    local expec = word -- The expected result
    if should_censor then
        expec = string.rep("*", #word)
    end

    local result = ProfanityFilter:Apply(word)
    PEARL.info(word, "|", result, "|", expec, "|", result == expec)

    return result == expec
end

local PFchecks = {
    {"t--e--s--t", true},
    {"T e s T", true},
    {"řiřřť", false},
    {"t1e2s3t", false},
        -- Ignore everything before the start and after the end
        -- of the filtered word
    {"ashh1.>te s>>t--.", false}
}
function PEARL.TESTS.PFCheckSeparators()
    local total = #PFchecks
    local passed = 0

    for _, check in ipairs(PFchecks) do
        if _PFCheck(check[1], check[2]) then
            passed = passed + 1
        end
    end

    PEARL.info("Tests passed", passed, "/", total)
end

--------------------------------
-- [[ LogLine Tests ]]
--------------------------------
local LogLine = require("libraries/discordapi/models/logline")

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
-- [[ Blacklist Tests ]]
--------------------------------

function PEARL.TESTS.BlacklistMethodTest()
    local userid = "KU_TEST"

    PEARL.info("---- Init ---")
    PEARL.Blacklist:PrintDebugInfo()
    PEARL.info("---- AddPlayerByID ---")
    PEARL.Blacklist:AddPlayerByID(userid)
    PEARL.Blacklist:PrintDebugInfo()
    table.foreach(PEARL.Blacklist:GetPlayerByID(userid), print)
    PEARL.info("---- RemovePlayerById ---")
    PEARL.Blacklist:RemovePlayerByID(userid)
    PEARL.Blacklist:PrintDebugInfo()
end

--------------------------------
-- [[ Altdentifier Tests ]]
--------------------------------

function PEARL.TESTS.AltDentifier()
    PEARL.info("=============== START ===============")
    local init_request_count = PEARL.RestClient:GetSentRequestsCount()

    PEARL.info("=============== TEST BANNED VALID ROOT ===============")
    TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_ZC24p91Q")

    PEARL.Scheduler:ExecuteInTime(10, function()
        PEARL.info("=============== TEST BANNED ROOT ===============")
        TheNet:Ban("KU_NujB7r1v")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_0Z4zp1dv")
    end)

    PEARL.Scheduler:ExecuteInTime(20, function()
        PEARL.info("=============== TEST INVALID USERID ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_TEST")
    end)

    PEARL.Scheduler:ExecuteInTime(30, function()
        PEARL.info("=============== TEST CACHED USERID ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_ZC24p91Q")
    end)

    -- Comment out "E_OWNERSHIP_MISSING" in DO_NOT_RETRY_ERRORS table
    -- in order for this to work.
    PEARL.Scheduler:ExecuteInTime(40, function()
        PEARL.info("=============== TEST RETRY ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", "KU_ZC24p91X")
    end)

    PEARL.Scheduler:ExecuteInTime(60, function()
        PEARL.info("=============== END ===============")
        local current_requests_count = PEARL.RestClient:GetSentRequestsCount()
        PEARL.info("Requests Sent:", current_requests_count - init_request_count)
    end)()
end

--------------------------------
-- [[ Suspicious Inventory Detector Tests]]
--------------------------------

local function GiveItemTo(inst, prefab, count)
    if not inst then
        return
    end

    count = count or 1
    for i = 1, count do
        local item = DebugSpawn(prefab)
        if item ~= nil then
            if item.components.finiteuses then
                item.components.finiteuses:SetUses(math.random(item.components.finiteuses.total))
                print(item.components.finiteuses:GetPercent())
            end

            --PEARL.debug("giving x"..tostring(count), item)
            inst.components.inventory:GiveItem(item)
        end
    end
end

local function GetSuspicioness(inventory)
    --PEARL.info(string.rep("-", 30))

    -- spawn our thief first
    local thief = c_spawn("wilson")

    for _, item in ipairs(inventory) do
        for prefab, count in pairs(item) do
            GiveItemTo(thief, prefab, count)
        end
    end


    local result = thief.components.inventory:CalcSuspicioness()
    -- if thief.components.inventory:IsSuspicious() then
    --     PEARL.info(string.rep("-", 30))
    --     PEARL.debug("["..tostring(index)..".]", DataDumper(inventory, nil, false, 0))
    --     --PEARL.debug(thief.components.inventory:GetDebugString())
    -- end

    thief:Remove()

    return result
end

function PEARL.TESTS.SusInv()
    local rfile, success = io.open(PEARL.MODROOT..""..PEARL.DATA_DIR_NAME.."/d_inventories.txt", "r")
    if not rfile then
        return PEARL.error("Failed to open the inventories file!", success)
    end

    local wfile, success = io.open(PEARL.MODROOT..""..PEARL.DATA_DIR_NAME.."/d_result.txt", "w")
    if not wfile then
        return PEARL.error("Failed to open the result file!", success)
    end

    PEARL.info("Searching for suspicious inventories...")
    local i = 1
    local count = 0
    for inv_str in rfile:lines() do
        if not inv_str:startswith("--") then
            local inventory = json.decode(inv_str)
            local suspicioness = GetSuspicioness(inventory)
            if suspicioness >= 1 then
                wfile:write("\nINVENTORY: ", i, " ITEM_COUNT: ", #inventory)
                wfile:write("\nSUSPICIONESS: ", math.round((suspicioness * 100), 2), "%")
                wfile:write("\nCONTENT: ", DataDumper(inventory, nil, false, 0))
                wfile:write("\n\n", string.rep("-", 50))

                count = count + 1
            end

            i = i + 1
        end

        print(string.rep("-", 50))
    end

    wfile:write("\nSUSPICIOUS INVENTORIES DETECTED: ", count)
    wfile:write("\n\n", string.rep("-", 50))

    rfile:close()
    wfile:close()

    PEARL.info("Done! Found:", count)
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
    cb = cb or function(result, is_successful, http_code)
        PEARL.info("Request Executed!", result)
    end

    TheSim:QueryServer(PEARL.DiscordLogger._webhook.url, cb, ...)
end

function _G.RawLog(message, cb)
    _G.RawRequest(cb, "POST", json.encode_compliant({
        content = message
    }))
end

function _G.RawLogJSON(json_data, cb)
    _G.RawRequest(cb, "POST", json_data)
end

function _G.DSay(message, whisper)
    Networking_Say(123, "KU_TEST", "Fi8iP",
        "wilson", message, nil, whisper or false,
        false, nil
    )
end

function _G.DebugGlobalFunction(name)
    PEARL.AddGlobalFunctionPreCall(name, function(...)
        PEARL.debug(tostring(name), "CALLED FROM:", debug.getinfo(3, "n").name.." ARGS:", ...)
    end)
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
        PEARL.MODROOT..""..PEARL.DATA_DIR_NAME.."/"..name.."_profiled.txt", "w"
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

function PEARL.execute_tests(testset_name)
    local tests = require("tests/"..testset_name)
    if not type(tests) == "table" then
        PEARL.info("Failed to load the specified test set!")
    end

    tests.test_all()
end

--------------------------------
-- [[ Logger ]]
--------------------------------

function PEARL.TESTS.TestChatLogs()
    -- SAY
    DSay(":wave: **Hello World!** @everyone")
    DSay("__Odkaz [tu](https://google.com)__", true)

    -- SLASH COMMAND
    ----- Default Emote
    Networking_SlashCmd(123, "KU_ZC24p91Q", "/wave")
    ----- Weable Emote
    Networking_SlashCmd(123, "KU_ZC24p91Q", "/carol")
    ----- Blocked Server
    Networking_SlashCmd(123, "KU_ZC24p91Q", "/regenerate")

    -- ANNOUNCEMENTS
    Networking_Announcement("Základný oznam")

    -- SYSTEM
    Networking_SystemMessage("Správa servera")
end

--------------------------------
-- [[ Localizer ]]
--------------------------------

--- @TODO

--------------------------------
-- [[ Game Announcements ]]
--------------------------------

function PEARL.TESTS.AnnouncementCategories()
    for name, type in pairs(PEARL.CONSTS.ANNOUNCEMENT_TYPES) do
        PEARL.Announce(name, type)
    end
end

--------------------------------
-- [[ Formatting and Markdown ]]
--------------------------------

function PEARL.TESTS.MarkdownInChat()
    DSay("**test**")
end
