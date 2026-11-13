-- Itens dos menus (texto + id) no idioma atual. O app liga cada id a uma acao.
-- "Sair" sai do KOReader inteiro e volta para a tela inicial do Kindle (o app abre pelo atalho
-- da biblioteca).
-- "Voltar ao menu principal" fecha a partida (sem apagar) e mostra a tela inicial.
local I18n = require("core.i18n")

local M = {}

local function item(id, key, kind)
    return { id = id, text = I18n.t(key), kind = kind }
end

function M.start(has_saved)
    local items = {}
    if has_saved then items[#items + 1] = item("continue", "menu_continue") end
    items[#items + 1] = item("new", "menu_new")
    items[#items + 1] = item("update", "menu_update")
    -- Desenhado como duas bandeiras (ui/menu_screen); o texto fica para leitores de tela e testes.
    items[#items + 1] = item("language", "menu_language", "language")
    items[#items + 1] = item("exit", "menu_exit")
    return items
end

function M.game()
    return {
        item("back", "menu_back"),
        item("who_starts", "menu_who_starts"),
        item("main_menu", "menu_main_menu"),
        item("new", "menu_new"),
        item("exit", "menu_exit"),
    }
end

-- Quantos jogadores: 2..6. Com 4, a tela seguinte pergunta o formato da mesa (M.formats).
function M.players()
    local items = {}
    for n = 2, 6 do
        items[#items + 1] = { count = n, text = I18n.t("players_n", { n = n }) }
    end
    return items
end

-- Formato da mesa de 4: um item alto com as duas previas lado a lado (ui/menu_screen desenha) e Voltar.
function M.formats()
    return {
        { id = "format", kind = "format", weight = 4, text = I18n.t("format_title") },
        item("back", "back"),
    }
end

-- Previa tocada: a esquerda e duas fileiras, a direita um de cada lado.
function M.format_at(r, x)
    return x < r.x + math.floor(r.w / 2) and "rows" or "sides"
end

-- Botao de idioma: metade esquerda e o ingles, metade direita o portugues.
function M.language_at(r, x)
    return x < r.x + math.floor(r.w / 2) and "en" or "pt"
end

return M
