#!/usr/bin/env python3
"""Gera release/v1/ (arquivos + manifest.json) a partir de lifecounter.koplugin/."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

# Arquivos que o atualizador nunca troca (precisam bater com PROTECTED em core/updater.lua),
# mais o que e privado ou escrito pelo proprio atualizador.
EXCLUDED = {
    "main.lua", "_meta.lua", "core/updater.lua", "core/fs.lua",
    "config.lua", "version.txt", "pending.marker",
}


def build_release(plugin_dir, out_dir, version):
    if isinstance(version, bool) or not isinstance(version, int) or version < 1:
        raise ValueError("version deve ser um inteiro positivo")
    plugin_dir, out_dir = Path(plugin_dir), Path(out_dir)

    entries = []
    for path in sorted(plugin_dir.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(plugin_dir)
        if any(part.startswith(".") for part in rel.parts):
            continue
        rel_str = rel.as_posix()
        if rel_str in EXCLUDED:
            continue
        data = path.read_bytes()
        entries.append((rel_str, data))
    if not entries:
        raise ValueError("nada para publicar")

    if out_dir.exists():
        shutil.rmtree(out_dir)
    manifest = {"version": version, "files": []}
    for rel_str, data in entries:
        target = out_dir / rel_str
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        manifest["files"].append({
            "path": rel_str,
            "sha256": hashlib.sha256(data).hexdigest(),
            "size": len(data),
        })
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--version", type=int, required=True)
    ap.add_argument("--plugin", default=str(root / "lifecounter.koplugin"))
    ap.add_argument("--out", default=str(root / "release" / "v1"))
    args = ap.parse_args()
    manifest = build_release(args.plugin, args.out, args.version)
    print(f"v{manifest['version']}: {len(manifest['files'])} arquivos em {args.out}")


if __name__ == "__main__":
    main()
