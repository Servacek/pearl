--[[
    TODOS:
        - Restarting the client will crash the game.
        - Do not call this everytime we are loading, only when the server requests it.
        - VERY UNSTABLE, DEBUG IS NEEDED!
--]]


local PEARL = PEARL

---------------------------------
-- [[ Contants ]]
---------------------------------
-- Wait 12 frames for a server response.
local LOAD_DELAY = 12 * FRAMES

---------------------------------
-- [[ Declaration ]]
---------------------------------

PEARL.ClientLoader = {}

---------------------------------
-- [[ Private ]]
---------------------------------

local _load_fn = nil
local _load_task = nil
local _loaded = false
local _loading = false

local function _SetClientLoadFn(fn)
    _load_fn = fn
end

---------------------------------
-- [[ Public ]]
---------------------------------

function PEARL.ClientLoader:Load()
    if type(_load_fn) ~= "function" then
        return PEARL.error("_load_fn is invalid!")
    end

    if _loaded then
        return PEARL.warn("Client already loaded")
    end

    self:CancelDelayedLoad()

    PEARL.debug("Loading the client...", _load_fn)
    _loading = true
    Profile:Load(_load_fn)
    _loaded = true
    _loading = false
end

function PEARL.ClientLoader:DelayLoad()
    -- If task already exits, override it
    if self:IsLoadDelayed() then
        self:CancelDelayedLoad()
    end

    if _loaded then
        return PEARL.warn("Client already loaded")
    end

    PEARL.debug("Delaying client load... Waiting for a response from the server.")
    _load_task = staticScheduler:ExecuteInTime(LOAD_DELAY, self.Load, nil, self)
end

function PEARL.ClientLoader:CancelDelayedLoad()
    if self:IsLoadDelayed() then
        _load_task:Cancel()
        _load_task = nil
    end
end

function PEARL.ClientLoader:IsLoaded()
    return _loaded
end

function PEARL.ClientLoader:IsLoading()
    return _loading
end

function PEARL.ClientLoader:IsLoadDelayed()
    return _load_task ~= nil and _load_task.limit and _load_task.limit > 0
end

---------------------------------
-- [[ Setup ]]
---------------------------------

PEARL.AddClientPreLoad(function(self, load_fn)
    if not _load_fn then
        _SetClientLoadFn(load_fn)
    end
end)


PEARL.AddGlobalFunctionPreCall("OnNetworkDisconnect", function()
    PEARL.ClientLoader:CancelDelayedLoad()
end)
