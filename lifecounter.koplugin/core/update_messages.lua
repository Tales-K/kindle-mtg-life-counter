-- Traduz erros do atualizador em mensagens curtas para o jogador, no idioma atual.
local I18n = require("core.i18n")

local M = {}

local function has(err, needle) return err:find(needle, 1, true) ~= nil end

function M.describe(err)
    local t = I18n.t
    if err == nil then return t("err_unknown") end
    err = tostring(err)
    if err == "no config" then return t("err_no_config") end
    if err == "401" or err == "403" then return t("err_token") end
    if has(err, "certificate") or has(err, "handshake") or has(err, "ssl") then
        return t("err_cert")
    end
    if has(err, "hash mismatch") or has(err, "size mismatch") then
        return t("err_bad_file")
    end
    if has(err, "bad path") or has(err, "protected path") or has(err, "bad version")
        or has(err, "no files") or has(err, "bad sha256") or has(err, "bad size")
        or has(err, "duplicate path") or has(err, "manifest") or has(err, "empty path") then
        return t("err_bad_update")
    end
    if has(err, "timeout") or has(err, "refused") or has(err, "not known") or has(err, "closed")
        or has(err, "unreachable") or has(err, "network") or has(err, "no response") then
        return t("err_network")
    end
    return t("err_generic", { err = err })
end

return M
