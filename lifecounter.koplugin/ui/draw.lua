-- Ajudantes de desenho compartilhados pelas telas (so KOReader).
local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")

local Draw = {}

-- Texto que cabe em (max_w x max_h): reduz a fonte ate caber, nunca corta.
function Draw.fit_text(text, max_w, max_h, size, bold)
    local tw
    while size >= 6 do
        tw = TextWidget:new{ text = text, face = Font:getFace("cfont", size), bold = bold, fgcolor = Blitbuffer.COLOR_BLACK }
        local s = tw:getSize()
        if s.w <= max_w and s.h <= max_h then return tw end
        tw:free()
        size = math.floor(size * 0.9)
    end
    return TextWidget:new{ text = text, face = Font:getFace("cfont", 6), bold = bold, fgcolor = Blitbuffer.COLOR_BLACK }
end

function Draw.centered(bb, r, text, size, bold)
    local tw = Draw.fit_text(text, r.w - 16, r.h - 16, size, bold)
    local s = tw:getSize()
    tw:paintTo(bb, r.x + math.floor((r.w - s.w) / 2), r.y + math.floor((r.h - s.h) / 2))
    tw:free()
end

function Draw.box(bb, r, width)
    bb:paintBorder(r.x, r.y, r.w, r.h, width or 2, Blitbuffer.COLOR_BLACK)
end

return Draw
