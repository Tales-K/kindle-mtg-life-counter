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

return Actions
