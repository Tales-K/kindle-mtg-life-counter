-- Acesso a arquivos usado pelo atualizador. Usa o shell (mkdir/find/rm) para ficar
-- testavel no PC e funcionar no busybox do Kindle. Caminhos com aspas ou quebra de linha sao recusados.

local Fs = {}

local function safe(path)
    return type(path) == "string" and path ~= "" and not path:find("['\n\r%z]")
end

local function sh(cmd)
    local ok = os.execute(cmd)
    return ok == true or ok == 0
end

local function dirname(path)
    return path:match("^(.*)/[^/]*$")
end

function Fs.read(path)
    if not safe(path) then return nil end
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

function Fs.write(path, data)
    if not safe(path) then return nil, "unsafe path" end
    local dir = dirname(path)
    if dir and dir ~= "" and not sh("mkdir -p '" .. dir .. "'") then return nil, "mkdir failed" end
    local f, err = io.open(path, "wb")
    if not f then return nil, err end
    local w, werr = f:write(data)
    local c, cerr = f:close()
    if not w or not c then return nil, werr or cerr or "write failed" end
    return true
end

function Fs.remove(path)
    if not safe(path) then return nil end
    os.remove(path)
    return true
end

function Fs.remove_tree(path)
    if not safe(path) then return nil end
    if not sh("rm -rf '" .. path .. "'") then return nil end
    return true
end

function Fs.exists(path)
    if not safe(path) then return false end
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

function Fs.list(dir)
    local out = {}
    if not safe(dir) then return out end
    local p = io.popen("find '" .. dir .. "' -type f 2>/dev/null")
    if not p then return out end
    local prefix = dir .. "/"
    for line in p:lines() do
        if line:sub(1, #prefix) == prefix then out[#out + 1] = line:sub(#prefix + 1) end
    end
    p:close()
    table.sort(out)
    return out
end

return Fs
