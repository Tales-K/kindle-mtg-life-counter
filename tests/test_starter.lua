local H = require("helper")
local Starter = require("core.starter")

-- rand falso: devolve os valores da lista em ordem (como math.random(a, b)).
local function seq(list)
    local i = 0
    return function(a, b)
        i = i + 1
        local v = list[(i - 1) % #list + 1]
        assert(v >= a and v <= b, "fora do intervalo")
        return v
    end
end

H.test("starter: the result is the first draw, from 1 to the player count", function()
    local r = Starter.roll(4, seq({ 3, 1, 2, 3, 1, 2, 3 }), 6)
    H.eq(r.result, 3)
    H.eq(r.frames[#r.frames], 3)
end)

H.test("starter: a few frames, every value a player, never the same twice in a row", function()
    for n = 2, 6 do
        for _ = 1, 50 do
            local r = Starter.roll(n, math.random, 6)
            H.eq(#r.frames, 6)
            for i, v in ipairs(r.frames) do
                H.eq(v >= 1 and v <= n, true)
                if i > 1 then H.eq(v ~= r.frames[i - 1], true) end
            end
            H.eq(r.frames[6], r.result)
        end
    end
end)

H.test("starter: every player can be drawn (4 players, many rolls)", function()
    local seen = {}
    for _ = 1, 400 do seen[Starter.roll(4, math.random, 6).result] = true end
    H.eq(seen, { [1] = true, [2] = true, [3] = true, [4] = true })
end)
