package.path = "tests/?.lua;lifecounter.koplugin/?.lua;" .. package.path
local H = require("helper")

local p = io.popen("ls tests/test_*.lua 2>/dev/null")
local files = {}
for line in p:lines() do files[#files + 1] = line end
p:close()
table.sort(files)

for _, f in ipairs(files) do
    H.current_file = f
    local ok, err = pcall(dofile, f)
    if not ok then
        H.failed = H.failed + 1
        print("FAIL " .. f .. " (erro ao carregar): " .. tostring(err))
    end
end

print(string.format("\n%d ok, %d falhas", H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
