-- Tela de jogo: um painel por jogador, gestos de toque e segurar (so KOReader).
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Actions = require("core.actions")
local Debug = require("ui/debug")
local Delta = require("core.delta")
local Starter = require("core.starter")
local HoldRepeat = require("core.hold_repeat")
local View = require("core.field_view")
local Layout = require("core.layout")
local Panel = require("ui/panel")
local SidePanel = require("ui/side_panel")
local Sides = require("core.sides")
local Draw = require("ui/draw")
local I18n = require("core.i18n")
local Guard = require("core.input_guard")
local Tuning = require("core.tuning")
local socket = require("socket")
local Screen = Device.screen

local function repeater(fire)
    return HoldRepeat.new{
        interval = Tuning.HOLD_REPEAT_S, max = Tuning.HOLD_REPEAT_MAX, fire = fire,
        schedule = function(d, cb) UIManager:scheduleIn(d, cb) end,
        unschedule = function(cb) UIManager:unschedule(cb) end,
    }
end

local Board = InputContainer:extend{ modal = true, covers_fullscreen = true, name = "lifecounter_board" }

function Board:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    -- Mesa "um de cada lado" (4 triangulos, core/sides) ou duas fileiras (core/layout).
    self.sides = self.game.seating == "sides"
    self.layout = self.sides and Sides.compute(w, h) or Layout.compute(self.game.player_count, w, h)
    self.cache = {}
    self.changes = 0
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.deltas = self.deltas or Delta.new(Tuning.DELTA_S)
    -- Segurando o -/+: depois do primeiro +-10, repete ate soltar (cada passo so atualiza o painel).
    self.repeat_hold = repeater(function(a)
        if self.closed then return end
        if self.on_activity then self.on_activity() end
        self:_act(a.index, a.zone, true)
    end)
    -- Quando um "-6" deve sumir: redesenha so os paineis cujo desenho mudou.
    self._expire = function()
        if self.closed or not Draw.on_top(UIManager, self) then return end
        local now = socket.gettime()
        for _, p in ipairs(self.layout.panels) do
            local entry = self.cache[p.index]
            if entry and entry.key ~= self:_key(p.index, now) then
                UIManager:setDirty(self, function() return Tuning.REFRESH_MODE, Geom:new{ x = p.x, y = p.y, w = p.w, h = p.h } end)
            end
        end
        self:_schedule_expiry(now)
    end
    self._dice_off = function()
        self.dice = nil
        self:_dirty("ui", self:_dice_rect())
    end
    self._starter_off = function() self:_clear_starter() end
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
        HoldRelease = { GestureRange:new{ ges = "hold_release", range = self.dimen } },
    }
end

-- Chamado quando a tela volta a ficar por cima (ex.: depois de fechar o campo unico).
function Board:rearm()
    self.guard:arm(socket.gettime())
end

function Board:_ignored()
    return self.guard:ignore(socket.gettime())
end

function Board:_in_center(pos)
    if self.sides then return Sides.in_menu(self.layout, pos.x, pos.y) end
    local c = self.layout.center
    return pos.x >= c.x and pos.x < c.x + c.w and pos.y >= c.y and pos.y < c.y + c.h
end

function Board:_panel(index)
    for _, p in ipairs(self.layout.panels) do if p.index == index then return p end end
end

function Board:_act(index, zone, big, rotation)
    local before = self.game.players[index] and self.game.players[index].life
    local result, field = Actions.on_panel(self.game, self.store, index, zone, big)
    if result == "open" then
        if self.on_open then self.on_open(index, rotation, field) end
        return
    end
    if result ~= "changed" then return end
    self.deltas:add(View.life_key(index), self.game.players[index].life - before, socket.gettime())
    self:_clear_starter() -- a partida comecou: some a etiqueta "comeca"
    self.changes = self.changes + 1
    local p = self:_panel(index)
    local region = Geom:new{ x = p.x, y = p.y, w = p.w, h = p.h }
    UIManager:setDirty(self, function() return Tuning.REFRESH_MODE, region end)
    if self.changes % Tuning.FULL_REFRESH_EVERY == 0 then UIManager:setDirty(self, "full") end
end

function Board:_hit(x, y)
    if self.sides then return Sides.hit(self.layout, x, y) end
    return Layout.hit(self.layout, x, y)
end

function Board:_zone(hit)
    local p = hit.panel
    if self.sides then return Sides.zone_at(p.uw, p.uh, hit.index, hit.lx, hit.ly) end
    return Layout.zone_at(p.w, p.h, self.game.player_count, p.rotation, hit.index, hit.lx, hit.ly)
end

