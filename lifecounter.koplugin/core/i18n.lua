-- Textos da interface em ingles (padrao) e portugues. Parte pura, sem KOReader.
-- A escolha fica num arquivo (ex.: <settings>/lifecounter_lang, com "en" ou "pt"); sem arquivo, ingles.
-- Parametros entre chaves: t("players_n", { n = 3 }) -> "3 players".
local I18n = {}

I18n.DEFAULT = "en"
I18n.LANGS = { "en", "pt" }

local NAME = "Cryo MTG Life Counter"

I18n.STRINGS = {
    en = {
        app_name = NAME,
        start_title = NAME .. "  (v{version})",
        player = "P{n}",
        you = "you",
        menu_button = "MENU",
        -- Menus.
        menu_continue = "Continue game",
        menu_new = "New game",
        menu_update = "Update",
        menu_language = "English / Português",
        menu_exit = "Exit",
        menu_back = "Back to game",
        menu_who_starts = "Who starts?",
        starts_badge = "{player} starts",
        menu_main_menu = "Back to main menu",
        game_menu_title = "Menu",
        lang_en = "English",
        lang_pt = "Português",
        back = "Back",
        cancel = "Cancel",
        -- Nova partida.
        pick_players_title = "Players",
        players_n = "{n} players",
        format_title = "Table layout",
        format_rows = "Two rows",
        format_sides = "One per side",
        life_title = "Starting life",
        life_default = "{n} (Commander default)",
        -- Campo unico.
        field_commander = "{player} · Commander damage from {source}",
        field_poison = "{player} · Poison",
        reminder_commander = "of {n}",
        reminder_poison = "out at {n}",
        out_note = "{player} is out",
        hint_commander = "tap ±1 · hold ±10",
        hint_poison = "tap ±1",
        field_ok = "OK · back to game",
        -- Atualizacao.
        update_up_to_date = "Already on version {version}.",
        update_available = "Version {version} is available. Install?",
        update_install = "Install",
        update_done = "Updated to version {version}. Restarting KOReader...",
        rollback_notice = "The last update didn't open and was undone. You are on version {version}.",
        shortcut_installed = "\"" .. NAME .. "\" shortcut added to the Kindle library. "
            .. "On the Kindle home screen, tap it to open the counter directly.",
        err_unknown = "Unknown error.",
        err_no_config = "Missing config.lua with the URL and the token.",
        err_token = "The server refused the token.",
        err_cert = "HTTPS certificate error. Check the Kindle's clock.",
        err_bad_file = "Invalid update file. Nothing was changed.",
        err_bad_update = "Invalid update. Nothing was changed.",
        err_network = "No network, or the server is down.",
        err_generic = "Error: {err}",
    },
    pt = {
        app_name = NAME,
        start_title = NAME .. "  (v{version})",
        player = "J{n}",
        you = "você",
        menu_button = "MENU",
        menu_continue = "Continuar partida",
        menu_new = "Nova partida",
        menu_update = "Atualizar",
        menu_language = "English / Português",
        menu_exit = "Sair",
        menu_back = "Voltar ao jogo",
        menu_who_starts = "Quem começa?",
        starts_badge = "{player} começa",
        menu_main_menu = "Voltar ao menu principal",
        game_menu_title = "Menu",
        lang_en = "English",
        lang_pt = "Português",
        back = "Voltar",
        cancel = "Cancelar",
        pick_players_title = "Quantos jogadores?",
        players_n = "{n} jogadores",
        format_title = "Formato da mesa",
        format_rows = "Duas fileiras",
        format_sides = "Um de cada lado",
        life_title = "Vida inicial",
        life_default = "{n} (padrão commander)",
        field_commander = "{player} · dano de comandante de {source}",
        field_poison = "{player} · veneno",
        reminder_commander = "de {n}",
        reminder_poison = "fora com {n}",
        out_note = "{player} está fora",
        hint_commander = "toque ±1 · segurar ±10",
        hint_poison = "toque ±1",
        field_ok = "OK · voltar ao jogo",
        update_up_to_date = "Já está na versão {version}.",
        update_available = "Versão {version} disponível. Instalar?",
        update_install = "Instalar",
        update_done = "Atualizado para a versão {version}. Reiniciando o KOReader...",
        rollback_notice = "A última atualização não abriu e foi desfeita. Você está na versão {version}.",
        shortcut_installed = "Atalho \"" .. NAME .. "\" adicionado à biblioteca do Kindle. "
            .. "Na tela inicial do Kindle, toque nele para abrir direto o contador.",
        err_unknown = "Falha desconhecida.",
        err_no_config = "Falta o arquivo config.lua com a URL e o token.",
        err_token = "Token recusado pelo servidor.",
        err_cert = "Erro de certificado HTTPS. Confira a hora do Kindle.",
        err_bad_file = "Arquivo da atualizacao invalido. Nada foi alterado.",
        err_bad_update = "Atualizacao invalida. Nada foi alterado.",
        err_network = "Sem rede ou servidor fora do ar.",
        err_generic = "Falha: {err}",
    },
}

local current = I18n.DEFAULT

function I18n.lang() return current end

function I18n.set(lang)
    if I18n.STRINGS[lang] then current = lang end
    return current
end

-- Le a escolha salva; sem arquivo (ou com conteudo desconhecido) fica o padrao.
function I18n.load(fs, path)
    local s = fs.read(path)
    local lang = s and s:match("^%s*(%a+)")
    current = I18n.STRINGS[lang] and lang or I18n.DEFAULT
    return current
end

function I18n.save(fs, path, lang)
    if not I18n.STRINGS[lang] then return false end
    current = lang
    return fs.write(path, lang) == true
end

function I18n.toggle(fs, path)
    local nxt = current == "en" and "pt" or "en"
    I18n.save(fs, path, nxt)
    return current
end

function I18n.t(key, params)
    local s = I18n.STRINGS[current][key] or I18n.STRINGS[I18n.DEFAULT][key]
    if not s then return key end
    if not params then return s end
    return (s:gsub("{(%w+)}", function(name)
        local v = params[name]
        if v == nil then return nil end
        return tostring(v)
    end))
end

function I18n.player(n) return I18n.t("player", { n = n }) end

return I18n
