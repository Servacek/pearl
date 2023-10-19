--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Manages the REST client's request queue so requests are not sent directly.

    Functions:
        - GET(url, callbackfn, timeout, ...)
        - POST(url, callbackfn, encoded_data, timeout, ...)

    - NOTES:
        - Each shard has it's own Requester so they are not synced.
          Therefore it's recommended to, if possible, send all requests
          from Master to prevent exceeding any rate limits.

        - The discord REST API rate limit is 16 requests/second.

    - TODOS:
        - Fix request caching. It cannot rely just on the URL. Probably best
        option would be to explicitly cache the requests with an unique ID.
--]]

local Queue = PEARL.loadfile("libraries/queue")
--- @type Request
local Request = PEARL.loadfile("libraries/http/models/request")
local HTTPClientProxy = PEARL.loadfile("libraries/http/httpclientproxy")

local TheSim = TheSim

--------------------------------
-- [[ Constants ]]
--------------------------------

local MAX_REQUEST_RETRIES = 3

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class HTTPClient - singleton
local HTTPClient = {
    --- This should be public
    --- @type HTTPClientProxy
    proxy = HTTPClientProxy,
}

--------------------------------
-- [[ Internal Handlers ]]
--------------------------------

-- local function OnFinishCooldown()
--     --PEARL.debug("Cooldown task finished!")

--     HTTPClient:StopCooldown()
--     HTTPClient:ProcessNextRequest()
-- end

--------------------------------
-- [[ Static Variables ]]
--------------------------------

-- More can be added later
HTTPClient.METHODS = {
    POST    = "POST",
    GET     = "GET",
}

--------------------------------
-- [[ Setters ]]
--------------------------------

-- function HTTPClient:SetIsWaiting(waiting)
--     --PEARL.debug("HTTPClient:SetIsWaiting", waiting)

--     self._waiting = waiting

--     return self
-- end

function HTTPClient:SetRequestFrequency(frequency)
    if type(frequency) ~= "number" then
        return PEARL.error("Invalid frequency parameter!")
    end

    self._frequency = frequency

    return self
end

-- function HTTPClient:ResetForceTreshold()
--     self._force_threshold = MAX_FORCE_THRESHOLD
-- end

--------------------------------
-- [[ Getters ]]
--------------------------------

-- function HTTPClient:IsQueueDisabled()
--     return self._frequency <= 0
-- end

-- function HTTPClient:IsShuttingDown()
--     return self._shutting_down
-- end

-- function HTTPClient:IsWaiting()
--     return self._waiting
-- end

-- function HTTPClient:IsOnCooldown()
--     return self._cooldown_task and self._cooldown_task.running == true
-- end

function HTTPClient:IsProxyEnabled()
    return self.proxy and self.proxy:IsEnabled()
end

-- Used for debugging purposes
-- function HTTPClient:GetSentRequestsCount()
--     return self._rcount
-- end

--------------------------------
-- [[ Private Methods ]]
--------------------------------

function HTTPClient:SendRequest(request)
    if type(request) ~= "table" then
        return PEARL.warn("Attempted to send an invalid request!")
    end

    -- Run in a protected call so if an error occures and the request is not actually
    -- being sent, we do not block the requester.
    local success, err = pcall(TheSim.QueryServer, TheSim,
        request.url, function(...)
            request:OnCompleted(...)
        end, request.method, request:GetData(), request.timeout
    )

    if success then
        request:OnSend()
    else
        PEARL.error("Failed to execute request!", err)
    end

    return success, err
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function HTTPClient:Setup()
    if not TheNet:IsDedicated() or PEARL.INIT then
        return
    end

    if self.proxy and PEARL.CONFIG.PROXY.ENABLED and type(PEARL.CONFIG.PROXY.URL) == "string" then
        PEARL.info("Setting up the proxy...")

        self.proxy:SetEnabled(true)
        self.proxy:SetURL(PEARL.CONFIG.PROXY.URL)
    end

    -- [[ Events ]]
    --PEARL.EventProcessor:AddSafeEventHandler("quit", OnQuit)
end

-- function HTTPClient:StartCooldown(force)
--     if self:IsShuttingDown() then
--         return
--     end

