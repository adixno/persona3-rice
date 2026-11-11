#!/usr/bin/env python3
"""Persona 3 style scheme for the Caelestia shell: midnight navy, royal blue, cyan, red highlight.

Run again whenever `caelestia scheme set` or a wallpaper change overwrites it.
`scheme.py --txt` prints the caelestia-cli scheme file (caelestia/scheme.txt).
"""
import json, sys
from pathlib import Path

state = Path.home() / ".local/state/caelestia/scheme.json"

DEEP, NAVY, NAVY2 = "030a26", "071648", "0c2170"
BLUE, AZURE = "1238d6", "2f7bff"
CYAN, CYAN_DIM, ICE = "3fd8ff", "22a9d6", "aaf2ff"
WHITE, RED, PINK = "f2fbff", "ff1f3a", "ff5fae"

c = {
    "background": DEEP, "onBackground": WHITE,
    "surface": DEEP, "surfaceDim": DEEP, "surfaceBright": "163285",
    "surfaceContainerLowest": "020719", "surfaceContainerLow": "05103a",
    "surfaceContainer": NAVY, "surfaceContainerHigh": "0a1c5e",
    "surfaceContainerHighest": NAVY2,
    "onSurface": WHITE, "surfaceVariant": NAVY2, "onSurfaceVariant": "b9d9f2",
    "inverseSurface": WHITE, "inverseOnSurface": DEEP,
    "outline": CYAN, "outlineVariant": "1d3a8f",
    "shadow": "000000", "scrim": "000000", "surfaceTint": CYAN,
    "primary": CYAN, "primaryDim": CYAN_DIM, "onPrimary": DEEP,
    "primaryContainer": BLUE, "onPrimaryContainer": WHITE,
    "inversePrimary": BLUE,
    "primaryFixed": ICE, "primaryFixedDim": CYAN, "onPrimaryFixed": DEEP,
    "onPrimaryFixedVariant": BLUE,
    # secondary = white "paper" accents, tertiary = the red highlight slash
    "secondary": WHITE, "secondaryDim": ICE, "onSecondary": DEEP,
    "secondaryContainer": NAVY2, "onSecondaryContainer": WHITE,
    "secondaryFixed": WHITE, "secondaryFixedDim": ICE,
    "onSecondaryFixed": DEEP, "onSecondaryFixedVariant": NAVY2,
    "tertiary": RED, "tertiaryDim": "c4001a", "onTertiary": "ffffff",
    "tertiaryContainer": "7a0012", "onTertiaryContainer": "ffffff",
    "tertiaryFixed": RED, "tertiaryFixedDim": "c4001a",
    "onTertiaryFixed": "000000", "onTertiaryFixedVariant": "7a0012",
    "error": RED, "errorDim": "c4001a", "onError": "ffffff",
    "errorContainer": "7a0012", "onErrorContainer": "ffd6dc",
    "success": ICE, "onSuccess": DEEP, "successContainer": NAVY2,
    "onSuccessContainer": WHITE,
    "primary_paletteKeyColor": CYAN, "secondary_paletteKeyColor": "8a93b0",
    "tertiary_paletteKeyColor": RED, "neutral_paletteKeyColor": "6f7896",
    "neutral_variant_paletteKeyColor": "6f7896",
    "term0": "071648", "term1": RED, "term2": "5fffd0", "term3": "ffe27a",
    "term4": AZURE, "term5": PINK, "term6": CYAN, "term7": "c9e6ff",
    "term8": "3a4f8f", "term9": "ff5a6e", "term10": "9dffe4", "term11": "fff0b0",
    "term12": "7fb0ff", "term13": "ff9ccf", "term14": ICE, "term15": "ffffff",
    "text": WHITE, "subtext1": "c9e6ff", "subtext0": "8fb3d9",
    "overlay2": "6f8fc0", "overlay1": "56739f", "overlay0": "3f5a85",
    "surface2": "1d3a8f", "surface1": "163285", "surface0": NAVY2,
    "base": DEEP, "mantle": "020719", "crust": "01040f",
}
for k in ("red", "maroon"):
    c[k] = RED
for k in ("rosewater", "flamingo", "pink", "mauve", "peach"):
    c[k] = PINK
c["yellow"] = "ffe27a"
for k in ("green", "teal"):
    c[k] = "5fffd0"
for k in ("sky", "sapphire"):
    c[k] = CYAN
for k in ("blue", "lavender"):
    c[k] = AZURE

if "--txt" in sys.argv:
    print("\n".join(f"{k} {v}" for k, v in c.items()))
    sys.exit()

if state.exists():
    backup = state.with_name("scheme.json.bak")
    if not backup.exists():
        backup.write_text(state.read_text())
    cur = json.loads(state.read_text())
else:
    cur = {}

colours = {**cur.get("colours", {}), **c}
state.parent.mkdir(parents=True, exist_ok=True)
state.write_text(json.dumps({
    "name": "persona3", "flavour": "default", "mode": "dark",
    "variant": "tonalspot", "colours": colours,
}))
print(f"wrote {state}")
