-- Quanto um numero mudou nos ultimos toques (como no LifeTap): seis toques no -1 mostram "-6"
-- pequeno em cima do numero. Toques seguidos somam; `window` segundos sem mudar, o numero some.
-- Chaves sao livres ("life:1", "poison:2", "cmd:1:3"); o relogio vem de fora (testavel).
local Delta = {}
Delta.__index = Delta

function Delta.new(window)
    return setmetatable({ window = window, entries = {} }, Delta)
end

function Delta:add(key, amount, now)
    if amount == 0 then return end
    local e = self.entries[key]
    if e and now - e.last < self.window then
        e.value, e.last = e.value + amount, now
    else
        self.entries[key] = { value = amount, last = now }
    end
end

-- Valor ainda visivel, ou nil (passou a janela, ou voltou a zero).
function Delta:get(key, now)
    local e = self.entries[key]
    if not e or now - e.last >= self.window or e.value == 0 then return nil end
    return e.value
end

-- Proximo instante em que algum numero visivel some (para redesenhar), ou nil.
function Delta:next_expiry(now)
    local soon
    for key, e in pairs(self.entries) do
        if self:get(key, now) then
            local t = e.last + self.window
            if not soon or t < soon then soon = t end
        end
    end
    return soon
end

-- Altura (centro) do numero de variacao: logo acima dos algarismos do numero grande (centro
-- number_cy, number_px de fonte), com um respiro de meia letra; nunca acima de min_cy.
-- cap = altura dos algarismos em fracao do tamanho da fonte (ui/draw).
function Delta.place(number_cy, number_px, delta_px, min_cy, cap)
    local number_top = number_cy - cap * number_px / 2
    local cy = math.floor(number_top - cap * delta_px + 0.5)
    return math.max(min_cy, cy)
end

function Delta.text(v)
    if v == nil then return nil end
    return v > 0 and ("+" .. v) or tostring(v)
end

return Delta
