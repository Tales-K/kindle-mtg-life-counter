local Layout = {}

local CENTER_RATIO = 0.06

local function edges(total, k)
    local e = {}
    for j = 0, k do e[j] = math.floor(total * j / k) end
    return e
end

-- Assentos da mesa num retangulo w x h: fileira de baixo com ceil(n/2) jogadores (J1.. da
-- esquerda para a direita) e de cima com floor(n/2) (numerados no sentido horario, girados 180),
-- separadas por uma faixa de altura `gap`. Usado pela tela de jogo e pela miniatura da mesa.
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

-- Faixa de baixo do painel: gota do veneno a esquerda e miniatura da mesa a direita.
-- `split` e a divisa de toque entre as duas (sem folga: a faixa toda responde).
local function strip(pw, ph, n)
    local k = ph / 681
    local tiny, narrow = pw < 400 * k, pw < 700 * k
    local m20 = rnd(20 * k)
    local sh = rnd((tiny and 176 or 168) * k)
    local sy = ph - m20 - sh
    local icon_w = rnd((tiny and 70 or 90) * k)
    local gap = rnd((tiny and 8 or 14) * k)
    local avail = pw - 2 * m20 - icon_w - rnd((tiny and 16 or 36) * k)
    local mw = math.min(avail, math.ceil(n / 2) * rnd((narrow and 160 or 220) * k))
    local mx = m20 + icon_w + gap + math.floor((avail - mw) / 2)
    local mpad = rnd(14 * k)
    return {
        k = k, tiny = tiny, narrow = narrow, m20 = m20, sy = sy, sh = sh, icon_w = icon_w,
        split = m20 + icon_w + math.floor(gap / 2),
        minimap = { x = mx, y = sy + mpad, w = mw, h = sh - 2 * mpad },
    }
end

function Layout.panel(pw, ph, n)
    local s = strip(pw, ph, n)
    local k, tiny, narrow, m20, sy, sh = s.k, s.tiny, s.narrow, s.m20, s.sy, s.sh
    local top_y, bot_y = rnd(96 * k), sy - m20
    local icon_cx = m20 + (tiny and rnd(4 * k) or rnd(8 * k)) + math.floor(s.icon_w / 2)
    return {
        k = k, tiny = tiny, narrow = narrow,
        border = { inset = rnd(6 * k), width = math.max(2, rnd(7 * k)), radius = rnd(26 * k) },
        label = { x = rnd(34 * k), cy = rnd(54 * k), size = rnd(40 * k) },
        strip = { x = m20, y = sy, w = pw - 2 * m20, h = sh, radius = rnd(20 * k), width = math.max(2, rnd(5 * k)) },
        minimap = s.minimap,
        top_y = top_y, bot_y = bot_y, gy = math.floor((top_y + bot_y) / 2),
        glyph = { size = rnd((tiny and 34 or narrow and 50 or 60) * k), dx = rnd((tiny and 34 or narrow and 46 or 60) * k) },
        life_w = pw - rnd((tiny and 170 or narrow and 200 or 250) * k),
        skull = math.min(bot_y - top_y - rnd(30 * k), pw - rnd(130 * k)),
        -- Gota do veneno (sempre visivel) com o numero embaixo, a esquerda da miniatura.
        icon = { cx = icon_cx, cy = sy + math.floor(sh / 2), drop = rnd(48 * k), drop_dy = rnd(28 * k),
                 text_size = rnd((tiny and 36 or 40) * k), text_dy = rnd(40 * k) },
        zones = Layout.zones(pw, ph, n),
    }
end

-- Zonas de toque do painel "em pe": metade esquerda tira, direita soma; na faixa de baixo, a gota
-- (abre o campo de veneno) e a miniatura (cada quadradinho abre o campo de dano daquele oponente).
function Layout.zones(pw, ph, n)
    local s = strip(pw, ph, n)
    local sy, half = s.sy, math.floor(pw / 2)
    return {
        minus = { x = 0, y = 0, w = half, h = sy },
        plus = { x = half, y = 0, w = pw - half, h = sy },
        poison = { x = 0, y = sy, w = s.split, h = ph - sy },
        mini = { x = s.split, y = sy, w = pw - s.split, h = ph - sy },
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

-- Celula da miniatura no ponto (x, y) relativo a ela, aceitando pontos fora dela: a fileira e a
-- metade de cima ou de baixo, e as celulas das pontas vao ate a borda. Assim o toque pega a celula
-- inteira e o espaco ate a vizinha, sem buraco entre elas.
local function minimap_cell_at(n, rotation, mw, mh, x, y)
    local top = y < mh / 2
    local row = {}
    for _, c in ipairs(Layout.minimap(n, rotation, mw, mh)) do
        if (c.y + c.h / 2 < mh / 2) == top then row[#row + 1] = c end
    end
    table.sort(row, function(a, b) return a.x < b.x end)
    for _, c in ipairs(row) do
        if x < c.x + c.w then return c end
    end
    return row[#row]
end

-- O que ha no ponto (lx, ly) do painel "em pe" do jogador `owner`: { zone = "minus" | "plus" |
-- "poison" } ou { zone = "cmd", source = indice do oponente | "self" }; nil fora do painel.
function Layout.zone_at(pw, ph, n, rotation, owner, lx, ly)
    if lx < 0 or ly < 0 or lx >= pw or ly >= ph then return nil end
    local z = Layout.zones(pw, ph, n)
    for _, name in ipairs({ "minus", "plus", "poison" }) do
        local r = z[name]
        if lx >= r.x and lx < r.x + r.w and ly >= r.y and ly < r.y + r.h then return { zone = name } end
    end
    local m = strip(pw, ph, n).minimap
    local c = minimap_cell_at(n, rotation, m.w, m.h, lx - m.x, ly - m.y)
    return { zone = "cmd", source = c.index == owner and "self" or c.index }
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
