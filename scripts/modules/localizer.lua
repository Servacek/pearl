--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category BackEnd

--------------------------------
-- [[ Setup - Server ]]
--------------------------------

PEARL.ServerNetwork:AddConnectionFilter(function(userid, cfd)
    local locale = cfd.locale and string.upper(cfd.locale)
    if type(locale) ~= "string" or #locale <= 0 then
        PEARL.warn("Invalid locale!")
        return PEARL.CONFIG.FAIL_SAFE_NETWORK
    end

    PEARL.info("Client", userid, "localized as", cfd.locale)
    PEARL.PlayerDB:SafeSetField(userid, "lastlocale", locale)

    -- If the player was already loaded we do not care about localization.
    -- This happens for example during migration.
    if (
        (PEARL.CONFIG.LOCALIZER.CACHE and PEARL.PlayerDB:GetField(userid, "hadallowedlocale") == true) or
        PEARL.AllowList:Contains(userid) or
        PEARL.WhiteList:Contains(userid) or
        (PEARL.AdminList:Contains(userid) and not PEARL.CONFIG.DEBUG_MODE)
    ) then
        PEARL.debug("Client allowed.")
        return true -- Allow the connection
    end

    -- Check only if the locale is allowed explicitly
    -- So by default everything is prohibited
    -- Everything else should be checked before sending the localization request
    -- Cache only successfull localizations.
    if PEARL.ServerNetwork:IsLocaleAllowed(locale) then
        PEARL.info("Locale allowed.")

        if PEARL.CONFIG.LOCALIZER.CACHE then
            PEARL.info("Caching localized userid...")
            PEARL.PlayerDB:SetField(userid, "hadallowedlocale", true)
        end

        return true -- Allow the connection
    end

    PEARL.info("Locale prohibited.")
    -- Do not allow further loading
    return false, "ID_DST_LOCALE_BLOCKED"
end)
