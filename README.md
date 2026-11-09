# Cryo MTG Life Counter for Kindle

**Cryo MTG Life Counter** is a **Magic: The Gathering** (Commander) life counter built as a plugin for
[KOReader](https://github.com/koreader/koreader) on a **jailbroken Kindle**.

The idea: put the Kindle in the middle of the table instead of a phone, with each player reading
their own panel facing their side. Inspired by LifeTap.

<p align="center">
  <img src="docs/img/seis-jogadores.png" width="270" alt="Game with 6 players">
  <img src="docs/img/dois-jogadores.png" width="270" alt="Game with 2 players, one knocked out by commander damage">
  <img src="docs/img/campo-dano.png" width="270" alt="Commander damage field of P4 on P1">
</p>

> Screenshots from the KOReader emulator at the Kindle screen size (1072 x 1448).

## Features

- **2 to 6 players**, with panels rotated to face each side of the table.
- **Tap** adds or subtracts 1; **hold** adds or subtracts 10.
- **Poison** per player: the drop with the number is always visible at the bottom of the panel;
  tap it to open the poison field (tap only, +/-1).
- **Commander damage** tracked separately per opponent: under each panel, a miniature of the table
  shows the damage taken from each opponent, in that opponent's position. Tap an opponent's little
  square to open a full-screen field facing the panel's owner, showing just that number
  (tap +/-1, hold +/-10). Damage removes the same life, and lowering it gives the life back.
- **Eliminated player** (0 life, 10 poison, or 21 damage from a single commander) turns into a black
  panel with a skull, and revives on its own if the number is corrected.
- **Game saved on every tap**: closing KOReader or running out of battery does not lose the game
  ("Continue game" on the start screen). "Back to main menu", in the in-game menu, returns to the
  start screen without erasing anything.
- **English or Portuguese** (English by default): on the start screen, tap the UK or Brazil flag.
  The choice is stored in `lifecounter_lang`, in KOReader's settings folder. Players are P1..P6 in
  English and J1..J6 in Portuguese.
- **"Exit"** closes KOReader and returns to the Kindle home screen.
- **Over-the-air updates** with the "Update" menu button (optional, see [below](#over-the-air-updates-optional-advanced)).
- Works offline: Wi-Fi is only needed to update.

## Installation

### Requirements

- A **jailbroken Kindle**, for example with WinterBreak or AdBreak (depending on your model and firmware)
  plus the **Universal Hotfix**. Step-by-step guides: <https://kindlemodding.org>.
- **KOReader** installed on the Kindle (the same guides cover it).
- **KUAL** (optional), only if you want a launcher entry.

### Step by step

1. **Download the project.** Clone it or download the zip from
   <https://github.com/Tales-K/kindle-mtg-life-counter>:

   ```bash
   git clone https://github.com/Tales-K/kindle-mtg-life-counter.git
   cd kindle-mtg-life-counter
   ```

2. **Copy the plugin to the Kindle.** Connect the Kindle by USB and copy the `lifecounter.koplugin`
   folder to `koreader/plugins/`, by hand or with the helper script:

   ```bash
   tools/push_to_kindle.sh --usb                    # default mount point: /media/$USER/Kindle
   tools/push_to_kindle.sh --usb /path/to/Kindle
   tools/push_to_kindle.sh --ssh user@IP 2222       # alternative: SSH enabled in KOReader
   ```

   The script uses `rsync`. In USB mode, if the Kindle has an `extensions/` folder (KUAL), it also
   copies `kual/lifecounter` there. It never sends or deletes the device's `config.lua`,
   `version.txt` and `pending.marker`.

   Expected layout on the Kindle:

   ```
   koreader/
     plugins/
       lifecounter.koplugin/
         main.lua
         _meta.lua
         app.lua
         config.example.lua
         core/
         ui/
         shortcut/
   extensions/            (only if you use KUAL)
     lifecounter/
       config.xml
       menu.json
       bin/launch.sh
   ```

3. **Eject and open KOReader once.** Eject the Kindle safely, then start KOReader. The app is at
   **Tools -> More tools -> Cryo MTG Life Counter**.

4. **Library shortcut.** On the first launch, the app installs a "book" named **Cryo MTG Life Counter**
   in the Kindle library (it copies `contador-mtg.sh` to `/mnt/us/documents`). This needs the
   **scriptlet** support from the Universal Hotfix. Tapping it opens KOReader directly in the counter,
   and **Exit** closes KOReader and returns to the Kindle home screen. If you delete the shortcut,
   it is not reinstalled.

5. **Optional extras:**
   - **KUAL:** the `kual/lifecounter` folder, copied to `extensions/` (the script does it in USB mode),
     adds a "Cryo MTG Life Counter" entry that opens KOReader already inside the counter.
   - **Gesture:** in KOReader, Settings -> Taps and gestures, bind a gesture to the
     **"Cryo MTG Life Counter"** action (Dispatcher).

## Quick usage

- **Panels:** tap the right half of a panel for +1 and the left half for -1 (from that player's side of the table); **hold** for +/-10.
- **Commander damage:** the little squares in the miniature are one per opponent. Tap one to open
  that opponent's field (single number). **21** from one commander eliminates the player.
- **Poison:** tap the drop. **10** eliminates the player.
- **Reviving:** lowering the number that caused the elimination brings the player back.
- **MENU** (center of the table): Back to game, Back to main menu, Restart game, New game, Exit.
- **Language:** pick the flag on the start screen (English by default).
- **Screen stays on:** the Kindle does not sleep during a game, until 30 minutes without a touch.
- **Saving:** the game is saved on every tap.

## Over-the-air updates (optional, advanced)

The "Update" button downloads a new version from your own Cloudflare Worker. The Worker
(`worker/src/index.js`) serves the files from `release/` as static assets and answers 401 to any
request without an `Authorization: Bearer <token>` header matching its `UPDATE_TOKEN` secret.
It only accepts `GET`/`HEAD` on `/v1/...` paths, and `manifest.json` is sent with `Cache-Control: no-store`.

### 1. Build the release

```bash
python3 tools/build_release.py --version 2    # integer, higher than the installed one
```

This creates `release/v1/` with the plugin files and a `manifest.json` (integer version, path,
SHA-256 and size of each file). Files the updater never replaces (`main.lua`, `_meta.lua`,
`core/updater.lua`, `core/fs.lua`) and private/local ones (`config.lua`, `version.txt`,
`pending.marker`) are left out. `release/` is not tracked by git.

### 2. Deploy the Worker

`wrangler` is not a dependency; use it through `npx`. Change `name` in `worker/wrangler.toml`
if you want a different Worker name.

```bash
cd worker
npx wrangler login
openssl rand -base64 32                    # one way to generate a token
npx wrangler secret put UPDATE_TOKEN       # paste the token when asked
npx wrangler deploy                        # publishes the Worker and the assets from ../release
```

Run `build_release.py` before every `wrangler deploy`: the assets are read from `../release` at deploy time.

### 3. Configure the Kindle

Copy `lifecounter.koplugin/config.example.lua` to `config.lua` in the plugin folder **on the Kindle**
and fill it in:

```lua
return {
    url = "https://kindle-life.YOUR-SUBDOMAIN.workers.dev/v1/",
    token = "PASTE-THE-TOKEN-HERE",
}
```

The real `config.lua` is in `.gitignore` and must never be committed.

### Integrity and rollback

Every file is checked against the manifest's SHA-256 before anything is replaced. The previous
version is kept, and if the new one fails to load, the plugin rolls back to it automatically on the
next start.

## Development

Tests:

```bash
luajit tests/run.lua                                   # plugin logic (Lua)
python3 -m unittest discover -s tools -p 'test_*.py'   # release generator
cd worker && npm test                                  # Worker (node --test test/*.test.js)
```

To try the UI without a Kindle, use the KOReader emulator on your PC in a window sized like the
Kindle screen (1072 x 1448). The walkthrough, including `LIFECOUNTER_AUTOSTART=1` to open the app
directly and `tools/screenshot.py` to capture the window, is in
[docs/dev-loop.md](docs/dev-loop.md) (note: that document is in Portuguese).

Project layout:

```
lifecounter.koplugin/   KOReader plugin
  main.lua, app.lua       plugin entry point, menu and actions
  core/                   game rules, saving, geometry, updater (testable on a PC)
  ui/                     screens and panel drawing
  shortcut/               library shortcut script (generated by tools/make_shortcut.py)
kual/lifecounter/       optional KUAL entry
worker/                 Cloudflare Worker for updates (+ tests)
tools/                  release build, push to Kindle, screenshot, shortcut generator
tests/                  Lua tests (luajit tests/run.lua)
docs/                   development loop, acceptance and project notes (mostly in Portuguese)
```

## License

MIT. See [LICENSE](LICENSE).
