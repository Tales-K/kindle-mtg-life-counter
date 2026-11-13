-- Ultimo formato de mesa escolhido para 4 jogadores ("rows" = duas fileiras, "sides" = um de cada
-- lado), guardado num arquivo de settings; vira o destaque da tela de formato na proxima vez.
local Pref = {}

local VALID = { rows = true, sides = true }

function Pref.load(fs, path)
    local s = fs.read(path)
    local v = s and s:match("^%s*(%a+)")
    return VALID[v] and v or "rows"
end

function Pref.save(fs, path, v)
    if not VALID[v] then return false end
    return fs.write(path, v) == true
end

-- Valor de Game.seating: nil para duas fileiras.
function Pref.game_seating(v)
    return v == "sides" and "sides" or nil
end

return Pref
