local H = require("helper")
local Repeat = require("core.hold_repeat")

-- Relogio falso: schedule guarda o callback; run() dispara o proximo.
local function fake()
    local f = { pending = nil, delays = {} }
    f.schedule = function(delay, cb) f.pending = cb; f.delays[#f.delays + 1] = delay end
    f.unschedule = function(cb) if f.pending == cb then f.pending = nil end end
    f.run = function() local cb = f.pending; f.pending = nil; if cb then cb() end end
    return f
end

local function make(max)
    local f, fired = fake(), {}
    local r = Repeat.new{ interval = 1, max = max or 30, schedule = f.schedule, unschedule = f.unschedule,
                          fire = function(a) fired[#fired + 1] = a end }
    return r, f, fired
end

H.test("hold repeat: nothing fires until the first interval", function()
    local r, f, fired = make()
    r:start("minus")
    H.eq(fired, {})
    H.eq(f.delays, { 1 })
end)

H.test("hold repeat: keeps firing every interval while held", function()
    local r, f, fired = make()
    r:start("plus")
    f.run(); f.run(); f.run()
    H.eq(fired, { "plus", "plus", "plus" })
end)

H.test("hold repeat: release stops it", function()
    local r, f, fired = make()
    r:start("minus")
    f.run()
    r:stop()
    f.run()
    H.eq(fired, { "minus" })
    H.eq(f.pending, nil)
end)

H.test("hold repeat: safety cap if the release never arrives", function()
    local r, f, fired = make(3)
    r:start("minus")
    for _ = 1, 10 do f.run() end
    H.eq(#fired, 3)
end)

H.test("hold repeat: a new hold replaces the old one", function()
    local r, f, fired = make()
    r:start("minus")
    r:start("plus")
    f.run()
    H.eq(fired, { "plus" })
end)
