#!/usr/bin/env python3
"""Build equip-mask.png for p3-equip's animated backdrop from equip-bg.png.
  R = water (top band, saturated blue/cyan, not the white diamond / grey ring)
  G = character area (hand-placed polygon around the lying character, soft edge)
Both blurred so the shader's movement fades out smoothly.
usage: make-mask.py ~/.local/share/persona-rice/media/p3   (needs numpy + pillow)"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

d = sys.argv[1]
img = Image.open(os.path.join(d, "equip-bg.png")).convert("RGB")
W, H = img.size
a = np.asarray(img).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]

# character polygon (designed on 1920x1080, scaled to the image)
sx, sy = W / 1920, H / 1080
poly = [(1010, 720), (1180, 650), (1420, 560), (1490, 400), (1640, 400), (1900, 520),
        (1920, 600), (1920, 1080), (1010, 1080)]
cm = Image.new("L", (W, H), 0)
ImageDraw.Draw(cm).polygon([(x * sx, y * sy) for x, y in poly], fill=255)
cm = cm.filter(ImageFilter.GaussianBlur(40 * sx))

# water: clearly blue, not white/grey, upper part of the frame, outside the character
yy = np.arange(H)[:, None] / H
blue = (b - r > 70) & (b > 150)
top = np.clip((0.62 - yy) / 0.12, 0, 1)
# keep clear of the crisp white diamond / grey ring edges so they never wobble
light = ((r > 200) & (g > 200) & (b > 200)) | ((np.abs(r - g) < 14) & (np.abs(g - b) < 14) & (r > 120))
near = np.asarray(Image.fromarray((light * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(int(9 * sx) | 1))) > 0
water = blue.astype(np.float32) * top * (1 - np.asarray(cm) / 255.0) * (~near)
wm = Image.fromarray((water * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * sx))

out = np.zeros((H, W, 3), np.uint8)
out[..., 0] = np.asarray(wm)
out[..., 1] = np.asarray(cm)
Image.fromarray(out).save(os.path.join(d, "equip-mask.png"))
print("wrote", os.path.join(d, "equip-mask.png"))
