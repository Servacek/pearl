
local PEARL = PEARL

local TheNet, TheSim = TheNet, TheSim

--------------------------------
-- [[ Imports ]]
--------------------------------

local AllowList = require("modules/allowlist")

--------------------------------
-- [[ Contants ]]
--------------------------------

local LOCALE_PATTERN = "&locale=(%w+)&"

local ALLOWED_LOCALES = {
    ["SK"] = true,
    ["CZ"] = true,
}

--------------------------------
-- [[ Private - Client Side ]]
--------------------------------

local function _GetLocale()
    local motd_url = TheSim:GetMOTDQueryURL()
    if type(motd_url) ~= "string" then
        return
    end

    local locale = motd_url:match(LOCALE_PATTERN)
    if type(locale) ~= "string" then
        return
    end

    return locale:upper()
end

local function _OnLocalizationRequestReceived()
    PEARL.debug("_OnLocalizationRequestReceived")

    local locale = _GetLocale()
    if type(locale) ~= "string" then
        return PEARL.error("Failed to fetch the locale!")
    end

    PEARL.debug("Client localized as ", locale)
    PEARL.SendRPCToServer(PEARL.RPCS.ClientLocalizationCompleted, locale)
end

--------------------------------
-- [[ Private - Server Side ]]
--------------------------------

local _timeout

local function _OnClientModNetworkReady(userid)
    print(LookupPlayerInstByUserID(userid))
    if LookupPlayerInstByUserID(userid) then
        return
    end

    -- Send a request to the client that it should localize.
    PEARL.SendRPCToClient(PEARL.RPCS.SendLocalizationRequest, userid)

    _timeout = PEARL.Scheduler:ExecuteInTime(PEARL.CONSTS.LOCALIZATION_TIMEOUT, function()
        PEARL.warn("The localization process for client ", userid, "has timed out.")
        --PEARL.ServerNetwork:SendUserDisconnectFor(userid, "ID_DISCONNECTION_NOTIFICATION")
    end)
end

local function _OnClientLocalizationComplete(userid, locale)
    PEARL.debug("Client", userid, "localized as", locale)

    if _timeout ~= nil then
        _timeout:Cancel()
        _timeout = nil
    end

    if AllowList:Contains(userid) or ALLOWED_LOCALES[locale] == true then
        return
    end

    -- Do not allow further loading
    return PEARL.ServerNetwork:SendUserDisconnectFor(
        userid, "ID_DST_LOCALE_BLOCKED"
    )
end

--------------------------------
-- [[ Setup ]]
--------------------------------

if TheNet:GetIsClient() then
    -- Being pushed only client side
    PEARL.EventProcessor:AddEventHandler("localization_request_received", _OnLocalizationRequestReceived)

    PEARL.AddClientPreLoad(function()
        if (PEARL.ClientLoader:IsLoading() or PEARL.ClientLoader:IsLoaded()) then
            return
        end

        -- Wait a few frames for a server's response.
        -- If none, continue normally.
        PEARL.ClientLoader:DelayLoad()

        -- Do not load the client yet.
        return false
    end)

    return
end

PEARL.EventProcessor:AddEventHandler(
    "ms_clientlocalizationcomplete", _OnClientLocalizationComplete
)
PEARL.EventProcessor:AddEventHandler(
    "ms_clientmodnetworkready", _OnClientModNetworkReady
)
