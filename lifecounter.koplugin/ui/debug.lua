-- Modo debug (so KOReader): investigar o travamento ao voltar do descanso, sem cabo nem inspector.
-- Liga/desliga segurando 5 s "Voltar ao menu principal" (estado guardado nos settings).
-- Ligado: uma barra fina no pe de todas as telas do app com um contador que muda a cada segundo
-- (se parar, o app travou) e as ultimas linhas do registro; tudo vai tambem para
-- settings/lifecounter_debug.log, uma escrita por linha, para ser lido depois de travar.
-- O contador PARA no descanso (IntoSS/Suspend) e volta ao acordar, para nao mudar o comportamento
-- do sono; os dois instantes ficam registrados. So a regiao da barra e atualizada.
local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Device = require("device")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Fs = require("core.fs")
local Log = require("core.debuglog")
local socket = require("socket")

local Debug = { enabled = false, paused = false, ticks = 0, paints = 0 }

local log
local LIPC_OUT, POWERD_OUT = "/tmp/lifecounter_lipc.out", "/tmp/lifecounter_powerd.out"
local pending = {} -- arquivos de saida de comandos em segundo plano a ler no proximo segundo

local function flag_path() return DataStorage:getSettingsDir() .. "/lifecounter_debug" end
function Debug.log_path() return DataStorage:getSettingsDir() .. "/lifecounter_debug.log" end

function Debug.event(text)
    if not Debug.enabled or not log then return end
    Debug.last = text
    log:add(text)
end

function Debug.last_lines(n)
    return log and log:last(n) or {}
end

-- Le (uma vez) o que um comando em segundo plano escreveu.
local function read_pending()
    for path, label in pairs(pending) do
        local s = Fs.read(path)
        if s and s ~= "" then
            pending[path] = nil
            Debug.event(label .. ": " .. s:gsub("%s+$", ""):gsub("\n", " | "))
            os.remove(path)
        end
    end
end

-- Estado do powerd do Kindle (em segundo plano, para nunca esperar pelo powerd).
function Debug.probe_powerd(reason)
    if not Debug.enabled or not Device:isKindle() then return end
    os.remove(POWERD_OUT)
    os.execute("lipc-get-prop com.lab126.powerd status > " .. POWERD_OUT .. " 2>&1 &")
    pending[POWERD_OUT] = "powerd status (" .. reason .. ")"
end

-- Comando do modo acordado (app.lua). Com o debug ligado, o resultado vai para um arquivo e e
-- registrado no proximo segundo; desligado, o comando e o mesmo de sempre.
function Debug.lipc_command(value)
    local base = "lipc-set-prop com.lab126.powerd preventScreenSaver " .. value
    if not Debug.enabled then return base .. " >/dev/null 2>&1 &" end
    os.remove(LIPC_OUT)
    pending[LIPC_OUT] = "lipc preventScreenSaver " .. value .. " result"
    Debug.event("lipc preventScreenSaver " .. value .. " sent")
    return "(" .. base .. "; echo rc=$?) > " .. LIPC_OUT .. " 2>&1 &"
end

function Debug.bar_rect(w, h)
    local bh = math.floor(66 * h / 1448)
    return { x = 0, y = h - bh, w = w, h = bh }
end

local function ours(w)
    return w and type(w.name) == "string" and w.name:match("^lifecounter_") ~= nil
end

