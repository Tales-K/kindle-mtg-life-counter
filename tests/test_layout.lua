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

H.test("zones are inside the panel and do not overlap each other", function()
    local zones = Layout.zones(536, 700)
    local names = {}
    for name, r in pairs(zones) do
        names[#names + 1] = name
        H.eq(r.x >= 0 and r.y >= 0 and r.x + r.w <= 536 and r.y + r.h <= 700, true)
    end
    H.eq(#names, 7)
    for i = 1, #names do
        for j = i + 1, #names do
            H.eq(overlap(zones[names[i]], zones[names[j]]), false)
        end
    end
end)

H.test("zone_at finds each zone and returns nil in the gap", function()
    local zones = Layout.zones(536, 700)
    for name, r in pairs(zones) do
        H.eq(Layout.zone_at(536, 700, r.x + math.floor(r.w / 2), r.y + math.floor(r.h / 2)), name)
        H.eq(Layout.zone_at(536, 700, r.x, r.y), name)
        H.eq(Layout.zone_at(536, 700, r.x + r.w - 1, r.y + r.h - 1), name)
    end
    local gx = zones.poison_plus.x + zones.poison_plus.w
    local gy = zones.poison_plus.y + 1
    H.eq(Layout.zone_at(536, 700, gx, gy), nil)
    H.eq(Layout.zone_at(536, 700, -1, 0), nil)
    H.eq(Layout.zone_at(536, 700, 536, 0), nil)
end)
