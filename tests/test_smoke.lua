local H = require("helper")

H.test("smoke passes", function()
    H.eq(1 + 1, 2)
end)

H.test("eq fails on different tables", function()
    local ok = pcall(H.eq, { 1, 2 }, { 1, 3 })
    H.eq(ok, false)
end)

H.test("eq passes on equal nested tables", function()
    H.eq({ a = { 1, 2 }, b = "x" }, { a = { 1, 2 }, b = "x" })
end)
