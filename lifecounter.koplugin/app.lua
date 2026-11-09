-- Entrada atualizavel do app: tela inicial, partida, menu e atualizacao.
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local Fs = require("core.fs")
local Game = require("core.game")
local KeepAwake = require("core.keep_awake")
local Tuning = require("core.tuning")
local socket = require("socket")
local Menus = require("core.menus")
local Messages = require("core.update_messages")
local RollbackNotice = require("core.rollback_notice")
local Store = require("core.store")

local App = {}

local function info(text) UIManager:show(InfoMessage:new{ text = text }) end

-- Menu em tela cheia e modal (um ButtonDialog comum ficaria ESCONDIDO atras da tela de jogo, que e modal).
local function show_menu(title, items)
    local MenuScreen = require("ui/menu_screen")
    UIManager:show(MenuScreen:new{ title = title, items = items }, "ui")
end

-- Junta os itens de core/menus (texto + id) com as acoes do app (callback, stay) pelo id.
local function with_actions(items, actions)
    local out = {}
    for i, it in ipairs(items) do
        local a = actions[it.id] or {}
        out[i] = { text = it.text, callback = a.callback, stay = a.stay }
    end
    return out
end

local function exit_koreader()
    UIManager:broadcastEvent(Event:new("Exit"))
end

local function version_of(plugin)
    local s = Fs.read(plugin.path .. "/version.txt")
    return tonumber(s and s:match("^%s*(%d+)")) or 0
end

local function load_saved(store)
    local t = store:load()
    if not t then return nil end
    return (Game.from_table(t))
end

local function demo_game(n)
    local g = Game.new(n, 40)
    local function set(i, f) if g.players[i] then f(g.players[i]) end end
    -- J1: dano de 2 oponentes (com 3+ jogadores) e veneno; J2 fora por 21 de J1; J6 fora por vida.
    set(1, function(p) p.life = 27; p.poison = 3; p.cmd[2] = 8; if g.players[3] then p.cmd[3] = 5 end end)
    set(2, function(p) p.cmd[1] = 21; p.life = 19 end)
    set(3, function(p) p.life = 13; p.cmd[1] = 14; p.cmd[2] = 6 end)
    set(4, function(p) p.life = 6; p.poison = 4 end)
    set(5, function(p) p.life = 100 end)
    set(6, function(p) p.life = -3 end)
    return g
end

local show_start, show_board, new_game

-- Kindle acordado durante a partida: cada toque renova; KEEP_AWAKE_S sem toque libera o descanso.
local function set_awake(on)
    local Device = require("device")
    if Device:isKindle() then
        -- Em segundo plano: ao liberar (0) o Kindle pode entrar em descanso na hora e avisar o
        -- KOReader; se o KOReader estiver parado esperando este comando, os dois travam.
        os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver " .. (on and "1" or "0") .. " >/dev/null 2>&1 &")
    end
end
local keep = KeepAwake.new{ timeout = Tuning.KEEP_AWAKE_S, set = set_awake }
local current_board -- so a partida que esta na tela controla o "acordado"
local function keep_tick()
    keep:check(socket.gettime())
    if current_board then UIManager:scheduleIn(60, keep_tick) end
end
local function activity() keep:touch(socket.gettime()) end

show_board = function(plugin, store, game)
    local Board = require("ui/board")
    local Field = require("ui/field")
    UIManager:preventStandby()
    local board
    local function close_board()
        UIManager:close(board, "ui")
        if current_board == board then
            current_board = nil
            UIManager:unschedule(keep_tick)
            keep:stop()
        end
        UIManager:allowStandby()
        UIManager:setDirty("all", "full")
    end
    board = Board:new{
        game = game, store = store, on_activity = activity,
        on_menu = function()
            show_menu("Menu", with_actions(Menus.game(), {
                back = {},
                restart = { stay = true, callback = function(menu)
                    UIManager:show(ConfirmBox:new{
                        text = "Reiniciar a partida? Vida, veneno e dano de comandante voltam ao inicio.",
                        ok_text = "Reiniciar",
                        ok_callback = function()
                            local fresh = Game.new(game.player_count, game.starting_life)
                            store:save(fresh:to_table())
                            show_board(plugin, store, fresh)
                            close_board()
                            menu:close()
                        end,
                    })
                end },
                new = { stay = true, callback = function(menu)
                    new_game(plugin, store, true, menu, close_board)
                end },
                koreader = { callback = close_board },
                exit = { callback = function()
                    close_board()
                    exit_koreader()
                end },
            }))
        end,
        -- Toque num quadradinho de oponente ou na gota: campo unico virado para o dono do painel.
        on_open = function(owner, rotation, field)
            local view
            view = Field:new{
                game = game, store = store, owner = owner, field = field, rotation = rotation,
                on_activity = activity,
                on_close = function() UIManager:close(view, "ui"); board:rearm() end,
            }
            UIManager:show(view, "ui")
        end,
    }
    UIManager:show(board, "full")
    current_board = board
    activity()
    UIManager:unschedule(keep_tick)
    UIManager:scheduleIn(60, keep_tick)
    return board
