-- Menu em tela cheia (titulo + botoes grandes), para o fluxo antes da partida (so KOReader).
-- Evita janelinhas por cima da tela do KOReader, que no e-ink deixavam o fundo aparecendo.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Debug = require("ui/debug")
local Draw = require("ui/draw")
local Guard = require("core.input_guard")
local I18n = require("core.i18n")
local Layout = require("core.layout")
local ML = require("core.menu_layout")
local Tuning = require("core.tuning")
local socket = require("socket")
local Screen = Device.screen

local MenuScreen = InputContainer:extend{ modal = true, covers_fullscreen = true, name = "lifecounter_menu" }

-- items = { { text = "...", callback = function(menu, pos, rect) end, stay = false, kind = nil }, ... }
-- Depois do callback o menu se fecha, a nao ser que o item tenha stay = true
-- (nesse caso o callback chama menu:close() quando quiser). pos e o ponto tocado e rect o botao.
-- kind = "language": o botao vira as duas bandeiras (Reino Unido e Brasil), a ativa destacada.
-- kind = "format": previas das duas mesas de 4 (duas fileiras | um de cada lado); item.active
-- ("rows"/"sides") e o ultimo usado, destacado. weight = altura relativa do botao (1 = normal).
function MenuScreen:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    local weights = {}
    for i, it in ipairs(self.items) do weights[i] = it.weight or 1 end
    self.layout = ML.compute(#self.items, w, h, weights)
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
        HoldRelease = { GestureRange:new{ ges = "hold_release", range = self.dimen } },
    }
    -- Item com on_long_hold: segurar ~5 s (o "hold" do KOReader chega ~0,5 s depois do toque).
    self._long = function()
        local item = self._long_item
        self._long_item = nil
        if item and item.on_long_hold then item.on_long_hold(self) end
    end
end

function MenuScreen:close()
    UIManager:close(self, "ui")
end

function MenuScreen:onHold(_, ges)
    local i = ML.hit(self.layout, ges.pos.x, ges.pos.y)
    local item = i and self.items[i]
    if item and item.on_long_hold then
        self._long_item = item
        UIManager:unschedule(self._long)
        UIManager:scheduleIn(4.5, self._long)
    end
    return true
end

function MenuScreen:onHoldRelease()
    self._long_item = nil
    UIManager:unschedule(self._long)
    return true
end

function MenuScreen:onTap(_, ges)
    if self.guard:ignore(socket.gettime()) then
        Debug.event(string.format("menu tap %d,%d IGNORED (open guard)", ges.pos.x, ges.pos.y))
        return true
    end
    local i = ML.hit(self.layout, ges.pos.x, ges.pos.y)
    local item = i and self.items[i]
    Debug.event(string.format("menu '%s' tap -> %s", tostring(self.title), item and item.text or "nothing"))
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

-- Previa de uma mesa de 4 no estilo da mesa em miniatura: tela em pe, um quadradinho por jogador.
local BLACK = Blitbuffer.COLOR_BLACK
local function mini_cell(bb, cx, cy, cw, ch, index, size)
    local r = { x = math.floor(cx - cw / 2), y = math.floor(cy - ch / 2), w = math.floor(cw), h = math.floor(ch) }
    Draw.border_round(bb, r, 3, BLACK, math.floor(ch * 0.18))
    Draw.text(bb, cx, cy, I18n.player(index), size, { bold = true })
end

local function paint_preview(bb, s, kind)
    Draw.border_round(bb, s, 4, BLACK, math.floor(s.w * 0.06))
    if kind == "rows" then
        local pad = math.floor(s.w * 0.07)
        for _, c in ipairs(Layout.seats(4, s.w - 2 * pad, s.h - 2 * pad, math.floor(s.h * 0.08))) do
            local r = { x = s.x + pad + c.x + 4, y = s.y + pad + c.y, w = c.w - 8, h = c.h }
            Draw.border_round(bb, r, 3, BLACK, math.floor(r.w * 0.12))
            Draw.text(bb, r.x + r.w / 2, r.y + r.h / 2, I18n.player(c.index), r.w * 0.3, { bold = true })
        end
        return
    end
    -- Um de cada lado: as diagonais, o botao redondo no meio e um quadradinho perto de cada borda.
    local t = 3
    for y = 0, s.h - 1 do
        local x = (y + 0.5) * s.w / s.h
        Draw.rect(bb, s.x + x - t / 2, s.y + y, t, 1, BLACK)
        Draw.rect(bb, s.x + s.w - x - t / 2, s.y + y, t, 1, BLACK)
    end
    local cx, cy = s.x + s.w / 2, s.y + s.h / 2
    local rr = s.w * 0.07
    Draw.ellipse(bb, cx, cy, rr, rr, BLACK)
    Draw.ellipse(bb, cx, cy, rr - t, rr - t, Blitbuffer.COLOR_WHITE)
    local cw, ch, size = s.w * 0.3, s.w * 0.17, s.w * 0.075
    mini_cell(bb, cx, s.y + s.h * 0.82, cw, ch, 1, size)
    mini_cell(bb, s.x + s.w * 0.16, cy, ch, cw, 2, size)
    mini_cell(bb, cx, s.y + s.h * 0.18, cw, ch, 3, size)
    mini_cell(bb, s.x + s.w * 0.84, cy, ch, cw, 4, size)
end

-- Botao de formato: duas metades com a previa e o nome; o ultimo usado com borda grossa e nome em negrito.
local function paint_format(bb, r, active)
    local gap = math.floor(r.w * 0.04)
    local half = math.floor((r.w - gap) / 2)
    for i, kind in ipairs({ "rows", "sides" }) do
        local box = { x = r.x + (i - 1) * (half + gap), y = r.y, w = half, h = r.h }
        local on = kind == active
        Draw.border_round(bb, box, on and 9 or 2, BLACK, math.floor(box.w * 0.06))
        local ph = math.floor(box.h * 0.74)
        local pw = math.min(math.floor(ph * 1072 / 1448), box.w - 40)
        ph = math.floor(pw * 1448 / 1072)
        local s = { x = box.x + math.floor((box.w - pw) / 2), y = box.y + math.floor(box.h * 0.05), w = pw, h = ph }
        paint_preview(bb, s, kind)
        Draw.text(bb, box.x + box.w / 2, s.y + s.h + math.floor((box.y + box.h - s.y - s.h) / 2), I18n.t("format_" .. kind),
            math.floor(box.h * 0.055), { bold = on })
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
        elseif item.kind == "format" then
            paint_format(bb, r, item.active)
        else
            Draw.box(bb, r, 3)
            Draw.centered(bb, r, item.text, 40)
        end
    end
    Debug.paint(bb, l.w, l.h)
    -- A trava conta a partir do fim da atualizacao do e-ink (que vem depois do desenho e,
    -- no Kindle, segura os toques na fila por ~0,4 s): o nextTick roda logo apos o refresh.
    if self.guard.waiting_paint then
        UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
    end
end

-- Eventos de energia espalhados pelo KOReader: so registram no modo debug (nao consomem).
function MenuScreen:onSuspend() Debug.broadcast("Suspend") end
function MenuScreen:onResume() Debug.broadcast("Resume") end
function MenuScreen:onOutOfScreenSaver() Debug.broadcast("OutOfScreenSaver") end
function MenuScreen:onCharging() Debug.broadcast("Charging") end
function MenuScreen:onNotCharging() Debug.broadcast("NotCharging") end

function MenuScreen:onCloseWidget()
    UIManager:unschedule(self._long)
end

return MenuScreen
