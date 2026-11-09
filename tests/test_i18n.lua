local H = require("helper")
local Fs = require("core.fs")
local I18n = require("core.i18n")

local function tmpdir()
    local p = io.popen("mktemp -d")
    local d = p:read("*l")
    p:close()
    return d
end

local function keys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

H.test("i18n: en and pt have exactly the same keys, all non-empty strings", function()
    H.eq(keys(I18n.STRINGS.en), keys(I18n.STRINGS.pt))
    for _, lang in ipairs({ "en", "pt" }) do
        for k, v in pairs(I18n.STRINGS[lang]) do
            if type(v) ~= "string" or v == "" then error(lang .. "." .. k .. " is empty") end
        end
    end
end)

H.test("i18n: placeholders match between en and pt", function()
    local function holes(s)
        local out = {}
        for name in s:gmatch("{(%w+)}") do out[name] = true end
        return out
    end
    for k, en in pairs(I18n.STRINGS.en) do
        H.eq({ k, holes(I18n.STRINGS.pt[k]) }, { k, holes(en) })
    end
end)

H.test("i18n: without a file the language is English", function()
    local d = tmpdir()
    I18n.set("pt")
    H.eq(I18n.load(Fs, d .. "/lifecounter_lang"), "en")
    H.eq(I18n.lang(), "en")
end)

H.test("i18n: an unknown or garbled file falls back to English", function()
    local d = tmpdir()
    Fs.write(d .. "/lang", "klingon")
    H.eq(I18n.load(Fs, d .. "/lang"), "en")
    Fs.write(d .. "/lang", "")
    H.eq(I18n.load(Fs, d .. "/lang"), "en")
end)

H.test("i18n: save persists the choice and load reads it back (trailing newline ok)", function()
    local d = tmpdir()
    local path = d .. "/lifecounter_lang"
    H.eq(I18n.save(Fs, path, "pt"), true)
    H.eq(Fs.read(path), "pt")
    I18n.set("en")
    H.eq(I18n.load(Fs, path), "pt")
    Fs.write(path, "pt\n")
    I18n.set("en")
    H.eq(I18n.load(Fs, path), "pt")
end)

H.test("i18n: save refuses an unknown language and keeps the current one", function()
    local d = tmpdir()
    I18n.set("en")
    H.eq(I18n.save(Fs, d .. "/lang", "xx"), false)
    H.eq(I18n.lang(), "en")
    H.eq(Fs.read(d .. "/lang"), nil)
end)

H.test("i18n: toggle switches en <-> pt and persists", function()
    local d = tmpdir()
    local path = d .. "/lang"
    I18n.set("en")
    H.eq(I18n.toggle(Fs, path), "pt")
    H.eq(Fs.read(path), "pt")
    H.eq(I18n.toggle(Fs, path), "en")
    H.eq(Fs.read(path), "en")
    H.eq(I18n.lang(), "en")
end)

H.test("i18n: t formats parameters in the current language", function()
    I18n.set("en")
    H.eq(I18n.t("field_commander", { player = "P1", source = "P4" }), "P1 · Commander damage from P4")
    H.eq(I18n.t("players_n", { n = 3 }), "3 players")
    I18n.set("pt")
    H.eq(I18n.t("field_commander", { player = "J1", source = "J4" }), "J1 · dano de comandante de J4")
    H.eq(I18n.t("players_n", { n = 3 }), "3 jogadores")
    I18n.set("en")
end)

H.test("i18n: a missing parameter or key never breaks the screen", function()
    I18n.set("en")
    H.eq(I18n.t("players_n"), "{n} players")
    H.eq(I18n.t("no_such_key"), "no_such_key")
end)

H.test("i18n: player names are P1..P6 in English and J1..J6 in Portuguese", function()
    I18n.set("en")
    H.eq(I18n.player(1), "P1")
    H.eq(I18n.player(6), "P6")
    I18n.set("pt")
    H.eq(I18n.player(1), "J1")
    H.eq(I18n.player(6), "J6")
    I18n.set("en")
end)

H.test("i18n: the app name is the same in both languages", function()
    for _, lang in ipairs({ "en", "pt" }) do
        I18n.set(lang)
        H.eq(I18n.t("start_title", { version = 16 }), "Cryo MTG Life Counter  (v16)")
    end
    I18n.set("en")
end)
