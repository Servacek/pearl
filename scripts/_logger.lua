
local TheShard, TheNet = TheShard, TheNet
local PEARL = PEARL
local string = string
local GetSkinDescription, GetSkinName, GetColorForItem, UserToName, subfmt = GetSkinDescription, GetSkinName, GetColorForItem, UserToName, subfmt

local Message = require('libraries/discordapi/models/message')
local Embed = require('libraries/discordapi/models/embed')

local UserCommands = require('usercommands')

-------------------------------------

--- @class Logger
local Logger = {}

-------------------------------------
-- [[ Private functions ]]
-------------------------------------

local function ignore_structure(inst)
    return inst == nil or not inst:IsValid() or inst:HasTag("fire") or inst:HasTag("burnt")
end

-------------------------------
-- [[ Entity Action Handlers ]]
-------------------------------

local function structcheckfn(k, v)
    return v and v:IsBaseStructure()
end

function Logger.OnTurnOffEmergencyStruct(doer, target)
    if not doer or not target or not doer:HasTag("player") then return end

    if target:IsBuilderUserid(doer.userid) or not (doer.components.griefer and doer.components.grifer:IsSuspicious()) then
        return
    end

    local icon = PEARL.EMOTES.GAME.SCIENCEMACHINE
    local message = STRINGS.PEARL.ACTIONS.TURNOFF:format(
        doer:GetDisplayName(), target:GetDisplayName()
    )

    if PEARL.CONFIG.ANNS.TURNOFF then
        return PEARL.Announce(message, nil, doer.entity)
    end

    PEARL.Logger:LogString(message, icon)
end

