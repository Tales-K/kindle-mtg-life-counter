local H = require("helper")
local Layout = require("core.layout")

local function count_rot(l, rot)
    local c = 0
    for _, p in ipairs(l.panels) do if p.rotation == rot then c = c + 1 end end
    return c
end

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local SIZES = { { 1072, 1448 }, { 1073, 1449 }, { 600, 800 } }

H.test("panel counts per row for n=2..6", function()
    for n = 2, 6 do
        local l = Layout.compute(n, 1072, 1448)
        H.eq(#l.panels, n)
        H.eq(count_rot(l, 180), math.floor(n / 2))
        H.eq(count_rot(l, 0), math.ceil(n / 2))
    end
end)

H.test("panels tile the screen with no overlap and no gap", function()
    for _, s in ipairs(SIZES) do
        for n = 2, 6 do
            local l = Layout.compute(n, s[1], s[2])
            local rects = { l.center }
            local area = l.center.w * l.center.h
            for _, p in ipairs(l.panels) do
                rects[#rects + 1] = p
                area = area + p.w * p.h
                H.eq(p.x >= 0 and p.y >= 0 and p.x + p.w <= s[1] and p.y + p.h <= s[2], true)
            end
            H.eq(area, s[1] * s[2])
            for i = 1, #rects do
                for j = i + 1, #rects do
                    H.eq(overlap(rects[i], rects[j]), false)
                end
            end
        end
    end
end)

H.test("top row has rotation 180 and sits above the center, bottom row rotation 0 below", function()
    local l = Layout.compute(5, 1072, 1448)
    for _, p in ipairs(l.panels) do
        if p.rotation == 180 then
            H.eq(p.y + p.h <= l.center.y, true)
        else
            H.eq(p.rotation, 0)
            H.eq(p.y >= l.center.y + l.center.h, true)
        end
    end
end)

H.test("center bar is about 6 percent of the height", function()
    local l = Layout.compute(4, 1072, 1448)
    H.eq(l.center.h >= 80 and l.center.h <= 100, true)
end)

H.test("numbering is clockwise from bottom-left", function()
    local function by_index(l)
        local m = {}
        for _, p in ipairs(l.panels) do m[p.index] = p end
        return m
    end
    local m = by_index(Layout.compute(4, 1072, 1448))
    H.eq(m[1].rotation == 0 and m[2].rotation == 0, true)
    H.eq(m[1].x < m[2].x, true)
    H.eq(m[3].rotation == 180 and m[4].rotation == 180, true)
    H.eq(m[3].x > m[4].x, true)
    local m5 = by_index(Layout.compute(5, 1072, 1448))
    H.eq(m5[1].x < m5[2].x and m5[2].x < m5[3].x, true)
    H.eq(m5[4].x > m5[5].x, true)
    H.eq(m5[3].rotation, 0)
    H.eq(m5[4].rotation, 180)
end)

H.test("hit on center bar returns nil", function()
    local l = Layout.compute(4, 1072, 1448)
    H.eq(Layout.hit(l, 500, l.center.y + 1), nil)
    H.eq(Layout.hit(l, 500, l.center.y + l.center.h - 1), nil)
end)

H.test("hit outside the screen returns nil", function()
    local l = Layout.compute(4, 1072, 1448)
    H.eq(Layout.hit(l, -1, 10), nil)
    H.eq(Layout.hit(l, 10, 1448), nil)
end)

H.test("hit maps a 0 panel to plain local coordinates", function()
    local l = Layout.compute(2, 1072, 1448)
    local p
    for _, q in ipairs(l.panels) do if q.rotation == 0 then p = q end end
    local h = Layout.hit(l, p.x + 10, p.y + 20)
    H.eq(h.index, p.index)
    H.eq(h.lx, 10)
    H.eq(h.ly, 20)
end)

H.test("hit at the visual top-left of a 180 panel maps to local bottom-right", function()
    local l = Layout.compute(2, 1072, 1448)
    local p
    for _, q in ipairs(l.panels) do if q.rotation == 180 then p = q end end
    local h = Layout.hit(l, p.x, p.y)
    H.eq(h.index, p.index)
    H.eq(h.lx, p.w - 1)
    H.eq(h.ly, p.h - 1)
end)

H.test("hit on every pixel column between neighbors goes to exactly one panel", function()
    for n = 2, 6 do
        local l = Layout.compute(n, 1073, 1449)
        for _, y in ipairs({ 1, l.center.y - 1, l.center.y + l.center.h, 1448 }) do
            for x = 0, 1072 do
                local h = Layout.hit(l, x, y)
                H.eq(h ~= nil, true)
            end
        end
    end
end)

H.test("seats match compute: same panels when the gap is the center bar", function()
    for n = 2, 6 do
        local l = Layout.compute(n, 1072, 1448)
        local s = Layout.seats(n, 1072, 1448, l.center.h)
        H.eq(#s, n)
        for k, p in ipairs(l.panels) do
            H.eq({ s[k].index, s[k].x, s[k].y, s[k].w, s[k].h, s[k].rotation },
                 { p.index, p.x, p.y, p.w, p.h, p.rotation })
        end
    end
end)

-- Paineis reais do Kindle (1072 x 1448) para n = 2..6, cada um com o seu tamanho e rotacao.
local function kindle_panels()
    local out = {}
    for n = 2, 6 do
        for _, p in ipairs(Layout.compute(n, 1072, 1448).panels) do out[#out + 1] = { n = n, p = p } end
    end
    return out
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

H.test("panel zones: minus/plus halves above, poison and minimap side by side in the strip, covering the panel", function()
    for _, sz in ipairs({ { 1072, 681 }, { 536, 681 }, { 357, 681 }, { 300, 371 } }) do
        local pw, ph = sz[1], sz[2]
        for n = 2, 6 do
            local z = Layout.zones(pw, ph, n)
            local names = {}
            local area = 0
            for name, r in pairs(z) do
                names[#names + 1] = name
                area = area + r.w * r.h
                H.eq(r.x >= 0 and r.y >= 0 and r.x + r.w <= pw and r.y + r.h <= ph, true)
            end
            table.sort(names)
            H.eq(names, { "mini", "minus", "plus", "poison" })
            H.eq(area, pw * ph)
            local list = { z.minus, z.plus, z.poison, z.mini }
            for i = 1, #list do
                for j = i + 1, #list do H.eq(overlap(list[i], list[j]), false) end
            end
            H.eq(z.minus.x, 0)
            H.eq(z.minus.w, math.floor(pw / 2))
            H.eq(z.poison.x, 0)
            H.eq(z.poison.y, z.mini.y)
            H.eq(z.mini.x + z.mini.w, pw)
            H.eq(z.mini.y + z.mini.h, ph)
            H.eq(z.mini.y > ph / 2, true)
        end
    end
end)

H.test("mini strip is at least 106 px tall on the Kindle", function()
    local l = Layout.compute(6, 1072, 1448)
    local z = Layout.zones(l.panels[1].w, l.panels[1].h, 6)
    H.eq(z.mini.h >= 106, true)
end)

H.test("panel geometry: poison drop always has room, also on the narrow 6-player panels", function()
    for _, e in ipairs(kindle_panels()) do
        local g = Layout.panel(e.p.w, e.p.h, e.n)
        H.eq(g.icon ~= nil, true)
        H.eq(inside(g.zones.poison, g.icon.cx, g.icon.cy), true)
        H.eq(g.minimap.x >= g.zones.mini.x, true)
    end
end)

H.test("zone_at: halves, poison drop, every minimap cell (opponent index or self), outside nil, rot 0 and 180, n=2..6", function()
    for _, e in ipairs(kindle_panels()) do
        local n, p = e.n, e.p
        local pw, ph, rot, owner = p.w, p.h, p.rotation, p.index
        local g = Layout.panel(pw, ph, n)
        local z = g.zones
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, 5, 5), { zone = "minus" })
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, math.floor(pw / 2) - 1, z.mini.y - 1), { zone = "minus" })
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, math.floor(pw / 2), 5), { zone = "plus" })
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, pw - 1, z.mini.y - 1), { zone = "plus" })
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, g.icon.cx, g.icon.cy), { zone = "poison" })
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, 0, ph - 1), { zone = "poison" })
        local m = g.minimap
        local seen = {}
        for _, c in ipairs(Layout.minimap(n, rot, m.w, m.h)) do
            local expected = c.index == owner and "self" or c.index
            local hit = Layout.zone_at(pw, ph, n, rot, owner, m.x + c.x + math.floor(c.w / 2), m.y + c.y + math.floor(c.h / 2))
            H.eq(hit, { zone = "cmd", source = expected })
            seen[c.index] = true
        end
        for i = 1, n do H.eq(seen[i], true) end
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, -1, 5), nil)
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, pw, 5), nil)
        H.eq(Layout.zone_at(pw, ph, n, rot, owner, 5, ph), nil)
    end
