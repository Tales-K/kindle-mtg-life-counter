-- Mesa de 4 "um de cada lado" (sem KOReader, testavel): a tela e cortada pelas duas diagonais em
-- 4 triangulos, um por borda. J1 embaixo, J2 na esquerda, J3 em cima, J4 na direita (sentido
-- horario). Cada jogador ve o proprio triangulo "em pe": a borda dele embaixo e a ponta no centro.
-- O triangulo "em pe" tem uw (base) x uh (profundidade); o desenho e girado para a borda certa.
local Sides = {}

local CAP = 0.714       -- altura dos algarismos em fracao da fonte (ui/draw)
local DIGIT_W = 0.6     -- largura de um algarismo (negrito) em fracao da fonte, com folga

local function rnd(v) return math.floor(v + 0.5) end

-- Assento -> giro do desenho (0 em pe, 90 com o "cima" apontando para a direita da tela, ...).
local SEATS = {
    { index = 1, seat = "bottom", rotation = 0 },
    { index = 2, seat = "left", rotation = 90 },
    { index = 3, seat = "top", rotation = 180 },
    { index = 4, seat = "right", rotation = 270 },
}

-- Ponto (x, y) de um retangulo de tela bw x bh -> ponto no desenho "em pe" (e o inverso).
-- Em pe: a borda do jogador embaixo e a mao esquerda dele em x = 0.
function Sides.to_upright(rot, bw, bh, x, y)
    if rot == 90 then return y, bw - 1 - x end
    if rot == 180 then return bw - 1 - x, bh - 1 - y end
    if rot == 270 then return bh - 1 - y, x end
    return x, y
end

function Sides.to_screen(rot, bw, bh, lx, ly)
    if rot == 90 then return bw - 1 - ly, lx end
    if rot == 180 then return bw - 1 - lx, bh - 1 - ly end
    if rot == 270 then return ly, bh - 1 - lx end
    return lx, ly
end

function Sides.compute(w, h)
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    local boxes = {
        bottom = { x = 0, y = cy, w = w, h = h - cy },
        top = { x = 0, y = 0, w = w, h = cy },
        left = { x = 0, y = 0, w = cx, h = h },
        right = { x = cx, y = 0, w = w - cx, h = h },
    }
    local panels = {}
    for _, s in ipairs(SEATS) do
        local b = boxes[s.seat]
        local sideways = s.rotation == 90 or s.rotation == 270
        panels[#panels + 1] = {
            index = s.index, seat = s.seat, rotation = s.rotation,
            x = b.x, y = b.y, w = b.w, h = b.h,
            uw = sideways and b.h or b.w, uh = sideways and b.w or b.h,
        }
    end
    local r = rnd(64 * math.min(w / 1072, h / 1448))
    return { kind = "sides", panels = panels, w = w, h = h, cx = cx, cy = cy, menu = { cx = cx, cy = cy, r = r } }
end

-- Assento do ponto (x, y): o lado mais proximo, medido em fracao da meia largura / meia altura.
local function seat_at(l, x, y)
    local u = (x + 0.5 - l.cx) / l.cx
    local v = (y + 0.5 - l.cy) / l.cy
    if math.abs(v) >= math.abs(u) then return v > 0 and "bottom" or "top" end
    return u > 0 and "right" or "left"
end

function Sides.in_menu(l, x, y)
    local m = l.menu
    local dx, dy = x - m.cx, y - m.cy
    return dx * dx + dy * dy <= m.r * m.r
end

function Sides.hit(l, x, y)
    if x < 0 or y < 0 or x >= l.w or y >= l.h or Sides.in_menu(l, x, y) then return nil end
    local seat = seat_at(l, x, y)
    for _, p in ipairs(l.panels) do
        if p.seat == seat then
            local lx, ly = Sides.to_upright(p.rotation, p.w, p.h, x - p.x, y - p.y)
            return { index = p.index, lx = lx, ly = ly, panel = p }
        end
    end
end

-- Pedaco da linha y da tela que pertence ao triangulo do painel p: { x0, x1 } (x1 exclusivo) ou nil.
function Sides.span(l, p, y)
    local v = math.abs(y + 0.5 - l.cy) / l.cy
    local x0, x1
    if p.seat == "bottom" or p.seat == "top" then
        if (p.seat == "bottom") ~= (y >= l.cy) then return nil end
        local hw = l.cx * v
        x0, x1 = rnd(l.cx - hw), rnd(l.cx + hw)
    elseif p.seat == "left" then
        x0, x1 = 0, rnd(l.cx * (1 - v))
    else
        x0, x1 = rnd(l.w - (l.w - l.cx) * (1 - v)), l.w
    end
    if x1 <= x0 then return nil end
    return { x0, x1 }
end

