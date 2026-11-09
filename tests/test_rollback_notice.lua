local H = require("helper")
local Fs = require("core.fs")
local Notice = require("core.rollback_notice")

local function tmpdir()
    local p = io.popen("mktemp -d")
    local d = p:read("*l")
    p:close()
    return d
end

local function setup(plugin_version, backup_version)
    local d = tmpdir()
    local plugin, backup = d .. "/plugin", d .. "/backup"
    Fs.write(plugin .. "/version.txt", plugin_version)
    Fs.write(plugin .. "/app.lua", "return {}")
    if backup_version then
        Fs.write(backup .. "/version.txt", backup_version)
        Fs.write(backup .. "/app.lua", "return {}")
    end
    return plugin, backup
end

H.test("rollback notice: backup with the same version as the plugin means the update was undone", function()
    local plugin, backup = setup("2", "2")
    H.eq(Notice.take(Fs, plugin, backup), true)
end)

H.test("rollback notice is reported only once (backup is cleared)", function()
    local plugin, backup = setup("2", "2")
    Notice.take(Fs, plugin, backup)
    H.eq(Fs.exists(backup .. "/version.txt"), false)
    H.eq(Notice.take(Fs, plugin, backup), false)
end)

H.test("rollback notice: a successful update (plugin newer than backup) is not a rollback and keeps the backup", function()
    local plugin, backup = setup("3", "2")
    H.eq(Notice.take(Fs, plugin, backup), false)
    H.eq(Fs.exists(backup .. "/version.txt"), true)
end)

H.test("rollback notice: no backup means nothing to report", function()
    local plugin, backup = setup("2", nil)
    H.eq(Notice.take(Fs, plugin, backup), false)
end)

H.test("rollback notice tolerates whitespace in version files", function()
    local plugin, backup = setup("2\n", " 2 ")
    H.eq(Notice.take(Fs, plugin, backup), true)
end)
