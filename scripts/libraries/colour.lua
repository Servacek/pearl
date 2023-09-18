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
    The Game uses percentages to represent RGB colors most of the time.
    When transmitting colors via RPCs or the HTTP protocol, we convert them
    to their decimal 32 bit integer representation.

    -----------------------------------------------------------------------

    By default a decimal representation uses only 24 bits. So it stores
    only the RGB values. If you want to store the alpha channel
    in a decimal use the functions with Decimal32 which use even the fourh byte.

    Note that this is here just for internal stuff since third party
    endpoints do not use colors with alpha channels normally.
--]]


--------------------------------
-- [[ Localizations ]]
--------------------------------

local math = math
local bit = bit

--------------------------------
-- [[ Constants ]]
--------------------------------

local HEX_RGB_PATTERN = "#%06X"
local HEX_RGBA_PATTERN = "#%08X"

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class Colour
local Colour = {}

--------------------------------
-- [[ Factories ]]
--------------------------------
-- Since the game prefers to use percentages to represent colours
-- these factories always return a table of percentual representations
-- of each of the colour channel including the alpha channel.

--- Colors default to 0 and alpha channel to 255
--- @param r integer? red (0-255)
--- @param g integer? green (0-255)
--- @param b integer? blue (0-255)
--- @param a integer? optional alpha (0-255)
--- @return table<p_red, p_green, p_blue, p_alpha>
function Colour.FromRGBA(r, g, b, a)
    return {Colour.RGBAToPercent(r or 0, g or 0, b or 0, a or 255)}
end

--- @param decimal integer The color's RGB 24 bit decimal value.
--- @return table<p_red, p_green, p_blue, p_alpha>
function Colour.FromDecimal(decimal)
    return {Colour.DecimalToPercent(decimal)}
end

--- @param decimal integer The color's RGBA 32 bit decimal value.
--- @return table<p_red, p_green, p_blue, p_alpha>
function Colour.FromDecimal32(decimal)
    return {Colour.Decimal32ToPercent(decimal)}
end

--------------------------------
-- [[ Converters ]]
--------------------------------

--- @param r number percent of red (0-1)
--- @param g number percent of green (0-1)
--- @param b number percent of blue (0-1)
--- @param a number? optional percent of the alpha channel (0-1) (1 by default)
--- @return integer red, integer green, integer blue, integer alpha
function Colour.PercentToRGBA(r, g, b, a)
    return
        math.floor(r * 255),
        math.floor(g * 255),
        math.floor(b * 255),
        math.floor((a or 1) * 255)
end

--- @param r integer red (0-255)
--- @param g integer green (0-255)
--- @param b integer blue (0-255)
--- @param a integer? optional alpha (0-255) (255 by default)
--- @return number p_red, number p_green, number p_blue, number p_alpha
function Colour.RGBAToPercent(r, g, b, a)
    return r / 255, g / 255, b / 255, (a or 255) / 255
end

--- @param r number red (0-255)
--- @param g number green (0-255)
--- @param b number blue (0-255)
--- @return integer decimal
function Colour.RGBToDecimal(r, g, b)
    return math.floor(bit.lshift(r, 16) + bit.lshift(g, 8) + b)
end

--- @param r number red (0-255)
--- @param g number green (0-255)
--- @param b number blue (0-255)
--- @param a number alpha (optional, default 255) (0-255)
--- @return integer decimal
function Colour.RGBAToDecimal32(r, g, b, a)
    return math.floor(
        bit.lshift(r, 24) + bit.lshift(g, 16) + bit.lshift(b, 8) + (a or 255)
    )
end

--- @param decimal integer An decimal integer using 24 bits for the RGB color.
--- @return integer red, integer green, integer blue
function Colour.DecimalToRGB(decimal)
    return
        bit.band(bit.rshift(decimal, 16), 0xFF),
        bit.band(bit.rshift(decimal, 8), 0xFF),
        bit.band(decimal, 0xFF)
end

--- @param decimal integer An decimal integer using 32 (storing the alpha channel as well) bits for the RGBA color.
--- @return integer red, integer green, integer blue, integer alpha
function Colour.Decimal32ToRGBA(decimal)
    return
        bit.band(bit.rshift(decimal, 24), 0xFF),
        bit.band(bit.rshift(decimal, 16), 0xFF),
        bit.band(bit.rshift(decimal, 8), 0xFF),
        bit.band(decimal, 0xFF)
end

--- @param r number percent of red (0-1)
--- @param g number percent of green (0-1)
--- @param b number percent of blue (0-1)
--- @return integer
function Colour.PercentToDecimal(r, g, b)
    return Colour.RGBToDecimal(Colour.PercentToRGBA(r, g, b))
end

--- @param r number percent of red (0-1)
--- @param g number percent of green (0-1)
--- @param b number percent of blue (0-1)
--- @param a number percent of alpha channel (optional, default 1) (0-1)
--- @return integer
function Colour.PercentToDecimal32(r, g, b, a)
    return Colour.RGBAToDecimal32(Colour.PercentToRGBA(r, g, b, a))
end

--- @param decimal integer The color's RGB 24 bit decimal value.
--- @return number p_red, number p_green, number p_blue, number p_alpha
function Colour.DecimalToPercent(decimal)
    return Colour.RGBAToPercent(Colour.DecimalToRGB(decimal))
end

--- @param decimal integer The color's RGBA 32 bit decimal value.
--- @return number p_red, number p_green, number p_blue, number p_alpha
function Colour.Decimal32ToPercent(decimal)
    return Colour.RGBAToPercent(Colour.Decimal32ToRGBA(decimal))
end

--- @param decimal integer The color's RGB 24 bit decimal value.
--- @return string hex
function Colour.DecimalToHEX(decimal)
    return HEX_RGB_PATTERN:format(decimal)
end

--- @param decimal integer The color's RGBA 32 bit decimal value.
--- @return string hex
function Colour.Decimal32ToHEX(decimal)
    return HEX_RGBA_PATTERN:format(decimal)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return Colour
