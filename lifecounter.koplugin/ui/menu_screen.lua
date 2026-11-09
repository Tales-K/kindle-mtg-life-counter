-- Menu em tela cheia (titulo + botoes grandes), para o fluxo antes da partida (so KOReader).
-- Evita janelinhas por cima da tela do KOReader, que no e-ink deixavam o fundo aparecendo.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Draw = require("ui/draw")
local Guard = require("core.input_guard")
local ML = require("core.menu_layout")
local Tuning = require("core.tuning")
local socket = require("socket")
local Screen = Device.screen

local MenuScreen = InputContainer:extend{ modal = true, name = "lifecounter_menu" }

-- items = { { text = "...", callback = function(menu) end, stay = false }, ... }
-- Depois do callback o menu se fecha, a nao ser que o item tenha stay = true
-- (nesse caso o callback chama menu:close() quando quiser).
function MenuScreen:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.layout = ML.compute(#self.items, w, h)
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.ges_events = { Tap = { GestureRange:new{ ges = "tap", range = self.dimen } } }
end

function MenuScreen:close()
    UIManager:close(self)
end

function MenuScreen:onTap(_, ges)
    if self.guard:ignore(socket.gettime()) then return true end
    local i = ML.hit(self.layout, ges.pos.x, ges.pos.y)
    local item = i and self.items[i]
    if item then
        if item.callback then item.callback(self) end
        if not item.stay then self:close() end
    end
    return true
end

function MenuScreen:paintTo(bb, x, y)
    local l = self.layout
    bb:paintRect(0, 0, l.w, l.h, Blitbuffer.COLOR_WHITE)
    Draw.centered(bb, l.title, self.title, 52, true)
    for i, item in ipairs(self.items) do
        local r = l.buttons[i]
        Draw.box(bb, r, 3)
        Draw.centered(bb, r, item.text, 40)
    end
    -- A trava conta a partir do fim da atualizacao do e-ink (que vem depois do desenho e,
    -- no Kindle, segura os toques na fila por ~0,4 s): o nextTick roda logo apos o refresh.
    if self.guard.waiting_paint then
        UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
    end
end

return MenuScreen
