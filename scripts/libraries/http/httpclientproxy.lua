--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODOS: Add support for non-waiting requests (these will return 201)

--------------------------------
-- [[ Constants ]]
--------------------------------

local PROXY_REQUEST_TIMEOUT = 10
local MAX_TIMEOUTS_IN_ROW   = 3
local CIRCUIT_COOLDOWN      = 30

--------------------------------
-- [[ Local ]]
--------------------------------

local _timeouts_in_row = 0
local _reported = false
local _circuit_open_until = 0
local _probe_in_flight = false

local function _OnProxyRequestTimeout(_, request)
    if _circuit_open_until > 0 then
        _circuit_open_until = (walltime() or 0) + CIRCUIT_COOLDOWN
        _probe_in_flight = false
        request:SetIsRetryable(false)
        return
    end

    _timeouts_in_row = _timeouts_in_row + 1
    if _timeouts_in_row < MAX_TIMEOUTS_IN_ROW then
        return
    end

    _circuit_open_until = (walltime() or 0) + CIRCUIT_COOLDOWN
    _probe_in_flight = false
    request:SetIsRetryable(false)

    if not _reported then
        PEARL.warn(("Proxy is unavailable; suppressing proxy retries for %d seconds."):format(CIRCUIT_COOLDOWN))
        PEARL.DiscordReporter:SendRawReportString("Proxy seems to be down!")
        _reported = true
    end
end

--------------------------------
-- [[ Class Init ]]
--------------------------------

--- @class HTTPClientProxy
local HTTPClientProxy = {
    _url = nil,
    _enabled = false
}

--------------------------------
-- [[ Static Variables ]]
--------------------------------

-- More can be added later
HTTPClientProxy.METHODS = {
    PATCH   = "PATCH",
    DELETE  = "DELETE",
    POST    = "POST",
    GET     = "GET",
}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function _OnProxyRequestComplete(response, request)
    if request.code ~= 0 then
        if _circuit_open_until > 0 then
            PEARL.info("Proxy is available again.")
        end

        _timeouts_in_row = 0
        _circuit_open_until = 0
        _probe_in_flight = false
        _reported = false
    end
end

local function _CreateProxyRequest(oncompletefn, ...)
    return PEARL.HTTPClient:Request(HTTPClientProxy._url, PEARL.HTTPClient.METHODS.POST, true)
        :AddStatusCodeHandle(0, _OnProxyRequestTimeout)
        :SetTimeout(PROXY_REQUEST_TIMEOUT)
        :AddOnComplete(function(response, request)
            _OnProxyRequestComplete(response, request)
            if type(oncompletefn) == "function" then
                oncompletefn(response, request)
            end
        end)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function HTTPClientProxy:SetURL(url)
    self._url = url
end

function HTTPClientProxy:IsEnabled()
    return self._enabled
end

function HTTPClientProxy:IsDisabled()
    return not self:IsEnabled()
end

function HTTPClientProxy:IsProxyURL(url)
    if type(url) ~= "string" then
        return false
    end

    if url:match("^https?://localhost:5000/") or url:match("^https?://127%.0%.0%.1:5000/") then
        return true
    end

    if type(self._url) == "string" and url:sub(1, #self._url) == self._url then
        return true
    end

    local discord_proxy = PEARL.CONFIG.DISCORD and PEARL.CONFIG.DISCORD.PROXY
    local discord_proxy_url = discord_proxy and discord_proxy.URL
    return type(discord_proxy_url) == "string"
        and url:sub(1, #discord_proxy_url) == discord_proxy_url
end

function HTTPClientProxy:IsCircuitOpen()
    return _circuit_open_until > (walltime() or 0)
end

function HTTPClientProxy:TrackRequest(request)
    return request
        :AddStatusCodeHandle(0, _OnProxyRequestTimeout)
        :AddOnComplete(_OnProxyRequestComplete)
end

function HTTPClientProxy:CanSendRequest()
    local now = walltime() or 0
    if _circuit_open_until <= now then
        if _circuit_open_until > 0 and not _probe_in_flight then
            _probe_in_flight = true
            return true
        end

        return _circuit_open_until == 0
    end

    return false
end

function HTTPClientProxy:SetEnabled(enabled)
    self._enabled = enabled
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param method string The method of the request.
--- @param oncompletefn? fun(result: string, success: boolean, http_code: string, ...: any): any The function that should be called after the request completes.
--- @param data table? The json data table for the request, if any.
--- @param timeout integer? The number of seconds before timeout should occur.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:Request(url, method, oncompletefn, data, timeout)
    if data ~= nil and type(data) ~= "table" then
        error("Attempted to create a proxy request with invalid data!")
    end

    return _CreateProxyRequest(oncompletefn)
        :SetProxyData({ -- Data for the proxied request
            url = url,
            timeout = timeout,
            method = method,
            json = data,
        })
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param callbackfn? fun(result: string, success: boolean, http_code: string, ...: any): any The function that should be called after the request completes.
--- @param timeout integer? The number of seconds before timeout should occur.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:DELETE(url, callbackfn, timeout, ...)
    return self:Request(url, self.METHODS.DELETE, callbackfn, nil, timeout)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param callbackfn? fun(result: string, success: boolean, http_code: string, ...: any): any The function that should be called after the request completes.
--- @param data table The data table body for the request.
--- @param timeout integer? The number of seconds before timeout should occur.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:PATCH(url, callbackfn, data, timeout)
    return self:Request(url, self.METHODS.PATCH, callbackfn, data, timeout)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param oncompletefn? fun(result: string, success: boolean, http_code: string, ...: any): any The function that should be called after the request completes.
--- @param timeout integer? The number of seconds before timeout should occur.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:GET(url, oncompletefn, timeout)
    return self:Request(url, self.METHODS.GET, oncompletefn, nil, timeout)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param oncompletefn? fun(result: string, success: boolean, http_code: string, ...: any): any The function that should be called after the request completes.
--- @param data table The data table body for the request.
--- @param timeout integer? The number of seconds before timeout should occur.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:POST(url, oncompletefn, data, timeout)
    return self:Request(url, self.METHODS.POST, oncompletefn, data, timeout)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return HTTPClientProxy
