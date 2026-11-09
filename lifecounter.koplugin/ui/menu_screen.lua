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
local I18n = require("core.i18n")
local ML = require("core.menu_layout")
local Tuning = require("core.tuning")
local socket = require("socket")
local Screen = Device.screen

local MenuScreen = InputContainer:extend{ modal = true, covers_fullscreen = true, name = "lifecounter_menu" }

-- items = { { text = "...", callback = function(menu, pos, rect) end, stay = false, kind = nil }, ... }
-- Depois do callback o menu se fecha, a nao ser que o item tenha stay = true
-- (nesse caso o callback chama menu:close() quando quiser). pos e o ponto tocado e rect o botao.
-- kind = "language": o botao vira as duas bandeiras (Reino Unido e Brasil), a ativa destacada.
function MenuScreen:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.layout = ML.compute(#self.items, w, h)
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.ges_events = { Tap = { GestureRange:new{ ges = "tap", range = self.dimen } } }
end

function MenuScreen:close()
    UIManager:close(self, "ui")
end

function MenuScreen:onTap(_, ges)
    if self.guard:ignore(socket.gettime()) then return true end
    local i = ML.hit(self.layout, ges.pos.x, ges.pos.y)
    local item = i and self.items[i]
    if item then
        if item.callback then item.callback(self, ges.pos, self.layout.buttons[i]) end
        if not item.stay then self:close() end
    end
    return true
end

-- Titulo numa linha; se nao couber, quebra antes da versao "(vN)" (ou do ultimo espaco).
local function paint_title(bb, r, text)
    if Draw.fits(text, r.w - 16, 52, true) then return Draw.centered(bb, r, text, 52, true) end
    local a, b = text:match("^(.-)%s+(%(.*%))$")
    if not a then a, b = text:match("^(.*)%s+(%S+)$") end
    if not a then return Draw.centered(bb, r, text, 52, true) end
    local h1 = math.floor(r.h * 0.6)
    Draw.centered(bb, { x = r.x, y = r.y, w = r.w, h = h1 }, a, 52, true)
    Draw.centered(bb, { x = r.x, y = r.y + h1 - 12, w = r.w, h = r.h - h1 + 12 }, b, 36, false)
end

-- Botao de idioma: duas metades, cada uma com a bandeira e o nome; a ativa com borda grossa e nome em negrito.
local function paint_language(bb, r)
    local active = I18n.lang()
    local gap = math.floor(r.h * 0.12)
    local half = math.floor((r.w - gap) / 2)
    for i, lang in ipairs({ "en", "pt" }) do
        local box = { x = r.x + (i - 1) * (half + gap), y = r.y, w = half, h = r.h }
        local on = lang == active
        Draw.border_round(bb, box, on and 9 or 2, Blitbuffer.COLOR_BLACK, math.floor(r.h * 0.12))
        local fh = math.floor(r.h * 0.52)
        local cy = box.y + math.floor(r.h * 0.39)
        Draw.flag(bb, lang, box.x + box.w / 2, cy, fh)
        Draw.text(bb, box.x + box.w / 2, box.y + math.floor(r.h * 0.83), I18n.t("lang_" .. lang),
            math.floor(r.h * 0.17), { bold = on })
    end
end

function MenuScreen:paintTo(bb, x, y)
    local l = self.layout
    bb:paintRect(0, 0, l.w, l.h, Blitbuffer.COLOR_WHITE)
    paint_title(bb, l.title, self.title)
    for i, item in ipairs(self.items) do
        local r = l.buttons[i]
        if item.kind == "language" then
            paint_language(bb, r)
        else
            Draw.box(bb, r, 3)
            Draw.centered(bb, r, item.text, 40)
        end
    end
    -- A trava conta a partir do fim da atualizacao do e-ink (que vem depois do desenho e,
    -- no Kindle, segura os toques na fila por ~0,4 s): o nextTick roda logo apos o refresh.
    if self.guard.waiting_paint then
        UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
    end
end

return MenuScreen
