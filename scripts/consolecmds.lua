


function PEARL.c_inventory(userid)
    if type(userid) ~= "string" then
        return PEARL.error("Invalid userid parameter")
    end

    local inventory, prefab, name = PEARL.GetInventoryTabelFor(userid)
    PEARL.info(DataDumper(inventory))

    local embed = PEARL.InventoryToEmbed(inventory, prefab, name, userid)
    return PEARL.Logger:LogEmbed(embed)
end

function PEARL.c_fire()
    for _, v in ipairs(AllPlayers) do
        if v.Transform then
            PEARL.ExtinguishFiresNear(
                v.Transform:GetWorldPosition()
            )
        end
    end

    PEARL.info("Fires near all", AllPlayers and #AllPlayers or 0, "were extinguished!")
end

function PEARL.c_unban(userid)
    return PEARL.Blacklist.RemovePlayerByID(userid)
end
