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
--]]

local Queue = PEARL.loadfile("libraries/queue")
local Request = PEARL.loadfile("models/request")

local Class = Class
local TheSim = TheSim

--------------------------------
-- [[ Constants ]]
--------------------------------

local DEFAULT_QUEUE_SIZE_LIMIT = 10
-- This is here in case something fails and the request frequency
-- isn't set according to the configurations.
local DEFAULT_REQUEST_FREQUENCY = 2
-- Determines the number of requests which can be force-sent from the queue
-- when the requester is shutting down.
local MAX_FORCE_THRESHOLD = 5

--------------------------------
-- [[ Private Functions ]]
--------------------------------

local _SendRequest, _ProcessQueue, _FinishCooldown

_SendRequest = function(self, request, force)
    if type(request) ~= "table" then
        return PEARL.warn("Attempted to send an invalid request!")
    end

    -- Run in a protected call so if an error occures and the request is not actually
    -- being sent, we do not block the requester.
    local success, err = pcall(TheSim.QueryServer, TheSim, request.url, function(...)
        request:OnCompleted(...)

        self:SetIsWaiting(false)

        -- Wait a few seconds before executing next request
        self:StartCooldown(force)
        self:ResetForceTreshold()
    end, request.method, request.data, request.timeout)

    if success then
        self:SetIsWaiting(true)
        self._rcount = self._rcount + 1
    else -- If we have failed to execute the task
        PEARL.error("Failed to execute request!", err)
        _FinishCooldown(self)
    end

    return success, err
end

_ProcessQueue = function(self)
    local next_request = self._queue and self._queue:take()
    if next_request then
        _SendRequest(self, next_request)
    end
end

_FinishCooldown = function(self)
    self._cooldown_task:stop()

    _ProcessQueue(self)
end

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class RestClient singleton
local RestClient = Class(function(self)
    self._frequency = DEFAULT_REQUEST_FREQUENCY

    self._force_threshold = MAX_FORCE_THRESHOLD

    -- Lazy load the queue
    --- @type Queue?
    self._queue = nil
    self._request_cache = {}
    --- @type Task?
    self._cooldown_task = nil

    -- Used for debugging
    self._rcount = 0

    -- internal state
    self._shutting_down = false
    self._waiting = false
    --self._ready = false

    -- [[ Events ]]
    PEARL.EventProcessor:AddSafeEventHandler("quit", function()
        self:OnShutdown()
    end)
end)

--------------------------------
-- [[ Static Variables ]]
--------------------------------

-- More can be added later
RestClient.METHODS = {
    POST    = "POST",
    GET     = "GET",
}

--------------------------------
-- [[ Setters ]]
--------------------------------

function RestClient:SetIsWaiting(waiting)
    self._waiting = waiting

    return self
end

function RestClient:SetRequestFrequency(frequency)
    self._frequency = frequency

    return self
end

function RestClient:CacheRequest(request)
    self._request_cache[request.url] = request

    return self
end

function RestClient:ResetForceTreshold()
    self._force_threshold = MAX_FORCE_THRESHOLD
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function RestClient:IsQueueDisabled()
    return self._frequency <= 0
end

function RestClient:IsShuttingDown()
    return self._shutting_down
end

function RestClient:IsWaiting()
    return self._waiting
end

function RestClient:IsOnCooldown()
    return self._cooldown_task ~= nil and self._cooldown_task.running
end

-- function RestClient:IsReady()
--     return self._ready
-- end

function RestClient:GetCached(url)
    return self._request_cache[url]
end

-- Used for debugging purposes
function RestClient:GetSentRequestsCount()
    return self._rcount
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function RestClient:StartCooldown(force)
    if self:IsShuttingDown() then
        return
    end

    -- Do not allow overriding except when the last request was force executed.
    -- In this case we want to restart the cooldown task.
    if not force and self:IsOnCooldown() then
        return PEARL.warn("Attempted to override the cooldown task!")
    end

    if self._cooldown_task then
        PEARL.debug("Restarting the cooldown task...")
        self._cooldown_task:restart()
    else
        PEARL.debug("Starting the cooldown task...")
        self._cooldown_task = PEARL.WallScheduler:ExecutePeriodic(
            self._frequency, _FinishCooldown, nil, nil, nil, self
        )
    end
end

function RestClient:ProcessRequest(request)
    -- If we are not waiting for anything or the queue is disabled
    -- then send the request immediately
    if not (self:IsWaiting() or self:IsOnCooldown()) or self:IsQueueDisabled() or self:IsShuttingDown() then
        return _SendRequest(self, request)
    end

    -- Lazy load the queue if needed
    if not self._queue then
        self._queue = Queue(DEFAULT_QUEUE_SIZE_LIMIT)
    end

    PEARL.debug("Adding request to the queue...")
    if not self._queue:push(request) then
        return PEARL.error("Failed to push the request to the queue!", request)
    end
end

function RestClient:ForceSend(request)
    if self._force_threshold <= 0 then
        return false
    end

    if self._cooldown_task and self._cooldown_task.running then
        PEARL.debug("Stopping the cooldown task...")
        self._cooldown_task:stop()
    end

    self._force_threshold = self._force_threshold - 1

    PEARL.debug(string.format("Forcing a request! (%d/%d)",
        self._force_threshold, MAX_FORCE_THRESHOLD
    ))

    return _SendRequest(self, request, true)
end

function RestClient:Request(url, method)
    local cached = self:GetCached(url)
    if cached ~= nil and cached.method == method then
        --PEARL.debug(method.." (cached)", url)
        return cached
    end

    --PEARL.debug(method, url)
    local request = Request(url, method)

    if not self:IsShuttingDown() then
        PEARL.debug("Caching request...")
        self:CacheRequest(request)
    end

    return request
end

function RestClient:RetryRequestAfter(request, seconds)
    PEARL.info("Retrying request in", seconds, "seconds...")

    return PEARL.WallScheduler:ExecuteInTime(seconds, function()
        RestClient:ProcessRequest(request)
    end)
end

function RestClient:GET(url, callbackfn, timeout, ...)
    return self:Request(url, RestClient.METHODS.GET)
        :SetCallbackFn(callbackfn, ...)
        :SetTimeout(timeout)
end

function RestClient:POST(url, callbackfn, encoded_data, timeout, ...)
    return self:Request(url, RestClient.METHODS.POST)
        :SetCallbackFn(callbackfn, ...)
        :SetTimeout(timeout)
        :SetData(encoded_data)
end

--------------------------------
-- [[ Callbacks ]]
--------------------------------

function RestClient:OnShutdown()
    PEARL.info("Shutting down...")
    self._shutting_down = true

    if self._cooldown_task then
        self._cooldown_task:cancel()
        self._cooldown_task = nil
    end

    if not self._queue or self._queue:empty() then
        -- We are done here.
        return
    end

    PEARL.info("Processing queued requests...")

    for request in self._queue:iter() do
        if request and not request:CanSkipOnDeadline() then
            if not self:ForceSend(request) then
                PEARL.info("Force-sent requests limit reached! Skipping the remaining requests...")
                break
            end
        end
    end

    self._queue:clear()
end

--------------------------------
-- [[ Return ]]
--------------------------------

return RestClient
