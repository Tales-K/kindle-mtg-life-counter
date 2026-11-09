local H = require("helper")
local Game = require("core.game")
local Store = require("core.store")

local function tmpdir()
    local p = io.popen("mktemp -d")
    local d = p:read("*l")
    p:close()
    return d
end

local function write(path, s)
    local f = assert(io.open(path, "wb"))
    f:write(s)
    f:close()
end

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

H.test("save then load round-trips a game", function()
    local dir = tmpdir()
    local store = Store.new(dir .. "/state.lua")
    local g = Game.new(4, 40)
    g:adjust_life(2, -7)
    g:adjust_poison(3, 3)
    g:adjust_commander(1, 4, 5)
    H.eq(store:save(g:to_table()), true)
    local t = assert(store:load())
    H.eq(t, g:to_table())
    H.eq(Game.from_table(t):to_table(), g:to_table())
end)

H.test("load on missing file returns nil missing", function()
    local store = Store.new(tmpdir() .. "/nada.lua")
    local t, err = store:load()
    H.eq(t, nil)
    H.eq(err, "missing")
end)

H.test("load on truncated file returns nil corrupt and keeps a .corrupt copy", function()
    local dir = tmpdir()
    local path = dir .. "/state.lua"
    write(path, 'return { version = 1, data = { player_count = 4, pla')
    local t, err = Store.new(path):load()
    H.eq(t, nil)
    H.eq(err, "corrupt")
    H.eq(read(path), nil)
    H.eq(read(path .. ".corrupt") ~= nil, true)
end)

H.test("load on file from future version returns nil", function()
    local dir = tmpdir()
    local path = dir .. "/state.lua"
    write(path, "return { version = 2, data = {} }")
    local t, err = Store.new(path):load()
    H.eq(t, nil)
    H.eq(err, "version")
end)

H.test("load refuses a file that tries to run code", function()
    local dir = tmpdir()
    local path = dir .. "/state.lua"
    write(path, 'return { version = 1, data = os.execute("touch ' .. dir .. '/pwned") }')
    local t = Store.new(path):load()
    H.eq(t, nil)
    H.eq(read(dir .. "/pwned"), nil)
end)

H.test("save leaves old file intact if tmp write fails", function()
    local dir = tmpdir()
    local path = dir .. "/state.lua"
    local store = Store.new(path)
    local g = Game.new(2, 40)
    H.eq(store:save(g:to_table()), true)
    local before = read(path)
    os.execute("mkdir '" .. path .. ".tmp'")
    g:adjust_life(1, -1)
    local ok, err = store:save(g:to_table())
    H.eq(ok, nil)
    H.eq(type(err), "string")
    H.eq(read(path), before)
end)

H.test("values with negative life and 4 digits round-trip", function()
    local dir = tmpdir()
    local store = Store.new(dir .. "/state.lua")
    local g = Game.new(2, 40)
    g:adjust_life(1, -140)
    g:adjust_life(2, 960)
    store:save(g:to_table())
    local g2 = assert(Game.from_table(assert(store:load())))
    H.eq(g2.players[1].life, -100)
    H.eq(g2.players[2].life, 1000)
end)
