#!/usr/bin/env python3
"""Gera lifecounter.koplugin/shortcut/contador-mtg.sh: o atalho ("scriptlet") que aparece
como livro na biblioteca do Kindle (Universal Hotfix) e abre o KOReader ja no Contador MTG.
A capa vai embutida no cabecalho # Icon: como PNG em base64. Precisa de Pillow so para gerar.

    python3 tools/make_shortcut.py
"""
import base64
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "lifecounter.koplugin" / "shortcut" / "contador-mtg.sh"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def icon_png(w=300, h=400):
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.rectangle([10, 10, w - 11, h - 11], outline=255, width=6)
    big = ImageFont.truetype(FONT, 150)
    small = ImageFont.truetype(FONT, 44)

    def centered(text, font, y):
        x0, y0, x1, y1 = d.textbbox((0, 0), text, font=font)
        d.text(((w - (x1 - x0)) / 2 - x0, y - y0), text, font=font, fill=255)

    centered("40", big, 70)
    centered("Contador", small, 255)
    centered("MTG", small, 310)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def script(png):
    b64 = base64.b64encode(png).decode()
    return (
        "#!/bin/sh\n"
        "# Name: Contador MTG\n"
        "# Author: Tales-K\n"
        f"# Icon: data:image/png;base64,{b64}\n"
        "# DontUseFBInk\n"
        "# Atalho da biblioteca (gerado por tools/make_shortcut.py): abre o KOReader ja dentro do\n"
        "# Contador MTG, como a entrada do KUAL. O plugin copia este arquivo para /mnt/us/documents.\n"
        "export LIFECOUNTER_AUTOSTART=1\n"
        "/mnt/us/koreader/koreader.sh --kual >/dev/null 2>&1 &\n"
    )


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(script(icon_png()))
    print(f"{OUT.relative_to(ROOT)}: {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
