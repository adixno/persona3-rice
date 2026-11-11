#!/usr/bin/env python3
"""Make the terminal greeting's card (sextant pixels: 2x3 per cell, ~7x11 px each in kitty)
from a card image and embed it in greeting.py (between the CARD-DATA markers).
The image is area-averaged straight to CW x CH sub-pixels (that stretch matches the
non-square sub-pixels, so the card keeps its shape on screen); the silhouette's solid pixels
are snapped to pure black and the eye kept as one white pixel.
Default image: ~/.local/share/persona-rice/media/p3/greeting-card.png
usage: make-pixel.py [image] [--preview out.png] [--no-embed]   (needs numpy + pillow)

A deck: make-pixel.py --sheet IMAGE [--preview out.png] [--no-numerals]
  IMAGE is one picture with several cards on a plain white (or transparent) background. Every
  card is cut out (rows top to bottom, left to right), shrunk the same way and written to
  ~/.local/share/persona-rice/media/p3/greeting-cards.json. When that file exists the greeting
  draws a random card from it each time (never the same one twice in a row) instead of the
  embedded one. Delete the file to go back to the single card. A sheet of 22 cards in order
  (0 to XXI; or 23 with two XX) gets its numbers redrawn as crisp pixels."""
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter

CW, CH = 44, 42          # 22 columns x 14 rows of sextants
DECK = os.path.expanduser("~/.local/share/persona-rice/media/p3/greeting-cards.json")


def shrink(src):
    """Area-average a card to CW x CH; pixels that are mostly solid dark become pure black."""
    lum = np.asarray(src.convert("L")).astype(float)
    dark = lum < 45
    out = np.asarray(src.resize((CW, CH), Image.BOX)).astype(float)
    ink = np.asarray(Image.fromarray((dark * 255).astype(np.uint8)).resize((CW, CH), Image.BOX)).astype(float) / 255
    out[ink > 0.5] = (6, 7, 12)
    return out, lum, dark


def runs(v, minlen):
    out, s = [], None
    for i, x in enumerate(list(v) + [False]):
        if x and s is None:
            s = i
        elif not x and s is not None:
            if i - s >= minlen:
                out.append((s, i))
            s = None
    return out


def cut_sheet(path):
    """Card boxes on a white/transparent sheet, in reading order."""
    im = Image.open(path).convert("RGBA")
    flat = Image.new("RGBA", im.size, (255, 255, 255, 255))
    flat.alpha_composite(im)
    im = flat.convert("RGB")
    fg = np.asarray(im).astype(int).min(axis=2) <= 235
    minh, minw = im.height // 16, im.width // 24
    cards = []
    for y0, y1 in runs(fg.sum(axis=1) > minw, minh):
        for x0, x1 in runs(fg[y0:y1].sum(axis=0) > (y1 - y0) * 0.12, minw):
            cards.append(im.crop((x0, y0, x1, y1)))
    return cards


GLYPH = {"0": ["0110", "1001", "1001", "1001", "0110"],
         "I": ["1", "1", "1", "1", "1"],
         "V": ["101", "101", "101", "101", "010"],
         "X": ["101", "101", "010", "101", "101"]}
ROMAN = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV",
         "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"]


def numeral(out, text):
    """Redraw the number on the plate as crisp pixels (the shrink smears it)."""
    rows = [" ".join(GLYPH[ch][r] for ch in text).replace(" ", "0") for r in range(5)]
    w = len(rows[0])
    x0, y0 = (CW - w + 1) // 2, round(CH * 0.835)
    plate = out[y0 + 2, CW // 2 - 6].copy()
    for r, row in enumerate(rows):
        for c in range(-1, w + 1):
            on = 0 <= c < w and row[c] == "1"
            out[y0 + r, x0 + c] = (245, 250, 255) if on else plate


def show(data):
    """A card at its on-screen sub-pixel shape (7 x 10.67 px)."""
    return Image.fromarray(data).resize((CW * 7, round(CH * 10.67)), Image.NEAREST)


argv = sys.argv[1:]
if "--sheet" in argv:
    i = argv.index("--sheet"); sheet = argv[i + 1]; del argv[i:i + 2]
    prev = None
    if "--preview" in argv:
        i = argv.index("--preview"); prev = argv[i + 1]
    cards = [shrink(c)[0] for c in cut_sheet(sheet)]
    if not cards:
        sys.exit("no cards found: the sheet needs a plain white or transparent background")
    # a full deck in order (22 cards, or 23 with a second XX before XXI) gets crisp numbers
    names = ROMAN if len(cards) == 22 else ROMAN[:21] + ["XX", "XXI"] if len(cards) == 23 else []
    if "--no-numerals" not in argv:
        for c, n in zip(cards, names):
            numeral(c, n)
    cards = [c.clip(0, 255).astype(np.uint8) for c in cards]
    os.makedirs(os.path.dirname(DECK), exist_ok=True)
    with open(DECK + ".tmp", "w") as f:
        json.dump({"w": CW, "h": CH, "cards": [c.tobytes().hex() for c in cards]}, f)
    os.replace(DECK + ".tmp", DECK)
    print(f"wrote {len(cards)} cards to {DECK}")
    if prev:
        tiles = [show(c) for c in cards]
        tw, th = tiles[0].size
        per = min(len(tiles), 8)
        grid = Image.new("RGB", (per * (tw + 10) + 10, -(-len(tiles) // per) * (th + 10) + 10), (3, 10, 38))
        for n, t in enumerate(tiles):
            grid.paste(t, (10 + (n % per) * (tw + 10), 10 + (n // per) * (th + 10)))
        grid.save(prev)
    sys.exit(0)

preview = None
if "--preview" in argv:
    i = argv.index("--preview"); preview = argv[i + 1]; del argv[i:i + 2]
embed = "--no-embed" not in argv
argv = [a for a in argv if a != "--no-embed"]
img = argv[0] if argv else os.path.expanduser("~/.local/share/persona-rice/media/p3/greeting-card.png")
gp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "greeting.py")

src = Image.open(img).convert("RGB")
out, lum, dark = shrink(src)
near = np.asarray(Image.fromarray((dark * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(10))).astype(float) / 255
cand = (lum > 215) & (near > 0.55)
if cand.any():
    ys, xs = np.nonzero(cand)
    out[int(ys.mean() * CH / src.height), int(xs.mean() * CW / src.width)] = (250, 252, 255)
# the "0" on the plate: a crisp glyph (the shrink smears it into "11")
ZERO = ["0110", "1001", "1001", "1001", "0110"]
zx, zy = CW // 2 - 2, round(CH * 0.835)
plate = out[zy + 2, CW // 2 - 5].copy()
for r, row in enumerate(ZERO):
    for c, b in enumerate(row):
        out[zy + r, zx + c] = (245, 250, 255) if b == "1" else plate
data = out.clip(0, 255).astype(np.uint8)
if preview:   # shown with the on-screen sub-pixel shape (7x11)
    show(data).save(preview)
if embed:
    block = f"# CARD-DATA start (generated by tools/make-pixel.py — do not edit)\nCW, CH = {CW}, {CH}\nCARD = bytes.fromhex(\"{data.tobytes().hex()}\")\n# CARD-DATA end\n"
    s = open(gp).read()
    a0, b0 = s.find("# CARD-DATA start"), s.find("# CARD-DATA end")
    open(gp, "w").write(s[:a0] + block + s[b0 + len("# CARD-DATA end\n"):])
    print(f"embedded {CW}x{CH} card into {gp}")
