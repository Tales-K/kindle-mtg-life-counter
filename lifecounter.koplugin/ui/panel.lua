-- Desenho de um painel de jogador no visual A2 (so KOReader): a vida ocupa o painel (metade
-- esquerda tira, direita soma), veneno discreto no canto e, embaixo, a mesa em miniatura com o
-- dano de comandante recebido de cada oponente. Jogador fora: painel preto com caveira.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Draw = require("ui/draw")
local Layout = require("core.layout")
local Screen = Device.screen

local Panel = {}

local BLACK, WHITE = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE

local function minimap(bb, g, game, index, rotation, fg, bg)
    local m, k = g.minimap, g.k
    local cmd = game.players[index].cmd
    local inset, radius = math.floor(3 * k + 0.5), math.floor(10 * k + 0.5)
    for _, c in ipairs(Layout.minimap(game.player_count, rotation, m.w, m.h)) do
        local r = { x = m.x + c.x + inset, y = m.y + c.y, w = c.w - 2 * inset, h = c.h }
        local cx, cy = r.x + r.w / 2, r.y + r.h / 2
        if c.index == index then
            Draw.fill_round(bb, r, fg, radius)
            Draw.text(bb, cx, cy, "você", math.min(26 * k, r.h * 0.42, r.w * 0.24), { bold = true, color = bg })
        else
            Draw.border_round(bb, r, math.max(2, math.floor(4 * k + 0.5)), fg, radius)
            local v = cmd[c.index] or 0
            if v > 0 then
                Draw.text(bb, cx, cy, tostring(v), math.min(52 * k, r.h * 0.74, r.w * 0.62 / math.max(1, #tostring(v) - 1)),
                    { bold = true, color = fg })
            else
                Draw.text(bb, cx, cy, "0", math.min(30 * k, r.h * 0.45), { color = fg })
            end
        end
    end
end

-- Painel "em pe", do tamanho pw x ph. rotation (0/180) so gira a miniatura da mesa.
function Panel.render(game, index, pw, ph, rotation)
    local player = game.players[index]
    local out = game:status(index) ~= nil
    local g = Layout.panel(pw, ph, game.player_count)
    local fg, bg = BLACK, WHITE
    if out then fg, bg = WHITE, BLACK end
    local bb = Blitbuffer.new(pw, ph, Screen.bb:getType())
    bb:fill(bg)

    if not out then
        local b = g.border
        Draw.border_round(bb, { x = b.inset, y = b.inset, w = pw - 2 * b.inset, h = ph - 2 * b.inset }, b.width, fg, b.radius)
    end

    Draw.text(bb, g.label.x, g.label.cy, "J" .. index, g.label.size, { bold = true, color = fg, align = "left" })
    if player.poison > 0 then
        local p = g.poison
        local w = Draw.text(bb, p.right, p.cy, tostring(player.poison), p.size, { bold = true, color = fg, align = "right" })
        Draw.drop(bb, p.right - w - p.gap, p.cy, p.drop, fg)
    end

    Draw.border_round(bb, g.strip, g.strip.width, fg, g.strip.radius)
    if g.icon then
        local i = g.icon
        Draw.shield(bb, i.cx, i.cy - i.dy, i.size, fg)
        Draw.text(bb, i.cx, i.cy + i.text_dy, "cmd", i.text_size, { color = fg })
    end
    minimap(bb, g, game, index, rotation, fg, bg)

    Draw.minus(bb, g.glyph.dx, g.gy, g.glyph.size, fg)
    Draw.plus(bb, pw - g.glyph.dx, g.gy, g.glyph.size, fg)
    if out then
        Draw.skull(bb, pw / 2, g.gy, g.skull, fg, bg)
    else
        local txt = tostring(player.life)
        local px = Draw.fit_px(#txt > 1 and txt or "00", g.life_w, g.bot_y - g.top_y, true)
        Draw.text(bb, pw / 2, g.gy, txt, px, { bold = true, color = fg })
    end
    return bb
end

-- Painel ja virado para quem esta sentado (rotation 0 ou 180). O chamador libera o buffer.
function Panel.render_oriented(game, index, pw, ph, rotation)
    local bb = Panel.render(game, index, pw, ph, rotation)
    if rotation == 180 then
        local rotated = bb:rotatedCopy(180)
        bb:free()
        return rotated
    end
    return bb
end

return Panel
