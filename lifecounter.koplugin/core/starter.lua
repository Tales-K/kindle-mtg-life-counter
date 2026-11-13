-- Sorteio de quem comeca, como um dado: o resultado sai de 1 ate o numero de jogadores, e a tela
-- mostra poucos quadros com o numero trocando ate parar nele (poucos por causa do e-ink).
-- rand(a, b) como math.random (injetado para testar).
local Starter = {}

function Starter.roll(n, rand, count)
    local result = rand(1, n)
    local frames = { [count] = result }
    -- De tras para frente: cada quadro diferente do seguinte (com 2 jogadores, alterna).
    for i = count - 1, 1, -1 do
        local v = rand(1, n - 1)
        if v >= frames[i + 1] then v = v + 1 end
        frames[i] = v
    end
    return { result = result, frames = frames }
end

return Starter
