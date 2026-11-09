-- Entrada atualizavel do app: tela inicial, partida, menu e atualizacao.
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local Fs = require("core.fs")
local Game = require("core.game")
local Messages = require("core.update_messages")
local RollbackNotice = require("core.rollback_notice")
local Store = require("core.store")

local App = {}

local function info(text) UIManager:show(InfoMessage:new{ text = text }) end

-- Menu em tela cheia e modal (um ButtonDialog comum ficaria ESCONDIDO atras da tela de jogo, que e modal).
local function show_menu(title, items)
    local MenuScreen = require("ui/menu_screen")
    UIManager:show(MenuScreen:new{ title = title, items = items })
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
    set(2, function(p) p.life = -100 end)
    set(3, function(p) p.life = 1000 end)
    set(4, function(p) p.life = 7; p.poison = 9 end)
    set(5, function(p) p.poison = 10 end)
    set(6, function(p) p.cmd[1] = 21; p.life = 19 end)
    return g
end

local show_start, show_board, new_game

show_board = function(plugin, store, game)
    local Board = require("ui/board")
    local Commander = require("ui/commander")
    UIManager:preventStandby()
    local board
    local function close_board()
        UIManager:close(board)
        UIManager:allowStandby()
        UIManager:setDirty("all", "full")
    end
    board = Board:new{
        game = game, store = store,
        on_menu = function()
            show_menu("Menu", {
                { text = "Voltar ao jogo" },
                { text = "Reiniciar partida", stay = true, callback = function(menu)
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
                { text = "Nova partida", stay = true, callback = function(menu)
                    new_game(plugin, store, true, menu, close_board)
                end },
                { text = "Sair para o KOReader", callback = close_board },
                { text = "Sair do KOReader", callback = function()
                    close_board()
                    exit_koreader()
                end },
            })
        end,
        on_commander = function(i, rotation)
            local view
            view = Commander:new{
                game = game, store = store, target = i, rotation = rotation,
                on_close = function() UIManager:close(view); board:rearm() end,
            }
            UIManager:show(view)
        end,
    }
    UIManager:show(board)
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
    local items = {}
    if saved then
        items[#items + 1] = { text = "Continuar partida", callback = function() show_board(plugin, store, saved) end }
    end
    items[#items + 1] = { text = "Nova partida", stay = true, callback = function(menu)
        new_game(plugin, store, saved ~= nil, menu)
    end }
    items[#items + 1] = { text = "Atualizar", stay = true, callback = function() update(plugin) end }
    items[#items + 1] = { text = "Fechar" }
    items[#items + 1] = { text = "Sair do KOReader", callback = exit_koreader }
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
        local dc = os.getenv("LIFECOUNTER_DEMO_COMMANDER")
        if dc then
            -- "alvo:rotacao": abre a tela de comandante e simula 2 toques em + na 1a linha e 1 segurar em + na 2a
            local target, rot = dc:match("^(%d+):(%d+)$")
            board.on_commander(tonumber(target), tonumber(rot))
            local Event = require("ui/event")
            local Geom = require("ui/geometry")
            local top = UIManager._window_stack[#UIManager._window_stack].widget
            local function send(kind, row, action, delay)
                local r = top.layout.rows[row][action]
                local x, y = r.x + 5, r.y + 5
                if tonumber(rot) == 180 then x, y = top.layout.w - 1 - x, top.layout.h - 1 - y end
                UIManager:scheduleIn(delay, function()
                    UIManager:sendEvent(Event:new("Gesture", { ges = kind, pos = Geom:new{ x = x, y = y, w = 0, h = 0 }, time = 0 }))
                end)
            end
            send("tap", 1, "plus", 1); send("tap", 1, "plus", 1.5); send("hold", 2, "plus", 2)
        end
        run_sim()
        return
    end

    show_start(plugin, store)
    -- Depois de um rollback automatico (versao nova nao abriu), avisa uma vez, por cima do menu.
    if RollbackNotice.take(Fs, plugin.path, DataStorage:getDataDir() .. "/lifecounter_backup") then
        info("A ultima atualizacao nao abriu e foi desfeita. Voce esta na versao " .. version_of(plugin) .. ".")
    end
    run_sim()
end

return App
