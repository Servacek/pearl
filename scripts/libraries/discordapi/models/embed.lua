--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @type utf8
local utf8 = PEARL.loadfile("libraries/utf8")

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class Embed
local Embed = Class(function(self)
    self.title = nil
    self.url = nil
    self.description = nil
    self.footer = nil
    self.color = nil

    self.image = nil
    self.url = nil
    self.thumbnail = nil
    self.timestamp = nil

    self.field = nil
end)

------------------------------------------
-- [[ Static Variables ]]
------------------------------------------

Embed.MAX_DESCRIPTION_LENGTH    = 4096
Embed.MAX_TITLE_LENGTH          = 256
Embed.MAX_FIELDS                = 25
Embed.MAX_FIELD_NAME_LENGTH     = 256
Embed.MAX_FIELD_VALUE_LENGTH    = 1024
Embed.MAX_FOOTER_LENGTH         = 2048
Embed.MAX_AUTHOR_LENGTH         = 256

Embed.COLORS = {
    DEFAULT	       = 0,
    AQUA	       = 1752220,
    DARK_AQUA	   = 1146986,
    GREEN	       = 3066993,
    DARK_GREEN	   = 2067276,
    BLUE	       = 3447003,
    DARK_BLUE	   = 2123412,
    PURPLE	       = 10181046,
    DARK_PURPLE	   = 7419530,
    GOLD	       = 15844367,
    DARK_GOLD	   = 12745742,
    ORANGE	       = 15105570,
    DARK_ORANGE	   = 11027200,
    RED	           = 15158332,
    DARK_RED	   = 10038562,
    GREY	       = 9807270,
    DARK_GREY	   = 9936031,
    DARKER_GREY	   = 8359053,
    LIGHT_GREY	   = 12370112,
    NAVY	       = 3426654,
    DARK_NAVY	   = 2899536,
    YELLOW	       = 16776960,
}

------------------------------------------
-- [[ Setters ]]
------------------------------------------
-- ALWAYS return self in these

function Embed:SetTitle(title, url)
    if not (type(title) == "string" and string.utf8len(title) < Embed.MAX_TITLE_LENGTH) then
        PEARL.warn("Attempted to set an invalid title!")

        return self
    end

    self.title = title

    if type(url) == "string" then
        self.url = url
    end

    return self
end

function Embed:SetDescription(description)
    if not (type(description) == "string" and string.utf8len(description) < Embed.MAX_DESCRIPTION_LENGTH) then
        PEARL.warn("Attempted to set an invalid description! Cropping...")
        description = tostring(description):ltake(Embed.MAX_DESCRIPTION_LENGTH, nil, "...")
    end

    self.description = description

    return self
end

function Embed:SetColor(int)
    self.color = int

    return self
end

function Embed:SetImage(url)
    if not self.image then
        self.image = {}
    end

    self.image.url = url

    return self
end

function Embed:SetThumbnail(url)
    if not self.thumbnail then
        self.thumbnail = {}
    end

    self.thumbnail.url = url

    return self
end

function Embed:SetTimestamp(timestamp)
    if type(timestamp) == "number" then
        -- Discord accepts only ISO8601 formatted timestamps
        self.timestamp = PEARL.ToISO8601UTC(timestamp)
    else
        self.timestamp = timestamp
    end

    return self
end

function Embed:SetFooter(text, icon_url, proxy_icon_url)
    if not (type(text) == "string" and string.utf8len(text) < Embed.MAX_FOOTER_LENGTH) then
        PEARL.warn("Attempted to set an invalid footer text!")

        return self
    end

    if not self.footer then
        self.footer = {}
    end

    self.footer.text = text
    self.footer.icon_url = icon_url
    self.footer.proxy_icon_url = proxy_icon_url

    return self
end

function Embed:SetUrl(url)
    self.url = url

    return self
end

function Embed:AddField(name, value, inline)
    if not (type(name) == "string" and string.utf8len(name) < Embed.MAX_FIELD_NAME_LENGTH) then
        PEARL.warn("Attempted to set an invalid field name!")

        return self
    end

    if not (type(value) == "string" and string.utf8len(value) < Embed.MAX_FIELD_VALUE_LENGTH) then
        PEARL.warn("Attempted to set an invalid field value!")

        return self
    end

    if not self.fields then
        self.fields = {}
    end

    if #self.fields <= Embed.MAX_FIELDS then
        self.fields[#self.fields + 1] = {
            name = name,
            value = value,
            inline = inline,
        }
    end

    return self
end

------------------------------------------
-- [[ Getters ]]
------------------------------------------

function Embed:HasTitle()
    return self.title ~= nil
end

function Embed:HasDescription()
    return self.description ~= nil
end

function Embed:HasImage()
    return self.image ~= nil and self.image.url ~= nil
end

function Embed:HasThumbnail()
    return self.thumbnail and self.thumbnail.url ~= nil
end

function Embed:HasTimestamp()
    return self.timestamp ~= nil
end

function Embed:HasFooter()
    return self.footer ~= nil and self.footer.text ~= nil
end

function Embed:ToTable()
    return {
        title = self.title,
        description = self.description,
        color = self.color,
        image = self.image,
        footer = self.footer,
        url = self.url,
        fields = self.fields,
    }
end

function Embed:ToJson()
    local success, result = pcall(json.encode_compliant, self:ToTable())
    return success, success and utf8.decode_string(result) or result
end

------------------------------------------

return Embed
