-- Carregador estavel do plugin. Fica fora das atualizacoes (assim como core/updater.lua e core/fs.lua):
-- o app de verdade esta em app.lua e pode ser trocado; se uma versao nova quebrar, voltamos para a anterior.
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local Fs = require("core.fs")
local Updater = require("core.updater")

local LifeCounter = WidgetContainer:extend{
    name = "lifecounter",
    is_doc_only = false,
}

-- O KOReader cria uma instancia do plugin a cada vez que abre o gerenciador de arquivos ou um livro;
-- a checagem de inicializacao tem que rodar uma unica vez por processo.
local boot_checked = false
local autostarted = false
local pending_notice = nil

-- Esquece so os modulos que sao arquivos deste plugin (para pegar arquivos trocados por uma
-- atualizacao), sem mexer nos do KOReader nem nos protegidos.
local function forget_plugin_modules(plugin_path)
    for name in pairs(package.loaded) do
        local path = plugin_path .. "/" .. name:gsub("%.", "/") .. ".lua"
        if name ~= "core.updater" and name ~= "core.fs" and Fs.exists(path) then
            package.loaded[name] = nil
        end
    end
end

function LifeCounter:onDispatcherRegisterActions()
    Dispatcher:registerAction("lifecounter_open", {
        category = "none", event = "LifeCounterOpen", title = "Contador MTG", general = true,
    })
end

-- Permite ligar o app a um gesto (Menu > Configuracoes > Toques e gestos) ou a um perfil.
function LifeCounter:onLifeCounterOpen()
    self:open()
    return true
end

-- So para desenvolvimento no aparelho: com o arquivo dev.flag na pasta do plugin e o "KOReader HTTP inspector"
-- ligado, da para mandar toques por /koreader/broadcast/LifeCounterSimTap/x/y[/tap|hold|hold_release].
function LifeCounter:onLifeCounterSimTap(x, y, kind)
    if not Fs.exists(self.path .. "/dev.flag") then return true end
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    UIManager:sendEvent(Event:new("Gesture", {
        ges = kind or "tap", pos = Geom:new{ x = tonumber(x), y = tonumber(y), w = 0, h = 0 }, time = 0,
    }))
    return true
end

function LifeCounter:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    if not boot_checked then
        boot_checked = true
        local ok, err = pcall(function()
            local guard = Updater.new{
                plugin_dir = self.path,
                backup_dir = DataStorage:getDataDir() .. "/lifecounter_backup",
                staging_dir = DataStorage:getDataDir() .. "/lifecounter_staging",
                fs = Fs,
            }
            local result = guard:boot_check(function()
                local loaded, lerr = pcall(function()
                    forget_plugin_modules(self.path)
                    require("app")
                end)
                if not loaded then logger.err("lifecounter: app novo nao carregou:", lerr) end
                return loaded
            end)
            if result == "rolled_back" then
                pending_notice = "A atualizacao nao foi concluida e foi desfeita. Voltando para a versao anterior."
            elseif result == "rolled_back_now" then
                pending_notice = "A versao nova falhou e foi desfeita. Reiniciando o KOReader..."
                UIManager:scheduleIn(2, function() UIManager:restartKOReader() end)
            end
            logger.info("lifecounter: checagem de inicializacao:", result)
        end)
        if not ok then logger.err("lifecounter: falha na checagem de inicializacao:", err) end
    end
    -- Abre o app sozinho, uma vez por processo, quando o KOReader e iniciado pela entrada do KUAL
    -- (ou no emulador de desenvolvimento) com LIFECOUNTER_AUTOSTART=1.
    if os.getenv("LIFECOUNTER_AUTOSTART") and not autostarted then
        autostarted = true
        UIManager:nextTick(function() self:open() end)
    end
end

function LifeCounter:addToMainMenu(menu_items)
    menu_items.lifecounter = {
        text = "Contador MTG",
        sorting_hint = "more_tools",
        callback = function() self:open() end,
    }
end

function LifeCounter:open()
    if pending_notice then
        UIManager:show(InfoMessage:new{ text = pending_notice })
        pending_notice = nil
    end
    local ok, err = pcall(function()
        forget_plugin_modules(self.path)
        require("app").open(self)
    end)
    if not ok then
        logger.err("lifecounter: falha ao abrir o app:", err)
        UIManager:show(InfoMessage:new{ text = "Contador MTG: erro ao abrir.\n" .. tostring(err) })
    end
end

return LifeCounter
