import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import build_release


def make_plugin(root: Path):
    files = {
        "main.lua": "loader",
        "_meta.lua": "meta",
        "config.lua": "SECRET TOKEN",
        "version.txt": "1",
        "pending.marker": "0",
        "core/updater.lua": "upd",
        "core/fs.lua": "fs",
        "core/game.lua": "game code",
        "ui/board.lua": "board code",
        "app.lua": "app code",
        ".hidden": "x",
        "core/.swp": "x",
    }
    for rel, content in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)


class BuildReleaseTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.plugin = Path(self.tmp.name) / "plugin"
        self.out = Path(self.tmp.name) / "out"
        make_plugin(self.plugin)

    def tearDown(self):
        self.tmp.cleanup()

    def build(self, version=3):
        return build_release.build_release(self.plugin, self.out, version)

    def test_manifest_hashes_match_file_contents(self):
        manifest = self.build()
        self.assertTrue(manifest["files"])
        for entry in manifest["files"]:
            data = (self.out / entry["path"]).read_bytes()
            self.assertEqual(entry["sha256"], hashlib.sha256(data).hexdigest())
            self.assertEqual(entry["size"], len(data))

    def test_manifest_json_on_disk_matches_returned_manifest(self):
        manifest = self.build()
        on_disk = json.loads((self.out / "manifest.json").read_text())
        self.assertEqual(on_disk, manifest)
        self.assertEqual(manifest["version"], 3)

    def test_excludes_protected_and_private_files(self):
        manifest = self.build()
        paths = [f["path"] for f in manifest["files"]]
        self.assertEqual(sorted(paths), ["app.lua", "core/game.lua", "ui/board.lua"])
        self.assertFalse((self.out / "config.lua").exists())
        self.assertNotIn("SECRET TOKEN", "".join(p.read_text() for p in self.out.rglob("*") if p.is_file()))

    def test_paths_are_relative_with_forward_slashes(self):
        for entry in self.build()["files"]:
            p = entry["path"]
            self.assertFalse(p.startswith("/"))
            self.assertNotIn("..", p.split("/"))
            self.assertNotIn("\\", p)

    def test_version_must_be_a_positive_integer(self):
        for bad in (0, -1, 1.5, "2", None, True):
            with self.assertRaises(ValueError):
                self.build(bad)

    def test_rebuild_removes_stale_files_from_output(self):
        self.build()
        (self.plugin / "ui" / "board.lua").unlink()
        manifest = self.build(4)
        self.assertFalse((self.out / "ui" / "board.lua").exists())
        self.assertEqual(sorted(f["path"] for f in manifest["files"]), ["app.lua", "core/game.lua"])

    def test_refuses_a_plugin_with_nothing_to_publish(self):
        for rel in ("app.lua", "core/game.lua", "ui/board.lua"):
            (self.plugin / rel).unlink()
        with self.assertRaises(ValueError):
            self.build()


class ProtectedListTest(unittest.TestCase):
    def test_excluded_matches_protected_in_updater_lua(self):
        import re
        lua = (Path(__file__).resolve().parent.parent / "lifecounter.koplugin" / "core" / "updater.lua").read_text()
        block = lua[lua.index("local PROTECTED"):lua.index("}", lua.index("local PROTECTED"))]
        protected = set(re.findall(r'\["([^"]+)"\]\s*=\s*true', block))
        self.assertEqual(protected | {"version.txt"}, build_release.EXCLUDED)


if __name__ == "__main__":
    unittest.main()
