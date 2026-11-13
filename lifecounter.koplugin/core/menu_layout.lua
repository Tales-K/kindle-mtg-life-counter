-- Geometria da tela de menu em tela cheia (titulo + botoes empilhados). Parte pura, sem KOReader.
local ML = {}

-- weights (opcional): altura relativa de cada botao (1 = botao normal); ex.: { 4, 1 } para uma
-- previa grande e um "Voltar".
function ML.compute(n, w, h, weights)
    local margin = math.floor(w * 0.08)
    local title = { x = 0, y = math.floor(h * 0.04), w = w, h = math.floor(h * 0.12) }
    local top = title.y + title.h + math.floor(h * 0.03)
    local bottom = h - math.floor(h * 0.04)
    local gap = math.floor(h * 0.02)
    local units = 0
    for i = 1, n do units = units + ((weights and weights[i]) or 1) end
    local bh = math.floor((bottom - top - gap * (n - 1)) / units)
    local cap = math.floor(h * 0.12)
    if bh > cap then bh = cap end
    local buttons = {}
    local y = top
    for i = 1, n do
        local bhi = math.floor(bh * ((weights and weights[i]) or 1))
        buttons[i] = { x = margin, y = y, w = w - 2 * margin, h = bhi }
        y = y + bhi + gap
    end
    return { title = title, buttons = buttons, w = w, h = h }
end

function ML.hit(layout, x, y)
    for i, b in ipairs(layout.buttons) do
        if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then return i end
    end
    return nil
end

return ML
