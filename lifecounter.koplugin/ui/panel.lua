-- Desenho de um painel de jogador (so KOReader).
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Draw = require("ui/draw")
local Layout = require("core.layout")
local Screen = Device.screen

local Panel = {}

local REASON = { life = "vida", poison = "veneno", commander = "comandante" }

local function max_commander(player)
    local m = 0
    for _, d in pairs(player.cmd) do if d > m then m = d end end
    return m
end

-- Painel "em pe", do tamanho pw x ph.
function Panel.render(player, status, pw, ph, index)
    local bb = Blitbuffer.new(pw, ph, Screen.bb:getType())
    bb:fill(Blitbuffer.COLOR_WHITE)
    local z = Layout.zones(pw, ph)

    Draw.box(bb, { x = 0, y = 0, w = pw, h = ph }, status and 10 or 3)
    for _, name in ipairs({ "minus", "plus", "poison_minus", "poison_plus", "commander" }) do Draw.box(bb, z[name]) end

    Draw.centered(bb, z.minus, "\u{2212}", 200)
    Draw.centered(bb, z.plus, "+", 200)

    local life_r = z.life
    if index then
        Draw.centered(bb, { x = life_r.x, y = life_r.y + 4, w = life_r.w, h = math.floor(life_r.h * 0.12) }, "J" .. index, 22)
    end
    if status then
        local label = { x = life_r.x, y = life_r.y + math.floor(life_r.h * 0.13), w = life_r.w, h = math.floor(life_r.h * 0.16) }
        Draw.centered(bb, label, "FORA: " .. REASON[status], 30, true)
        life_r = { x = life_r.x, y = label.y + label.h, w = life_r.w, h = life_r.y + life_r.h - (label.y + label.h) }
    end
    Draw.centered(bb, life_r, tostring(player.life), 260, true)

    Draw.centered(bb, z.poison_minus, "\u{2212}", 90)
    Draw.centered(bb, z.poison_plus, "+", 90)
    local pv = z.poison_value
    Draw.centered(bb, { x = pv.x, y = pv.y, w = pv.w, h = math.floor(pv.h * 0.35) }, "veneno", 20)
    Draw.centered(bb, { x = pv.x, y = pv.y + math.floor(pv.h * 0.35), w = pv.w, h = pv.h - math.floor(pv.h * 0.35) }, tostring(player.poison), 70, true)

    local c = z.commander
    if status then c = { x = c.x, y = c.y, w = c.w - 12, h = c.h } end -- borda grossa do painel "fora"
    local cmax = max_commander(player)
    Draw.centered(bb, { x = c.x, y = c.y, w = c.w, h = math.floor(c.h * 0.5) }, "Comandante", 34)
    Draw.centered(bb, { x = c.x, y = c.y + math.floor(c.h * 0.5), w = c.w, h = c.h - math.floor(c.h * 0.5) }, cmax > 0 and ("maior: " .. cmax) or "", 26)
    return bb
end

-- Painel ja virado para quem esta sentado (rotation 0 ou 180). O chamador libera o buffer.
function Panel.render_oriented(player, status, pw, ph, rotation, index)
    local bb = Panel.render(player, status, pw, ph, index)
    if rotation == 180 then
        local rotated = bb:rotatedCopy(180)
        bb:free()
        return rotated
    end
    return bb
end

function Panel.paint(bb, rect, rotation, player, status, index)
    local pbb = Panel.render_oriented(player, status, rect.w, rect.h, rotation, index)
    bb:blitFrom(pbb, rect.x, rect.y, 0, 0, rect.w, rect.h)
    pbb:free()
end

return Panel