function Board:onTap(_, ges)
    self.repeat_hold:stop() -- qualquer toque novo encerra uma repeticao que tenha ficado ligada
    if self.on_activity then self.on_activity() end
    local pos = ges.pos
    if self:_ignored() then
        Debug.event(string.format("tap %d,%d IGNORED (open guard)", pos.x, pos.y))
        return true
    end
    local hit = self:_hit(pos.x, pos.y)
    if Debug.enabled then
        local z = hit and self:_zone(hit)
        Debug.event(string.format("tap %d,%d -> %s", pos.x, pos.y, hit and ("P" .. hit.index .. " " .. tostring(z and z.zone)) or "center/menu"))
    end
    if not hit then
        if self:_in_center(pos) and self.on_menu then self.on_menu() end
        return true
    end
    self:_act(hit.index, self:_zone(hit), false, hit.panel.rotation)
    return true
end

function Board:onHold(_, ges)
    if self.on_activity then self.on_activity() end
    if self:_ignored() then return true end
    local mode = Tuning.HOLD_MODE
    if mode == "buttons" then return true end
    local hit = self:_hit(ges.pos.x, ges.pos.y)
    if not hit then return true end
    local zone = self:_zone(hit)
    Debug.event(string.format("hold P%d %s", hit.index, tostring(zone and zone.zone)))
    if mode == "hold" then
        self:_act(hit.index, zone, true)
        if zone and (zone.zone == "plus" or zone.zone == "minus") then
            self.repeat_hold:start({ index = hit.index, zone = zone })
        end
    else
        self.pending_hold = { index = hit.index, zone = zone }
    end
    return true
end

function Board:onHoldRelease()
    if self.repeat_hold.action ~= nil then Debug.event("hold released (repeat stopped)") end
    self.repeat_hold:stop()
    local p = self.pending_hold
    self.pending_hold = nil
    if p then self:_act(p.index, p.zone, true) end
    return true
end

