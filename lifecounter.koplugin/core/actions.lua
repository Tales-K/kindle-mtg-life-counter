local Tuning = require("core.tuning")

local Actions = {}

-- Aplica um toque (big=false) ou segurar (big=true) numa zona de um painel.
-- Devolve true se mudou algo (e nesse caso grava o estado uma vez).
function Actions.apply(game, store, index, zone, big)
    local player = game.players[index]
    if not player then return false end
    local step = big and Tuning.BIG_STEP or Tuning.SMALL_STEP
    if zone == "plus" then
        game:adjust_life(index, step)
    elseif zone == "minus" then
        game:adjust_life(index, -step)
    elseif zone == "poison_plus" then
        game:adjust_poison(index, step)
    elseif zone == "poison_minus" then
        game:adjust_poison(index, -step)
    else
        return false
    end
    store:save(game:to_table())
    return true
end

-- Dano de comandante recebido por `target` do jogador `source`. sign = +1 ou -1.
-- Tambem tira (ou devolve) a mesma quantidade de vida. Grava uma vez se algo mudou.
function Actions.apply_commander(game, store, target, source, sign, big)
    if target == source or not game.players[target] or not game.players[source] then return false end
    local step = (big and Tuning.BIG_STEP or Tuning.SMALL_STEP) * sign
    local applied = game:adjust_commander(target, source, step)
    if applied == 0 then return false end
    store:save(game:to_table())
    return true
end

-- Toque/segurar num painel da tela de jogo. Devolve "changed" (vida mudou e foi gravada),
-- "open" (toque na miniatura: abrir a tela de dano, sem mudar nada) ou nil.
function Actions.on_panel(game, store, index, zone, big)
    if zone == "mini" then return (not big) and "open" or nil end
    if zone ~= "plus" and zone ~= "minus" then return nil end
    return Actions.apply(game, store, index, zone, big) and "changed" or nil
end

-- Toque/segurar na tela de dano (hit de commander_view). Dano: +-1 ou +-10 (tambem mexe na vida).
-- Veneno: so o toque, +-1. Devolve true se mudou algo.
function Actions.on_commander(game, store, target, hit, big)
    if not hit then return false end
    local a = hit.action
    if a == "plus" or a == "minus" then
        return Actions.apply_commander(game, store, target, hit.source, a == "plus" and 1 or -1, big)
    end
    if (a == "poison_plus" or a == "poison_minus") and not big then
        return Actions.apply(game, store, target, a, false)
    end
    return false
end

return Actions
