-- Registro do modo debug: as ultimas linhas na memoria (para a barra na tela) e todas num arquivo,
-- uma escrita por linha (abre, acrescenta, fecha), para sobreviver a um travamento e ser lido
-- depois. O arquivo e cortado (fica so com as ultimas linhas) quando passa de max_bytes.
-- Relogio e formato injetados (testavel).
local Log = {}
Log.__index = Log

function Log.hms(t)
    t = math.floor(t) % 86400
    return string.format("%02d:%02d:%02d", math.floor(t / 3600), math.floor(t / 60) % 60, t % 60)
end

function Log.new(o)
    return setmetatable({
        max = o.max or 50, clock = o.clock or os.time,
        fmt = o.fmt or function(t) return os.date("%H:%M:%S", math.floor(t)) end,
        fs = o.fs, path = o.path, max_bytes = o.max_bytes or 256 * 1024,
        lines = {}, size = nil,
    }, Log)
end

local function push(self, line)
    self.lines[#self.lines + 1] = line
    if #self.lines > self.max then table.remove(self.lines, 1) end
end

-- Traz as ultimas linhas do arquivo (da execucao anterior, por exemplo a que travou).
function Log:load()
    if not (self.fs and self.path) then return end
    local s = self.fs.read(self.path)
    if not s then return end
    self.size = #s
    for line in s:gmatch("[^\n]+") do push(self, line) end
end

function Log:add(text)
    local line = self.fmt(self.clock()) .. " " .. text
    push(self, line)
    if not (self.fs and self.path) then return line end
    if self.size == nil then
        local s = self.fs.read(self.path)
        self.size = s and #s or 0
    end
    local f = io.open(self.path, "a")
    if f then
        f:write(line, "\n")
        f:close()
        self.size = self.size + #line + 1
    end
    if self.size > self.max_bytes then
        local body = table.concat(self.lines, "\n") .. "\n"
        self.fs.write(self.path, body)
        self.size = #body
    end
    return line
end

function Log:last(n)
    local out = {}
    for i = math.max(1, #self.lines - n + 1), #self.lines do out[#out + 1] = self.lines[i] end
    return out
end

function Log.load_enabled(fs, path)
    local s = fs.read(path)
    return s ~= nil and s:match("^%s*on") ~= nil
end

function Log.save_enabled(fs, path, on)
    return fs.write(path, on and "on" or "off") == true
end

return Log
