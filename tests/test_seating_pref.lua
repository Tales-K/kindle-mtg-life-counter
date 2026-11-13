local H = require("helper")
local Fs = require("core.fs")
local Pref = require("core.seating_pref")

local function tmpdir()
    local d = os.tmpname(); os.remove(d); os.execute("mkdir -p " .. d)
    return d
end

H.test("seating pref: two rows when nothing was saved", function()
    H.eq(Pref.load(Fs, tmpdir() .. "/lifecounter_seating"), "rows")
end)

H.test("seating pref: remembers the last format", function()
    local p = tmpdir() .. "/lifecounter_seating"
    H.eq(Pref.save(Fs, p, "sides"), true)
    H.eq(Pref.load(Fs, p), "sides")
    Pref.save(Fs, p, "rows")
    H.eq(Pref.load(Fs, p), "rows")
end)

H.test("seating pref: unknown values are refused / read as two rows", function()
    local p = tmpdir() .. "/lifecounter_seating"
    H.eq(Pref.save(Fs, p, "circle"), false)
    Fs.write(p, "garbage")
    H.eq(Pref.load(Fs, p), "rows")
end)

H.test("seating pref: game seating value (nil for rows)", function()
    H.eq(Pref.game_seating("rows"), nil)
    H.eq(Pref.game_seating("sides"), "sides")
end)
