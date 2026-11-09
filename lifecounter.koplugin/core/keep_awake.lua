-- Mantem o Kindle acordado durante a partida enquanto houver uso: cada toque renova o prazo;
-- depois de `timeout` segundos sem toque, libera o descanso (para nao gastar bateria a toa).
-- `set(on)` faz a chamada ao sistema; aqui so fica a regra de quando chamar.
local KeepAwake = {}
KeepAwake.__index = KeepAwake

function KeepAwake.new(o)
    return setmetatable({ timeout = o.timeout, set = o.set, on = false, deadline = nil }, KeepAwake)
end

function KeepAwake:touch(now)
    self.deadline = now + self.timeout
    if not self.on then
        self.on = true
        self.set(true)
    end
end

function KeepAwake:check(now)
    if self.on and self.deadline and now >= self.deadline then
        self.on = false
        self.set(false)
    end
end

function KeepAwake:stop()
    if self.on then
        self.on = false
        self.set(false)
    end
end

return KeepAwake