function Logger.OnIgniteEntity(doer, target, neighbors)
    if not doer or not target or not doer:HasTag("player") then return end

    local message
    local icon = PEARL.EMOTES.GAME.TORCH
    local ents_string = PEARL.FormatSortedPrefabs(neighbors, target)
    print(#neighbors, ents_string)
    if ents_string then
        message = STRINGS.PEARL.ACTIONS.IGNITE_NEAR:format(
            doer:GetDisplayName(), target:ToStringSupportStacks(), ents_string
        )
    else
        message = STRINGS.PEARL.ACTIONS.IGNITE:format(
            doer:GetDisplayName(), target:ToStringSupportStacks()
        )
    end

    if PEARL.CONFIG.ANNS.IGNITE and (
        target:IsBaseStructure()
        or #neighbors > 2
        or table.check(neighbors, structcheckfn)
    ) then PEARL.Announce(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES.IGNITE, doer.entity) end

    PEARL.Logger:LogString(message, icon)
end

function Logger.OnFireExtinguished(doer)
    if doer then
        PEARL.Announce(STRINGS.PEARL.LOGS.EXTINGUISH_NEAR:format(
            doer:GetDisplayName()
        ))
    else
        PEARL.Announce(STRINGS.PEARL.LOGS.EXTINGUISH)
    end
end

function Logger.OnHammerStruct(doer, target)
    if not doer or not target or not doer:HasTag("player") then return end
    if target:HasTag("burnt") then return end

    local message
    local icon = PEARL.EMOTES.GAME.HAMMER
    if target:HasBuilder() then
        message = STRINGS.PEARL.LOGS.OWNER:format(
            STRINGS.PEARL.ACTIONS.HAMMER:format(doer:GetDisplayName(), target:GetDisplayName()),
            target:GetBuilderName()
        )
    else
        message = STRINGS.PEARL.ACTIONS.HAMMER:format(
            doer:GetDisplayName(), target:GetDisplayName()
        )
    end

    -- We announce this to the game only if there is a builder
    if PEARL.CONFIG.ANNS.HAMMER
    and target:HasBuilder()
    and not target:IsBuildBy(doer.userid)
    then
        PEARL.Announce(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES.DESTROY)
    end

    PEARL.Logger:LogString(message, icon)
end

function Logger.OnBuild(doer, inst)
    if not doer or not inst or not doer:HasTag("player") then return end
    if not PEARL.PREFABS.FIRE_SOURCES[inst.prefab] then return end

    local entities = inst:GetEntitiesNear(
        PEARL.CONSTS.FIRE_RADIUS,
        PEARL.CONSTS.FIRE_MUSTHAVE_TAGS,
        PEARL.CONSTS.ENT_CANTHAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS
    )

    local ents_string = PEARL.FormatSortedPrefabs(entities)
    if not ents_string then return end

    local icon = PEARL.EMOTES.GAME.FIRE
    local message = STRINGS.PEARL.FIRE_SOURCE_BUILT_NEAR:format(
        doer:GetDisplayName(), inst:GetDisplayName(), ents_string
    )

    if PEARL.CONFIG.ANNS.IGNITE and (
        #entities >= 3
        or entities:check(structcheckfn)
    ) then
        PEARL.Announce(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURNTUP)
    end

    PEARL.Logger:LogString(message, icon)
end

-- TODO
-- function Logger.OnActionAttack(doer, target, invobject)
--     if doer == nil or not doer:HasTag("player") or invobject == nil or target == nil then
--         return
--     end

--     if not SUB.PREFABS.AREA_RANGED_STAFFS[invobject.prefab] or not invobject:HasTag("lighter") then
--         return
--     end

--     local message
--     local entities = SUB.GetEntitiesNear(target, SUB.CONSTS.FIRE_RADIUS, nil, {"fireimmune"})
--     if (#entities > 2 and SUB.ArrayContainsEntityWithTag(entities, "structure")) or #entities >= 5 then
--         print("LIGHTER ATTACK")
--     end
-- end

-- TODO: Apply grief protection
-- TODO: justify the radiuses
function Logger.OnActionCastSpell(doer, target, invobject, pos)
    if (doer == nil or invobject == nil or not doer:HasTag("player"))
    or (target == nil and pos == nil) then
        return
    end

    pos = pos or target:GetPosition()
    local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, PEARL.CONSTS.FIRE_RADIUS,
        PEARL.CONSTS.FIRE_MUSTHAVE_TAGS,
        PEARL.CONSTS.ENT_CANTHAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS
    )

    local message
    local icon
    if target ~= nil then
        icon = PEARL.EMOTES.GAME.HAMMER
         -- Using a area ranged staff on a target near structures (ex. Weather Pain)
        if PEARL.PREFABS.AREA_RANGED_STAFFS[invobject.prefab]
        and (#entities > 2 and PEARL.ArrayContainsEntityWithTag(entities, "structure")) then
            message = string.format(STRINGS.PEARL.USE_STAFF_ON_NEAR,
                doer:GetDisplayName(), invobject:GetDisplayName(), target:GetDisplayName(), PEARL.FormatSortedPrefabs(entities, target)
            )

        -- Using a non-area ranged staff on a structure (Deconstruction Staff)
        -- TODO: replace magic string with a constant
        elseif invobject.prefab == "greenstaff"
        and target:HasTag("structure") and not ignore_structure(target) then
            message = string.format(STRINGS.PEARL.USE_STAFF_ON,
                doer:GetDisplayName(), invobject:GetDisplayName(), target:GetDisplayName()
            )
        end

        if message and PEARL.CONFIG.ANNS.DESTROY then
            PEARL.Announce(message, icon)
        end
    else
        -- Using a staff to summon fire object near objects (ex. Star Caller Staff)
        if PEARL.PREFABS.AREA_RANGED_STAFFS[invobject.prefab]
        and (#entities > 0 and PEARL.ArrayContainsEntityWithTag(entities, "structure", PEARL.IsBurnable)) or #entities >= 5 then
            icon = PEARL.EMOTES.GAME.FIRE
            message = string.format(STRINGS.PEARL.USE_STAFF_NEAR,
                doer:GetDisplayName(), invobject:GetDisplayName(), PEARL.FormatSortedPrefabs(entities, target)
            )
        end

        if message ~= nil and PEARL.CONFIG.ANNS.IGNITE then
            PEARL.Announce(message, icon)
        end
    end

    PEARL.Logger:LogString(message, icon)
end

-- TODO
function Logger.OnActionFeed(doer, target, invobject)
    if doer ~= nil and doer:IsValid() and doer:HasTag("player")
    and target ~= nil and target:IsValid() and invobject ~= nil
    and PEARL.PREFABS.FOOD[invobject.prefab] then
        local icon = PEARL.EMOTES.GAME.FAKETEETH
        local message = string.format(
            STRINGS.PEARL.ACTIONS.FEED, doer:GetDisplayName(), target:GetDisplayName(), invobject:GetDisplayName()
        )

        if PEARL.CONFIG.ANNS.EATRARE then
            PEARL.Announce(message, icon)
        end

        PEARL.Logger:LogString(message, icon)
    end
end

function Logger.OnActivated(doer, target)
    if not (doer and target) then
        return
    end

    PEARL.Logger:LogString(STRINGS.PEARL.ACTIONS.TURNON:format(
        doer:GetDisplayName(), target:GetDisplayName()
    ), PEARL.ICONS.ANNOUNCEMENTS["default"])
end

--V2C: InGamePlay() is used to check whether world has finished
--     loading and snapshot player sessions have been restored.
--     Do not validate inventory when restoring snapshot saves,
--     because the user is not actually logged in at that time.
function Logger.OnStructureBurntUp(target)
    if target and target:IsValid() and InGamePlay() then
        local message
        local icon = PEARL.EMOTES.GAME.FIRE
        if target.builder and target.builder.name then
            message = STRINGS.PEARL.LOGS.OWNER:format(
                STRINGS.PEARL.ACTIONS.BURNTUP:format(target:GetDisplayName()),
                target.builder.name
            )
        else
            message = STRINGS.PEARL.ACTIONS.BURNTUP:format(
                target:GetDisplayName()
            )
        end

        if PEARL.CONFIG.ANNS.BURNTUP then
            PEARL.Announce(message, icon)
        end

        PEARL.Logger:LogString(message, icon)
    end
end

function Logger.OnRareFoodAten(eater, food)
    if not eater or not food then return end

    local icon = PEARL.EMOTES.GAME.FAKETEETH
    local message = STRINGS.PEARL.ACTIONS.EAT:format(
        eater:GetDisplayName(), food:GetDisplayName()
    )

    if PEARL.CONFIG.ANNS.EATRARE then
        PEARL.Announce(message, icon)
    end

    PEARL.Logger:LogString(message, icon)
end

function Logger.OnDangerAtPortal(doer, target)
    if not doer or not target then return end

    local icon = PEARL.EMOTES.GAME.EYEPLANT
    local message = STRINGS.PEARL.DANGER_AT_PORTAL:format(
        doer:GetDisplayName(), target:GetDisplayName()
    )

    if PEARL.CONFIG.ANNS.DANGER_AT_PORTAL then
        PEARL.Announce(message, icon)
    end

    PEARL.Logger:LogString(message, icon)
end

function Logger.OnEntityDeath(data)
    local inst, afflicter
    if data ~= nil then
        inst = data.inst
        afflicter = data.afflicter
    end

    if not inst.prefab then return end

    if not (afflicter ~= nil and inst ~= nil and afflicter:IsValid() and inst:IsValid()) then
        return
    end

    -- MOB SPREADING FIRE AFTER DEATH
    if PEARL.PREFABS.MOBS.FIRE_SPREADERS[inst.prefab] and afflicter:HasTag("player") then
        local entities = inst:GetEntitiesNear(
            -- The flames have bigger radius in this case
            (PEARL.CONSTS.FIRE_RADIUS + 3),
            PEARL.CONSTS.FIRE_MUSTHAVE_TAGS,
            PEARL.CONSTS.ENT_CANTHAVE_TAGS,
            PEARL.CONSTS.ENT_ONEOF_TAGS
        )

        if #entities >= 4 or PEARL.ArrayContainsEntityWithTag(entities, "structure") then
            local icon = PEARL.EMOTES.GAME.FIRE
            local message = string.format(STRINGS.PEARL.MOB_KILLED_NEAR,
                afflicter:GetDisplayName(), inst:GetDisplayName(), PEARL.FormatSortedPrefabs(entities, inst)
            )

            if PEARL.CONFIG.ANNS.IGNITE then
                PEARL.Announce(message, icon)
            end

            PEARL.Logger:LogString(message, icon)
        end

    -- NOT RESPAWNABLE MOB
    elseif PEARL.PREFABS.MOBS.MONITOR_POPULATION[inst.prefab] and afflicter:HasTag("player") then
        local count = c_countprefabs(inst.prefab, false) or -1
        if count <= 0 then return end

        local icon = PEARL.EMOTES.GAME.HAMBAT
        local message = string.format(STRINGS.PEARL.MONITORED_MOB_KILLED,
            afflicter:GetDisplayName(), inst:GetDisplayName(), count
        )

        if PEARL.CONFIG.ANNS.KILLMONITORED then
            PEARL.Announce(message, icon)
        end

        PEARL.Logger:LogString(message, icon)

    -- BOSS, this should be announced even if the afflicter isn't a player
    elseif inst:HasTag("epic") then
        local icon = PEARL.EMOTES.GAME.TROPHY
        local message = string.format(
            STRINGS.PEARL.MOB_KILLED, afflicter:GetDisplayName(), inst:GetDisplayName()
        )

        if PEARL.CONFIG.ANNS.KILLBOSS then
            PEARL.Announce(message, icon)
        end

        PEARL.Logger:LogString(message, icon)

    -- COMPANION
    elseif PEARL.PREFABS.MOBS.COMPANIONS[inst.prefab] and afflicter:HasTag("player") then
        local icon = PEARL.EMOTES.GAME.HAMBAT
        local message = string.format(
            STRINGS.PEARL.MOB_KILLED, afflicter:GetDisplayName(), inst:GetDisplayName()
        )

        if PEARL.CONFIG.ANNS.KILLFOLLOWER then
            PEARL.Announce(message, icon)
        end

        PEARL.Logger:LogString(message, icon)

    -- FOLLOWER
    elseif inst.components and inst.components.follower and afflicter:HasTag("player") then
        local leader = inst.components.follower:GetLeader()
        if leader and leader:IsValid() and leader.userid ~= afflicter.userid and leader:HasTag("player") then
            local icon = PEARL.EMOTES.GAME.HAMBAT
            local message = string.format(
                STRINGS.PEARL.FOLLOWER_KILLED, afflicter:GetDisplayName(), inst:GetDisplayName(), leader:GetDisplayName()
            )

            if PEARL.CONFIG.ANNS.KILLFOLLOWER then
                PEARL.Announce(message, icon)
            end

            PEARL.Logger:LogString(message, icon)
        end
    end
end


function Logger.OnTakeRareItem(doer, data)
    if not (doer and data and data.item) then
        return
    end

    if PEARL.CONFIG.ANNS.TAKE then
        PEARL.Announce(subfmt(STRINGS.PEARL.ACTIONS.TAKE_ITEM.GENERIC, {
            doer = doer:GetDisplayName(), count = data.stacksize, item = data.item:GetDisplayName()
        }), PEARL.EMOTES.GAME.BACKPACK)
    end
end
-- local last_picked = nil
-- local last_picker = nil
-- function Logger.OnPutInInventory(item, owner)
--     if not (owner ~= nil and item ~= nil) then
--         return
--     end

--     -- For backpacks, bundles and stuff like that
--     owner = item.components.inventoryitem:GetGrandOwner()

--     -- Not only players have inventory!
--     if owner:HasTag("player") and owner ~= item.lastowner and owner ~= nil
--     and (last_picked ~= item or last_picker ~= owner) then
--         local count = 1
--         if item.components.stackable then
--             count = item.components.stackable:StackSize()
--         end

--         local icon = SUB.EMOTES.GAME.BACKPACK
--         local message = string.format(
--             SUB.STRINGS.ITEM_PICKED, owner:GetDisplayName(), count, item:GetDisplayName()
--         )

--         if SUB.CONSTS.ANNS.PICKUP then
--             PEARL.Announce(message, SUB.EMOTES.GAME.BACKPACK)
--         end

--         SUB.Lhook:SendAnnouncement(message, icon)
--     end

--     print("-------------------------")
--     print("Last owner: ", item.lastowner)
--     print("New owner: ", owner)
--     print("Last picker: ", last_picker)
--     print("Last picked: ", last_picked)

--     item.lastowner = owner
--     last_picked = item
--     if owner:HasTag("player") then
--         last_picker = owner
--     end
-- end

----------------------------

PEARL.Logger = Logger
