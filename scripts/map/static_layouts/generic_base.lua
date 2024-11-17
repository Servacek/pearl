--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



return function (x, y, z)
    -- Spawn a ready-made base!
    local topleft = Vector3(x - 12, 0, z - 12)
    local bottomright = Vector3(x + 12, 0, z + 12)
    local width = bottomright-topleft
    -- No walls in this version.
    -- for i=0,width.x do
    --     if i < width.x/2-1 or i > width.x/2+1 then
    --         local wall = SpawnPrefab("wall_stone")
    --         wall.Transform:SetPosition(topleft.x + i, 0, topleft.z)
    --         wall = SpawnPrefab("wall_stone")
    --         wall.Transform:SetPosition(bottomright.x - i, 0, bottomright.z)
    --     end
    -- end
    -- for i=0,width.z do
    --     if i < width.z/2-1 or i > width.z/2+1 then
    --         local wall = SpawnPrefab("wall_wood")
    --         wall.Transform:SetPosition(topleft.x, 0, topleft.z + i)
    --         wall = SpawnPrefab("wall_hay")
    --         wall.Transform:SetPosition(bottomright.x, 0, bottomright.z - i)
    --     end
    -- end

    local function pass() end
    local function fill_container(container, prefabs)
        local inventory = container.components.container
        for prefab, stacksize in pairs(prefabs) do
            local item = SpawnPrefab(prefab)
            if item then
                item.Transform:SetPosition(x, 0, z)
                if item.components.stackable then
                    item.components.stackable:SetStackSize(stacksize)
                end
                inventory:GiveItem(item)
            end
        end
    end
    local function hang(meatrack, prefab)
        if meatrack.components.dryer then
            meatrack.components.dryer:StartDrying(SpawnPrefab(prefab))
        end
    end

    local items = {
        {"homesign", function(sign)
            if sign.components.writeable then
                sign.components.writeable:SetText("Welcome to the base.")
            end
        end},
        {"lightning_rod", pass},
        {"treasurechest", function(chest) fill_container(chest, {
            ["log"] = 5,
            ["flint"] = 4,
            ["heatrock"] = 1,
            ["backpack"] = 1,
        }) chest.Transform:SetPosition(x - 8, 0, z - 9) end},
        {"treasurechest", function(chest) fill_container(chest, {
            ["cutgrass"] = 10,
            ["torch"] = 1,
            ["axe"] = 1,
            ["spear"] = 1,
            ["pickaxe"] = 1,
        }) chest.Transform:SetPosition(x - 8, 0, z - 10) end},
        {"treasurechest", function(chest) fill_container(chest, {
            ["armorwood"] = 1,
            ["backpack"] = 1, -- Will be dropped next to it.
            ["footballhat"] = 1,
            ["flowerhat"] = 1,
            ["winterhat"] = 1,
        }) chest.Transform:SetPosition(x - 8, 0, z - 11) end},
        {"researchlab2", function(engine) engine.Transform:SetPosition(x - 8, 0, z - 8) end},
        {"firepit", function(firepit) firepit.Transform:SetPosition(x + 5, 0, z + 5) end},
        {"coldfirepit", pass},
        {"meatrack", function(meatrack) hang(meatrack, "monstermeat") end},
        {"meatrack", function(meatrack) hang(meatrack, "monstermeat") end},
        {"meatrack", function(meatrack) hang(meatrack, "meat") end},
        {"meatrack", function(meatrack) hang(meatrack, "meat") end},
        {"icebox", function(chest) fill_container(chest, {
            ["meatballs"] = 2,
            ["berries"] = 4,
            ["carrot"] = 2,
            ["heatrock"] = 1,
            ["monstermeat"] = 5,
        }) chest.Transform:SetPosition(x + 10, 0, z + 8) end},
        {"cookpot", function(cookpot) cookpot.Transform:SetPosition(x + 8, 0, z + 8) end},
        {"birdcage", function(birdcage) -- Spawn a birdcage with a crow in it.
            if birdcage.components.occupiable then
                local result = birdcage.components.occupiable:Occupy(SpawnPrefab("crow"))
            end
        end},
        --{"firesuppressor", pass}, -- This extinguishes the firepits :/
    }
    for _, item in ipairs(items) do
        local prefab = item[1]
        local pos = topleft + Vector3(width.x*math.random(), 0, width.z*math.random())
        local inst = SpawnPrefab(prefab)
        if inst then
            if not inst.components.built then
                inst:AddComponent("built")
            end

            inst.components.built:SetBuilderData(TheNet:GetUserID(), "[HOST]")

            inst.Transform:SetPosition(pos.x, pos.y, pos.z)
            item[2](inst)
        end
    end

    -- Clear out any trees in the area
    local trees = TheSim:FindEntities(x, y, z, 12, {"tree"}, {"stump"})
    for _, tree in ipairs(trees) do
        if tree.components.workable and tree.components.workable.action == ACTIONS.CHOP then
            tree.components.workable:Destroy(TheWorld)
        end
    end

    --- Some resources for easier survival
    local group_items = {
        "grass",
        "berrybush",
        "sapling",
    }
    for i,v in ipairs(group_items) do
        for _ = 1, 6 do
            local attempts = 100
            local plant = SpawnPrefab(group_items[i])
            for attempt = 1, attempts do -- 1000 attempts to place each plant, then it gives up
                local pos = topleft + Vector3(width.x*math.random(), 0, width.z*math.random())
                if TheWorld.Map:CanDeployPlantAtPoint(pos, plant) then
                    plant.Transform:SetPosition(pos.x, pos.y, pos.z)
                    break
                end

                if attempt == attempts then
                    plant:Remove() -- We give up.
                end
            end
        end
    end
end
