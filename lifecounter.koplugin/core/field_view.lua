-- Parte pura do campo unico (sem KOReader), para poder testar no PC. O campo ocupa a tela toda e
-- mostra um so numero do jogador dono do painel: o dano de comandante que ele recebeu de um
-- oponente, ou o veneno dele. Fica virado para o dono (a tela inteira gira 180 se ele esta em cima).
-- De cima para baixo, "em pe": titulo, miniatura da mesa, numero com metades -/+, botao OK.
local Game = require("core.game")
local I18n = require("core.i18n")

local View = {}

local function rnd(v) return math.floor(v + 0.5) end

function View.layout(w, h, rotation)
    local kx, ky = w / 1072, h / 1448
    local k = math.min(kx, ky)
    local m = rnd(24 * k)
    local fy, fb = rnd(400 * ky), h - rnd(250 * ky)
    local half = math.floor(w / 2)
    local mw, mh = rnd(300 * kx), rnd(170 * ky)
    local by = fb + rnd(24 * ky)
    return {
        w = w, h = h, rotation = rotation == 180 and 180 or 0, k = k, kx = kx, ky = ky, m = m,
        -- Zonas de toque (sem folga entre elas; o cabecalho nao reage).
        zones = {
            minus = { x = 0, y = fy, w = half, h = fb - fy },
            plus = { x = half, y = fy, w = w - half, h = fb - fy },
            ok = { x = 0, y = fb, w = w, h = h - fb },
        },
        -- So desenho.
        title = { cy = rnd(78 * ky), size = rnd(50 * k), sub_cy = rnd(140 * ky), sub_size = rnd(32 * k) },
        mini = { x = math.floor((w - mw) / 2), y = rnd(196 * ky), w = mw, h = mh },
        field = { x = m, y = fy, w = w - 2 * m, h = fb - fy - rnd(6 * ky) },
        button = { x = m, y = by, w = w - 2 * m, h = h - by - m },
    }
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Toque na tela -> "minus" | "plus" | "ok" | nil.
function View.hit(l, x, y)
    if x < 0 or y < 0 or x >= l.w or y >= l.h then return nil end
    if l.rotation == 180 then x, y = l.w - 1 - x, l.h - 1 - y end
    for _, name in ipairs({ "minus", "plus", "ok" }) do
        if inside(l.zones[name], x, y) then return name end
    end
    return nil
end

function View.title(owner, field)
    local p = I18n.player(owner)
    if field.kind == "poison" then return I18n.t("field_poison", { player = p }) end
    return I18n.t("field_commander", { player = p, source = I18n.player(field.source) })
end

function View.reminder(field)
    if field.kind == "poison" then return I18n.t("reminder_poison", { n = Game.POISON_LETHAL }) end
    return I18n.t("reminder_commander", { n = Game.COMMANDER_LETHAL })
end

function View.hint(field)
    return I18n.t(field.kind == "poison" and "hint_poison" or "hint_commander")
end

function View.out_note(owner)
    return I18n.t("out_note", { player = I18n.player(owner) })
end

function View.value(game, owner, field)
    local p = game.players[owner]
    if field.kind == "poison" then return p.poison end
    return p.cmd[field.source] or 0
end

-- Chaves do numero de variacao (core/delta): a vida no painel, e o numero do campo unico.
function View.life_key(owner) return "life:" .. owner end

function View.delta_key(owner, field)
    if field.kind == "poison" then return "poison:" .. owner end
    return "cmd:" .. owner .. ":" .. field.source
end

return View
