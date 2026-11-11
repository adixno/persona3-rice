#!/usr/bin/env python3
"""Build skills-mask.png for p3-skills from skills-bg.png: R = the blue underwater areas
(kept ~9 px clear of anything white or grey: the band, the SKILL lettering, the shirt), G = 0.
usage: make-mask.py ~/.local/share/persona-rice/media/p3   (needs numpy + pillow)"""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

d = sys.argv[1]
a = np.asarray(Image.open(os.path.join(d, "skills-bg.png")).convert("RGB")).astype(np.float32)
H, W, _ = a.shape
s = H / 1080
r, g, b = a[..., 0], a[..., 1], a[..., 2]
blue = (b - r > 60) & (b > 90)
light = ((r > 190) & (g > 190) & (b > 190)) | ((np.abs(r - g) < 16) & (np.abs(g - b) < 22) & (r > 110))
near = np.asarray(Image.fromarray((light * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(int(9 * s) | 1))) > 0
water = (blue & ~near).astype(np.float32)
wm = Image.fromarray((water * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5 * s))
out = np.zeros((H, W, 3), np.uint8)
out[..., 0] = np.asarray(wm)
Image.fromarray(out).save(os.path.join(d, "skills-mask.png"))
print("wrote skills-mask.png")
