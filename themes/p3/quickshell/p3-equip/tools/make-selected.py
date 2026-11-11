#!/usr/bin/env python3
"""Build equip-bg-sel.png (the "slot selected" backdrop) from equip-sel-src.png.
The source art has the game's own top bar baked in; p3-equip draws its own bar there (and
animates the chosen row into it), so this paints the bar out: inside the bar band, pixels come
from equip-bg.png with its white diamond recoloured to the selected state's navy. The white
diagonal band (left edge x = 853 + y on a 1920x1080 frame) is kept.
usage: make-selected.py ~/.local/share/persona-rice/media/p3   (needs numpy + pillow)"""
import sys, os
import numpy as np
from PIL import Image

d = sys.argv[1]
A = np.asarray(Image.open(os.path.join(d, "equip-bg.png")).convert("RGB")).astype(np.float32)
B = np.asarray(Image.open(os.path.join(d, "equip-sel-src.png")).convert("RGB")).astype(np.float32)
H, W, _ = B.shape
s = H / 1080
navy = np.array([12, 32, 91], np.float32)

out = B.copy()
y0, y1 = int(82 * s), int(214 * s)
for y in range(y0, y1):
    edge = int((853 + y / s) * s) - 1          # band's left edge on this row
    seg = A[y, :edge]
    # how "diamond white" the A pixel is -> recolour towards navy (keeps soft edges soft)
    wv = np.clip((seg.min(axis=1) - 170) / 70, 0, 1)[:, None]
    out[y, :edge] = seg * (1 - wv) + navy * wv
Image.fromarray(out.astype(np.uint8)).save(os.path.join(d, "equip-bg-sel.png"))
print("wrote", os.path.join(d, "equip-bg-sel.png"))
