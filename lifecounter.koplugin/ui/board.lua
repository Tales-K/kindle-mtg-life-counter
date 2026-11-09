-- Tela de jogo: um painel por jogador, gestos de toque e segurar (so KOReader).
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Actions = require("core.actions")
local Layout = require("core.layout")
local Panel = require("ui/panel")
local Draw = require("ui/draw")
local Guard = require("core.input_guard")
local Tuning = require("core.tuning")
local socket = require("socket")
local Screen = Device.screen

local Board = InputContainer:extend{ modal = true, name = "lifecounter_board" }

function Board:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.layout = Layout.compute(self.game.player_count, w, h)
    self.cache = {}
    self.changes = 0
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
        HoldRelease = { GestureRange:new{ ges = "hold_release", range = self.dimen } },
    }
end

-- Chamado quando a tela volta a ficar por cima (ex.: depois de fechar a de comandante).
function Board:rearm()
    self.guard:arm(socket.gettime())
end

function Board:_ignored()
    return self.guard:ignore(socket.gettime())
end

function Board:_in_center(pos)
    local c = self.layout.center
    return pos.x >= c.x and pos.x < c.x + c.w and pos.y >= c.y and pos.y < c.y + c.h
end

function Board:_panel(index)
    for _, p in ipairs(self.layout.panels) do if p.index == index then return p end end
end

function Board:_act(index, zone, big, rotation)
    local result = Actions.on_panel(self.game, self.store, index, zone, big)
    if result == "open" then
        if self.on_commander then self.on_commander(index, rotation) end
        return
    end
    if result ~= "changed" then return end
    self.changes = self.changes + 1
    local p = self:_panel(index)
    local region = Geom:new{ x = p.x, y = p.y, w = p.w, h = p.h }
    UIManager:setDirty(self, function() return Tuning.REFRESH_MODE, region end)
    if self.changes % Tuning.FULL_REFRESH_EVERY == 0 then UIManager:setDirty(self, "full") end
end

function Board:onTap(_, ges)
    if self:_ignored() then return true end
    local pos = ges.pos
    local hit = Layout.hit(self.layout, pos.x, pos.y)
    if not hit then
        if self:_in_center(pos) and self.on_menu then self.on_menu() end
        return true
    end
    local zone = Layout.zone_at(hit.panel.w, hit.panel.h, hit.lx, hit.ly)
    self:_act(hit.index, zone, false, hit.panel.rotation)
    return true
end

function Board:onHold(_, ges)
    if self:_ignored() then return true end
    local mode = Tuning.HOLD_MODE
    if mode == "buttons" then return true end
    local hit = Layout.hit(self.layout, ges.pos.x, ges.pos.y)
    if not hit then return true end
    local zone = Layout.zone_at(hit.panel.w, hit.panel.h, hit.lx, hit.ly)
    if mode == "hold" then
        self:_act(hit.index, zone, true)
    else
        self.pending_hold = { index = hit.index, zone = zone }
    end
    return true
end

function Board:onHoldRelease()
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

function Board:paintTo(bb, x, y)
    bb:paintRect(0, 0, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    for _, p in ipairs(self.layout.panels) do
        local key = status_key(self.game.players[p.index], self.game:status(p.index))
        local entry = self.cache[p.index]
        if not entry or entry.key ~= key then
            if entry then entry.bb:free() end
            entry = { key = key, bb = Panel.render_oriented(self.game, p.index, p.w, p.h, p.rotation) }
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
    Draw.text(bb, c.x + c.w / 2, c.y + c.h / 2, "MENU", 36 * k, { bold = true })
    -- A trava conta a partir do fim da atualizacao do e-ink (que vem depois do desenho e,
    -- no Kindle, segura os toques na fila por ~0,4 s): o nextTick roda logo apos o refresh.
    if self.guard.waiting_paint then
        UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
    end
end

function Board:onCloseWidget()
    for _, e in pairs(self.cache) do e.bb:free() end
    self.cache = {}
end

return Board
