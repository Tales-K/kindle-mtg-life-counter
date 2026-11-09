-- Descobre se a ultima atualizacao foi desfeita (rollback), para avisar o jogador uma vez.
-- Depois de um rollback o plugin volta a ter a mesma versao do backup; depois de uma
-- atualizacao boa o plugin fica mais novo que o backup. Ao avisar, o backup (agora igual
-- a versao atual, sem utilidade) e apagado, entao o aviso aparece so uma vez.
local M = {}

local function version_at(fs, dir)
    local s = fs.read(dir .. "/version.txt")
    return tonumber(s and s:match("^%s*(%d+)"))
end

function M.take(fs, plugin_dir, backup_dir)
    local backup = version_at(fs, backup_dir)
    if not backup or backup ~= version_at(fs, plugin_dir) then return false end
    fs.remove_tree(backup_dir)
    return true
end

return M
