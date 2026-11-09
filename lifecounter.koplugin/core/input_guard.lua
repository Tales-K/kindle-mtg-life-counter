-- Ignora toques logo depois de uma tela abrir (o e-ink demora a desenhar e um toque duplo
-- cairia em botoes da tela nova).
local Guard = {}

function Guard.should_ignore(opened_at, now, delay)
    if not opened_at then return false end
    local elapsed = now - opened_at
    return elapsed >= 0 and elapsed < delay
end

-- Janela de protecao que comeca quando a tela TERMINA o primeiro desenho (no Kindle o desenho
-- pode levar mais que o proprio atraso, e os toques dados nesse meio-tempo ficam na fila).
local Window = {}
Window.__index = Window

function Guard.window(delay)
    return setmetatable({ delay = delay }, Window)
end

function Window:arm(now)
    self.opened_at = now
    self.waiting_paint = true
end

function Window:painted(now)
    if self.waiting_paint then
        self.opened_at = now
        self.waiting_paint = false
    end
end

function Window:ignore(now)
    return Guard.should_ignore(self.opened_at, now, self.delay)
end

return Guard
