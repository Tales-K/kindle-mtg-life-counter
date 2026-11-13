local H = require("helper")
local Fs = require("core.fs")
local Log = require("core.debuglog")

local function tmpdir()
    local d = os.tmpname(); os.remove(d); os.execute("mkdir -p " .. d)
    return d
end

local function clock(t) return function() return t.now end end

H.test("debuglog: lines carry the time and keep only the last ones", function()
    local t = { now = 3600 * 13 + 61 }
    local log = Log.new{ max = 3, clock = clock(t), fmt = function(s) return string.format("%05d", s) end }
    for i = 1, 5 do log:add("e" .. i) end
    H.eq(log:last(3), { "46861 e3", "46861 e4", "46861 e5" })
    H.eq(log:last(1), { "46861 e5" })
end)

H.test("debuglog: every line also goes to the file, appended (survives a freeze)", function()
    local path = tmpdir() .. "/lifecounter_debug.log"
    local log = Log.new{ max = 10, clock = function() return 0 end, fmt = function() return "T" end, fs = Fs, path = path }
    log:add("one"); log:add("two")
    H.eq(Fs.read(path), "T one\nT two\n")
    local again = Log.new{ max = 10, clock = function() return 0 end, fmt = function() return "T" end, fs = Fs, path = path }
    again:add("three")
    H.eq(Fs.read(path), "T one\nT two\nT three\n")
end)

H.test("debuglog: on start, the last lines of the previous run come back from the file", function()
    local path = tmpdir() .. "/lifecounter_debug.log"
    Fs.write(path, "a\nb\nc\nd\n")
    local log = Log.new{ max = 2, clock = function() return 0 end, fmt = function() return "T" end, fs = Fs, path = path }
    log:load()
    H.eq(log:last(5), { "c", "d" })
end)

H.test("debuglog: the file is cut down when it grows too big", function()
    local path = tmpdir() .. "/lifecounter_debug.log"
    local log = Log.new{ max = 5, clock = function() return 0 end, fmt = function() return "T" end, fs = Fs, path = path, max_bytes = 40 }
    for i = 1, 20 do log:add("line" .. i) end
    local s = Fs.read(path)
    H.eq(#s <= 80, true)
    H.eq(s:sub(-9), "T line20\n")
end)

H.test("debuglog: enabled flag persists (off by default)", function()
    local path = tmpdir() .. "/lifecounter_debug"
    H.eq(Log.load_enabled(Fs, path), false)
    Log.save_enabled(Fs, path, true)
    H.eq(Log.load_enabled(Fs, path), true)
    Log.save_enabled(Fs, path, false)
    H.eq(Log.load_enabled(Fs, path), false)
end)

H.test("debuglog: clock text is HH:MM:SS of the day", function()
    H.eq(Log.hms(3600 * 13 + 61), "13:01:01")
end)
