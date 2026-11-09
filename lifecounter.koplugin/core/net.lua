-- HTTP real para o atualizador (so KOReader). So aceita HTTPS.
local Net = {}

function Net.http_get(url, headers)
    if type(url) ~= "string" or not url:match("^https://") then return nil, "https required" end
    local https = require("ssl.https")
    local socketutil = require("socketutil")
    socketutil:set_timeout(10, 40)
    local sink = {}
    local ok, code = https.request{
        url = url, method = "GET", headers = headers,
        sink = socketutil.table_sink(sink),
    }
    socketutil:reset_timeout()
    if not ok then return nil, tostring(code) end
    if code ~= 200 then return nil, tostring(code) end
    return table.concat(sink)
end

function Net.json_decode(s)
    local ok, json = pcall(require, "json")
    if not ok then return nil end
    local ok2, value = pcall(json.decode, s)
    if ok2 then return value end
    return nil
end

return Net
