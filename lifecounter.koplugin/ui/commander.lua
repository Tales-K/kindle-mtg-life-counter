-- Tela de dano de comandante: uma linha por oponente (so KOReader).
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

local Commander = InputContainer:extend{ modal = true, name = "lifecounter_commander", rotation = 0 }

function Commander:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.guard = Guard.window(Tuning.OPEN_GUARD_S)
    self.guard:arm(socket.gettime())
    self.view_rows = View.rows(self.game, self.target)
    self.layout = View.layout(#self.view_rows, w, h)
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
    local row = self.view_rows[hit.row]
    local sign = hit.action == "plus" and 1 or -1
    if Actions.apply_commander(self.game, self.store, self.target, row.source, sign, big) then
        self.view_rows = View.rows(self.game, self.target)
        if self.bb then self.bb:free(); self.bb = nil end
        UIManager:setDirty(self, function() return Tuning.REFRESH_MODE, self.dimen end)
    end
end

function Commander:onTap(_, ges)
    if self.guard:ignore(socket.gettime()) then return true end
    self:_do(View.hit(self.layout, ges.pos.x, ges.pos.y, self.rotation), false)
    return true
end

function Commander:onHold(_, ges)
    if self.guard:ignore(socket.gettime()) then return true end
    local mode = Tuning.HOLD_MODE
    if mode == "buttons" then return true end
    local hit = View.hit(self.layout, ges.pos.x, ges.pos.y, self.rotation)
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

function Commander:_render()
    local l = self.layout
    local bb = Blitbuffer.new(l.w, l.h, Screen.bb:getType())
    bb:fill(Blitbuffer.COLOR_WHITE)
    Draw.centered(bb, l.header, "Dano de comandante em J" .. self.target, 40, true)
    for i, row in ipairs(self.view_rows) do
        local r = l.rows[i]
        Draw.box(bb, r.minus); Draw.box(bb, r.value); Draw.box(bb, r.plus)
        Draw.centered(bb, r.minus, "\u{2212}", 120)
        Draw.centered(bb, r.plus, "+", 120)
        Draw.centered(bb, { x = r.value.x, y = r.value.y, w = r.value.w, h = math.floor(r.value.h * 0.3) }, "de J" .. row.source, 28)
        local num = { x = r.value.x, y = r.value.y + math.floor(r.value.h * 0.3), w = r.value.w, h = r.value.h - math.floor(r.value.h * 0.3) }
        Draw.centered(bb, num, tostring(row.damage) .. (row.lethal and "  LETAL" or ""), 90, true)
        if row.lethal then Draw.box(bb, r.value, 8) end
    end
    Draw.box(bb, l.back)
    Draw.centered(bb, l.back, "Voltar", 40, true)
    if self.rotation == 180 then
        local rot = bb:rotatedCopy(180)
        bb:free()
        bb = rot
    end
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