end)

H.test("zone_at: the minimap hit takes the whole cell, no dead pixel between cells (tolerant taps)", function()
    for _, e in ipairs(kindle_panels()) do
        local n, p = e.n, e.p
        local g = Layout.panel(p.w, p.h, n)
        local z, m = g.zones.mini, g.minimap
        local cells = Layout.minimap(n, p.rotation, m.w, m.h)
        for y = z.y, z.y + z.h - 1, 3 do
            for x = z.x, z.x + z.w - 1, 3 do
                local hit = Layout.zone_at(p.w, p.h, n, p.rotation, p.index, x, y)
                H.eq(hit ~= nil and hit.zone, "cmd")
            end
        end
        -- Cada pixel da celula desenhada (e do espaco ate a vizinha) vai para a propria celula.
        for _, c in ipairs(cells) do
            local expected = c.index == p.index and "self" or c.index
            for _, pt in ipairs({ { c.x, c.y }, { c.x + c.w - 1, c.y }, { c.x, c.y + c.h - 1 }, { c.x + c.w - 1, c.y + c.h - 1 } }) do
                local hit = Layout.zone_at(p.w, p.h, n, p.rotation, p.index, m.x + pt[1], m.y + pt[2])
                H.eq(hit.source, expected)
            end
        end
    end
end)

