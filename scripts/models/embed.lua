
local Embed = Class(function(self)
    self.title = nil
    self.url = nil
    self.description = nil
    self.color = nil
    self.image = {}
end)

function Embed:SetTitle(str, url)
    self.title = str

    if url ~= nil then
        self.url = url
    end

    return self
end

function Embed:SetDescription(str)
    self.description = str

    return self
end

function Embed:SetColor(int)
    self.color = int

    return self
end

function Embed:SetImage(url)
    self.image['url'] = url

    return self
end

function Embed:ToTable()
    return {
        title = self.title,
        description = self.description,
        color = self.color,
        image = self.image,
    }
end

-----------------------------------------------

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

-------------------------------

return Embed