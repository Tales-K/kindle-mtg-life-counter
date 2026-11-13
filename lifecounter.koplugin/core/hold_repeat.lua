-- Segurar continua somando: depois do primeiro +-10 (aplicado por quem chama), enquanto o dedo
-- segue na tela, `fire(action)` roda de novo a cada `interval` segundos, ate o soltar (stop) ou
-- `max` repeticoes (seguranca, se o soltar nunca chegar). O relogio vem de fora (testavel):
-- schedule(delay, cb) / unschedule(cb), como UIManager:scheduleIn / unschedule.
local Repeat = {}
Repeat.__index = Repeat

function Repeat.new(o)
    local self = setmetatable({ interval = o.interval, max = o.max, schedule = o.schedule,
                                unschedule = o.unschedule, fire = o.fire, count = 0 }, Repeat)
    self.tick = function()
        if self.action == nil then return end
        self.count = self.count + 1
        self.fire(self.action)
        if self.action ~= nil and self.count < self.max then self.schedule(self.interval, self.tick) end
    end
    return self
end

function Repeat:start(action)
    self:stop()
    self.action, self.count = action, 0
    self.schedule(self.interval, self.tick)
end

function Repeat:stop()
    self.unschedule(self.tick)
    self.action = nil
end

return Repeat
