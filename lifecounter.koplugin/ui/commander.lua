-- Tela de dano de comandante no visual A2 (so KOReader): a mesa em tela cheia, um quadrado por
-- jogador no lugar dele (fileira de cima girada 180). No quadrado de cada oponente, o dano que ele
-- causou ao alvo (metade esquerda tira, direita soma). Faixa do meio virada para o alvo: Voltar e veneno.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Actions = require("core.actions")
local View = require("core.commander_view")
local Draw = require("ui/draw")
local Guard = require("core.input_guard")
local Tuning = require("core.tuning")
local socket = require("socket")
local Screen = Device.screen

local BLACK, WHITE = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE

local Commander = InputContainer:extend{ modal = true, covers_fullscreen = true, name = "lifecounter_commander" }

function Commander:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.layout = View.layout(self.game.player_count, self.target, w, h)
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
        HoldRelease = { GestureRange:new{ ges = "hold_release", range = self.dimen } },
    }
end

function Commander:_do(hit, big)
    if not hit then return end
    if hit.action == "back" then
        if self.on_close then self.on_close() end
        return
    end
    if Actions.on_commander(self.game, self.store, self.target, hit, big) then
        if self.bb then self.bb:free(); self.bb = nil end
        UIManager:setDirty(self, function() return Tuning.REFRESH_MODE, self.dimen end)
    end
end

function Commander:onTap(_, ges)
    if self.on_activity then self.on_activity() end
    if self.guard:ignore(socket.gettime()) then return true end
    self:_do(View.hit(self.layout, ges.pos.x, ges.pos.y), false)
    return true
end

function Commander:onHold(_, ges)
    if self.on_activity then self.on_activity() end
    if self.guard:ignore(socket.gettime()) then return true end
    local mode = Tuning.HOLD_MODE
    if mode == "buttons" then return true end
    local hit = View.hit(self.layout, ges.pos.x, ges.pos.y)
    if hit and hit.action ~= "back" then
        if mode == "hold" then self:_do(hit, true) else self.pending = hit end
    end
    return true
end

function Commander:onHoldRelease()
    local hit = self.pending
    self.pending = nil
    if hit then self:_do(hit, true) end
    return true
end

local function oriented(bb, rotation)
    if rotation ~= 180 then return bb end
    local rot = bb:rotatedCopy(180)
    bb:free()
    return rot
end

-- Quadrado "em pe" (sw x sh) de um jogador. Proporcoes do mockup (quadrado de 559 px de altura).
function Commander:_square(index, sw, sh)
    local bb = Blitbuffer.new(sw, sh, Screen.bb:getType())
    bb:fill(WHITE)
    local k = sh / 559
    local m = math.floor(10 * k + 0.5)
    local r = { x = m, y = m, w = sw - 2 * m - 1, h = sh - 2 * m - 1 }
    local cx, cy = sw / 2, sh / 2
    if index == self.target then
        Draw.fill_round(bb, r, BLACK, math.floor(26 * k))
        Draw.text(bb, cx, cy - 40 * k, "VOCÊ", (sw > 400 * k and 84 or 64) * k, { bold = true, color = WHITE })
        Draw.text(bb, cx, cy + 50 * k, "J" .. index, 52 * k, { bold = true, color = WHITE })
        return bb
    end
    Draw.border_round(bb, r, math.max(3, math.floor(8 * k + 0.5)), BLACK, math.floor(26 * k))
    Draw.text(bb, cx, 62 * k, "de J" .. index, 50 * k, { bold = true })
    local v = tostring(self.game.players[self.target].cmd[index] or 0)
    local narrow = sw < 400 * k
    local ny = cy + 20 * k
    local px = Draw.fit_px(#v > 1 and v or "00", sw - (narrow and 160 or 250) * k, sh - 210 * k, true)
    Draw.text(bb, cx, ny, v, px, { bold = true })
    local gx, gs = 62 * k, 56 * k
    if narrow then gx, gs = 42 * k, 40 * k end
    Draw.minus(bb, gx, ny, gs)
    Draw.plus(bb, sw - gx, ny, gs)
    Draw.text(bb, cx, sh - 50 * k, "de 21", 32 * k)
    return bb
end

-- Faixa do meio "em pe" (virada para o alvo). Proporcoes do mockup (1072 x 330).
function Commander:_band()
    local l = self.layout
    local b, c, kx, ky = l.band, l.controls, l.kx, l.ky
    local k = math.min(kx, ky)
    local bb = Blitbuffer.new(b.w, b.h, Screen.bb:getType())
    bb:fill(WHITE)
    local lw = math.max(3, math.floor(6 * ky + 0.5))
    bb:paintRect(0, 0, b.w, lw, BLACK)
    bb:paintRect(0, b.h - lw - 1, b.w, lw, BLACK)
    local function button(r)
        Draw.border_round(bb, r, lw, BLACK, math.floor(18 * k))
        return r.x + r.w / 2, r.y + r.h / 2
    end
    local bx, by = button(c.back)
    Draw.text(bb, bx, by, "\u{2039} Voltar", 46 * k, { bold = true })
    Draw.text(bb, 320 * kx, 62 * ky, "Comandante em J" .. self.target, 46 * k, { bold = true, align = "left" })
    Draw.text(bb, 320 * kx, 116 * ky, "toque em quem causou o dano \u{00B7} segurar = 10", 28 * k, { align = "left" })
    Draw.rect(bb, 24 * kx, 166 * ky - 1, b.w - 48 * kx, math.max(2, 3 * ky), BLACK)
    local yc = (166 + (330 - 166) / 2) * ky
    Draw.drop(bb, 60 * kx, yc, 54 * k, BLACK)
    Draw.text(bb, 100 * kx, yc - 16 * ky, "VENENO", 44 * k, { bold = true, align = "left" })
    Draw.text(bb, 100 * kx, yc + 30 * ky, "fora com 10", 26 * k, { align = "left" })
    local mx, my = button(c.poison_minus)
    Draw.minus(bb, mx, my, 64 * k)
    local px, py = button(c.poison_plus)
    Draw.plus(bb, px, py, 64 * k)
    local vx = (c.poison_minus.x + c.poison_minus.w + c.poison_plus.x) / 2
    Draw.text(bb, vx, yc, tostring(self.game.players[self.target].poison), 110 * k, { bold = true })
    return bb
end

function Commander:_render()
    local l = self.layout
    local bb = Blitbuffer.new(l.w, l.h, Screen.bb:getType())
    bb:fill(WHITE)
    for _, cell in ipairs(l.cells) do
        local sq = oriented(self:_square(cell.index, cell.w, cell.h), cell.rotation)
        bb:blitFrom(sq, cell.x, cell.y, 0, 0, cell.w, cell.h)
        sq:free()
    end
    local band = oriented(self:_band(), l.band.rotation)
    bb:blitFrom(band, l.band.x, l.band.y, 0, 0, l.band.w, l.band.h)
    band:free()
    return bb
end

function Commander:paintTo(bb, x, y)
    if not self.bb then self.bb = self:_render() end
    bb:blitFrom(self.bb, 0, 0, 0, 0, self.dimen.w, self.dimen.h)
    -- A trava conta a partir do fim da atualizacao do e-ink (que vem depois do desenho e,
    -- no Kindle, segura os toques na fila por ~0,4 s): o nextTick roda logo apos o refresh.
    if self.guard.waiting_paint then
        UIManager:nextTick(function() self.guard:painted(socket.gettime()) end)
    end
end

function Commander:onCloseWidget()
    if self.bb then self.bb:free(); self.bb = nil end
end

return Commander
