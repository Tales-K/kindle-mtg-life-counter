local H = require("helper")
local Guard = require("core.input_guard")

H.test("never armed means nothing is ignored", function()
    H.eq(Guard.should_ignore(nil, 100, 0.4), false)
end)

H.test("a tap right after opening is ignored", function()
    H.eq(Guard.should_ignore(100, 100.1, 0.4), true)
    H.eq(Guard.should_ignore(100, 100.399, 0.4), true)
end)

H.test("a tap at or after the delay is accepted", function()
    H.eq(Guard.should_ignore(100, 100.4, 0.4), false)
    H.eq(Guard.should_ignore(100, 105, 0.4), false)
end)

H.test("a clock that went backwards does not block input forever", function()
    H.eq(Guard.should_ignore(100, 50, 0.4), false)
end)

H.test("window: taps queued while the new screen was still drawing are ignored", function()
    local w = Guard.window(0.4)
    w:arm(100)          -- tela criada
    w:painted(101.5)    -- desenho lento terminou 1,5 s depois
    H.eq(w:ignore(101.6), true)  -- toque que estava na fila durante o desenho
    H.eq(w:ignore(101.9), false)
end)

H.test("window: later repaints do not extend the guard", function()
    local w = Guard.window(0.4)
    w:arm(100)
    w:painted(100.2)
    H.eq(w:ignore(100.7), false)
    w:painted(101)      -- redesenho depois de um toque valido
    H.eq(w:ignore(101.1), false)
end)

H.test("window: re-arming (screen shown again) starts a new guard at the next paint", function()
    local w = Guard.window(0.4)
    w:arm(100); w:painted(100.1)
    w:arm(200)
    H.eq(w:ignore(200.05), true)
    w:painted(201)
    H.eq(w:ignore(201.2), true)
    H.eq(w:ignore(201.5), false)
end)

H.test("window: never armed ignores nothing", function()
    H.eq(Guard.window(0.4):ignore(5), false)
end)
