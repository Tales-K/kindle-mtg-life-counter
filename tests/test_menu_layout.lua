local H = require("helper")
local ML = require("core.menu_layout")

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

H.test("one rect per button, inside the screen, in top-to-bottom order, no overlap with each other or the title", function()
    for n = 1, 8 do
        local l = ML.compute(n, 1074, 1448)
        H.eq(#l.buttons, n)
        local prev_bottom = l.title.y + l.title.h
        for i, b in ipairs(l.buttons) do
            H.eq(b.x >= 0 and b.y >= 0 and b.x + b.w <= 1074 and b.y + b.h <= 1448, true)
            H.eq(b.y >= prev_bottom, true)
            prev_bottom = b.y + b.h
            H.eq(overlap(b, l.title), false)
            if i > 1 then H.eq(overlap(b, l.buttons[i - 1]), false) end
        end
    end
end)

H.test("buttons are tall enough to tap on a 6 inch screen (at least 100 px) even with 8 buttons", function()
    local l = ML.compute(8, 1074, 1448)
    for _, b in ipairs(l.buttons) do H.eq(b.h >= 100, true) end
end)

H.test("few buttons are capped so they do not become giant", function()
    local l = ML.compute(2, 1074, 1448)
    H.eq(l.buttons[1].h <= math.floor(0.13 * 1448), true)
end)

H.test("hit returns the index of the button under the point", function()
    local l = ML.compute(4, 720, 972)
    for i, b in ipairs(l.buttons) do
        H.eq(ML.hit(l, b.x + 1, b.y + 1), i)
        H.eq(ML.hit(l, b.x + b.w - 1, b.y + b.h - 1), i)
        H.eq(ML.hit(l, b.x + math.floor(b.w / 2), b.y + math.floor(b.h / 2)), i)
    end
end)

H.test("hit returns nil on the title, in the gaps, in the side margins and outside", function()
    local l = ML.compute(3, 720, 972)
    H.eq(ML.hit(l, 300, l.title.y + 5), nil)
    local gap_y = l.buttons[1].y + l.buttons[1].h
    H.eq(ML.hit(l, 300, gap_y), nil)
    H.eq(ML.hit(l, 1, l.buttons[2].y + 5), nil)
    H.eq(ML.hit(l, -1, 10), nil)
    H.eq(ML.hit(l, 10, 972), nil)
end)

H.test("weights: a preview item gets several times the height of a normal button, all on screen", function()
    local l = ML.compute(2, 1072, 1448, { 4, 1 })
    local a, b = l.buttons[1], l.buttons[2]
    H.eq(a.h >= 3.5 * b.h and a.h <= 4.5 * b.h, true)
    H.eq(b.y + b.h <= 1448, true)
    H.eq(a.h >= 500, true)
end)
