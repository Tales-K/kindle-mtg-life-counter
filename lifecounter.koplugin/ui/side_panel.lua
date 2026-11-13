-- Triangulo de um jogador na mesa "um de cada lado" (so KOReader). Mesmo visual A2 do painel
-- retangular (ui/panel), adaptado ao triangulo "em pe" de core/sides: a vida no meio (metade esquerda
-- tira, direita soma), na base a gota do veneno e a mesa em miniatura, "P1" perto da ponta.
-- Jogador fora: triangulo preto com caveira.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Delta = require("core.delta")
local Draw = require("ui/draw")
local I18n = require("core.i18n")
local Sides = require("core.sides")
local Screen = Device.screen

local SidePanel = {}

local BLACK, WHITE = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE

local function minimap(bb, g, game, index, fg, bg)
    local m, k = g.minimap, g.k
    local cmd = game.players[index].cmd
    local inset, radius = math.floor(3 * k + 0.5), math.floor(10 * k + 0.5)
    for _, c in ipairs(Sides.minimap(index, m.w, m.h)) do
        local r = { x = m.x + c.x + inset, y = m.y + c.y, w = c.w - 2 * inset, h = c.h }
        local cx, cy = r.x + r.w / 2, r.y + r.h / 2
        if c.index == index then
            Draw.fill_round(bb, r, fg, radius)
            Draw.text(bb, cx, cy, I18n.t("you"), math.min(30 * k, r.h * 0.5, r.w * 0.3), { bold = true, color = bg })
        else
            Draw.border_round(bb, r, math.max(2, math.floor(4 * k + 0.5)), fg, radius)
            local v = cmd[c.index] or 0
            Draw.text(bb, cx, cy, tostring(v), math.min((v > 0 and 52 or 32) * k, r.h * (v > 0 and 0.72 or 0.48), r.w * 0.3),
                { bold = v > 0, color = fg })
        end
    end
end

-- Triangulo "em pe" (uw x uh, ponta no meio de cima). delta: "-6" pequeno em cima da vida, ou nil.
function SidePanel.render(game, index, uw, uh, delta)
    local player = game.players[index]
    local out = game:status(index) ~= nil
    local g = Sides.panel(uw, uh)
    local fg, bg = BLACK, WHITE
    local bb = Blitbuffer.new(uw, uh, Screen.bb:getType())
    bb:fill(WHITE)
    if out then
        fg, bg = WHITE, BLACK
        Draw.trapezoid(bb, uw / 2, 0, uh, 0, uw / 2 + 1, BLACK)
    end

    Draw.text(bb, uw / 2, g.label.cy, I18n.player(index), g.label.size, { bold = true, color = fg })

    Draw.border_round(bb, g.strip, g.strip.width, fg, g.strip.radius)
    local i = g.icon
    Draw.drop(bb, i.cx, i.cy - i.drop_dy, i.drop, fg)
    Draw.text(bb, i.cx, i.cy + i.text_dy, tostring(player.poison), i.text_size, { bold = true, color = fg })
    minimap(bb, g, game, index, fg, bg)

    Draw.minus(bb, g.minus.cx, g.minus.cy, g.glyph, fg)
    Draw.plus(bb, g.plus.cx, g.plus.cy, g.glyph, fg)
    local n = g.number
    local number_px = g.skull / Draw.CAP
    if out then
        Draw.skull(bb, uw / 2, g.gy, g.skull, fg, bg)
    else
        local txt = tostring(player.life)
        number_px = Draw.fit_px(#txt > 1 and txt or "00", n.w, n.h, true)
        Draw.text(bb, uw / 2, g.gy, txt, number_px, { bold = true, color = fg })
    end
    if delta then
        local size = g.delta_size
        local min_cy = g.label.cy + math.floor((g.label.size + size) * Draw.CAP / 2 + 6 * g.k)
        Draw.text(bb, uw / 2, Delta.place(g.gy, number_px, size, min_cy, Draw.CAP), delta, size, { bold = true, color = fg })
    end
    return bb
end

-- Ja girado para a borda do jogador (p de Sides.compute). O chamador libera o buffer.
function SidePanel.render_oriented(game, p, delta)
    return Draw.orient(SidePanel.render(game, p.index, p.uw, p.uh, delta), p.rotation)
end

-- Diagonais da mesa e o botao de menu redondo no centro, por cima dos triangulos.
function SidePanel.decorate(bb, l)
    local t = math.max(4, math.floor(6 * l.w / 1072 + 0.5))
    for y = 0, l.h - 1 do
        local x = (y + 0.5) * l.w / l.h
        Draw.rect(bb, x - t / 2, y, t, 1, BLACK)
        Draw.rect(bb, l.w - x - t / 2, y, t, 1, BLACK)
    end
    local m = l.menu
    Draw.ellipse(bb, m.cx, m.cy, m.r, m.r, BLACK)
    Draw.ellipse(bb, m.cx, m.cy, m.r - t, m.r - t, WHITE)
    -- Tres tracos (menu), legiveis de qualquer lado.
    local bw, bh = math.floor(m.r * 0.9), math.max(4, math.floor(m.r * 0.13))
    for k = -1, 1 do
        Draw.rect(bb, m.cx - bw / 2, m.cy + k * m.r * 0.32 - bh / 2, bw, bh, BLACK)
    end
end

return SidePanel
