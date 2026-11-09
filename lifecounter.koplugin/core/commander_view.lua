-- Parte pura da tela de dano de comandante (sem KOReader), para poder testar no PC.
local Game = require("core.game")

local View = {}

function View.rows(game, target)
    local rows = {}
    local cmd = game.players[target].cmd
    for source = 1, game.player_count do
        if source ~= target then
            local damage = cmd[source] or 0
            rows[#rows + 1] = { source = source, damage = damage, lethal = damage >= Game.COMMANDER_LETHAL }
        end
    end
    return rows
end

function View.layout(count, w, h)
    local header_h = math.floor(h * 0.12)
    local back_h = math.floor(h * 0.12)
    local row_h = math.floor((h - header_h - back_h) / count)
    local a, b = math.floor(w * 0.25), math.floor(w * 0.75)
    local layout = {
        w = w, h = h,
        header = { x = 0, y = 0, w = w, h = header_h },
        rows = {},
    }
    for i = 1, count do
        local y = header_h + (i - 1) * row_h
        layout.rows[i] = {
            minus = { x = 0, y = y, w = a, h = row_h },
            value = { x = a, y = y, w = b - a, h = row_h },
            plus = { x = b, y = y, w = w - b, h = row_h },
        }
    end
    layout.back = { x = 0, y = h - back_h, w = w, h = back_h }
    return layout
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- rotation 180: o ponto da tela e girado de volta para o quadro "em pe".
function View.hit(layout, x, y, rotation)
    if rotation == 180 then
        x, y = layout.w - 1 - x, layout.h - 1 - y
    end
    if x < 0 or y < 0 or x >= layout.w or y >= layout.h then return nil end
    if inside(layout.back, x, y) then return { action = "back" } end
    for i, r in ipairs(layout.rows) do
        if inside(r.minus, x, y) then return { row = i, action = "minus" } end
        if inside(r.plus, x, y) then return { row = i, action = "plus" } end
    end
    return nil
end

return View
