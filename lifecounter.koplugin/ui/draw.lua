-- Ajudantes de desenho compartilhados pelas telas (so KOReader). So preto e branco puros:
-- formas com paintRect/paintRoundedRect/paintBorder, sem anti-aliasing.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local Screen = Device.screen

local Draw = {}

local BLACK = Blitbuffer.COLOR_BLACK
local BOLD_FONT = "NotoSans-Bold.ttf"
local CAP = 0.714 -- altura dos algarismos/maiusculas da Noto Sans, em fracao do tamanho da fonte

-- Texto que cabe em (max_w x max_h): reduz a fonte ate caber, nunca corta.
function Draw.fit_text(text, max_w, max_h, size, bold)
    local tw
    while size >= 6 do
        tw = TextWidget:new{ text = text, face = Font:getFace("cfont", size), bold = bold, fgcolor = BLACK }
        local s = tw:getSize()
        if s.w <= max_w and s.h <= max_h then return tw end
        tw:free()
        size = math.floor(size * 0.9)
    end
    return TextWidget:new{ text = text, face = Font:getFace("cfont", 6), bold = bold, fgcolor = BLACK }
end

function Draw.centered(bb, r, text, size, bold)
    local tw = Draw.fit_text(text, r.w - 16, r.h - 16, size, bold)
    local s = tw:getSize()
    tw:paintTo(bb, r.x + math.floor((r.w - s.w) / 2), r.y + math.floor((r.h - s.h) / 2))
    tw:free()
end

function Draw.box(bb, r, width)
    bb:paintBorder(r.x, r.y, r.w, r.h, width or 2, BLACK)
end

-- Fonte com tamanho em pixels de verdade (o KOReader escala o tamanho pela tela).
local px_ratio
local function face(px, bold)
    px_ratio = px_ratio or (Screen:scaleBySize(1000) / 1000)
    return Font:getFace(bold and BOLD_FONT or "cfont", math.max(4, math.floor(px / px_ratio + 0.5)))
end

local function widget(text, px, bold, color)
    return TextWidget:new{ text = text, face = face(px, bold), fgcolor = color or BLACK, padding = 0 }
end

-- Texto com a altura das maiusculas centrada em cy. align: "center" (x = centro), "left", "right".
-- Devolve a largura desenhada.
function Draw.text(bb, x, cy, text, px, opts)
    opts = opts or {}
    local tw = widget(text, px, opts.bold, opts.color)
    local w = tw:getSize().w
    local cap = CAP * tw.face.size
    local y = math.floor(cy + cap / 2 - tw:getBaseline() + 0.5)
    local left = x
    if opts.align == "left" then left = x
    elseif opts.align == "right" then left = x - w
    else left = x - math.floor(w / 2) end
    tw:paintTo(bb, left, y)
    tw:free()
    return w
end

