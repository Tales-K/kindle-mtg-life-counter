local H = require("helper")
local Updater = require("core.updater")

local function fake_fs(files)
    local fs = { files = files or {}, fail_paths = {} }
    function fs.read(p) return fs.files[p] end
    function fs.write(p, d)
        if fs.fail_paths[p] then return nil, "disk full" end
        fs.files[p] = d
        return true
    end
    function fs.remove(p) fs.files[p] = nil; return true end
    function fs.remove_tree(prefix)
        for k in pairs(fs.files) do
            if k:sub(1, #prefix + 1) == prefix .. "/" then fs.files[k] = nil end
        end
        return true
    end
    function fs.exists(p) return fs.files[p] ~= nil end
    function fs.list(dir)
        local out = {}
        for k in pairs(fs.files) do
            if k:sub(1, #dir + 1) == dir .. "/" then out[#out + 1] = k:sub(#dir + 2) end
        end
        table.sort(out)
        return out
    end
    return fs
end

local function sha(s) return "sum:" .. s end

local function setup(opts)
    opts = opts or {}
    local fs = fake_fs({
        ["/p/main.lua"] = "MAIN",
        ["/p/_meta.lua"] = "META",
        ["/p/core/updater.lua"] = "UPD",
        ["/p/core/fs.lua"] = "FS",
        ["/p/config.lua"] = "TOKEN",
        ["/p/core/game.lua"] = "old game",
        ["/p/ui/old.lua"] = "old ui",
        ["/p/version.txt"] = "1",
    })
    local server = { ["https://x/v1/core/game.lua"] = "new game", ["https://x/v1/app.lua"] = "new app" }
    local manifest = {
        version = 2,
        files = {
            { path = "core/game.lua", sha256 = sha("new game"), size = 8 },
            { path = "app.lua", sha256 = sha("new app"), size = 7 },
        },
    }
    local decoded = {}
    local calls = {}
    local u = Updater.new({
        base_url = "https://x/v1/", token = "SECRET",
        plugin_dir = "/p", backup_dir = "/b", staging_dir = "/s",
        fs = fs, sha256 = sha,
        json_decode = function(s) return decoded[s] end,
        http_get = function(url, headers)
            calls[#calls + 1] = { url = url, headers = headers }
            if url == "https://x/v1/manifest.json" then
                if opts.manifest_error then return nil, opts.manifest_error end
                return "MANIFEST", nil
            end
            local body = server[url]
            if not body then return nil, "404" end
            return body
        end,
    })
    decoded["MANIFEST"] = manifest
    return u, fs, server, manifest, decoded, calls
end

H.test("current_version reads version.txt and defaults to 0", function()
    local u, fs = setup()
    H.eq(u:current_version(), 1)
    fs.files["/p/version.txt"] = nil
    H.eq(u:current_version(), 0)
end)

H.test("check reports available with a newer version", function()
    local u = setup()
    local r = u:check()
    H.eq(r.state, "available")
    H.eq(r.version, 2)
    H.eq(r.manifest.version, 2)
end)

H.test("check reports up_to_date when versions are equal", function()
    local u, _, _, m = setup()
    m.version = 1
    H.eq(u:check().state, "up_to_date")
end)

H.test("check treats a lower server version as up_to_date", function()
    local u, _, _, m = setup()
    m.version = 0
    local r = u:check()
    H.eq(r.state == "up_to_date" or r.state == "error", true)
    H.eq(r.state ~= "available", true)
end)

H.test("check sends Authorization Bearer header and never puts the token in the url", function()
    local u, _, _, _, _, calls = setup()
    u:check()
    H.eq(calls[1].headers.Authorization, "Bearer SECRET")
    H.eq(calls[1].url:find("SECRET", 1, true), nil)
end)

H.test("check returns error on http failure and on bad json", function()
    local u = setup({ manifest_error = "401" })
    local r = u:check()
    H.eq(r.state, "error")
    H.eq(r.err, "401")
    local u2, _, _, _, decoded = setup()
    decoded["MANIFEST"] = nil
    H.eq(u2:check().state, "error")
end)

H.test("check returns error on a manifest with no files or bad version", function()
    local u, _, _, m = setup()
    m.files = {}
    H.eq(u:check().state, "error")
    local u2, _, _, m2 = setup()
    m2.version = "2"
    H.eq(u2:check().state, "error")
end)

H.test("install rejects dangerous or protected manifest paths", function()
    local bad = { "../x.lua", "/abs.lua", "a\\b.lua", "a/../b.lua", "./x.lua", "a//b.lua", "",
        "config.lua", "main.lua", "_meta.lua", "core/updater.lua", "core/fs.lua", "version.txt", "pending.marker" }
    for _, path in ipairs(bad) do
        local u, fs, _, m = setup()
        m.files[#m.files + 1] = { path = path, sha256 = sha("x"), size = 1 }
        local ok, err = u:install(m)
        H.eq(ok, nil)
        H.eq(type(err), "string")
        H.eq(fs.files["/p/core/game.lua"], "old game")
        H.eq(fs.files["/p/config.lua"], "TOKEN")
    end
end)

H.test("install aborts when a file is missing from the server", function()
    local u, fs, server, m = setup()
    server["https://x/v1/app.lua"] = nil
    local ok, err = u:install(m)
    H.eq(ok, nil)
    H.eq(fs.files["/p/core/game.lua"], "old game")
    H.eq(fs.files["/p/version.txt"], "1")
    H.eq(fs.files["/p/pending.marker"], nil)
end)

H.test("install aborts when a file is truncated", function()
    local u, fs, server, m = setup()
    server["https://x/v1/app.lua"] = "new ap"
    local ok = u:install(m)
    H.eq(ok, nil)
    H.eq(fs.files["/p/core/game.lua"], "old game")
    H.eq(fs.files["/p/app.lua"], nil)
end)

H.test("install aborts and leaves plugin_dir untouched when a hash differs", function()
    local u, fs, server, m = setup()
    server["https://x/v1/app.lua"] = "evil app"
    m.files[2].size = 8
    local ok, err = u:install(m)
    H.eq(ok, nil)
    H.eq(fs.files["/p/core/game.lua"], "old game")
    H.eq(fs.files["/p/app.lua"], nil)
    H.eq(fs.files["/p/version.txt"], "1")
end)

H.test("install swaps files, removes stale ones, keeps protected ones and writes marker and version", function()
    local u, fs, _, m = setup()
    H.eq(u:install(m), true)
    H.eq(fs.files["/p/core/game.lua"], "new game")
    H.eq(fs.files["/p/app.lua"], "new app")
    H.eq(fs.files["/p/ui/old.lua"], nil)
    H.eq(fs.files["/p/main.lua"], "MAIN")
    H.eq(fs.files["/p/config.lua"], "TOKEN")
    H.eq(fs.files["/p/version.txt"], "2")
    H.eq(fs.files["/p/pending.marker"], "0")
    H.eq(fs.files["/b/core/game.lua"], "old game")
    H.eq(fs.files["/b/ui/old.lua"], "old ui")
    H.eq(fs.files["/b/config.lua"], nil)
    H.eq(fs.list("/s"), {})
end)

H.test("install cleans leftovers in staging first", function()
    local u, fs, _, m = setup()
    fs.files["/s/leftover.lua"] = "junk"
    H.eq(u:install(m), true)
    H.eq(fs.files["/s/leftover.lua"], nil)
    H.eq(fs.files["/p/leftover.lua"], nil)
end)

H.test("install that fails halfway restores the old version", function()
    local u, fs, _, m = setup()
    fs.fail_paths["/p/app.lua"] = true
    local ok, err = u:install(m)
    H.eq(ok, nil)
    H.eq(fs.files["/p/core/game.lua"], "old game")
    H.eq(fs.files["/p/ui/old.lua"], "old ui")
    H.eq(fs.files["/p/version.txt"], "1")
    H.eq(fs.files["/p/app.lua"], nil)
    H.eq(fs.files["/p/pending.marker"], nil)
    H.eq(fs.files["/p/config.lua"], "TOKEN")
end)

H.test("mark_boot_ok removes the marker", function()
    local u, fs, _, m = setup()
    u:install(m)
    u:mark_boot_ok()
    H.eq(fs.files["/p/pending.marker"], nil)
    H.eq(fs.files["/p/core/game.lua"], "new game")
end)

H.test("boot_check does nothing without a marker and never loads the app", function()
    local u, fs = setup()
    local loaded = 0
    H.eq(u:boot_check(function() loaded = loaded + 1; return true end), "none")
    H.eq(loaded, 0)
    H.eq(fs.files["/p/core/game.lua"], "old game")
end)

H.test("boot_check confirms a good first boot: marker is 1 while loading, then removed", function()
    local u, fs, _, m = setup()
    u:install(m)
    local seen
    local result = u:boot_check(function() seen = fs.files["/p/pending.marker"]; return true end)
    H.eq(result, "confirmed")
    H.eq(seen, "1")
    H.eq(fs.files["/p/pending.marker"], nil)
    H.eq(fs.files["/p/core/game.lua"], "new game")
    H.eq(fs.files["/p/version.txt"], "2")
end)

H.test("boot_check rolls back right away when the new app fails to load", function()
    local u, fs, _, m = setup()
    u:install(m)
    H.eq(u:boot_check(function() return false end), "rolled_back_now")
    H.eq(fs.files["/p/core/game.lua"], "old game")
    H.eq(fs.files["/p/ui/old.lua"], "old ui")
    H.eq(fs.files["/p/app.lua"], nil)
    H.eq(fs.files["/p/version.txt"], "1")
    H.eq(fs.files["/p/pending.marker"], nil)
    H.eq(fs.files["/p/config.lua"], "TOKEN")
end)

H.test("boot_check rolls back when a previous boot never finished (marker 1)", function()
    local u, fs, _, m = setup()
    u:install(m)
    fs.files["/p/pending.marker"] = "1"
    local loaded = 0
    H.eq(u:boot_check(function() loaded = loaded + 1; return true end), "rolled_back")
    H.eq(loaded, 0)
    H.eq(fs.files["/p/core/game.lua"], "old game")
    H.eq(fs.files["/p/pending.marker"], nil)
end)

H.test("boot_check with a stale marker and no backup clears it and reports none", function()
    local u, fs = setup()
    fs.files["/p/pending.marker"] = "1"
    H.eq(u:boot_check(function() return true end), "none")
    H.eq(fs.files["/p/pending.marker"], nil)
    H.eq(fs.files["/p/core/game.lua"], "old game")
end)

H.test("a second boot_check in the same run after a confirmed boot does nothing", function()
    local u, fs, _, m = setup()
    u:install(m)
    H.eq(u:boot_check(function() return true end), "confirmed")
    H.eq(u:boot_check(function() return true end), "none")
    H.eq(fs.files["/p/core/game.lua"], "new game")
end)

H.test("rollback restores immediately when called by the loader", function()
    local u, fs, _, m = setup()
    u:install(m)
    H.eq(u:rollback(), true)
    H.eq(fs.files["/p/core/game.lua"], "old game")
    H.eq(fs.files["/p/pending.marker"], nil)
end)

H.test("rollback without a backup does nothing and clears the marker", function()
    local u, fs = setup()
    fs.files["/p/pending.marker"] = "1"
    H.eq(u:rollback(), false)
    H.eq(fs.files["/p/pending.marker"], nil)
    H.eq(fs.files["/p/core/game.lua"], "old game")
end)
