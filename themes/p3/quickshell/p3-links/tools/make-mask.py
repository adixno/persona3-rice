#!/usr/bin/env python3
"""Build links-bg/mask.png for p3-links' living backdrop from the 20 aligned frames.
  R = water (top band: blue/cyan, away from the character and anything white)
  G = cloth sway weight: the cyan coat flap + the lanyard cord, unioned over all frames
      (aligned with offsets.json), ramping from 0 at the attached top to 1 at the free end.
  B = 1 where nothing may move (the card + its frame), used to hard-protect it.
usage: make-mask.py ~/.local/share/persona-rice/media/p3/links-bg   (needs numpy + pillow)"""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

d = sys.argv[1]
offs = json.load(open(os.path.join(d, "offsets.json")))["abs"]
W, H = 1920, 1080
def poly(pts, blur=0):
    m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).polygon(pts, fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur)) if blur else m
coat_zone = np.asarray(poly([(900, 480), (880, 700), (760, 880), (600, 1080), (330, 1080), (520, 860), (700, 640), (840, 470)])) > 0
cord_zone = np.asarray(poly([(860, 540), (930, 540), (880, 880), (790, 880)])) > 0
card_zone = poly([(860, 190), (1150, 190), (1150, 575), (860, 575)], 6)

coat = np.zeros((H, W), bool); cord = np.zeros((H, W), bool); water = np.zeros((H, W), np.float32)
for i in range(20):
    a = Image.open(os.path.join(d, f"{i:02d}.png")).convert("RGB")
    dx, dy = offs[i]
    a = a.transform(a.size, Image.AFFINE, (1, 0, dx, 0, 1, dy))    # align to frame 00
    p = np.asarray(a).astype(np.int16); r, g, b = p[..., 0], p[..., 1], p[..., 2]
    cyan = (r < 120) & (g > 170) & (b > 210)
    dark = (b > r + 40) & (g < 120)                                   # cord is navy
    coat |= cyan & coat_zone
    cord |= dark & cord_zone
    yy = np.arange(H)[:, None]
    blue = (b - r > 60) & (b > 140) & ~((r > 200) & (g > 200))
    water = np.maximum(water, (blue & (yy < 330) & ((np.arange(W)[None, :] < 930) | (np.arange(W)[None, :] > 1250))).astype(np.float32))

def soft(m, grow, blur):
    im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(grow)).filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im).astype(np.float32) / 255
yy = np.arange(H, dtype=np.float32)[:, None]
ramp_coat = np.clip((yy - 500) / 420, 0, 1)
ramp_cord = np.clip((yy - 560) / 280, 0, 1)
G = np.maximum(soft(coat, 21, 10) * ramp_coat, soft(cord, 15, 6) * ramp_cord)
card = np.asarray(card_zone).astype(np.float32) / 255
G *= 1 - card
R = soft(water > 0, 3, 6) * np.clip((330 - yy) / 60, 0, 1)
out = np.stack([R, G, card], -1)
Image.fromarray((out * 255).astype(np.uint8)).save(os.path.join(d, "mask.png"))
print("wrote mask.png")