-- Geometria do triangulo "em pe" (uw x uh, ponta em (uw/2, 0)). k segue a profundidade.
function Sides.panel(uw, uh)
    local k = uh / 724
    local slope = (uw / 2) / uh -- meia largura por pixel de profundidade
    local function hw(y) return slope * y end
    local m = rnd(18 * k)

    -- Faixa da base: gota do veneno e mesa em miniatura, centralizadas.
    local sh = rnd(170 * k)
    local sy = uh - m - sh
    local sw = 2 * math.floor(hw(sy) - m)
    local strip = { x = math.floor((uw - sw) / 2), y = sy, w = sw, h = sh, radius = rnd(20 * k), width = math.max(2, rnd(5 * k)) }
    local icon_w, gap, mpad = rnd(100 * k), rnd(16 * k), rnd(12 * k)
    local mw = math.min(sw - icon_w - gap - 2 * m, 3 * rnd(150 * k))
    local gx = strip.x + math.floor((sw - (icon_w + gap + mw)) / 2)
    local minimap = { x = gx + icon_w + gap, y = sy + mpad, w = mw, h = sh - 2 * mpad }

    -- Numero da vida: entre a faixa e a ponta, no ponto em que ele fica maior.
    local y_b = sy - rnd(14 * k)
    local best_t, best_px = y_b, 0
    for y_t = rnd(0.28 * uh), y_b - 20, 2 do
        local avail = 2 * (hw(y_t) - m)
        local px = math.min((y_b - y_t) / CAP, avail / (2 * DIGIT_W))
        if px > best_px then best_t, best_px = y_t, px end
    end
    local y_t = best_t
    local number = { y = y_t, h = y_b - y_t, w = 2 * math.floor(hw(y_t) - m) }
    local gy = math.floor((y_t + y_b) / 2)

    -- - e + nos cantos de baixo do numero, onde o triangulo e mais largo.
    local glyph = rnd(52 * k)
    local gcy = math.floor(gy + (y_b - gy) / 2)
    local gdx = math.floor(hw(gcy - glyph / 2) - m - glyph / 2)

    local label_size, delta_size = rnd(34 * k), rnd(44 * k)
    return {
        k = k, m = m, slope = slope,
        strip = strip, minimap = minimap, split = gx + icon_w + math.floor(gap / 2),
        icon = { cx = gx + math.floor(icon_w / 2), cy = sy + math.floor(sh / 2), drop = rnd(48 * k),
                 drop_dy = rnd(26 * k), text_size = rnd(40 * k), text_dy = rnd(40 * k) },
        number = number, gy = gy,
        skull = math.floor(math.min(y_b - y_t, number.w * 0.8)),
        glyph = glyph,
        minus = { cx = math.floor(uw / 2) - gdx, cy = gcy },
        plus = { cx = math.floor(uw / 2) + gdx, cy = gcy },
        label = { cy = y_t - rnd(80 * k), size = label_size },
        delta_size = delta_size,
    }
end

-- Mesa em miniatura do jogador `owner`, vista do lugar dele: em frente em cima; embaixo, o vizinho
-- da esquerda, ele mesmo ("voce") e o da direita. Sentido horario: a esquerda de J1 e J2.
function Sides.minimap(owner, mw, mh)
    local function seat(step) return (owner - 1 + step) % 4 + 1 end
    local gap = math.max(6, math.floor(mh / 12))
    local rh = math.floor((mh - gap) / 2)
    local cw = math.floor(mw / 3)
    return {
        { index = seat(2), x = cw, y = 0, w = cw, h = rh },
        { index = seat(1), x = 0, y = mh - rh, w = cw, h = rh },
        { index = owner, x = cw, y = mh - rh, w = cw, h = rh },
        { index = seat(3), x = 2 * cw, y = mh - rh, w = mw - 2 * cw, h = rh },
    }
end

-- Celula no ponto (x, y) da miniatura: metade de cima e quem esta em frente; embaixo, por tercos.
local function minimap_cell_at(owner, mw, mh, x, y)
    local cells = Sides.minimap(owner, mw, mh)
    if y < mh / 2 then return cells[1] end
    local cw = math.floor(mw / 3)
    if x < cw then return cells[2] end
    if x < 2 * cw then return cells[3] end
    return cells[4]
end

-- O que ha no ponto (lx, ly) do triangulo "em pe" do jogador `owner` (mesmo formato de Layout.zone_at).
function Sides.zone_at(uw, uh, owner, lx, ly)
    if lx < 0 or ly < 0 or lx >= uw or ly >= uh then return nil end
    local g = Sides.panel(uw, uh)
    if ly < g.strip.y then return { zone = lx < uw / 2 and "minus" or "plus" } end
    if lx < g.split then return { zone = "poison" } end
    local m = g.minimap
    local c = minimap_cell_at(owner, m.w, m.h, lx - m.x, ly - m.y)
    return { zone = "cmd", source = c.index == owner and "self" or c.index }
end

return Sides