local function status_key(player, status)
    local cmd = {}
    for src, d in pairs(player.cmd) do cmd[#cmd + 1] = src .. ":" .. d end
    table.sort(cmd)
    return table.concat({ player.life, player.poison, status or "-", table.concat(cmd, ",") }, "|")
end

function Board:_delta(index, now)
    return Delta.text(self.deltas:get(View.life_key(index), now))
end

function Board:_key(index, now)
    return status_key(self.game.players[index], self.game:status(index)) .. "|" .. (self:_delta(index, now) or "")
        .. (self.starter == index and "|S" or "")
end

-- Marca a regiao para redesenhar se a tela estiver visivel (se nao, ao voltar para cima ela e
-- redesenhada inteira de qualquer jeito).
function Board:_dirty(mode, r)
    if self.closed or not Draw.on_top(UIManager, self) then return end
    local region = Geom:new{ x = r.x, y = r.y, w = r.w, h = r.h }
    UIManager:setDirty(self, function() return mode, region end)
end

-- Quadrado do sorteio no centro da tela.
function Board:_dice_rect()
    local s = math.floor(240 * self.dimen.w / 1072)
    return { x = math.floor((self.dimen.w - s) / 2), y = math.floor((self.dimen.h - s) / 2), w = s, h = s }
end

function Board:_clear_starter()
    if not self.starter then return end
    local p = self:_panel(self.starter)
    self.starter = nil
    UIManager:unschedule(self._starter_off)
    if p then self:_dirty(Tuning.REFRESH_MODE, p) end
end

-- "Quem comeca?": poucos quadros com o numero trocando no centro (so aquele quadrado e
-- atualizado), depois o resultado fica alguns segundos e o painel sorteado ganha a etiqueta
-- "P3 comeca", virada para o jogador.
function Board:roll_starter()
    if self.rolling or self.closed then return end
    self.rolling = true
    self:_clear_starter()
    if not Board.seeded then math.randomseed(math.floor(socket.gettime() * 1000) % 2147483647); Board.seeded = true end
    local r = Starter.roll(self.game.player_count, math.random, Tuning.STARTER_FRAMES)
    local rect = self:_dice_rect()
    UIManager:unschedule(self._dice_off)
    for i, v in ipairs(r.frames) do
        UIManager:scheduleIn((i - 1) * Tuning.STARTER_FRAME_S, function()
            if self.closed then return end
            local last = i == #r.frames
            self.dice = { value = v, final = last }
            self:_dirty(Tuning.REFRESH_MODE, rect)
            if not last then return end
            self.rolling = false
            self.starter = r.result
            self:_dirty("ui", self:_panel(r.result))
            UIManager:scheduleIn(Tuning.DICE_HOLD_S, self._dice_off)
            UIManager:unschedule(self._starter_off)
            UIManager:scheduleIn(Tuning.STARTER_SHOW_S, self._starter_off)
        end)
    end
end

function Board:_paint_dice(bb)
    local d = self.dice
    if not d then return end
    local r = self:_dice_rect()
    local k = r.w / 240
    local fg, bg = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE
    if d.final then fg, bg = bg, fg end
    Draw.fill_round(bb, r, Blitbuffer.COLOR_BLACK, math.floor(30 * k))
    local inner = { x = r.x + math.floor(8 * k), y = r.y + math.floor(8 * k), w = r.w - math.floor(16 * k), h = r.h - math.floor(16 * k) }
    Draw.fill_round(bb, inner, bg, math.floor(24 * k))
    Draw.text(bb, r.x + r.w / 2, r.y + r.h / 2, I18n.player(d.value), 110 * k, { bold = true, color = fg })
end

function Board:_schedule_expiry(now)
    UIManager:unschedule(self._expire)
    local soon = self.deltas:next_expiry(now)
    if soon then UIManager:scheduleIn(math.max(0.05, soon - now + 0.05), self._expire) end
end

-- Mesa "um de cada lado": os triangulos vao para uma tela pronta (composite), linha a linha, so a
-- parte de cada linha que e do triangulo; so os que mudaram sao refeitos.
function Board:_paint_sides(bb, now)
    local l = self.layout
    if not self.composite then
        self.composite = Blitbuffer.new(l.w, l.h, Screen.bb:getType())
        self.composite:fill(Blitbuffer.COLOR_WHITE)
    end
    local changed = false
    for _, p in ipairs(l.panels) do
        local key = self:_key(p.index, now)
        local entry = self.cache[p.index]
        if not entry or entry.key ~= key then
            local pb = SidePanel.render_oriented(self.game, p, self:_delta(p.index, now), self.starter == p.index)
            for row = p.y, p.y + p.h - 1 do
                local s = Sides.span(l, p, row)
                if s then self.composite:blitFrom(pb, s[1], row, s[1] - p.x, row - p.y, s[2] - s[1], 1) end
            end
            pb:free()
            self.cache[p.index] = { key = key }
            changed = true
        end
    end
    if changed then SidePanel.decorate(self.composite, l) end
    bb:blitFrom(self.composite, 0, 0, 0, 0, l.w, l.h)
end

function Board:paintTo(bb, x, y)
    local now = socket.gettime()
    Debug.paints = Debug.paints + 1
    if self.sides then
        self:_paint_sides(bb, now)
        self:_paint_dice(bb)
        Debug.paint(bb, self.dimen.w, self.dimen.h)
        self:_schedule_expiry(now)
        if self.guard.waiting_paint then
            UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
        end
        return
    end
    bb:paintRect(0, 0, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    for _, p in ipairs(self.layout.panels) do
        local key = self:_key(p.index, now)
        local entry = self.cache[p.index]
        if not entry or entry.key ~= key then
            if entry then entry.bb:free() end
            entry = { key = key, bb = Panel.render_oriented(self.game, p.index, p.w, p.h, p.rotation, self:_delta(p.index, now), self.starter == p.index) }
            self.cache[p.index] = entry
        end
        bb:blitFrom(entry.bb, p.x, p.y, 0, 0, p.w, p.h)
    end
    local c = self.layout.center
    -- Barra central do mockup A2: duas linhas e o botao MENU (o toque vale na barra toda).
    local k = c.h / 86
    local lw = math.max(2, math.floor(4 * k + 0.5))
    bb:paintRect(c.x, c.y, c.w, lw, Blitbuffer.COLOR_BLACK)
    bb:paintRect(c.x, c.y + c.h - lw - 1, c.w, lw, Blitbuffer.COLOR_BLACK)
    local bw, pad = math.floor(220 * k), math.floor(10 * k)
    local button = { x = c.x + math.floor((c.w - bw) / 2), y = c.y + pad, w = bw, h = c.h - 2 * pad }
    Draw.border_round(bb, button, lw, Blitbuffer.COLOR_BLACK, math.floor(14 * k))
    Draw.text(bb, c.x + c.w / 2, c.y + c.h / 2, I18n.t("menu_button"), 36 * k, { bold = true })
    self:_paint_dice(bb)
    Debug.paint(bb, self.dimen.w, self.dimen.h)
    self:_schedule_expiry(now)
    -- A trava conta a partir do fim da atualizacao do e-ink (que vem depois do desenho e,
    -- no Kindle, segura os toques na fila por ~0,4 s): o nextTick roda logo apos o refresh.
    if self.guard.waiting_paint then
        UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
    end
end


-- Eventos de energia espalhados pelo KOReader: so registram no modo debug (nao consomem).
function Board:onSuspend() Debug.broadcast("Suspend") end
function Board:onResume() Debug.broadcast("Resume") end
function Board:onOutOfScreenSaver() Debug.broadcast("OutOfScreenSaver") end
function Board:onCharging() Debug.broadcast("Charging") end
function Board:onNotCharging() Debug.broadcast("NotCharging") end

function Board:onCloseWidget()
    self.closed = true
    self.repeat_hold:stop()
    UIManager:unschedule(self._dice_off)
    UIManager:unschedule(self._starter_off)
    UIManager:unschedule(self._expire)
    for _, e in pairs(self.cache) do if e.bb then e.bb:free() end end
    self.cache = {}
    if self.composite then self.composite:free(); self.composite = nil end
end

return Board
