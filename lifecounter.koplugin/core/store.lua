local VERSION = 1

local Store = {}
Store.__index = Store

function Store.new(path)
    return setmetatable({ path = path }, Store)
end

local function serialize(v)
    local tv = type(v)
    if tv == "number" then
        return string.format("%d", v)
    elseif tv == "boolean" then
        return tostring(v)
    elseif tv == "string" then
        return string.format("%q", v)
    elseif tv == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v[k])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("cannot serialize " .. tv)
end

function Store:save(t)
    local ok, body = pcall(serialize, t)
    if not ok then return nil, tostring(body) end
    local content = "return {version=" .. VERSION .. ",data=" .. body .. "}\n"
    local tmp = self.path .. ".tmp"
    local f, err = io.open(tmp, "wb")
    if not f then return nil, err end
    local wrote, werr = f:write(content)
    local closed, cerr = f:close()
    if not wrote or not closed then
        os.remove(tmp)
        return nil, werr or cerr or "write failed"
    end
    local renamed, rerr = os.rename(tmp, self.path)
    if not renamed then
        os.remove(tmp)
        return nil, rerr
    end
    return true
end

function Store:load()
    local f = io.open(self.path, "rb")
    if not f then return nil, "missing" end
    local content = f:read("*a")
    f:close()

    local chunk = loadstring(content, "=state")
    local ok, result
    if chunk then
        setfenv(chunk, {})
        ok, result = pcall(chunk)
    end
    if not chunk or not ok or type(result) ~= "table" or type(result.data) ~= "table" then
        os.rename(self.path, self.path .. ".corrupt")
        return nil, "corrupt"
    end
    if result.version ~= VERSION then
        return nil, "version"
    end
    return result.data
end

return Store