end

local function choose_life(plugin, store, count)
    local items = {}
    for _, life in ipairs({ 20, 30, 40, 50 }) do
        items[#items + 1] = { text = life == 40 and "40 (padrao commander)" or tostring(life), callback = function()
            local game = Game.new(count, life)
            store:save(game:to_table())
            show_board(plugin, store, game)
        end }
    end
    items[#items + 1] = { text = "Voltar", stay = true, callback = function(menu)
        menu:close()
        App.pick_players(plugin, store)
    end }
    show_menu("Vida inicial", items)
end

function App.pick_players(plugin, store)
    local items = {}
    for n = 2, 6 do
        items[#items + 1] = { text = n .. " jogadores", callback = function() choose_life(plugin, store, n) end }
    end
    items[#items + 1] = { text = "Voltar", stay = true, callback = function(menu)
        menu:close()
        show_start(plugin, store)
    end }
    show_menu("Quantos jogadores?", items)
end

-- from_menu: o menu que chamou (sera fechado depois que o proximo estiver na tela).
new_game = function(plugin, store, has_saved, from_menu, before)
    local function go()
        App.pick_players(plugin, store)
        if before then before() end
        if from_menu then from_menu:close() end
    end
    if has_saved then
        UIManager:show(ConfirmBox:new{
            text = "Isso substitui a partida salva. Continuar?",
            ok_text = "Nova partida", ok_callback = go,
        })
    else
        go()
    end
end

local function load_config(plugin)
    local f = loadfile(plugin.path .. "/config.lua")
    if not f then return nil end
    setfenv(f, {})
    local ok, cfg = pcall(f)
    if not ok or type(cfg) ~= "table" or type(cfg.url) ~= "string" or type(cfg.token) ~= "string" then return nil end
    return cfg
end

local function update(plugin)
    local cfg = load_config(plugin)
    if not cfg then return info(Messages.describe("no config")) end
    local Net = require("core.net")
    local Updater = require("core.updater")
    local updater = Updater.new{
        base_url = cfg.url, token = cfg.token, plugin_dir = plugin.path,
        backup_dir = DataStorage:getDataDir() .. "/lifecounter_backup",
        staging_dir = DataStorage:getDataDir() .. "/lifecounter_staging",
        fs = Fs, sha256 = require("ffi/sha2").sha256,
        json_decode = Net.json_decode, http_get = Net.http_get,
    }
    NetworkMgr:runWhenOnline(function()
        local r = updater:check()
        if r.state == "error" then return info(Messages.describe(r.err)) end
        if r.state == "up_to_date" then return info("Ja esta na versao " .. r.version .. ".") end
        UIManager:show(ConfirmBox:new{
            text = "Versao " .. r.version .. " disponivel. Instalar?",
            ok_text = "Instalar",
            ok_callback = function()
                local ok, err = updater:install(r.manifest)
                if not ok then
                    -- Falha ja avisada aqui; um backup igual a versao atual nao deve virar aviso de rollback depois.
                    RollbackNotice.take(Fs, plugin.path, DataStorage:getDataDir() .. "/lifecounter_backup")
                    return info(Messages.describe(err))
                end
                info("Atualizado para a versao " .. r.version .. ". Reiniciando o KOReader...")
                UIManager:forceRePaint()
                UIManager:scheduleIn(3, function() UIManager:restartKOReader() end)
            end,
        })
    end)
end

show_start = function(plugin, store)
    local saved = load_saved(store)
    local items = with_actions(Menus.start(saved ~= nil), {
        continue = { callback = function() show_board(plugin, store, saved) end },
        new = { stay = true, callback = function(menu) new_game(plugin, store, saved ~= nil, menu) end },
        update = { stay = true, callback = function() update(plugin) end },
        koreader = {},
        exit = { callback = exit_koreader },
    })
    show_menu("Contador MTG  (v" .. version_of(plugin) .. ")", items)
end

local function run_sim()
    -- Gancho so de desenvolvimento: LIFECOUNTER_SIM_TAPS="x:y:segundos,x:y:segundos" simula toques na tela.
    local sim = os.getenv("LIFECOUNTER_SIM_TAPS")
    if not sim then return end
    local Geom = require("ui/geometry")
    for x, y, delay in sim:gmatch("(%d+):(%d+):([%d%.]+)") do
        UIManager:scheduleIn(tonumber(delay), function()
            UIManager:sendEvent(Event:new("Gesture", {
                ges = "tap", pos = Geom:new{ x = tonumber(x), y = tonumber(y), w = 0, h = 0 }, time = 0,
            }))
        end)
    end
end

function App.open(plugin)
    local store = Store.new(DataStorage:getSettingsDir() .. "/lifecounter_state.lua")

    -- Ganchos so de desenvolvimento (emulador).
    local demo = tonumber(os.getenv("LIFECOUNTER_DEMO") or "")
    if demo then
        local board = show_board(plugin, store, demo_game(demo))
        -- "dono:oponente[:toques]" ou "dono:v[:toques]": toca no quadradinho do oponente (ou na gota)
        -- no painel do dono, como um jogador faria, e depois simula os toques no campo unico:
        -- "+"/"-" tocar, "H"/"h" segurar em +/-, "o" OK. Padrao: "++H".
        local owner, what, script = (os.getenv("LIFECOUNTER_DEMO_COMMANDER") or ""):match("^(%d+):(%w+):?([%+%-Hho]*)$")
        owner = tonumber(owner)
        local panel
        for _, q in ipairs(board.layout.panels) do if q.index == owner then panel = q end end
        if panel then
            local Geom = require("ui/geometry")
            local Layout = require("core.layout")
            local View = require("core.field_view")
            local function send(kind, rect, rotation, lx, ly, delay)
                local x, y = rect.x + math.floor(lx), rect.y + math.floor(ly)
                if rotation == 180 then x, y = rect.x + rect.w - 1 - math.floor(lx), rect.y + rect.h - 1 - math.floor(ly) end
                UIManager:scheduleIn(delay, function()
                    UIManager:sendEvent(Event:new("Gesture", { ges = kind, pos = Geom:new{ x = x, y = y, w = 0, h = 0 }, time = 0 }))
                end)
            end
            local g = Layout.panel(panel.w, panel.h, demo)
            local lx, ly = g.icon.cx, g.icon.cy
            local m = g.minimap
            for _, c in ipairs(Layout.minimap(demo, panel.rotation, m.w, m.h)) do
                if c.index == tonumber(what) then lx, ly = m.x + c.x + c.w / 2, m.y + c.y + c.h / 2 end
            end
            send("tap", panel, panel.rotation, lx, ly, 1)
            local screen = board.dimen
            local fl = View.layout(screen.w, screen.h, panel.rotation)
            local t = 2
            for ch in (script ~= "" and script or "++H"):gmatch(".") do
                local zone = (ch == "+" or ch == "H") and "plus" or (ch == "-" or ch == "h") and "minus" or "ok"
                local r = fl.zones[zone]
                send((ch == "H" or ch == "h") and "hold" or "tap", screen, panel.rotation, r.x + r.w / 2, r.y + r.h / 2, t)
                t = t + 0.7
            end
        end
        run_sim()
        return
    end

    show_start(plugin, store)
    -- Depois de um rollback automatico (versao nova nao abriu), avisa uma vez, por cima do menu.
    if RollbackNotice.take(Fs, plugin.path, DataStorage:getDataDir() .. "/lifecounter_backup") then
        info("A ultima atualizacao nao abriu e foi desfeita. Voce esta na versao " .. version_of(plugin) .. ".")
    end
    -- Atalho "Contador MTG" na biblioteca do Kindle (scriptlet do Universal Hotfix), uma vez.
    local Device = require("device")
    if Device:isKindle() then
        local ok, result = pcall(require("core.shortcut").install, Fs, plugin.path .. "/shortcut/contador-mtg.sh",
            "/mnt/us/documents", DataStorage:getSettingsDir() .. "/lifecounter_shortcut")
        if ok and result == "installed" then
            info("Atalho \"Contador MTG\" adicionado a biblioteca do Kindle. Na tela inicial do Kindle, toque nele para abrir direto o contador.")
        end
    end
    run_sim()
end

return App
