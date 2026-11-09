local H = require("helper")
local M = require("core.update_messages")

H.test("describe maps 401 and 403 to token refused", function()
    H.eq(M.describe("401"), "Token recusado pelo servidor.")
    H.eq(M.describe("403"), "Token recusado pelo servidor.")
end)

H.test("describe maps network failures to no network", function()
    for _, e in ipairs({ "timeout", "connection refused", "host or service not provided, or not known", "closed" }) do
        H.eq(M.describe(e), "Sem rede ou servidor fora do ar.")
    end
end)

H.test("describe maps certificate problems and mentions the clock", function()
    local msg = M.describe("certificate verify failed")
    H.eq(msg:find("certificado", 1, true) ~= nil, true)
    H.eq(msg:find("hora", 1, true) ~= nil, true)
end)

H.test("describe maps hash and size mismatches to invalid file", function()
    H.eq(M.describe("hash mismatch core/game.lua"), "Arquivo da atualizacao invalido. Nada foi alterado.")
    H.eq(M.describe("size mismatch app.lua"), "Arquivo da atualizacao invalido. Nada foi alterado.")
end)

H.test("describe maps bad manifest and bad paths to invalid update", function()
    H.eq(M.describe("bad path ../x"), "Atualizacao invalida. Nada foi alterado.")
    H.eq(M.describe("protected path main.lua"), "Atualizacao invalida. Nada foi alterado.")
    H.eq(M.describe("bad version"), "Atualizacao invalida. Nada foi alterado.")
end)

H.test("describe maps a missing config to a setup hint", function()
    H.eq(M.describe("no config"), "Falta o arquivo config.lua com a URL e o token.")
end)

H.test("describe falls back to the raw text and survives nil", function()
    H.eq(M.describe("algo estranho"), "Falha: algo estranho")
    H.eq(M.describe(nil), "Falha desconhecida.")
end)
