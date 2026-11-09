local H = require("helper")
local View = require("core.field_view")

local SIZES = { { 1072, 1448 }, { 600, 800 } }

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Ponto do quadro "em pe" do campo -> ponto na tela (a tela inteira gira 180 para quem esta em cima).
local function to_screen(l, lx, ly)
    if l.rotation == 180 then return l.w - 1 - lx, l.h - 1 - ly end
    return lx, ly
end

local function mid(r) return r.x + math.floor(r.w / 2), r.y + math.floor(r.h / 2) end

H.test("field layout: minus and plus halves, OK below, all inside the screen and big enough", function()
    for _, s in ipairs(SIZES) do
        for _, rot in ipairs({ 0, 180 }) do
            local l = View.layout(s[1], s[2], rot)
            H.eq(l.rotation, rot)
            local z = l.zones
            for _, name in ipairs({ "minus", "plus", "ok" }) do
                local r = z[name]
                H.eq(r.x >= 0 and r.y >= 0 and r.x + r.w <= s[1] and r.y + r.h <= s[2], true)
                H.eq(r.h >= 106 * s[2] / 1448, true)
            end
            H.eq(overlap(z.minus, z.plus) or overlap(z.minus, z.ok) or overlap(z.plus, z.ok), false)
            H.eq(z.minus.x, 0)
            H.eq(z.minus.w + z.plus.w, s[1])
            H.eq(z.plus.x, z.minus.w)
            H.eq(z.ok.y >= z.minus.y + z.minus.h, true)
            H.eq(z.ok.y + z.ok.h, s[2])
            -- Numero, botao e miniatura cabem onde devem.
            H.eq(inside(z.ok, l.button.x, l.button.y) and inside(z.ok, l.button.x + l.button.w - 1, l.button.y + l.button.h - 1), true)
            H.eq(l.mini.y + l.mini.h <= z.minus.y, true)
            -- O campo ocupa a maior parte da tela.
            H.eq(z.minus.h >= s[2] / 2, true)
        end
    end
end)

H.test("field hit, owner below (rotation 0): left half minus, right half plus, bottom OK, header nothing", function()
    local l = View.layout(1072, 1448, 0)
    local z = l.zones
    H.eq(View.hit(l, 10, z.minus.y + 10), "minus")
    H.eq(View.hit(l, 535, z.minus.y + z.minus.h - 1), "minus")
    H.eq(View.hit(l, 536, z.minus.y + 10), "plus")
    H.eq(View.hit(l, 1071, z.plus.y + z.plus.h - 1), "plus")
    H.eq(View.hit(l, mid(l.button)), "ok")
    H.eq(View.hit(l, 1071, 1447), "ok")
    H.eq(View.hit(l, 10, 10), nil)
    H.eq(View.hit(l, mid(l.mini)), nil)
end)

H.test("field hit, owner above (rotation 180): screen left is plus, screen right is minus, OK at the top", function()
    local l = View.layout(1072, 1448, 180)
    local z = l.zones
    local y = 1447 - (z.minus.y + 10)
    H.eq(View.hit(l, 10, y), "plus")
    H.eq(View.hit(l, 1061, y), "minus")
    H.eq(View.hit(l, 536, 5), "ok")
    H.eq(View.hit(l, to_screen(l, mid(l.button))), "ok")
    H.eq(View.hit(l, 10, 1440), nil)
    for _, name in ipairs({ "minus", "plus", "ok" }) do
        H.eq(View.hit(l, to_screen(l, mid(z[name]))), name)
    end
end)

H.test("field hit: off-screen points do nothing", function()
    for _, rot in ipairs({ 0, 180 }) do
        local l = View.layout(1072, 1448, rot)
        H.eq(View.hit(l, -1, 700), nil)
        H.eq(View.hit(l, 1072, 700), nil)
        H.eq(View.hit(l, 500, -1), nil)
        H.eq(View.hit(l, 500, 1448), nil)
    end
end)

H.test("field texts: title names owner and opponent, reminder shows the lethal amount", function()
    H.eq(View.title(1, { kind = "commander", source = 4 }), "J1 · dano de comandante de J4")
    H.eq(View.title(3, { kind = "poison" }), "J3 · veneno")
    H.eq(View.reminder({ kind = "commander", source = 4 }), "de 21")
    H.eq(View.reminder({ kind = "poison" }), "fora com 10")
end)

H.test("field value: commander damage from that opponent, or poison", function()
    local Game = require("core.game")
    local g = Game.new(4, 40)
    g:adjust_commander(1, 4, 7)
    g:adjust_poison(1, 3)
    H.eq(View.value(g, 1, { kind = "commander", source = 4 }), 7)
    H.eq(View.value(g, 1, { kind = "commander", source = 2 }), 0)
    H.eq(View.value(g, 1, { kind = "poison" }), 3)
end)
