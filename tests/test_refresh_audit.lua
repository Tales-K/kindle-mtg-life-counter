-- No KOReader, UIManager:show(w) / UIManager:close(w) sem tipo de refresh so redesenham na
-- memoria: o e-ink atualiza apenas a area que outra janela pedir (bug real no Kindle: ao abrir
-- uma tela cheia, so o pedaco da janelinha anterior mudava). Nem o emulador nem a captura pelo
-- inspector mostram isso, entao este teste exige o tipo de refresh em toda tela nossa.
-- InfoMessage e ConfirmBox ficam de fora: eles pedem o proprio refresh ao aparecer e sumir.
local H = require("helper")

local function lua_files()
    local p = io.popen("find lifecounter.koplugin -name '*.lua' | sort")
    local files = {}
    for f in p:lines() do files[#files + 1] = f end
    p:close()
    return files
end

H.test("every UIManager:show/close of our full-screen widgets asks for an e-ink refresh", function()
    local bad = {}
    for _, f in ipairs(lua_files()) do
        local n = 0
        for line in io.lines(f) do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            if code:find("UIManager:show%(") or code:find("UIManager:close%(") then
                local dialog = code:find("InfoMessage") or code:find("ConfirmBox")
                local has_type = code:find('UIManager:%a+%(.-,%s*"%a+"')
                if not dialog and not has_type then bad[#bad + 1] = f .. ":" .. n .. ": " .. code:gsub("^%s+", "") end
            end
        end
    end
    H.eq(bad, {})
end)
