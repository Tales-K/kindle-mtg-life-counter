#!/usr/bin/env python3
"""Captura a tela X11 (via xwd) e salva em PNG. Uso: screenshot.py saida.png DISPLAY ID_DA_JANELA (xwininfo -root -tree)"""
import struct
import subprocess
import sys

from PIL import Image


def main():
    out = sys.argv[1]
    display = sys.argv[2]
    raw = subprocess.run(["xwd", "-id", sys.argv[3], "-silent", "-display", display], check=True, capture_output=True).stdout
    h = struct.unpack(">25I", raw[:100])
    header_size, width, height, bpp, bpl, ncolors = h[0], h[4], h[5], h[11], h[12], h[19]
    data = raw[header_size + ncolors * 12:]
    if bpp != 32:
        sys.exit(f"bpp {bpp} nao suportado")
    Image.frombytes("RGB", (width, height), data, "raw", "BGRX", bpl).save(out)
    print(f"{out}: {width}x{height}")


if __name__ == "__main__":
    main()
