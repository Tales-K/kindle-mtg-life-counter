local Layout = {}

local CENTER_RATIO = 0.06

local function edges(total, k)
    local e = {}
    for j = 0, k do e[j] = math.floor(total * j / k) end
    return e
end

-- Assentos da mesa num retangulo w x h: fileira de baixo com ceil(n/2) jogadores (J1.. da
-- esquerda para a direita) e de cima com floor(n/2) (numerados no sentido horario, girados 180),
-- separadas por uma faixa de altura `gap`. Usado pela tela de jogo, pela miniatura e pela tela de dano.
function Layout.seats(n, w, h, gap)
    local rh = math.floor((h - gap) / 2)
    local seats = {}
    local nb, nt = math.ceil(n / 2), math.floor(n / 2)
    local eb = edges(w, nb)
    for j = 1, nb do
        seats[#seats + 1] = { index = j, x = eb[j - 1], y = h - rh, w = eb[j] - eb[j - 1], h = rh, rotation = 0 }
    end
    local et = edges(w, nt)
    for j = 1, nt do
        seats[#seats + 1] = { index = n - j + 1, x = et[j - 1], y = 0, w = et[j] - et[j - 1], h = rh, rotation = 180 }
    end
    return seats
end

function Layout.compute(n, w, h)
    local panels = Layout.seats(n, w, h, math.floor(CENTER_RATIO * h))
    local rows_h = panels[1].h
    local center = { x = 0, y = rows_h, w = w, h = h - 2 * rows_h }
    return { panels = panels, center = center, w = w, h = h }
end

-- Geometria do painel "em pe" (pw x ph). Proporcoes do mockup A2 (painel de 681 px de altura).
local function rnd(v) return math.floor(v + 0.5) end

function Layout.panel(pw, ph, n)
    local k = ph / 681
    local tiny, narrow = pw < 400 * k, pw < 700 * k
    local m20 = rnd(20 * k)
    local sh = rnd((tiny and 176 or 168) * k)
    local sy = ph - m20 - sh
    local icon_w = tiny and 0 or rnd(90 * k)
    local avail = pw - 2 * m20 - icon_w - rnd((tiny and 16 or 36) * k)
    local mw = math.min(avail, math.ceil(n / 2) * rnd((narrow and 160 or 220) * k))
    local mx = m20 + icon_w + rnd((tiny and 8 or 14) * k) + math.floor((avail - mw) / 2)
    local mpad = rnd(14 * k)
    local top_y, bot_y = rnd(96 * k), sy - m20
    local g = {
        k = k, tiny = tiny, narrow = narrow,
        border = { inset = rnd(6 * k), width = math.max(2, rnd(7 * k)), radius = rnd(26 * k) },
        label = { x = rnd(34 * k), cy = rnd(54 * k), size = rnd(40 * k) },
        poison = { right = pw - rnd(34 * k), cy = rnd(54 * k), size = rnd(38 * k), drop = rnd(40 * k), gap = rnd(26 * k) },
        strip = { x = m20, y = sy, w = pw - 2 * m20, h = sh, radius = rnd(20 * k), width = math.max(2, rnd(5 * k)) },
        minimap = { x = mx, y = sy + mpad, w = mw, h = sh - 2 * mpad },
        top_y = top_y, bot_y = bot_y, gy = math.floor((top_y + bot_y) / 2),
        glyph = { size = rnd((tiny and 34 or narrow and 50 or 60) * k), dx = rnd((tiny and 34 or narrow and 46 or 60) * k) },
        life_w = pw - rnd((tiny and 170 or narrow and 200 or 250) * k),
        skull = math.min(bot_y - top_y - rnd(30 * k), pw - rnd(130 * k)),
        zones = Layout.zones(pw, ph),
    }
    if not tiny then
        g.icon = { cx = m20 + rnd(14 * k) + math.floor(icon_w / 2) - rnd(6 * k), cy = sy + math.floor(sh / 2),
                   size = rnd(46 * k), text_size = rnd(26 * k), text_dy = rnd(40 * k), dy = rnd(18 * k) }
    end
    return g
end

-- Zonas de toque do painel "em pe": metade esquerda tira, direita soma, tira de baixo abre a tela de dano.
function Layout.zones(pw, ph)
    local k = ph / 681
    local sy = ph - rnd(20 * k) - rnd((pw < 400 * k and 176 or 168) * k)
    local half = math.floor(pw / 2)
    return {
        minus = { x = 0, y = 0, w = half, h = sy },
        plus = { x = half, y = 0, w = pw - half, h = sy },
        mini = { x = 0, y = sy, w = pw, h = ph - sy },
    }
end

-- Celulas da miniatura da mesa (mw x mh), no quadro do painel do dono. O painel de quem esta em
-- cima e girado 180 na tela, entao a mesa e girada tambem: na tela, cada celula fica sobre o painel real.
function Layout.minimap(n, rotation, mw, mh)
    local cells = Layout.seats(n, mw, mh, math.max(8, math.floor(mh / 12)))
    if rotation == 180 then
        for _, c in ipairs(cells) do
            c.x, c.y = mw - c.x - c.w, mh - c.y - c.h
        end
    end
    return cells
end

function Layout.zone_at(pw, ph, lx, ly)
    if lx < 0 or ly < 0 or lx >= pw or ly >= ph then return nil end
    for name, r in pairs(Layout.zones(pw, ph)) do
        if lx >= r.x and lx < r.x + r.w and ly >= r.y and ly < r.y + r.h then
            return name
        end
    end
    return nil
end

function Layout.hit(layout, x, y)
    for _, p in ipairs(layout.panels) do
        if x >= p.x and x < p.x + p.w and y >= p.y and y < p.y + p.h then
            local lx, ly = x - p.x, y - p.y
            if p.rotation == 180 then
                lx, ly = p.w - 1 - lx, p.h - 1 - ly
            end
            return { index = p.index, lx = lx, ly = ly, panel = p }
        end
    end
    return nil
end

return Layout
