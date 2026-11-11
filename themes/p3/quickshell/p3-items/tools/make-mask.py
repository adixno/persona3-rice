#!/usr/bin/env python3
"""Build items-mask.png for p3-items from items-bg.png: R = underwater (everything below the
white ITEM band, faded in a little below its edge so the edge never wobbles), G = 0.
usage: make-mask.py ~/.local/share/persona-rice/media/p3   (needs numpy + pillow)"""
import sys, os
import numpy as np
from PIL import Image

d = sys.argv[1]
img = np.asarray(Image.open(os.path.join(d, "items-bg.png")).convert("RGB")).astype(np.float32)
H, W, _ = img.shape
# band bottom: first row (from the top) where the middle of the frame stops being white
mid = img[:, int(W * 0.72): int(W * 0.95)].min(axis=2).mean(axis=1)   # right side: no hair over the band
band = next((y for y in range(H) if mid[y] < 200 and y > H * 0.05), int(H * 0.19))
yy = np.arange(H, dtype=np.float32)[:, None]
r = np.clip((yy - band - 14 * H / 1080) / (40 * H / 1080), 0, 1) * np.ones((1, W), np.float32)
out = np.zeros((H, W, 3), np.uint8)
out[..., 0] = (r * 255).astype(np.uint8)
Image.fromarray(out).save(os.path.join(d, "items-mask.png"))
print("band bottom at", band, "px; wrote items-mask.png")
