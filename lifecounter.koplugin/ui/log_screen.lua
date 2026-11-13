-- Log de debug em tela cheia (so KOReader): as ultimas linhas do registro; um toque fecha.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Draw = require("ui/draw")
local Screen = Device.screen

local LogScreen = InputContainer:extend{ modal = true, covers_fullscreen = true, name = "lifecounter_log" }

function LogScreen:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.ges_events = { Tap = { GestureRange:new{ ges = "tap", range = self.dimen } } }
end

function LogScreen:onTap()
    UIManager:close(self, "ui")
    return true
end

function LogScreen:paintTo(bb, x, y)
    local w, h = self.dimen.w, self.dimen.h
    bb:paintRect(0, 0, w, h, Blitbuffer.COLOR_WHITE)
    local k = h / 1448
    local px, lh = math.floor(18 * k), math.floor(31 * k)
    Draw.text(bb, w / 2, math.floor(30 * k), "lifecounter_debug.log", math.floor(26 * k), { bold = true })
    local y0 = math.floor(70 * k)
    for i, l in ipairs(self.lines or {}) do
        if #l > 100 then l = l:sub(1, 100) end
        Draw.text(bb, 10, y0 + (i - 1) * lh, l, px, { align = "left" })
    end
    require("ui/debug").paint(bb, w, h)
end

return LogScreen
