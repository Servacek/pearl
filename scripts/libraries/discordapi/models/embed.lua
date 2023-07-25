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
    For the embed object, you can set every field except type (it will be rich regardless of if you try to set it),
    provider, video, and any height, width, or proxy_url values for images.
--]]

--- @type utf8
local utf8 = PEARL.loadfile("libraries/utf8")

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class Embed
local Embed = Class(function(self)
    self.author = nil
    self.title = nil
    self.url = nil
    self.description = nil
    self.footer = nil
    self.color = nil

    self.image = nil
    self.url = nil
    self.thumbnail = nil
    self.timestamp = nil

    self.fields = nil
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

--- @param title? string title of embed
--- @param url?   string url of embed
--- @return Embed
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

--- @param name	string	name of author
--- @param url?	string	url of author (only supports http(s))
--- @param icon_url?	string	url of author icon (only supports http(s) and attachments)
--- @param proxy_icon_url?	string	a proxied url of author icon
--- @return Embed
function Embed:SetAuthor(name, url, icon_url, proxy_icon_url)
    if not self.author then
        self.author = {}
    end

    self.author.name = name
    self.author.url = url
    self.author.icon_url = icon_url
    self.author.proxy_icon_url = proxy_icon_url

    return self
end

--- @param description?	string	description of embed
--- @return Embed
function Embed:SetDescription(description)
    if not (type(description) == "string" and string.utf8len(description) < Embed.MAX_DESCRIPTION_LENGTH) then
        PEARL.warn("Attempted to set an invalid description! Cropping...")
        description = tostring(description):ltake(Embed.MAX_DESCRIPTION_LENGTH, nil, "...")
    end

    self.description = description

    return self
end

--- @param color?	integer	color code of the embed
--- @return Embed
function Embed:SetColor(color)
    self.color = color

    return self
end

--- @param url	string	source url of thumbnail (only supports http(s) and attachments)
--- @return Embed
function Embed:SetImage(url)
    if type(url) ~= "string" then
        PEARL.error("Invalid embed image URL provided!")
        return self
    end

    if not self.image then
        self.image = {}
    end

    self.image.url = url

    return self
end

--- @param url	string	source url of thumbnail (only supports http(s) and attachments)
--- @return Embed
function Embed:SetThumbnail(url)
    if type(url) ~= "string" then
        PEARL.error("Invalid embed thumbnail URL provided.")
        return self
    end

    if not self.thumbnail then
        self.thumbnail = {}
    end

    self.thumbnail.url = url

    return self
end

--- @param timestamp?	number|string	timestamp of embed content
--- @return Embed
function Embed:SetTimestamp(timestamp)
    if type(timestamp) == "number" then
        -- Discord accepts only ISO8601 formatted timestamps
        self.timestamp = PEARL.ToISO8601UTC(timestamp)
    else
        self.timestamp = timestamp
    end

    return self
end

--- @param text	string	footer text
--- @param icon_url?	string	url of footer icon (only supports http(s) and attachments)
--- @param proxy_icon_url?	string	a proxied url of footer icon
--- @return Embed
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

--- @param url string	url of embed
--- @return Embed
function Embed:SetUrl(url)
    self.url = url

    return self
end

--- @param name	string	name of the field
--- @param value	string	value of the field
--- @param inline?	boolean	whether or not this field should display inline
--- @return Embed
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

--- The combined sum of characters in all title, description, field.name, field.value,
--- footer.text, and author.name fields across all embeds
--- attached to a message must not exceed 6000 characters.
function Embed:GetTotalLength()
    local length = 0

    if self.title then
        length = length + #self.title
    end

    if self.description then
        length = length + #self.description
    end

    if self.fields and #self.fields > 0 then
        for i = 1, #self.fields do
            if self.fields[i] then
                length = length + (self.fields[i].name and #self.fields[i].name or 0)
                length = length + (self.fields[i].value and #self.fields[i].value or 0)
            end
        end
    end

    if self.footer then
        length = length + (self.footer.text and #self.footer.text or 0)
    end

    if self.author then
        length = length + (self.author.name and #self.author.name or 0)
    end

    return length
end

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

function Embed:HasAuthor()
    return self.author ~= nil and self.author.name ~= nil
end

function Embed:HasFields()
    return self.fields ~= nil and #self.fields > 0
end

function Embed:IsValid()
    return self:HasTitle() or self:HasDescription() or self:HasFields()
end

function Embed:ToTable()
    return {
        author = self.author,
        title = self.title,
        description = self.description,
        color = self.color,
        image = self.image,
        footer = self.footer,
        url = self.url,
        fields = self.fields,
        thumbnail = self.thumbnail,
        timestamp = self.timestamp,
    }
end

function Embed:ToJson()
    return json.encode_sanitized(self:ToTable())
end

------------------------------------------

return Embed
