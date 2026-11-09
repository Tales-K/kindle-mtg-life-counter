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

H.test("panel zones: minus and plus halves above, mini strip below, covering the panel", function()
    for _, sz in ipairs({ { 1072, 681 }, { 536, 681 }, { 357, 681 }, { 300, 371 } }) do
        local pw, ph = sz[1], sz[2]
        local z = Layout.zones(pw, ph)
        local names = {}
        local area = 0
        for name, r in pairs(z) do
            names[#names + 1] = name
            area = area + r.w * r.h
            H.eq(r.x >= 0 and r.y >= 0 and r.x + r.w <= pw and r.y + r.h <= ph, true)
        end
        table.sort(names)
        H.eq(names, { "mini", "minus", "plus" })
        H.eq(area, pw * ph)
        H.eq(overlap(z.minus, z.plus) or overlap(z.minus, z.mini) or overlap(z.plus, z.mini), false)
        H.eq(z.minus.x, 0)
        H.eq(z.minus.w, math.floor(pw / 2))
        H.eq(z.mini.y + z.mini.h, ph)
        H.eq(z.mini.y > ph / 2, true)
    end
end)

H.test("mini strip is at least 106 px tall on the Kindle", function()
    local l = Layout.compute(6, 1072, 1448)
    local z = Layout.zones(l.panels[1].w, l.panels[1].h)
    H.eq(z.mini.h >= 106, true)
end)

H.test("zone_at: left half minus, right half plus, bottom strip mini, outside nil", function()
    local pw, ph = 536, 681
    local z = Layout.zones(pw, ph)
    H.eq(Layout.zone_at(pw, ph, 5, 5), "minus")
    H.eq(Layout.zone_at(pw, ph, math.floor(pw / 2) - 1, z.mini.y - 1), "minus")
    H.eq(Layout.zone_at(pw, ph, math.floor(pw / 2), 5), "plus")
    H.eq(Layout.zone_at(pw, ph, pw - 1, z.mini.y - 1), "plus")
    H.eq(Layout.zone_at(pw, ph, 5, z.mini.y), "mini")
    H.eq(Layout.zone_at(pw, ph, pw - 1, ph - 1), "mini")
    H.eq(Layout.zone_at(pw, ph, -1, 5), nil)
    H.eq(Layout.zone_at(pw, ph, pw, 5), nil)
end)

local function zone_on_screen(l, x, y)
    local h = Layout.hit(l, x, y)
    return h and Layout.zone_at(h.panel.w, h.panel.h, h.lx, h.ly), h and h.index
end

H.test("rotation 0 panel: screen left is minus, screen right is plus, screen bottom is mini", function()
    local l = Layout.compute(4, 1072, 1448)
    local p
    for _, q in ipairs(l.panels) do if q.index == 1 then p = q end end
    H.eq({ zone_on_screen(l, p.x + 20, p.y + 300) }, { "minus", 1 })
    H.eq({ zone_on_screen(l, p.x + p.w - 20, p.y + 300) }, { "plus", 1 })
    H.eq({ zone_on_screen(l, p.x + 100, p.y + p.h - 10) }, { "mini", 1 })
end)

H.test("rotation 180 panel: screen left is plus, screen right is minus, screen top is mini", function()
    local l = Layout.compute(4, 1072, 1448)
    local p
    for _, q in ipairs(l.panels) do if q.index == 3 then p = q end end
    H.eq(p.rotation, 180)
    H.eq({ zone_on_screen(l, p.x + 20, p.y + 300) }, { "plus", 3 })
    H.eq({ zone_on_screen(l, p.x + p.w - 20, p.y + 300) }, { "minus", 3 })
    H.eq({ zone_on_screen(l, p.x + 100, p.y + 10) }, { "mini", 3 })
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
        local m, z = g.minimap, g.zones.mini
        H.eq(m.x >= z.x and m.y >= z.y and m.x + m.w <= z.x + z.w and m.y + m.h <= z.y + z.h, true)
        H.eq(m.w > 0 and m.h > 0, true)
    end
end)
