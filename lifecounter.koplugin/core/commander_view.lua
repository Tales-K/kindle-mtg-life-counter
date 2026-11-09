-- Parte pura da tela de dano de comandante (sem KOReader), para poder testar no PC.
-- A tela e a mesa em tamanho grande: um quadrado por jogador no lugar dele (fileira de cima
-- girada 180) e uma faixa no meio, virada para o jogador alvo, com "Voltar" e o veneno.
local Layout = require("core.layout")

local View = {}

local BAND_RATIO = 330 / 1448 -- proporcao do mockup A2

local function rnd(v) return math.floor(v + 0.5) end

function View.layout(n, target, w, h)
    local cells = Layout.seats(n, w, h, math.floor(h * BAND_RATIO))
    local rh = cells[1].h
    local rotation = 0
    for _, c in ipairs(cells) do if c.index == target then rotation = c.rotation end end
    local band = { x = 0, y = rh, w = w, h = h - 2 * rh, rotation = rotation }
    local kx, ky = w / 1072, band.h / 330
    local py, pb = rnd(182 * ky), rnd(18 * ky)
    local controls = {
        back = { x = rnd(24 * kx), y = rnd(20 * ky), w = rnd(266 * kx), h = rnd(126 * ky) },
        poison_minus = { x = rnd(420 * kx), y = py, w = rnd(180 * kx), h = band.h - pb - py },
        poison_plus = { x = rnd(860 * kx), y = py, w = w - rnd(24 * kx) - rnd(860 * kx), h = band.h - pb - py },
    }
    return { w = w, h = h, n = n, target = target, cells = cells, band = band, controls = controls, kx = kx, ky = ky }
end

-- Ponto (lx, ly) no quadro "em pe" de um retangulo com rotacao 0/180 -> ponto na tela (e vice-versa).
function View.screen_point(r, rotation, lx, ly)
    if rotation == 180 then return r.x + r.w - 1 - lx, r.y + r.h - 1 - ly end
    return r.x + lx, r.y + ly
end

local function local_point(r, rotation, x, y)
    local lx, ly = x - r.x, y - r.y
    if rotation == 180 then lx, ly = r.w - 1 - lx, r.h - 1 - ly end
    return lx, ly
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Devolve { action = "minus"|"plus", source = i } num oponente, { action = "back"|"poison_minus"|
-- "poison_plus" } na faixa, ou nil (quadrado do proprio alvo, vazios e fora da tela).
function View.hit(l, x, y)
    if inside(l.band, x, y) then
        local lx, ly = local_point(l.band, l.band.rotation, x, y)
        for _, name in ipairs({ "back", "poison_minus", "poison_plus" }) do
            if inside(l.controls[name], lx, ly) then return { action = name } end
        end
        return nil
    end
    for _, c in ipairs(l.cells) do
        if inside(c, x, y) then
            if c.index == l.target then return nil end
            local lx = local_point(c, c.rotation, x, y)
            return { action = lx < math.floor(c.w / 2) and "minus" or "plus", source = c.index }
        end
    end
    return nil
end

return View
