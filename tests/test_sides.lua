local H = require("helper")
local Sides = require("core.sides")

local W, HH = 1072, 1448

local function by_index(l)
    local out = {}
    for _, p in ipairs(l.panels) do out[p.index] = p end
    return out
end

H.test("sides: P1 bottom, P2 left, P3 top, P4 right (clockwise), each facing its edge", function()
    local p = by_index(Sides.compute(W, HH))
    H.eq({ p[1].seat, p[1].rotation }, { "bottom", 0 })
    H.eq({ p[2].seat, p[2].rotation }, { "left", 90 })
    H.eq({ p[3].seat, p[3].rotation }, { "top", 180 })
    H.eq({ p[4].seat, p[4].rotation }, { "right", 270 })
end)

H.test("sides: upright size is base x depth of each triangle", function()
    local p = by_index(Sides.compute(W, HH))
    H.eq({ p[1].uw, p[1].uh }, { 1072, 724 })
    H.eq({ p[3].uw, p[3].uh }, { 1072, 724 })
    H.eq({ p[2].uw, p[2].uh }, { 1448, 536 })
    H.eq({ p[4].uw, p[4].uh }, { 1448, 536 })
end)

H.test("sides: a tap near each edge hits the player of that edge", function()
    local l = Sides.compute(W, HH)
    H.eq(Sides.hit(l, 536, 1400).index, 1)
    H.eq(Sides.hit(l, 20, 724).index, 2)
    H.eq(Sides.hit(l, 536, 30).index, 3)
    H.eq(Sides.hit(l, 1050, 724).index, 4)
    -- cantos: perto da diagonal, o lado mais proximo
    H.eq(Sides.hit(l, 100, 1440).index, 1)
    H.eq(Sides.hit(l, 5, 1300).index, 2)
end)

H.test("sides: the menu circle in the middle is not a player", function()
    local l = Sides.compute(W, HH)
    H.eq(Sides.in_menu(l, 536, 724), true)
    H.eq(Sides.in_menu(l, 536 + l.menu.r - 2, 724), true)
    H.eq(Sides.in_menu(l, 536, 724 + l.menu.r + 5), false)
    H.eq(Sides.hit(l, 536, 724), nil)
end)

H.test("sides: upright coords put the player's edge at the bottom and their left hand at x=0", function()
    local l = Sides.compute(W, HH)
    -- P1 (baixo): canto inferior esquerdo da tela e a esquerda dele
    local h = Sides.hit(l, 2, 1446)
    H.eq({ h.index, h.lx, h.ly }, { 1, 2, 722 })
    -- P3 (cima, girado 180): canto superior direito da tela e a esquerda dele
    h = Sides.hit(l, 1069, 1)
    H.eq({ h.index, h.lx, h.ly }, { 3, 2, 722 })
    -- P2 (esquerda, olhando para a direita): a esquerda dele e o topo da tela
    h = Sides.hit(l, 1, 3)
    H.eq({ h.index, h.lx, h.ly }, { 2, 3, 534 })
    -- P4 (direita, olhando para a esquerda): a esquerda dele e o pe da tela
    h = Sides.hit(l, 1070, 1444)
    H.eq({ h.index, h.lx, h.ly }, { 4, 3, 534 })
end)

H.test("sides: to_upright and to_screen are inverses for every rotation", function()
    for _, rot in ipairs({ 0, 90, 180, 270 }) do
        for _, pt in ipairs({ { 0, 0 }, { 10, 20 }, { 535, 1447 }, { 300, 700 } }) do
            local lx, ly = Sides.to_upright(rot, 536, 1448, pt[1], pt[2])
            local x, y = Sides.to_screen(rot, 536, 1448, lx, ly)
            H.eq({ x, y }, pt)
        end
    end
end)

H.test("sides: row span of each triangle on screen", function()
    local l = Sides.compute(W, HH)
    local p = by_index(l)
    -- linha do meio: os laterais vao da borda ate o centro; cima/baixo nao tem nada
    H.eq(Sides.span(l, p[2], 724), { 0, 536 })
    H.eq(Sides.span(l, p[4], 724), { 536, 1072 })
    H.eq(Sides.span(l, p[1], 724), nil)
    -- ultima linha: o de baixo ocupa a largura toda, os laterais nada
    H.eq(Sides.span(l, p[1], 1447), { 0, 1072 })
    H.eq(Sides.span(l, p[2], 1447), nil)
end)

H.test("sides panel: number, glyphs, strip and label fit inside the triangle", function()
    for _, dims in ipairs({ { 1072, 724 }, { 1448, 536 } }) do
        local uw, uh = dims[1], dims[2]
        local g = Sides.panel(uw, uh)
        local function inside(x, y) return math.abs(x - uw / 2) <= (uw / 2) * y / uh end
        local s = g.strip
        H.eq(inside(s.x, s.y) and inside(s.x + s.w, s.y), true)
        H.eq(s.y + s.h <= uh, true)
        local n = g.number
        H.eq(inside(uw / 2 - n.w / 2, n.y) and inside(uw / 2 + n.w / 2, n.y), true)
        H.eq(n.y + n.h <= s.y, true)
        H.eq(inside(g.minus.cx - g.glyph / 2, g.minus.cy - g.glyph / 2), true)
        H.eq(inside(g.plus.cx + g.glyph / 2, g.plus.cy - g.glyph / 2), true)
        H.eq(g.label.cy < n.y, true)
        -- numero grande de verdade: pelo menos 40% da profundidade do triangulo
        H.eq(n.h >= 0.4 * uh * 0.714 * 0.9, true)
    end
end)

H.test("sides zones: halves for -/+, drop and mini-table in the strip", function()
    local uw, uh = 1072, 724
    local g = Sides.panel(uw, uh)
    local y = g.number.y + 10
    H.eq(Sides.zone_at(uw, uh, 1, uw / 2 - 30, y), { zone = "minus" })
    H.eq(Sides.zone_at(uw, uh, 1, uw / 2 + 30, y), { zone = "plus" })
    local sy = g.strip.y + 10
    H.eq(Sides.zone_at(uw, uh, 1, g.strip.x + 5, sy), { zone = "poison" })
end)

H.test("sides minimap: across on top, left and right neighbours beside you", function()
    -- P1 (baixo): a esquerda dele e P2, em frente P3, a direita P4
    local cells = Sides.minimap(1, 300, 120)
    local at = {}
    for _, c in ipairs(cells) do at[c.index] = c end
    H.eq(at[3].y < at[1].y, true)
    H.eq(at[2].x < at[1].x and at[1].x < at[4].x, true)
    H.eq(at[2].y, at[1].y)
    -- P2 (esquerda): a esquerda dele e P3, em frente P4, a direita P1
    at = {}
    for _, c in ipairs(Sides.minimap(2, 300, 120)) do at[c.index] = c end
    H.eq(at[3].x < at[2].x and at[2].x < at[1].x, true)
    H.eq(at[4].y < at[2].y, true)
end)

H.test("sides zones: each mini-table cell opens that opponent; own cell is self", function()
    local uw, uh = 1072, 724
    local g = Sides.panel(uw, uh)
    local m = g.minimap
    for _, c in ipairs(Sides.minimap(1, m.w, m.h)) do
        local z = Sides.zone_at(uw, uh, 1, m.x + c.x + c.w / 2, m.y + c.y + c.h / 2)
        H.eq(z, { zone = "cmd", source = c.index == 1 and "self" or c.index })
    end
end)
