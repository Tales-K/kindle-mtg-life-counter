local Layout = {}

local CENTER_RATIO = 0.06

local function edges(total, k)
    local e = {}
    for j = 0, k do e[j] = math.floor(total * j / k) end
    return e
end

function Layout.compute(n, w, h)
    local rows_h = math.floor((h - math.floor(CENTER_RATIO * h)) / 2)
    local center = { x = 0, y = rows_h, w = w, h = h - 2 * rows_h }
    local panels = {}

    local nb = math.ceil(n / 2)
    local nt = math.floor(n / 2)

    local eb = edges(w, nb)
    for j = 1, nb do
        panels[#panels + 1] = {
            index = j, x = eb[j - 1], y = center.y + center.h,
            w = eb[j] - eb[j - 1], h = rows_h, rotation = 0,
        }
    end

    local et = edges(w, nt)
    for j = 1, nt do
        panels[#panels + 1] = {
            index = n - j + 1, x = et[j - 1], y = 0,
            w = et[j] - et[j - 1], h = rows_h, rotation = 180,
        }
    end

    return { panels = panels, center = center, w = w, h = h }
end

function Layout.zones(pw, ph)
    local y1 = math.floor(ph * 0.6)
    local top = { 0, math.floor(pw * 0.22), math.floor(pw * 0.78), pw }
    local low = {
        0, math.floor(pw * 0.20), math.floor(pw * 0.45),
        math.floor(pw * 0.65), math.floor(pw * 0.70), pw,
    }
    local function r(x0, x1, ya, yb) return { x = x0, y = ya, w = x1 - x0, h = yb - ya } end
    return {
        minus = r(top[1], top[2], 0, y1),
        life = r(top[2], top[3], 0, y1),
        plus = r(top[3], top[4], 0, y1),
        poison_minus = r(low[1], low[2], y1, ph),
        poison_value = r(low[2], low[3], y1, ph),
        poison_plus = r(low[3], low[4], y1, ph),
        commander = r(low[5], low[6], y1, ph),
    }
end

function Layout.zone_at(pw, ph, lx, ly)
    if lx < 0 or ly < 0 or lx >= pw or ly >= ph then return nil end
    for name, r in pairs(Layout.zones(pw, ph)) do
        if lx >= r.x and lx < r.x + r.w and ly >= r.y and ly < r.y + r.h then
            return name
        end
    end
    return nil
end

function Layout.hit(layout, x, y)
    for _, p in ipairs(layout.panels) do
        if x >= p.x and x < p.x + p.w and y >= p.y and y < p.y + p.h then
            local lx, ly = x - p.x, y - p.y
            if p.rotation == 180 then
                lx, ly = p.w - 1 - lx, p.h - 1 - ly
            end
            return { index = p.index, lx = lx, ly = ly, panel = p }
        end
    end
    return nil
end

return Layout
