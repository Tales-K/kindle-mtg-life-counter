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

-- Toque/segurar num painel da tela de jogo (hit de Layout.zone_at). Devolve "changed" (vida mudou e
-- foi gravada); "open", campo (toque num quadradinho de oponente ou na gota: abrir o campo unico
-- { kind = "commander", source = i } ou { kind = "poison" }, sem mudar nada); ou nil.
function Actions.on_panel(game, store, index, hit, big)
    if not hit then return nil end
    local zone = hit.zone
    if zone == "plus" or zone == "minus" then
        return Actions.apply(game, store, index, zone, big) and "changed" or nil
    end
    if big then return nil end
    if zone == "poison" then return "open", { kind = "poison" } end
    if zone == "cmd" and type(hit.source) == "number" and game.players[hit.source] and hit.source ~= index then
        return "open", { kind = "commander", source = hit.source }
    end
    return nil
end

-- Toque/segurar em "minus"/"plus" no campo unico do jogador `owner`. Dano de comandante: +-1 ou
-- +-10 (tambem mexe na vida). Veneno: so o toque, +-1 (segurar nao muda, para ninguem chegar a 10
-- sem querer). Devolve true se mudou algo.
function Actions.on_field(game, store, owner, field, action, big)
    if not field or (action ~= "plus" and action ~= "minus") then return false end
    if field.kind == "commander" then
        return Actions.apply_commander(game, store, owner, field.source, action == "plus" and 1 or -1, big)
    end
    if field.kind == "poison" and not big then
        return Actions.apply(game, store, owner, "poison_" .. action, false)
    end
    return false
end

return Actions
