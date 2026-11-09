local H = { passed = 0, failed = 0, current_file = "?" }

local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. show(v[k]) end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function H.eq(actual, expected)
    if not equal(actual, expected) then
        error("esperado " .. show(expected) .. ", obtido " .. show(actual), 2)
    end
end

function H.raises(fn, pattern)
    local ok, err = pcall(fn)
    if ok then error("esperava erro, mas nao houve", 2) end
    if pattern and not tostring(err):find(pattern, 1, true) then
        error("erro '" .. tostring(err) .. "' nao contem '" .. pattern .. "'", 2)
    end
end

function H.test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        H.passed = H.passed + 1
        print("ok   " .. name)
    else
        H.failed = H.failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

return H
