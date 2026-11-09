-- Atalho na biblioteca do Kindle: copia o "scriptlet" do plugin (um .sh que o Universal
-- Hotfix mostra como livro) para /mnt/us/documents. Instala uma vez; se o dono apagar,
-- nao volta (fica um marcador). Se a copia ainda existe e o plugin trouxe outra versao, troca.
-- So usa funcoes de core/fs que ja existiam (fs.lua e protegido e nao muda pela atualizacao).
local M = {}

M.NAME = "contador-mtg.sh"

local function is_dir(path)
    if type(path) ~= "string" or path:find("['\n\r%z]") then return false end
    local ok = os.execute("test -d '" .. path .. "'")
    return ok == true or ok == 0
end

function M.install(fs, src, docs_dir, marker)
    local body = fs.read(src)
    if not body then return "no_source" end
    if not is_dir(docs_dir) then return "no_documents" end
    local dst = docs_dir .. "/" .. M.NAME
    local current = fs.read(dst)
    if current then
        if current == body then return "skipped" end
        if not fs.write(dst, body) then return "failed" end
        return "updated"
    end
    if fs.exists(marker) then return "skipped" end
    if not fs.write(dst, body) then return "failed" end
    fs.write(marker, "1")
    return "installed"
end

return M
