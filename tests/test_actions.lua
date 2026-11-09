local H = require("helper")
local Game = require("core.game")
local Actions = require("core.actions")

local function fake_store()
    local s = { saves = 0 }
    function s:save(t) self.saves = self.saves + 1; self.last = t; return true end
    return s
end

H.test("plus zone adds 1 and saves once", function()
    local g, s = Game.new(2, 40), fake_store()
    H.eq(Actions.apply(g, s, 1, "plus", false), true)
    H.eq(g.players[1].life, 41)
    H.eq(s.saves, 1)
    H.eq(s.last, g:to_table())
end)

H.test("minus zone subtracts 1", function()
    local g, s = Game.new(2, 40), fake_store()
    Actions.apply(g, s, 2, "minus", false)
    H.eq(g.players[2].life, 39)
    H.eq(g.players[1].life, 40)
end)

H.test("big plus changes life by exactly 10", function()
    local g, s = Game.new(2, 40), fake_store()
    Actions.apply(g, s, 1, "plus", true)
    H.eq(g.players[1].life, 50)
    H.eq(s.saves, 1)
end)

H.test("big minus on poison subtracts 10 floored at 0", function()
    local g, s = Game.new(2, 40), fake_store()
    g:adjust_poison(1, 4)
    Actions.apply(g, s, 1, "poison_minus", true)
    H.eq(g.players[1].poison, 0)
end)

H.test("poison plus adds 1", function()
    local g, s = Game.new(3, 40), fake_store()
    Actions.apply(g, s, 3, "poison_plus", false)
    H.eq(g.players[3].poison, 1)
end)

H.test("zones without an action do nothing and do not save", function()
    local g, s = Game.new(2, 40), fake_store()
    for _, z in ipairs({ "life", "poison_value", "commander" }) do
        H.eq(Actions.apply(g, s, 1, z, false), false)
    end
    H.eq(Actions.apply(g, s, 1, nil, false), false)
    H.eq(s.saves, 0)
    H.eq(g.players[1].life, 40)
end)

H.test("unknown player index does nothing", function()
    local g, s = Game.new(2, 40), fake_store()
    H.eq(Actions.apply(g, s, 5, "plus", false), false)
    H.eq(s.saves, 0)
end)

H.test("many quick taps each count once", function()
    local g, s = Game.new(2, 40), fake_store()
    for _ = 1, 25 do Actions.apply(g, s, 1, "minus", false) end
    H.eq(g.players[1].life, 15)
    H.eq(s.saves, 25)
end)
