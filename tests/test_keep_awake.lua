local H = require("helper")
local KeepAwake = require("core.keep_awake")

local function make(timeout)
    local calls = {}
    local k = KeepAwake.new{ timeout = timeout or 1800, set = function(on) calls[#calls + 1] = on end }
    return k, calls
end

H.test("keep awake: first activity prevents sleep", function()
    local k, calls = make()
    k:touch(0)
    H.eq(calls, { true })
end)

H.test("keep awake: more activity does not repeat the system call", function()
    local k, calls = make()
    k:touch(0); k:touch(10); k:touch(20)
    H.eq(calls, { true })
end)

H.test("keep awake: released after 30 min without activity", function()
    local k, calls = make(1800)
    k:touch(0)
    k:check(1799)
    H.eq(calls, { true })
    k:check(1800)
    H.eq(calls, { true, false })
end)

H.test("keep awake: each activity restarts the 30 min", function()
    local k, calls = make(1800)
    k:touch(0)
    k:touch(1000)
    k:check(2000)
    H.eq(calls, { true })
    k:check(2800)
    H.eq(calls, { true, false })
end)

H.test("keep awake: activity after release prevents sleep again", function()
    local k, calls = make(1800)
    k:touch(0); k:check(1800); k:touch(1900)
    H.eq(calls, { true, false, true })
end)

H.test("keep awake: stop releases once, and only if active", function()
    local k, calls = make()
    k:stop()
    H.eq(calls, {})
    k:touch(0); k:stop(); k:stop()
    H.eq(calls, { true, false })
end)
