local MIN_PLAYERS, MAX_PLAYERS = 2, 6
local POISON_LETHAL = 10
local COMMANDER_LETHAL = 21

local Game = {}
Game.__index = Game
Game.POISON_LETHAL = POISON_LETHAL
Game.COMMANDER_LETHAL = COMMANDER_LETHAL

local function is_int(v)
    return type(v) == "number" and v == math.floor(v)
end

-- seating: nil (duas fileiras) ou "sides" (4 jogadores, um de cada lado da mesa: core/sides).
local function bad_seating(seating, n)
    return seating ~= nil and not (seating == "sides" and n == 4)
end

function Game.new(player_count, starting_life, seating)
    if not is_int(player_count) or player_count < MIN_PLAYERS or player_count > MAX_PLAYERS then
        error("player_count must be an integer from 2 to 6", 2)
    end
    if not is_int(starting_life) or starting_life < 1 then
        error("starting_life must be an integer >= 1", 2)
    end
    if bad_seating(seating, player_count) then error("seating 'sides' needs 4 players", 2) end
    local self = setmetatable({ player_count = player_count, starting_life = starting_life, seating = seating, players = {} }, Game)
    for i = 1, player_count do
        self.players[i] = { life = starting_life, poison = 0, cmd = {} }
    end
    return self
end

function Game:adjust_life(i, delta)
    self.players[i].life = self.players[i].life + delta
end

function Game:adjust_poison(i, delta)
    local p = self.players[i]
    p.poison = math.max(0, p.poison + delta)
end

function Game:adjust_commander(target, source, delta)
    if target == source then error("a player cannot deal commander damage to self", 2) end
    local p = self.players[target]
    local before = p.cmd[source] or 0
    local after = math.max(0, before + delta)
    local applied = after - before
    p.cmd[source] = after
    p.life = p.life - applied
    return applied
end

function Game:status(i)
    local p = self.players[i]
    if p.life <= 0 then return "life" end
    if p.poison >= POISON_LETHAL then return "poison" end
    for _, dmg in pairs(p.cmd) do
        if dmg >= COMMANDER_LETHAL then return "commander" end
    end
    return nil
end

function Game:to_table()
    local t = { player_count = self.player_count, starting_life = self.starting_life, seating = self.seating, players = {} }
    for i = 1, self.player_count do
        local p = self.players[i]
        local cmd = {}
        for src, dmg in pairs(p.cmd) do cmd[src] = dmg end
        t.players[i] = { life = p.life, poison = p.poison, cmd = cmd }
    end
    return t
end

function Game.from_table(t)
    if type(t) ~= "table" then return nil, "not a table" end
    local n, sl = t.player_count, t.starting_life
    if not is_int(n) or n < MIN_PLAYERS or n > MAX_PLAYERS then return nil, "bad player_count" end
    if not is_int(sl) or sl < 1 then return nil, "bad starting_life" end
    if type(t.players) ~= "table" then return nil, "no players" end
    if bad_seating(t.seating, n) then return nil, "bad seating" end
    local self = setmetatable({ player_count = n, starting_life = sl, seating = t.seating, players = {} }, Game)
    for i = 1, n do
        local p = t.players[i]
        if type(p) ~= "table" then return nil, "missing player " .. i end
        if not is_int(p.life) then return nil, "bad life" end
        if not is_int(p.poison) or p.poison < 0 then return nil, "bad poison" end
        local cmd = {}
        if type(p.cmd) ~= "table" then return nil, "bad cmd" end
        for src, dmg in pairs(p.cmd) do
            if not is_int(src) or src < 1 or src > n or src == i then return nil, "bad cmd source" end
            if not is_int(dmg) or dmg < 0 then return nil, "bad cmd damage" end
            cmd[src] = dmg
        end
        self.players[i] = { life = p.life, poison = p.poison, cmd = cmd }
    end
    return self
end

return Game