--     -- Do not allow overriding except when the last request was force executed.
--     -- In this case we want to restart the cooldown task.
--     if not force and self:IsOnCooldown() then
--         return PEARL.warn("Attempted to override the cooldown task!")
--     end

--     if self._cooldown_task then
--         --PEARL.debug("Restarting the cooldown task...")
--         self._cooldown_task:restart()
--     else
--         --PEARL.debug("Starting the cooldown task...", "Frequency:", self._frequency)
--         self._cooldown_task = PEARL.WallScheduler:ExecutePeriodic(
--             self._frequency, OnFinishCooldown, nil, nil, nil, self
--         )
--     end
-- end

-- function HTTPClient:StopCooldown()
--     --PEARL.debug("Stopping the cooldown task...")

--     return self._cooldown_task and self._cooldown_task:stop()
-- end

-- Returns the next processed request, if any.
-- function HTTPClient:ProcessNextRequest(force)
--     local next_request = self._queue and self._queue:take()
--     if next_request then
--         self:_DoSendRequest(next_request, force)
--         return next_request
--     end

--     return next_request
-- end

-- function HTTPClient:HandleRequest(request)
--     --PEARL.debug("HTTPClient:HandleRequest")

--     -- If we are not waiting for anything or the queue is disabled
--     -- then send the request immediately
--     if not (self:IsWaiting() or self:IsOnCooldown()) or self:IsQueueDisabled() or self:IsShuttingDown() then
--         return self:SendRequest(request)
--     end

--     -- Lazy load the queue if needed
--     if not self._queue then
--         self._queue = Queue(DEFAULT_QUEUE_SIZE_LIMIT)
--     end

--     --PEARL.debug("Adding request to the queue...")
--     if not self._queue:push(request) then
--         return PEARL.error("Failed to push the request to the queue! Queue probably full.", request)
--     end
-- end

-- function HTTPClient:ForceSend(request)

--     -- If we are forcefully sending multiple requests to the same host.
--     -- This is here in order to prevent hitting the rate limits when something
--     -- gets really wrong and some request loop is created.
--     -- if request.host == self._last_host then
--     --     self._force_threshold = self._force_threshold - 1
--     -- end

--     -- PEARL.debug(string.format("Forcing a request! (%d/%d)",
--     --     self._force_threshold, MAX_FORCE_THRESHOLD
--     -- ))

--     return self:SendRequest(request, true)
-- end

--- @param request Request
--- @param seconds number
function HTTPClient:RetryRequestAfter(request, seconds)
    if not request:IsRetryable() then
        return PEARL.warn("Max retry count reached! Request failed...")
    end

    print("RETRIES", request.retries)
    request:OnRetry()
    PEARL.info(("Retrying request in %d seconds... (%d/%d)"):format(
        seconds, request.retries, request.maxretries
    ))

    PEARL.WallScheduler:ExecuteInTime(
        seconds, self.SendRequest, nil, self, request
    )
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param method string The method of the request.
--- @param callbackfn? fun(result: string, success: boolean, http_code: number, ...: any): any The function that should be called after the request completes.
--- @param data string|table? The json data body for the request (JSON or table)
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClient:Request(url, method, callbackfn, data, timeout, ...)
    return Request(url, method)
        :SetOnSuccess(callbackfn, ...)
        :SetData(data)
        :SetTimeout(timeout)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param onsuccess? fun(result: string, success: boolean, http_code: number, ...: any): any The function that should be called after the request completes.
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClient:GET(url, onsuccess, timeout, ...)
    return Request(url, HTTPClient.METHODS.GET)
        :SetOnSuccess(onsuccess, ...)
        :SetTimeout(timeout)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param onsuccess? fun(response: table|string, self: Request, ...: any): any The function that should be called after the request completes.
--- @param data string|table The json data body for the request (JSON or table)
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClient:POST(url, onsuccess, data, timeout, ...)
    assert(data, "Invalid data provided for POST request. Method would be changed to GET implicitly.")
    return Request(url, HTTPClient.METHODS.POST)
        :SetOnSuccess(onsuccess, ...)
        :SetTimeout(timeout)
        :SetData(data)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return HTTPClient
