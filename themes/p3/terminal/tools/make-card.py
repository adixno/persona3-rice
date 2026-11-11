#!/usr/bin/env python3
"""Pre-render the greeting card's animation frames from a card image (kitty shows them inline
at full quality). Writes ~/.local/share/persona-rice/media/p3/greeting-frames/:
  flip-00..NN.png  card turning in from its back (edge-on → face)
  rest.png         the card itself
  sheen-00..NN.png a holographic sheen sweeping across, plus a light running round the edge
usage: make-card.py [image]   (needs numpy + pillow)"""
import os, sys, math, shutil
import numpy as np
from PIL import Image, ImageDraw

img = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/persona-rice/media/p3/greeting-card.png")
out = os.path.expanduser("~/.local/share/persona-rice/media/p3/greeting-frames")
shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
card = Image.open(img).convert("RGBA")
H = 540
Wd = round(card.width * H / card.height)
card = card.resize((Wd, H), Image.LANCZOS)
FLIP, SHEEN = 12, 22

# back: navy with a cyan diamond lattice inside a light frame
back = Image.new("RGBA", (Wd, H), (8, 24, 84, 255))
d = ImageDraw.Draw(back)
step = 26
for k in range(-H, Wd + H, step):
    d.line([(k, 0), (k + H, H)], fill=(47, 123, 255, 255), width=2)
    d.line([(k, 0), (k - H, H)], fill=(47, 123, 255, 255), width=2)
for i, (col, w) in enumerate([((242, 251, 255, 255), 5), ((63, 216, 255, 255), 6), ((242, 251, 255, 255), 2)]):
    o = sum(x[1] for x in [(0, 5), (0, 6), (0, 2)][:i])
    d.rectangle([o, o, Wd - 1 - o, H - 1 - o], outline=col, width=w)

def squeeze(face, sx):
    """Card turned about its vertical axis: width scaled by sx, centred, transparent around."""
    f = Image.new("RGBA", (Wd, H), (0, 0, 0, 0))
    w = max(1, round(Wd * sx))
    f.paste(face.resize((w, H), Image.LANCZOS), ((Wd - w) // 2, 0))
    return f

for i in range(FLIP):
    t = (i + 1) / FLIP
    ang = math.pi * (1 - t)
    face = back if ang > math.pi / 2 else card
    squeeze(face, max(0.02, abs(math.cos(ang)))).save(f"{out}/flip-{i:02d}.png")
card.save(f"{out}/rest.png")

a = np.asarray(card).astype(float)
lum = a[..., :3].mean(2)
yy, xx = np.mgrid[0:H, 0:Wd]
per = 2 * (Wd + H)
for i in range(SHEEN):
    p = i / (SHEEN - 1)
    diag = xx + yy * 0.5
    pos = -80 + p * (Wd + H * 0.5 + 160)
    band = np.clip(1 - np.abs(diag - pos) / 70, 0, 1) ** 1.5
    band *= np.clip((lum - 35) / 60, 0, 1)                 # the black silhouette stays black
    tint = np.stack([170 + 85 * yy / H, 242 - 72 * yy / H, 255 - 25 * yy / H], -1)   # ice → pink
    rgb = a[..., :3] * (1 - band[..., None] * 0.7) + tint * band[..., None] * 0.7
    fr = Image.fromarray(np.dstack([rgb.clip(0, 255), a[..., 3]]).astype(np.uint8), "RGBA")
    # a short light running round the edge
    dd = ImageDraw.Draw(fr)
    g = p * per
    for k in range(18):
        q = (g - k * 3) % per
        if q < Wd: x, y = q, 2
        elif q < Wd + H: x, y = Wd - 3, q - Wd
        elif q < 2 * Wd + H: x, y = Wd - (q - Wd - H), H - 3
        else: x, y = 2, H - (q - 2 * Wd - H)
        dd.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 255, 255, int(255 * (1 - k / 18))))
    fr.save(f"{out}/sheen-{i:02d}.png")
print(f"wrote {FLIP} flip + rest + {SHEEN} sheen frames ({Wd}x{H}) to {out}")
