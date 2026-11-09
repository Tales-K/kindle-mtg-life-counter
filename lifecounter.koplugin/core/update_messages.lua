-- Traduz erros do atualizador em mensagens curtas para o jogador.
local M = {}

local function has(err, needle) return err:find(needle, 1, true) ~= nil end

function M.describe(err)
    if err == nil then return "Falha desconhecida." end
    err = tostring(err)
    if err == "no config" then return "Falta o arquivo config.lua com a URL e o token." end
    if err == "401" or err == "403" then return "Token recusado pelo servidor." end
    if has(err, "certificate") or has(err, "handshake") or has(err, "ssl") then
        return "Erro de certificado HTTPS. Confira a hora do Kindle."
    end
    if has(err, "hash mismatch") or has(err, "size mismatch") then
        return "Arquivo da atualizacao invalido. Nada foi alterado."
    end
    if has(err, "bad path") or has(err, "protected path") or has(err, "bad version")
        or has(err, "no files") or has(err, "bad sha256") or has(err, "bad size")
        or has(err, "duplicate path") or has(err, "manifest") or has(err, "empty path") then
        return "Atualizacao invalida. Nada foi alterado."
    end
    if has(err, "timeout") or has(err, "refused") or has(err, "not known") or has(err, "closed")
        or has(err, "unreachable") or has(err, "network") or has(err, "no response") then
        return "Sem rede ou servidor fora do ar."
    end
    return "Falha: " .. err
end

return M
