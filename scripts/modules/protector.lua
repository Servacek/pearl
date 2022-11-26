--- @TODO for v2.1

local PEARL = PEARL


local _active_tasks = {}

-----------------------------------------------
-- [[ Private Functions ]]
-----------------------------------------------

local function doextinguishextask(pos)
    if not pos then return end

    PEARL.ExtinguishFiresNear(pos.x, pos.y, pos.z)
    TheNet:Announce(STRINGS.PEARL.LOGS.EXTINGUISH)
end

-----------------------------------------------
-- [[ Private Action Handlers ]]
-----------------------------------------------

local function onstartedfire(player, data)
    if not (player and player.userid and data and data.target and data.near) then
        return
    end

    if (data.target:IsBaseStructure() and not data.near:IsBuildBy(player.userid)
        and #data.near > 2) or #data.near > 4
    then
        if not _active_tasks[player.userid] then
            _active_tasks[player.useird] = PEARL.Scheduler:ExecuteInTime(
                4, doextinguishextask, nil, data.target:GetPosition()
            )
        end
    end
end

local function onplayerjoined(world, player)
    if player then
        player:ListenForEvent("sub_onstartedfire", onstartedfire)
    end
end

local function onplayerleft(world, player)
    if player then
        player:RemoveEventCallback("sub_onstartedfire", onstartedfire)
    end
end

---------------------------

PEARL.AddWorldPostInit(function(inst)
    inst:ListenForEvent("ms_playerjoined", onplayerjoined)
    inst:ListenForEvent("ms_playerleft", onplayerleft)
end)
