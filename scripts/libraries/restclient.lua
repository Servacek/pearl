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

--- @TODO: Think about some way to prevent forced request to exceed rate limits.
--- Since now you basically force requests in a loop...

local Queue = PEARL.loadfile("models/queue")
local Request = PEARL.loadfile("models/request")

local PEARL = PEARL
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
local MAX_FORCE_THRESHOLD = 3

--------------------------------
-- [[ Private Functions ]]
--------------------------------

local _SendRequest, _ProcessQueue, _FinishCooldown

_SendRequest = function(self, request, force)
    -- PEARL.debug("_SendRequest", request, force)

    if not request or (self._cooldown and not force) then
        return
    end

    self:SetIsOnCooldown(true)
    TheSim:QueryServer(request.url, function(...)
        request:OnCompleted(...)

        -- Wait a few seconds before executing next request
        self:StartCooldown()
        self:ResetForceTreshold()
    end, request.method, request.data, request.timeout)

    self._rcount = self._rcount + 1
end

_ProcessQueue = function(self)
    if not self._queue then
        return
    end

    _SendRequest(self, self._queue:Take())
end

_FinishCooldown = function(self)
    self:SetIsOnCooldown(false)

    -- Allow garbage-collection for the cooldown task
    -- Would be better if the task could be recycled.... @TODO
    self._cooldown_task = nil

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
    self._cooldown = false
    self._shutting_down = false
    --self._ready = false

    -- [[ Events ]]
    PEARL.EventProcessor:AddEventHandler("quit", function()
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

function RestClient:SetIsOnCooldown(cooldown)
    self._cooldown = cooldown

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

function RestClient:IsOnCooldown()
    return self._cooldown
end

function RestClient:IsShuttingDown()
    return self._shutting_down
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

function RestClient:StartCooldown()
    if self:IsShuttingDown() then
        return
    end

    -- Do not allow overriding except when the last request was force executed.
    -- In this case we want to reset the cooldown task.
    if self._cooldown_task and not self._cooldown_task.finished then
        return PEARL.warn("Attempted to override an unfinished cooldown task!")
    end

    PEARL.debug("Cooling down...")
    self._cooldown_task = PEARL.Scheduler:ExecuteInTime(
        self._frequency, _FinishCooldown, nil, self
    )
end

function RestClient:ProcessRequest(request)
    -- If we are not waiting for anything or the queue is disabled
    -- then send the request immediately
    if not self:IsOnCooldown() or self:IsQueueDisabled() or self:IsShuttingDown() then
        return _SendRequest(self, request)
    end

    -- Lazy load the queue if needed
    if not self._queue then
        self._queue = Queue(DEFAULT_QUEUE_SIZE_LIMIT)
    end

    PEARL.debug("Adding request to the queue...")
    self._queue:Push(request)
end

function RestClient:ForceSend(request)
    if self._force_threshold <= 0 then
        return false
    end

    -- Clear the cooldown task for now and reset it when the forced request completes
    if self._cooldown_task then
        PEARL.debug("Clearing the task because of the forced request!")

        self._cooldown_task:Cancel()
        self._cooldown_task = nil
    end

    self._force_threshold = self._force_threshold - 1

    PEARL.debug(string.format("Forcing a request! (%d/%d)",
        self._force_threshold, MAX_FORCE_THRESHOLD
    ))
    _SendRequest(self, request, true)

    return true
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

    return PEARL.Scheduler:ExecuteInTime(seconds, function()
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
    PEARL.info("Requester", "Shutting down...")
    self._shutting_down = true

    if self._cooldown_task then
        self._cooldown_task:Cancel()
        self._cooldown_task = nil
    end

    if not self._queue or self._queue:IsEmpty() then
        -- We are done here.
        return
    end

    PEARL.info("Processing queued requests...")

    for request in self._queue:Iter() do
        if request and not request:CanSkipOnDeadline() then
            if not self:ForceSend(request) then
                PEARL.info("Force-sent requests limit reached! Skipping the remaining requests...")
                break
            end
        end
    end

    self._queue:Clear()
end

--------------------------------
-- [[ Return ]]
--------------------------------

return RestClient
