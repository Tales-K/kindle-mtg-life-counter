local H = require("helper")
local Game = require("core.game")
local Actions = require("core.actions")
local View = require("core.commander_view")

local function fake_store()
    local s = { saves = 0 }
    function s:save() self.saves = self.saves + 1; return true end
    return s
end

H.test("rows lists every opponent but not the target, in seat order", function()
    local g = Game.new(4, 40)
    local rows = View.rows(g, 2)
    H.eq(#rows, 3)
    H.eq({ rows[1].source, rows[2].source, rows[3].source }, { 1, 3, 4 })
end)

H.test("rows marks 21 as lethal and 20 as not", function()
    local g = Game.new(3, 99)
    g:adjust_commander(1, 2, 20)
    g:adjust_commander(1, 3, 21)
    local rows = View.rows(g, 1)
    H.eq(rows[1].damage, 20)
    H.eq(rows[1].lethal, false)
    H.eq(rows[2].damage, 21)
    H.eq(rows[2].lethal, true)
end)

H.test("rows uses 0 for sources with no damage", function()
    local rows = View.rows(Game.new(2, 40), 1)
    H.eq(rows[1], { source = 2, damage = 0, lethal = false })
end)

H.test("commander actions: plus adds damage and removes life, saves once", function()
    local g, s = Game.new(3, 40), fake_store()
    H.eq(Actions.apply_commander(g, s, 1, 2, 1, false), true)
    H.eq(g.players[1].cmd[2], 1)
    H.eq(g.players[1].life, 39)
    H.eq(s.saves, 1)
end)

H.test("commander actions: big minus floors at zero and returns only dealt life", function()
    local g, s = Game.new(3, 40), fake_store()
    g:adjust_commander(1, 2, 4)
    H.eq(Actions.apply_commander(g, s, 1, 2, -1, true), true)
    H.eq(g.players[1].cmd[2], 0)
    H.eq(g.players[1].life, 40)
end)

H.test("commander actions: minus at zero changes nothing and does not save", function()
    local g, s = Game.new(3, 40), fake_store()
    H.eq(Actions.apply_commander(g, s, 1, 2, -1, false), false)
    H.eq(s.saves, 0)
    H.eq(g.players[1].life, 40)
end)

H.test("commander actions: source equal to target does nothing", function()
    local g, s = Game.new(3, 40), fake_store()
    H.eq(Actions.apply_commander(g, s, 1, 1, 1, false), false)
    H.eq(s.saves, 0)
end)

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

H.test("layout has one band per row plus header and back, all inside the screen without overlap", function()
    for count = 1, 5 do
        local l = View.layout(count, 720, 972)
        H.eq(#l.rows, count)
        local rects = { l.header, l.back }
        for _, r in ipairs(l.rows) do
            rects[#rects + 1] = r.minus
            rects[#rects + 1] = r.value
            rects[#rects + 1] = r.plus
        end
        for _, r in ipairs(rects) do
            H.eq(r.x >= 0 and r.y >= 0 and r.x + r.w <= 720 and r.y + r.h <= 972, true)
        end
        for i = 1, #rects do
            for j = i + 1, #rects do H.eq(overlap(rects[i], rects[j]), false) end
        end
    end
end)

H.test("hit finds plus, minus and back, and nil elsewhere", function()
    local l = View.layout(3, 720, 972)
    local r2 = l.rows[2]
    H.eq(View.hit(l, r2.plus.x + 2, r2.plus.y + 2, 0), { row = 2, action = "plus" })
    H.eq(View.hit(l, r2.minus.x + 2, r2.minus.y + 2, 0), { row = 2, action = "minus" })
    H.eq(View.hit(l, l.back.x + 2, l.back.y + 2, 0), { action = "back" })
    H.eq(View.hit(l, l.header.x + 2, l.header.y + 2, 0), nil)
    H.eq(View.hit(l, -1, 5, 0), nil)
end)

H.test("hit with rotation 180 maps the screen point back to the upright frame", function()
    local l = View.layout(3, 720, 972)
    local r2 = l.rows[2]
    local x, y = r2.plus.x + 2, r2.plus.y + 2
    H.eq(View.hit(l, 720 - 1 - x, 972 - 1 - y, 180), { row = 2, action = "plus" })
end)
