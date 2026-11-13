-- Campo unico (so KOReader): a tela toda com um so numero do dono do painel, o dano de comandante
-- recebido de um oponente ou o veneno, com metades -/+ como no painel e um botao OK para voltar.
-- Fica virado para o dono (girado 180 se ele esta na fileira de cima). Geometria em core/field_view.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Actions = require("core.actions")
local Debug = require("ui/debug")
local Delta = require("core.delta")
local HoldRepeat = require("core.hold_repeat")
local Layout = require("core.layout")
local Sides = require("core.sides")
local View = require("core.field_view")
local Draw = require("ui/draw")
local I18n = require("core.i18n")
local Guard = require("core.input_guard")
local Tuning = require("core.tuning")
local socket = require("socket")
local Screen = Device.screen

local BLACK, WHITE = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE

local function repeater(fire)
    return HoldRepeat.new{
        interval = Tuning.HOLD_REPEAT_S, max = Tuning.HOLD_REPEAT_MAX, fire = fire,
        schedule = function(d, cb) UIManager:scheduleIn(d, cb) end,
        unschedule = function(cb) UIManager:unschedule(cb) end,
    }
end

local Field = InputContainer:extend{ modal = true, covers_fullscreen = true, name = "lifecounter_field" }

function Field:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.layout = View.layout(w, h, self.rotation)
    self.deltas = self.deltas or Delta.new(Tuning.DELTA_S)
    -- Segurando o -/+ do dano de comandante: repete o +-10 ate soltar.
    self.repeat_hold = repeater(function(action)
        if self.closed then return end
        if self.on_activity then self.on_activity() end
        self:_do(action, true)
    end)
    self.key = View.delta_key(self.owner, self.field)
    -- Quando o "-6" deve sumir: redesenha o campo se ele estiver na tela.
    self._expire = function()
        if self.closed or not Draw.on_top(UIManager, self) then return end
        if self:_delta(socket.gettime()) ~= self.drawn_delta then
            UIManager:setDirty(self, function() return Tuning.REFRESH_MODE, self.dimen end)
        end
    end
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
        HoldRelease = { GestureRange:new{ ges = "hold_release", range = self.dimen } },
    }
end

function Field:_do(action, big)
    if action == "ok" then
        if not big and self.on_close then self.on_close() end
        return
    end
    local p = self.game.players[self.owner]
    local value, life = View.value(self.game, self.owner, self.field), p.life
    if Actions.on_field(self.game, self.store, self.owner, self.field, action, big) then
        -- O dano de comandante tambem mexe na vida: a tela de jogo mostra quanto, se ainda der tempo.
        local now = socket.gettime()
        self.deltas:add(self.key, View.value(self.game, self.owner, self.field) - value, now)
        self.deltas:add(View.life_key(self.owner), p.life - life, now)
        if self.bb then self.bb:free(); self.bb = nil end
        UIManager:setDirty(self, function() return Tuning.REFRESH_MODE, self.dimen end)
    end
end

function Field:onTap(_, ges)
    self.repeat_hold:stop()
    if self.on_activity then self.on_activity() end
    if self.guard:ignore(socket.gettime()) then
        Debug.event(string.format("field tap %d,%d IGNORED (open guard)", ges.pos.x, ges.pos.y))
        return true
    end
    Debug.event(string.format("field tap %d,%d -> %s", ges.pos.x, ges.pos.y, tostring(View.hit(self.layout, ges.pos.x, ges.pos.y))))
    self:_do(View.hit(self.layout, ges.pos.x, ges.pos.y), false)
    return true
end

function Field:onHold(_, ges)
    if self.on_activity then self.on_activity() end
    if self.guard:ignore(socket.gettime()) then return true end
    local mode = Tuning.HOLD_MODE
    if mode == "buttons" then return true end
    local action = View.hit(self.layout, ges.pos.x, ges.pos.y)
    if action == "minus" or action == "plus" then
        if mode == "hold" then
            self:_do(action, true)
            if self.field.kind == "commander" then self.repeat_hold:start(action) end
        else
            self.pending = action
        end
    end
    return true
end

function Field:onHoldRelease()
    self.repeat_hold:stop()
    local action = self.pending
    self.pending = nil
    if action then self:_do(action, true) end
    return true
end