-- Ponto (lx, ly) do quadro "em pe" de um painel -> ponto na tela.
local function to_screen(p, lx, ly)
    if p.rotation == 180 then return p.x + p.w - 1 - lx, p.y + p.h - 1 - ly end
    return p.x + lx, p.y + ly
end

local function panel_of(l, index)
    for _, q in ipairs(l.panels) do if q.index == index then return q end end
end

local function zone_on_screen(l, x, y)
    local h = Layout.hit(l, x, y)
    if not h then return nil end
    return Layout.zone_at(h.panel.w, h.panel.h, #l.panels, h.panel.rotation, h.index, h.lx, h.ly), h.index
end

H.test("rotation 0 panel: screen left is minus, screen right is plus, bottom strip is poison then minimap", function()
    local l = Layout.compute(4, 1072, 1448)
    local p = panel_of(l, 1)
    H.eq({ zone_on_screen(l, p.x + 20, p.y + 300) }, { { zone = "minus" }, 1 })
    H.eq({ zone_on_screen(l, p.x + p.w - 20, p.y + 300) }, { { zone = "plus" }, 1 })
    H.eq({ zone_on_screen(l, p.x + 10, p.y + p.h - 10) }, { { zone = "poison" }, 1 })
end)

H.test("rotation 180 panel: screen left is plus, screen right is minus, top strip is minimap then poison", function()
    local l = Layout.compute(4, 1072, 1448)
    local p = panel_of(l, 3)
    H.eq(p.rotation, 180)
    H.eq({ zone_on_screen(l, p.x + 20, p.y + 300) }, { { zone = "plus" }, 3 })
    H.eq({ zone_on_screen(l, p.x + p.w - 20, p.y + 300) }, { { zone = "minus" }, 3 })
    H.eq({ zone_on_screen(l, p.x + p.w - 10, p.y + 10) }, { { zone = "poison" }, 3 })
end)

H.test("minimap on screen: J1 (bottom-left, 4 players) touching its top-left square gets J4", function()
    local l = Layout.compute(4, 1072, 1448)
    local p = panel_of(l, 1)
    local m = Layout.panel(p.w, p.h, 4).minimap
    -- No painel de baixo a miniatura nao gira: canto superior esquerdo da miniatura.
    local x, y = to_screen(p, m.x + 4, m.y + 4)
    H.eq({ zone_on_screen(l, x, y) }, { { zone = "cmd", source = 4 }, 1 })
    x, y = to_screen(p, m.x + m.w - 4, m.y + 4)
    H.eq({ zone_on_screen(l, x, y) }, { { zone = "cmd", source = 3 }, 1 })
    x, y = to_screen(p, m.x + m.w - 4, m.y + m.h - 4)
    H.eq({ zone_on_screen(l, x, y) }, { { zone = "cmd", source = 2 }, 1 })
    x, y = to_screen(p, m.x + 4, m.y + m.h - 4)
    H.eq({ zone_on_screen(l, x, y) }, { { zone = "cmd", source = "self" }, 1 })
end)

H.test("minimap on screen: J3 (top-right, turned 180) sees the table the same way, square over the real seat", function()
    local l = Layout.compute(4, 1072, 1448)
    local p = panel_of(l, 3)
    local m = Layout.panel(p.w, p.h, 4).minimap
    -- Cantos da miniatura NA TELA (o painel esta girado): esquerda/direita e cima/baixo da tela.
    local xs = { select(1, to_screen(p, m.x + m.w - 4, 0)), select(1, to_screen(p, m.x + 4, 0)) }
    local ys = { select(2, to_screen(p, 0, m.y + m.h - 4)), select(2, to_screen(p, 0, m.y + 4)) }
    local left, right = math.min(xs[1], xs[2]), math.max(xs[1], xs[2])
    local top, bottom = math.min(ys[1], ys[2]), math.max(ys[1], ys[2])
    H.eq({ zone_on_screen(l, left, top) }, { { zone = "cmd", source = 4 }, 3 })
    H.eq({ zone_on_screen(l, right, top) }, { { zone = "cmd", source = "self" }, 3 })
    H.eq({ zone_on_screen(l, left, bottom) }, { { zone = "cmd", source = 1 }, 3 })
    H.eq({ zone_on_screen(l, right, bottom) }, { { zone = "cmd", source = 2 }, 3 })
end)

-- Centro de um retangulo em coordenadas normalizadas (0..1) da tela/miniatura.
local function center_norm(r, w, h)
    return (r.x + r.w / 2) / w, (r.y + r.h / 2) / h
end

H.test("minimap cells sit where the real panels are, for n=2..6 and both owner rotations", function()
    local W, Hh = 1072, 1448
    for n = 2, 6 do
        local l = Layout.compute(n, W, Hh)
        local by_index = {}
        for _, p in ipairs(l.panels) do by_index[p.index] = p end
        for _, rot in ipairs({ 0, 180 }) do
            local mw, mh = 300, 140
            local cells = Layout.minimap(n, rot, mw, mh)
            H.eq(#cells, n)
            for _, c in ipairs(cells) do
                H.eq(c.x >= 0 and c.y >= 0 and c.x + c.w <= mw and c.y + c.h <= mh, true)
                local cx, cy = center_norm(c, mw, mh)
                -- O painel gira junto com o dono: no quadro da tela, a celula volta ao lugar.
                if rot == 180 then cx, cy = 1 - cx, 1 - cy end
                local px, py = center_norm(by_index[c.index], W, Hh)
                H.eq(math.abs(cx - px) < 0.01, true)
                H.eq((cy < 0.5) == (py < 0.5), true)
                -- largura proporcional ao painel real
                H.eq(math.abs(c.w / mw - by_index[c.index].w / W) < 0.01, true)
            end
            for i = 1, #cells do
                for j = i + 1, #cells do H.eq(overlap(cells[i], cells[j]), false) end
            end
        end
    end
end)

H.test("panel geometry keeps the minimap inside the mini strip", function()
    for n = 2, 6 do
        local l = Layout.compute(n, 1072, 1448)
        local p = l.panels[1]
        local g = Layout.panel(p.w, p.h, n)
        local m, z = g.minimap, g.zones.mini -- miniatura inteira dentro da faixa da mesa
        H.eq(m.x >= z.x and m.y >= z.y and m.x + m.w <= z.x + z.w and m.y + m.h <= z.y + z.h, true)
        H.eq(m.w > 0 and m.h > 0, true)
    end
end)
