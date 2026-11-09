-- Itens dos menus (texto + id). O app liga cada id a uma acao.
-- "Fechar" sai do KOReader inteiro e volta para a tela inicial do Kindle (o app abre pelo atalho
-- da biblioteca); "Abrir o KOReader" fecha so o contador e fica no KOReader.
local M = {}

function M.start(has_saved)
    local items = {}
    if has_saved then items[#items + 1] = { id = "continue", text = "Continuar partida" } end
    items[#items + 1] = { id = "new", text = "Nova partida" }
    items[#items + 1] = { id = "update", text = "Atualizar" }
    items[#items + 1] = { id = "koreader", text = "Abrir o KOReader" }
    items[#items + 1] = { id = "exit", text = "Fechar" }
    return items
end

function M.game()
    return {
        { id = "back", text = "Voltar ao jogo" },
        { id = "restart", text = "Reiniciar partida" },
        { id = "new", text = "Nova partida" },
        { id = "koreader", text = "Abrir o KOReader" },
        { id = "exit", text = "Fechar" },
    }
end

return M
