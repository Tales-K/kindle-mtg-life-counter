local H = require("helper")
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

H.test("start menu with a saved game: Fechar leaves KOReader, and there is a way to stay in KOReader", function()
    local items = Menus.start(true)
    H.eq(labels(items), { "Continuar partida", "Nova partida", "Atualizar", "Abrir o KOReader", "Fechar" })
    H.eq(ids(items), { "continue", "new", "update", "koreader", "exit" })
end)

H.test("start menu without a saved game has no Continuar", function()
    H.eq(ids(Menus.start(false)), { "new", "update", "koreader", "exit" })
end)

H.test("game menu: Fechar leaves KOReader (no separate 'Sair do KOReader')", function()
    local items = Menus.game()
    H.eq(labels(items), { "Voltar ao jogo", "Reiniciar partida", "Nova partida", "Abrir o KOReader", "Fechar" })
    H.eq(ids(items), { "back", "restart", "new", "koreader", "exit" })
end)