-- Miniatura da mesa no cabecalho: o quadrado do oponente em preto, o do dono marcado "you"/"você".
function Field:_mini(bb)
    local l, k = self.layout, self.layout.k
    local m = l.mini
    if self.field.kind == "poison" then
        Draw.drop(bb, m.x + m.w / 2, m.y + m.h / 2, m.h * 0.8, BLACK)
        return
    end
    local inset, radius = math.floor(4 * k + 0.5), math.floor(10 * k + 0.5)
    local cells = self.game.seating == "sides" and Sides.minimap(self.owner, m.w, m.h)
        or Layout.minimap(self.game.player_count, l.rotation, m.w, m.h)
    for _, c in ipairs(cells) do
        local r = { x = m.x + c.x + inset, y = m.y + c.y, w = c.w - 2 * inset, h = c.h }
        local cx, cy = r.x + r.w / 2, r.y + r.h / 2
        local size = math.min(30 * k, r.h * 0.45, r.w * 0.28)
        if c.index == self.field.source then
            Draw.fill_round(bb, r, BLACK, radius)
            Draw.text(bb, cx, cy, I18n.player(c.index), size * 1.2, { bold = true, color = WHITE })
        elseif c.index == self.owner then
            Draw.border_round(bb, r, math.max(3, math.floor(6 * k + 0.5)), BLACK, radius)
            Draw.text(bb, cx, cy, I18n.t("you"), size, { bold = true })
        else
            Draw.border_round(bb, r, math.max(1, math.floor(2 * k + 0.5)), BLACK, radius)
            Draw.text(bb, cx, cy, I18n.player(c.index), size)
        end
    end
end

-- Tela "em pe" (virada para o dono).
function Field:_render_upright()
    local l, k = self.layout, self.layout.k
    local bb = Blitbuffer.new(l.w, l.h, Screen.bb:getType())
    bb:fill(WHITE)
    local t = l.title
    Draw.text(bb, l.w / 2, t.cy, View.title(self.owner, self.field), t.size, { bold = true })
    Draw.text(bb, l.w / 2, t.sub_cy, View.hint(self.field), t.sub_size)
    self:_mini(bb)

    local f = l.field
    local lw = math.max(3, math.floor(7 * k + 0.5))
    Draw.border_round(bb, f, lw, BLACK, math.floor(26 * k))
    local cy = f.y + f.h / 2 - 30 * k
    local gdx, gs = 90 * k, 80 * k
    Draw.minus(bb, f.x + gdx, cy, gs)
    Draw.plus(bb, f.x + f.w - gdx, cy, gs)
    local v = tostring(View.value(self.game, self.owner, self.field))
    local px = Draw.fit_px(#v > 1 and v or "00", f.w - 2 * (gdx + gs), f.h * 0.6, true)
    Draw.text(bb, l.w / 2, cy, v, px, { bold = true })
    if self.drawn_delta then
        local size = math.floor(56 * k + 0.5)
        Draw.text(bb, l.w / 2, Delta.place(cy, px, size, f.y + math.floor(50 * k), Draw.CAP), self.drawn_delta, size, { bold = true })
    end
    local note = View.reminder(self.field)
    if self.game:status(self.owner) then note = note .. " · " .. View.out_note(self.owner) end
    Draw.text(bb, l.w / 2, f.y + f.h - 80 * k, note, 44 * k, { bold = self.game:status(self.owner) ~= nil })

    local b = l.button
    Draw.fill_round(bb, b, BLACK, math.floor(26 * k))
    Draw.text(bb, b.x + b.w / 2, b.y + b.h / 2, I18n.t("field_ok"), 56 * k, { bold = true, color = WHITE })
    return bb
end

function Field:_render()
    return Draw.orient(self:_render_upright(), self.layout.rotation)
end

function Field:_delta(now)
    return Delta.text(self.deltas:get(self.key, now))
end

function Field:paintTo(bb, x, y)
    local now = socket.gettime()
    local delta = self:_delta(now)
    if self.bb and delta ~= self.drawn_delta then self.bb:free(); self.bb = nil end
    if not self.bb then
        self.drawn_delta = delta
        self.bb = self:_render()
    end
    UIManager:unschedule(self._expire)
    local soon = self.deltas:next_expiry(now)
    if soon then UIManager:scheduleIn(math.max(0.05, soon - now + 0.05), self._expire) end
    bb:blitFrom(self.bb, 0, 0, 0, 0, self.dimen.w, self.dimen.h)
    Debug.paint(bb, self.dimen.w, self.dimen.h)
    -- A trava conta a partir do fim da atualizacao do e-ink (que vem depois do desenho e,
    -- no Kindle, segura os toques na fila por ~0,4 s): o nextTick roda logo apos o refresh.
    if self.guard.waiting_paint then
        UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
    end
end


-- Eventos de energia espalhados pelo KOReader: so registram no modo debug (nao consomem).
function Field:onSuspend() Debug.broadcast("Suspend") end
function Field:onResume() Debug.broadcast("Resume") end
function Field:onOutOfScreenSaver() Debug.broadcast("OutOfScreenSaver") end
function Field:onCharging() Debug.broadcast("Charging") end
function Field:onNotCharging() Debug.broadcast("NotCharging") end

function Field:onCloseWidget()
    self.closed = true
    self.repeat_hold:stop()
    UIManager:unschedule(self._expire)
    if self.bb then self.bb:free(); self.bb = nil end
end

return Field