-- A tela do app mais alta na pilha (a que desenha a barra) e quem esta no topo, se nao for do app
-- (ex.: a janela da tela de descanso que ficou aberta e engole os toques).
local function stack_info()
    local stack = UIManager._window_stack or {}
    local top = stack[#stack] and stack[#stack].widget
    local foreign = top and not ours(top) and string.format("%s%s", tostring(top.name or "?"), top.modal and "(modal)" or "") or nil
    for i = #stack, 1, -1 do
        if ours(stack[i].widget) then return stack[i].widget, foreign end
    end
    return nil, foreign
end

local last_foreign
function Debug.top_note()
    return last_foreign and (" | TOP=" .. last_foreign) or ""
end

function Debug.refresh_bar()
    local w, foreign = stack_info()
    if foreign ~= last_foreign then
        last_foreign = foreign
        Debug.event(foreign and ("window on top of the app: " .. foreign) or "app is on top again")
    end
    if not w then return end
    local r = Debug.bar_rect(w.dimen.w, w.dimen.h)
    UIManager:setDirty(w, function() return "fast", Geom:new(r) end)
end

local tick
tick = function()
    if not Debug.enabled or Debug.paused then return end
    Debug.ticks = Debug.ticks + 1
    read_pending()
    Debug.refresh_bar()
    UIManager:scheduleIn(1, tick)
end

local function start_ticker()
    UIManager:unschedule(tick)
    if Debug.enabled and not Debug.paused then UIManager:scheduleIn(1, tick) end
end

function Debug.pause(reason)
    if not Debug.enabled then return end
    Debug.event("PAUSE counter: " .. reason)
    Debug.paused = true
    UIManager:unschedule(tick)
end

function Debug.resume(reason)
    if not Debug.enabled then return end
    Debug.event("RESUME counter: " .. reason)
    Debug.probe_powerd(reason)
    if Debug.paused then
        Debug.paused = false
        start_ticker()
    end
end

-- Eventos de energia que o KOReader espalha para as telas (onSuspend etc. das telas do app).
-- Varias telas recebem o mesmo evento: registra uma vez so.
local last_broadcast = {}
function Debug.broadcast(name)
    if not Debug.enabled then return end
    local now = socket.gettime()
    if last_broadcast[name] and now - last_broadcast[name] < 0.2 then return end
    last_broadcast[name] = now
    if name == "Suspend" then Debug.pause("event Suspend")
    elseif name == "Resume" then Debug.resume("event Resume")
    else Debug.event("event " .. name) end
end

-- Envolve funcoes do KOReader para registrar (o comportamento continua o mesmo: so registra antes).
local function wrap(obj, name, before)
    local orig = obj and obj[name]
    if type(orig) ~= "function" then return end
    obj[name] = function(...)
        if Debug.enabled then pcall(before, ...) end
        return orig(...)
    end
end

local hooked = false
local function install_hooks()
    if hooked then return end
    hooked = true
    -- Kindle: o powerd avisa por estes metodos (descanso, acordar, suspensao de verdade).
    wrap(Device, "intoScreenSaver", function(_, src) Debug.pause("powerd IntoScreenSaver src=" .. tostring(src)) end)
    wrap(Device, "outofScreenSaver", function(_, src) Debug.resume("powerd OutOfScreenSaver src=" .. tostring(src)) end)
    wrap(Device, "readyToSuspend", function(_, d) Debug.event("powerd ReadyToSuspend delay=" .. tostring(d)) end)
    wrap(Device, "wakeupFromSuspend", function(_, ts) Debug.event("powerd WakeupFromSuspend ts=" .. tostring(ts)) end)
    local ok, Screensaver = pcall(require, "ui/screensaver")
    if ok then
        wrap(Screensaver, "show", function() Debug.event("screensaver show") end)
        wrap(Screensaver, "close", function() Debug.event("screensaver close (delay=" .. tostring(G_reader_settings and G_reader_settings:readSetting("screensaver_delay")) .. ")") end)
    end
end

function Debug.setup()
    log = log or Log.new{ max = 40, fs = Fs, path = Debug.log_path() }
    Debug.enabled = Log.load_enabled(Fs, flag_path()) or os.getenv("LIFECOUNTER_DEBUG") == "1"
    if Debug.enabled then
        if #log.lines == 0 then log:load() end
        install_hooks()
        Debug.event("---- app opened (lines above: previous run)")
        Debug.paused = false
        start_ticker()
    end
end

function Debug.set_enabled(on)
    if on then
        Debug.enabled = true
        Log.save_enabled(Fs, flag_path(), true)
        if #log.lines == 0 then log:load() end
        install_hooks()
        Debug.event("debug ON")
        Debug.probe_powerd("debug on")
        Debug.paused = false
        start_ticker()
    else
        Debug.event("debug OFF")
        Log.save_enabled(Fs, flag_path(), false)
        Debug.enabled = false
        UIManager:unschedule(tick)
    end
end

-- Estado do app numa linha (app.lua preenche: modo acordado, timers da partida).
Debug.status = function() return "" end

function Debug.paint(bb, w, h)
    if not Debug.enabled then return end
    local Draw = require("ui/draw")
    local r = Debug.bar_rect(w, h)
    local k = h / 1448
    bb:paintRect(r.x, r.y, r.w, r.h, Blitbuffer.COLOR_WHITE)
    bb:paintRect(r.x, r.y, r.w, math.max(2, math.floor(3 * k)), Blitbuffer.COLOR_BLACK)
    local px = math.floor(17 * k)
    local lh = math.floor((r.h - 4) / 3)
    local head = string.format("#%d %s%s  %s%s", Debug.ticks, os.date("%H:%M:%S"), Debug.paused and " PAUSED" or "", Debug.status(), Debug.top_note())
    local lines = { head }
    for _, l in ipairs(Debug.last_lines(2)) do lines[#lines + 1] = l end
    for i, l in ipairs(lines) do
        if #l > 95 then l = l:sub(1, 95) end
        Draw.text(bb, 8, r.y + 4 + (i - 0.5) * lh, l, px, { bold = i == 1, align = "left" })
    end
end

return Debug
