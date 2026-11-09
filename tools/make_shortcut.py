#!/usr/bin/env python3
"""Gera lifecounter.koplugin/shortcut/contador-mtg.sh: o atalho ("scriptlet") que aparece
como livro na biblioteca do Kindle (Universal Hotfix) e abre o KOReader ja no Cryo MTG Life Counter.
O nome do arquivo continua contador-mtg.sh para o atalho ja instalado ser trocado no lugar.
A capa vai embutida no cabecalho # Icon: como PNG em base64. Precisa de Pillow so para gerar.

    python3 tools/make_shortcut.py [capa.png]
"""
import base64
import io
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "lifecounter.koplugin" / "shortcut" / "contador-mtg.sh"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def snowflake(d, cx, cy, r, width, fill):
    """Floco de neve de 6 bracos, cada um com dois pares de galhos em V."""
    for k in range(6):
        a = math.radians(90 + 60 * k)
        ux, uy = math.cos(a), -math.sin(a)
        d.line([(cx, cy), (cx + ux * r, cy + uy * r)], fill=fill, width=width)
        for t, size in ((0.45, 0.30), (0.75, 0.22)):
            bx, by = cx + ux * r * t, cy + uy * r * t
            for side in (-1, 1):
                b = a + side * math.radians(45)
                d.line([(bx, by), (bx + math.cos(b) * r * size, by - math.sin(b) * r * size)], fill=fill, width=width)
    d.ellipse([cx - width, cy - width, cx + width, cy + width], fill=fill)


def icon_png(w=300, h=400, s=4):
    """Capa: fundo preto, floco de neve, "CRYO" grande e "MTG Life Counter" embaixo.
    Desenhada 4x maior e reduzida (bordas suaves), em tons de cinza."""
    W, H = w * s, h * s
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    d.rectangle([10 * s, 10 * s, W - 11 * s, H - 11 * s], outline=255, width=6 * s)

    def fit(text, max_w, size):
        while True:
            font = ImageFont.truetype(FONT, size * s)
            x0, _, x1, _ = d.textbbox((0, 0), text, font=font)
            if x1 - x0 <= max_w * s or size <= 8:
                return font
            size -= 2

    def centered(text, font, y):
        x0, y0, x1, y1 = d.textbbox((0, 0), text, font=font)
        d.text(((W - (x1 - x0)) / 2 - x0, y * s - y0), text, font=font, fill=255)

    snowflake(d, W / 2, 108 * s, 66 * s, 9 * s, 255)
    centered("CRYO", fit("CRYO", 236, 100), 196)
    d.line([(60 * s, 300 * s), (W - 60 * s, 300 * s)], fill=255, width=3 * s)
    small = fit("Life Counter", 220, 40)
    centered("MTG", small, 314)
    centered("Life Counter", small, 352)
    # 16 tons, como o e-ink: deixa o PNG (e o cabecalho do atalho) bem menor.
    im = im.resize((w, h), Image.LANCZOS).point(lambda v: (v // 17) * 17)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def script(png):
    b64 = base64.b64encode(png).decode()
    return (
        "#!/bin/sh\n"
        "# Name: Cryo MTG Life Counter\n"
        "# Author: Tales-K\n"
        f"# Icon: data:image/png;base64,{b64}\n"
        "# DontUseFBInk\n"
        "# Atalho da biblioteca (gerado por tools/make_shortcut.py): abre o KOReader ja dentro do\n"
        "# Cryo MTG Life Counter, como a entrada do KUAL. O plugin copia este arquivo para /mnt/us/documents.\n"
        "export LIFECOUNTER_AUTOSTART=1\n"
        "/mnt/us/koreader/koreader.sh --kual >/dev/null 2>&1 &\n"
    )


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    png = icon_png()
    OUT.write_text(script(png))
    if len(sys.argv) > 1:  # opcional: salva a capa em PNG para conferir
        Path(sys.argv[1]).write_bytes(png)
    print(f"{OUT.relative_to(ROOT)}: {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
