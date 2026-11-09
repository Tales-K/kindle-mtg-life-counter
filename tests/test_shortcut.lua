local H = require("helper")
local Fs = require("core.fs")
local Shortcut = require("core.shortcut")

local function tmpdir()
    local p = io.popen("mktemp -d")
    local d = p:read("*l")
    p:close()
    return d
end

local function setup()
    local d = tmpdir()
    local o = {
        src = d .. "/plugin/shortcut/contador-mtg.sh",
        docs = d .. "/documents",
        marker = d .. "/settings/lifecounter_shortcut",
    }
    Fs.write(o.src, "#!/bin/sh\n# Name: Contador MTG\n")
    Fs.write(o.docs .. "/.keep", "")
    return o
end

H.test("shortcut: copies the scriptlet into documents the first time", function()
    local o = setup()
    H.eq(Shortcut.install(Fs, o.src, o.docs, o.marker), "installed")
    H.eq(Fs.read(o.docs .. "/contador-mtg.sh"), "#!/bin/sh\n# Name: Contador MTG\n")
end)

H.test("shortcut: does not come back after the owner deletes it", function()
    local o = setup()
    Shortcut.install(Fs, o.src, o.docs, o.marker)
    Fs.remove(o.docs .. "/contador-mtg.sh")
    H.eq(Shortcut.install(Fs, o.src, o.docs, o.marker), "skipped")
    H.eq(Fs.exists(o.docs .. "/contador-mtg.sh"), false)
end)

H.test("shortcut: a newer scriptlet replaces the installed copy if it is still there", function()
    local o = setup()
    Shortcut.install(Fs, o.src, o.docs, o.marker)
    Fs.write(o.src, "#!/bin/sh\n# Name: Contador MTG\n# v2\n")
    H.eq(Shortcut.install(Fs, o.src, o.docs, o.marker), "updated")
    H.eq(Fs.read(o.docs .. "/contador-mtg.sh"), "#!/bin/sh\n# Name: Contador MTG\n# v2\n")
end)

H.test("shortcut: nothing to do without a documents folder (not a Kindle)", function()
    local o = setup()
    H.eq(Shortcut.install(Fs, o.src, o.docs .. "-nao-existe", o.marker), "no_documents")
end)

H.test("shortcut: nothing to do when the plugin has no scriptlet", function()
    local o = setup()
    H.eq(Shortcut.install(Fs, o.src .. ".nada", o.docs, o.marker), "no_source")
end)
