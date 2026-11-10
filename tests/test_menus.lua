local H = require("helper")
local I18n = require("core.i18n")
local Menus = require("core.menus")

local function labels(items)
    local out = {}
    for i, it in ipairs(items) do out[i] = it.text end
    return out
end

local function ids(items)
    local out = {}
    for i, it in ipairs(items) do out[i] = it.id end
    return out
end

H.test("start menu ids are stable: continue, new, update, language, exit (no Open KOReader)", function()
    for _, lang in ipairs({ "en", "pt" }) do
        I18n.set(lang)
        H.eq(ids(Menus.start(true)), { "continue", "new", "update", "language", "exit" })
        H.eq(ids(Menus.start(false)), { "new", "update", "language", "exit" })
    end
    I18n.set("en")
end)

H.test("start menu in English: Exit leaves KOReader", function()
    I18n.set("en")
    H.eq(labels(Menus.start(true)), { "Continue game", "New game", "Update", "English / Português", "Exit" })
end)

H.test("start menu in Portuguese", function()
    I18n.set("pt")
    H.eq(labels(Menus.start(true)), { "Continuar partida", "Nova partida", "Atualizar", "English / Português", "Sair" })
    I18n.set("en")
end)

H.test("start menu: the language item is drawn as flags", function()
    I18n.set("en")
    local items = Menus.start(false)
    H.eq(items[3].id, "language")
    H.eq(items[3].kind, "language")
end)

H.test("game menu ids are stable: back, main_menu, new, exit (no Restart, no Open KOReader)", function()
    for _, lang in ipairs({ "en", "pt" }) do
        I18n.set(lang)
        H.eq(ids(Menus.game()), { "back", "main_menu", "new", "exit" })
    end
    I18n.set("en")
end)

H.test("game menu in English", function()
    I18n.set("en")
    H.eq(labels(Menus.game()), { "Back to game", "Back to main menu", "New game", "Exit" })
end)

H.test("game menu in Portuguese", function()
    I18n.set("pt")
    H.eq(labels(Menus.game()), { "Voltar ao jogo", "Voltar ao menu principal", "Nova partida", "Sair" })
    I18n.set("en")
end)

H.test("language half: left half is English, right half is Portuguese", function()
    local r = { x = 100, y = 50, w = 800, h = 120 }
    H.eq(Menus.language_at(r, 100), "en")
    H.eq(Menus.language_at(r, 499), "en")
    H.eq(Menus.language_at(r, 500), "pt")
    H.eq(Menus.language_at(r, 899), "pt")
end)
