local H = require("helper")
local Game = require("core.game")
local Actions = require("core.actions")
local View = require("core.commander_view")
local Layout = require("core.layout")

local function fake_store()
    local s = { saves = 0 }
    function s:save() self.saves = self.saves + 1; return true end
    return s
end

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

local W, HH = 1072, 1448

local function cell_of(l, index)
    for _, c in ipairs(l.cells) do if c.index == index then return c end end
end

-- Ponto (lx, ly) no quadro "em pe" de um retangulo girado (0 ou 180) -> ponto na tela.
local function to_screen(r, rot, lx, ly)
    if rot == 180 then return r.x + r.w - 1 - lx, r.y + r.h - 1 - ly end
    return r.x + lx, r.y + ly
end

H.test("damage screen: one square per player, in the same seat and order as the panels", function()
    for n = 2, 6 do
        local panels = Layout.compute(n, W, HH).panels
        for target = 1, n do
            local l = View.layout(n, target, W, HH)
            H.eq(#l.cells, n)
            for k, p in ipairs(panels) do
                local c = l.cells[k]
                H.eq({ c.index, c.x, c.w, c.rotation }, { p.index, p.x, p.w, p.rotation })
                H.eq(c.y == 0, p.y == 0)
                H.eq(c.w >= 106 and c.h >= 106, true)
            end
        end
    end
end)

H.test("damage screen: band sits between the rows, faces the target and nothing overlaps", function()
    for n = 2, 6 do
        local panels = Layout.compute(n, W, HH).panels
        for _, p in ipairs(panels) do
            local l = View.layout(n, p.index, W, HH)
            local b = l.band
            H.eq(b.rotation, p.rotation)
            H.eq(b.x == 0 and b.w == W, true)
            local area = b.w * b.h
            for _, c in ipairs(l.cells) do
                area = area + c.w * c.h
                H.eq(overlap(c, b), false)
            end
            H.eq(area, W * HH)
            for _, name in ipairs({ "back", "poison_minus", "poison_plus" }) do
                local r = l.controls[name]
                H.eq(r.x >= 0 and r.y >= 0 and r.x + r.w <= b.w and r.y + r.h <= b.h, true)
                H.eq(r.w >= 106 and r.h >= 106, true)
            end
            H.eq(overlap(l.controls.back, l.controls.poison_minus), false)
            H.eq(overlap(l.controls.poison_minus, l.controls.poison_plus), false)
        end
    end
end)

H.test("damage hit: opponent below (rotation 0), left half minus and right half plus", function()
    local l = View.layout(4, 3, W, HH)
    local c = cell_of(l, 1)
    H.eq(c.rotation, 0)
    H.eq(View.hit(l, c.x + 10, c.y + 200), { action = "minus", source = 1 })
    H.eq(View.hit(l, c.x + c.w - 10, c.y + 200), { action = "plus", source = 1 })
end)

H.test("damage hit: opponent above (rotation 180), screen left is plus and screen right minus", function()
    local l = View.layout(4, 1, W, HH)
    local c = cell_of(l, 4)
    H.eq(c.rotation, 180)
    H.eq(View.hit(l, c.x + 10, c.y + 200), { action = "plus", source = 4 })
    H.eq(View.hit(l, c.x + c.w - 10, c.y + 200), { action = "minus", source = 4 })
end)

H.test("damage hit: the target's own square does nothing", function()
    for _, target in ipairs({ 1, 3 }) do
        local l = View.layout(4, target, W, HH)
        local c = cell_of(l, target)
        H.eq(View.hit(l, c.x + 10, c.y + 10), nil)
        H.eq(View.hit(l, c.x + c.w - 10, c.y + c.h - 10), nil)
    end
end)

H.test("damage hit: back and poison controls with the band upright (target below)", function()
    local l = View.layout(4, 2, W, HH)
    H.eq(l.band.rotation, 0)
    for name, expected in pairs({ back = "back", poison_minus = "poison_minus", poison_plus = "poison_plus" }) do
        local r = l.controls[name]
        local x, y = to_screen(l.band, 0, r.x + 5, r.y + 5)
        H.eq(View.hit(l, x, y), { action = expected })
    end
end)

H.test("damage hit: back and poison controls with the band turned 180 (target above)", function()
    local l = View.layout(5, 4, W, HH)
    H.eq(l.band.rotation, 180)
    for name, expected in pairs({ back = "back", poison_minus = "poison_minus", poison_plus = "poison_plus" }) do
        local r = l.controls[name]
        local x, y = to_screen(l.band, 180, r.x + 5, r.y + 5)
        H.eq(View.hit(l, x, y), { action = expected })
    end
    -- O "Voltar" de quem esta em cima fica no canto direito da tela.
    local bx = to_screen(l.band, 180, l.controls.back.x + 5, l.controls.back.y + 5)
    H.eq(bx > W / 2, true)
end)

H.test("damage hit: band outside the controls and off-screen points do nothing", function()
    local l = View.layout(3, 1, W, HH)
    local x, y = to_screen(l.band, 0, l.band.w - 5, 3)
    H.eq(View.hit(l, x, y), nil)
    H.eq(View.hit(l, -1, 5), nil)
    H.eq(View.hit(l, 5, HH), nil)
end)

H.test("on_commander: damage hit adds damage and takes life; poison tap moves poison by 1", function()
    local g, s = Game.new(3, 40), fake_store()
    H.eq(Actions.on_commander(g, s, 1, { action = "plus", source = 2 }, false), true)
    H.eq(g.players[1].cmd[2], 1)
    H.eq(g.players[1].life, 39)
    H.eq(Actions.on_commander(g, s, 1, { action = "minus", source = 2 }, true), true)
    H.eq(g.players[1].cmd[2], 0)
    H.eq(g.players[1].life, 40)
    H.eq(Actions.on_commander(g, s, 1, { action = "poison_plus" }, false), true)
    H.eq(Actions.on_commander(g, s, 1, { action = "poison_plus" }, false), true)
    H.eq(Actions.on_commander(g, s, 1, { action = "poison_minus" }, false), true)
    H.eq(g.players[1].poison, 1)
    H.eq(s.saves, 5)
end)

H.test("on_commander: holding poison or back changes nothing", function()
    local g, s = Game.new(3, 40), fake_store()
    H.eq(Actions.on_commander(g, s, 1, { action = "poison_plus" }, true), false)
    H.eq(Actions.on_commander(g, s, 1, { action = "back" }, false), false)
    H.eq(Actions.on_commander(g, s, 1, nil, false), false)
    H.eq(g:to_table(), Game.new(3, 40):to_table())
    H.eq(s.saves, 0)
end)
