-- Atualizador: checa o manifesto, baixa e confere os arquivos, troca com backup e reverte.
-- Todas as dependencias (rede, disco, hash, json) sao injetadas para poder testar no PC.

local PROTECTED = {
    ["main.lua"] = true, ["_meta.lua"] = true,
    ["core/updater.lua"] = true, ["core/fs.lua"] = true,
    ["config.lua"] = true, ["pending.marker"] = true,
}

local function is_int(v) return type(v) == "number" and v == math.floor(v) end

local function safe_path(path)
    if type(path) ~= "string" or path == "" then return false, "empty path" end
    if path:find("\\", 1, true) or path:sub(1, 1) == "/" then return false, "bad path " .. path end
    for part in (path .. "/"):gmatch("(.-)/") do
        if part == "" or part == "." or part == ".." then return false, "bad path " .. path end
    end
    if PROTECTED[path] or path == "version.txt" then return false, "protected path " .. path end
    return true
end

local function validate_manifest(m)
    if type(m) ~= "table" then return false, "manifest is not a table" end
    if not is_int(m.version) or m.version < 1 then return false, "bad version" end
    if type(m.files) ~= "table" or #m.files == 0 then return false, "no files" end
    local seen = {}
    for _, f in ipairs(m.files) do
        if type(f) ~= "table" then return false, "bad file entry" end
        local ok, err = safe_path(f.path)
        if not ok then return false, err end
        if seen[f.path] then return false, "duplicate path " .. f.path end
        seen[f.path] = true
        if type(f.sha256) ~= "string" or f.sha256 == "" then return false, "bad sha256" end
        if not is_int(f.size) or f.size < 0 then return false, "bad size" end
    end
    return true
end

local Updater = {}
Updater.__index = Updater
Updater.PROTECTED = PROTECTED

function Updater.new(o)
    return setmetatable({
        base_url = o.base_url, token = o.token,
        plugin_dir = o.plugin_dir, backup_dir = o.backup_dir, staging_dir = o.staging_dir,
        fs = o.fs, sha256 = o.sha256, json_decode = o.json_decode, http_get = o.http_get,
    }, Updater)
end

function Updater:_marker() return self.plugin_dir .. "/pending.marker" end
function Updater:_headers() return { Authorization = "Bearer " .. self.token } end

function Updater:current_version()
    local s = self.fs.read(self.plugin_dir .. "/version.txt")
    return tonumber(s and s:match("^%s*(%d+)")) or 0
end

function Updater:check()
    local body, err = self.http_get(self.base_url .. "manifest.json", self:_headers())
    if not body then return { state = "error", err = err or "no response" } end
    local m = self.json_decode(body)
    local ok, verr = validate_manifest(m)
    if not ok then return { state = "error", err = verr } end
    local current = self:current_version()
    if m.version > current then
        return { state = "available", version = m.version, manifest = m }
    end
    return { state = "up_to_date", version = current }
end

function Updater:_managed(dir)
    local out = {}
    for _, rel in ipairs(self.fs.list(dir)) do
        if not PROTECTED[rel] then out[#out + 1] = rel end
    end
    return out
end

-- Deixa plugin_dir igual ao backup (arquivos protegidos ficam como estao).
function Updater:_restore()
    local fs = self.fs
    local keep = {}
    for _, rel in ipairs(self:_managed(self.backup_dir)) do keep[rel] = true end
    for _, rel in ipairs(self:_managed(self.plugin_dir)) do
        if not keep[rel] then fs.remove(self.plugin_dir .. "/" .. rel) end
    end
    for rel in pairs(keep) do
        fs.write(self.plugin_dir .. "/" .. rel, fs.read(self.backup_dir .. "/" .. rel))
    end
end

function Updater:install(manifest)
    local ok, verr = validate_manifest(manifest)
    if not ok then return nil, verr end
    local fs = self.fs
    local function fail(err)
        fs.remove_tree(self.staging_dir)
        return nil, err
    end

    fs.remove_tree(self.staging_dir)
    for _, f in ipairs(manifest.files) do
        local body, err = self.http_get(self.base_url .. f.path, self:_headers())
        if not body then return fail("download " .. f.path .. ": " .. tostring(err)) end
        if #body ~= f.size then return fail("size mismatch " .. f.path) end
        if self.sha256(body) ~= f.sha256 then return fail("hash mismatch " .. f.path) end
        local w, werr = fs.write(self.staging_dir .. "/" .. f.path, body)
        if not w then return fail("staging " .. f.path .. ": " .. tostring(werr)) end
    end

    fs.remove_tree(self.backup_dir)
    for _, rel in ipairs(self:_managed(self.plugin_dir)) do
        local w, werr = fs.write(self.backup_dir .. "/" .. rel, fs.read(self.plugin_dir .. "/" .. rel))
        if not w then
            fs.remove_tree(self.backup_dir)
            return fail("backup " .. rel .. ": " .. tostring(werr))
        end
    end

    local mw, merr = fs.write(self:_marker(), "0")
    if not mw then return fail("marker: " .. tostring(merr)) end

    local function swap()
        local wanted = {}
        for _, f in ipairs(manifest.files) do
            wanted[f.path] = true
            local w, err = fs.write(self.plugin_dir .. "/" .. f.path, fs.read(self.staging_dir .. "/" .. f.path))
            if not w then return nil, "swap " .. f.path .. ": " .. tostring(err) end
        end
        for _, rel in ipairs(self:_managed(self.plugin_dir)) do
            if not wanted[rel] and rel ~= "version.txt" then fs.remove(self.plugin_dir .. "/" .. rel) end
        end
        local w, err = fs.write(self.plugin_dir .. "/version.txt", tostring(manifest.version))
        if not w then return nil, "version: " .. tostring(err) end
        return true
    end

    local sok, serr = swap()
    if not sok then
        self:_restore()
        fs.remove(self:_marker())
        return fail(serr)
    end
    fs.remove_tree(self.staging_dir)
    return true
end

function Updater:mark_boot_ok()
    self.fs.remove(self:_marker())
end

function Updater:rollback()
    local fs = self.fs
    local has_backup = #self:_managed(self.backup_dir) > 0
    if has_backup then self:_restore() end
    fs.remove(self:_marker())
    return has_backup
end

-- Chamado UMA vez por processo do KOReader (nao a cada instancia do plugin).
-- load_app() tenta carregar o app e devolve true se deu certo.
-- Devolve: "none" | "confirmed" | "rolled_back" (boot anterior nao terminou) | "rolled_back_now" (app novo nao carregou).
function Updater:boot_check(load_app)
    local m = self.fs.read(self:_marker())
    if not m then return "none" end
    if m:match("^1") then
        return self:rollback() and "rolled_back" or "none"
    end
    self.fs.write(self:_marker(), "1")
    if load_app() then
        self:mark_boot_ok()
        return "confirmed"
    end
    self:rollback()
    return "rolled_back_now"
end

return Updater