-- Maior tamanho (px) em que `text` cabe em max_w de largura e max_h de altura de algarismo.
-- Os algarismos da Noto tem a mesma largura, entao o resultado vale para qualquer numero com
-- a mesma quantidade de caracteres (guardado em cache).
local fit_cache = {}
function Draw.fit_px(text, max_w, max_h, bold)
    local probe = string.rep("0", #text)
    local key = table.concat({ probe, max_w, max_h, bold and 1 or 0 }, ":")
    if fit_cache[key] then return fit_cache[key] end
    local lo, hi = 8, math.max(8, math.floor(max_h / CAP))
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        local tw = widget(probe, mid, bold)
        local w = tw:getSize().w
        tw:free()
        if w <= max_w then lo = mid else hi = mid - 1 end
    end
    fit_cache[key] = lo
    return lo
end

function Draw.rect(bb, x, y, w, h, color)
    x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
    if w > 0 and h > 0 then bb:paintRect(x, y, w, h, color) end
end

function Draw.fill_round(bb, r, color, radius)
    bb:paintRoundedRect(r.x, r.y, r.w, r.h, color, radius)
end

function Draw.border_round(bb, r, width, color, radius)
    bb:paintBorder(r.x, r.y, r.w, r.h, width, color, radius, 0)
end

-- Faixas horizontais com meia-largura variando de hw0 (em y0) a hw1 (em y1), centradas em cx.
function Draw.trapezoid(bb, cx, y0, y1, hw0, hw1, color)
    y0, y1 = math.floor(y0 + 0.5), math.floor(y1 + 0.5)
    for y = y0, y1 do
        local t = y1 == y0 and 1 or (y - y0) / (y1 - y0)
        local hw = hw0 + (hw1 - hw0) * t
        Draw.rect(bb, cx - hw, y, 2 * hw, 1, color)
    end
end

function Draw.ellipse(bb, cx, cy, rx, ry, color)
    local y0, y1 = math.floor(cy - ry + 0.5), math.floor(cy + ry + 0.5)
    for y = y0, y1 do
        local d = (y + 0.5 - cy) / ry
        if d > -1 and d < 1 then
            local hw = rx * math.sqrt(1 - d * d)
            Draw.rect(bb, cx - hw, y, 2 * hw, 1, color)
        end
    end
end

function Draw.minus(bb, cx, cy, s, color)
    local t = math.max(8, math.floor(s / 6))
    Draw.rect(bb, cx - s / 2, cy - t / 2, s, t, color or BLACK)
end

function Draw.plus(bb, cx, cy, s, color)
    Draw.minus(bb, cx, cy, s, color)
    local t = math.max(8, math.floor(s / 6))
    Draw.rect(bb, cx - t / 2, cy - s / 2, t, s, color or BLACK)
end

-- Gota de veneno de altura s centrada em (cx, cy).
function Draw.drop(bb, cx, cy, s, color)
    local r = s * 0.32
    Draw.ellipse(bb, cx, cy + s * 0.5 - r, r, r, color)
    Draw.trapezoid(bb, cx, cy - s * 0.5, cy + s * 0.5 - r * 1.15, 0, r * 0.95, color)
end

-- Caveira de altura s, na cor fg, com olhos/nariz/dentes na cor bg.
function Draw.skull(bb, cx, cy, s, fg, bg)
    local top, bot = cy - s / 2, cy + s / 2
    Draw.ellipse(bb, cx, top + s * 0.37, s * 0.45, s * 0.37, fg)
    local jaw = { x = math.floor(cx - s * 0.27), y = math.floor(top + s * 0.55) }
    jaw.w, jaw.h = math.floor(s * 0.54), math.floor(bot - jaw.y)
    Draw.fill_round(bb, jaw, fg, math.floor(s * 0.07))
    local er = s * 0.12
    for _, dx in ipairs({ -1, 1 }) do
        Draw.ellipse(bb, cx + dx * s * 0.19, top + s * 0.38 + er * 0.05, er, er * 1.05, bg)
    end
    local ny = top + s * 0.60
    Draw.trapezoid(bb, cx, ny - s * 0.07, ny + s * 0.04, 0, s * 0.055, bg)
    local lw = math.max(4, math.floor(s * 0.035))
    for k = -1, 1 do
        Draw.rect(bb, cx + k * s * 0.12 - lw / 2, bot - s * 0.17, lw, s * 0.155, bg)
    end
end

-- Pinta (w x h) em (x0, y0) pixel a pixel: fn(u, v) devolve o tom de cinza (0 preto .. 255 branco)
-- no ponto (u, v) em [0,1)x[0,1) (centro do pixel) ou nil para deixar como esta. Junta pixels
-- vizinhos do mesmo tom numa faixa. (Tons como numeros: cores do Blitbuffer nao comparam com nil.)
function Draw.raster(bb, x0, y0, w, h, fn)
    x0, y0, w, h = math.floor(x0 + 0.5), math.floor(y0 + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
    for py = 0, h - 1 do
        local v = (py + 0.5) / h
        local run_x, run_c = 0, nil
        for px = 0, w do
            local c = px < w and fn((px + 0.5) / w, v) or nil
            if c ~= run_c then
                if run_c then bb:paintRect(x0 + run_x, y0 + py, px - run_x, 1, Blitbuffer.Color8(run_c)) end
                run_x, run_c = px, c
            end
        end
    end
end

-- Bandeiras em tons de cinza (o e-ink nao tem cor), so com retangulos.
local UK_BLUE, UK_RED, FLAG_WHITE = 0x70, 0x00, 0xFF
local BR_GREEN, BR_YELLOW, BR_BLUE = 0x80, 0xD8, 0x30

-- Union Jack (2:1): campo azul, aspas brancas com as vermelhas deslocadas (contratrocadas),
-- cruz branca larga e cruz vermelha de Sao Jorge. Medidas oficiais em 60 x 30.
local DIAG = math.sqrt(60 * 60 + 30 * 30)
local function uk(u, v)
    local x, y = u * 60, v * 30
    local dx, dy = math.abs(x - 30), math.abs(y - 15)
    if dx < 3 or dy < 3 then return UK_RED end
    if dx < 5 or dy < 5 then return FLAG_WHITE end
    local s1 = (x * 30 - y * 60) / DIAG          -- > 0: acima da diagonal principal
    local s2 = (x * 30 + y * 60 - 1800) / DIAG   -- > 0: abaixo da outra diagonal
    local left = x < 30
    if (left and s1 > -2 and s1 < 0) or (not left and s1 > 0 and s1 < 2)
        or (not left and s2 > -2 and s2 < 0) or (left and s2 > 0 and s2 < 2) then
        return UK_RED
    end
    if math.abs(s1) < 3 or math.abs(s2) < 3 then return FLAG_WHITE end
    return UK_BLUE
end

-- Bandeira do Brasil (10:7), em modulos 20 x 14: campo verde, losango amarelo, circulo azul
-- e a faixa branca: arcos de raio 8 e 8,5 com centro 2 modulos a esquerda do pe do diametro
-- vertical do circulo na base da bandeira (Lei 5.700).
local function br(u, v)
    local x, y = u * 20, v * 14
    local cx, cy = 10, 7
    local ddx, ddy = x - cx, y - cy
    if ddx * ddx + ddy * ddy <= 3.5 * 3.5 then
        local bx, by = x - (cx - 2), y - 14
        local d = math.sqrt(bx * bx + by * by)
        if d >= 8 and d <= 8.5 then return FLAG_WHITE end
        return BR_BLUE
    end
    if math.abs(ddx) / 8.3 + math.abs(ddy) / 5.3 <= 1 then return BR_YELLOW end
    return BR_GREEN
end

local FLAGS = { en = { fn = uk, ratio = 2 }, pt = { fn = br, ratio = 10 / 7 } }

function Draw.flag_ratio(lang) return FLAGS[lang].ratio end

-- Bandeira de altura h centrada em (cx, cy), com um filete preto em volta.
function Draw.flag(bb, lang, cx, cy, h)
    local f = FLAGS[lang]
    local w = math.floor(h * f.ratio + 0.5)
    local x, y = math.floor(cx - w / 2 + 0.5), math.floor(cy - h / 2 + 0.5)
    Draw.raster(bb, x, y, w, h, f.fn)
    bb:paintBorder(x - 2, y - 2, w + 4, h + 4, 2, BLACK)
end

-- Cabe numa linha (largura max_w) no tamanho dado?
function Draw.fits(text, max_w, size, bold)
    local tw = TextWidget:new{ text = text, face = Font:getFace("cfont", size), bold = bold, fgcolor = BLACK }
    local ok = tw:getSize().w <= max_w
    tw:free()
    return ok
end

return Draw
