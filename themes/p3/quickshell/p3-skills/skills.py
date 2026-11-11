#!/usr/bin/env python3
"""p3-skills backend (modes = bundles of p3-equip settings).

  skills.py list        -> JSON {modes: [...], state: {...current settings...}}
  skills.py cast ID     -> apply every setting of mode ID (via p3-equip/equip.py), then its 'open'

Modes come from ~/.config/p3-skills/modes.json if it exists, else modes.json next to this file.
"""
import json, os, sys, subprocess, importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
USER = os.path.expanduser("~/.config/p3-skills/modes.json")
EQUIP = os.path.join(os.path.dirname(HERE), "p3-equip", "equip.py")
ORDER = ["profile", "gamemode", "brightness", "nightlight", "volume", "dnd", "awake", "bluetooth", "wifi"]


def modes():
    for p in (USER, os.path.join(HERE, "modes.json")):
        try:
            with open(p) as f:
                return json.load(f).get("modes", [])
        except (OSError, ValueError):
            continue
    return []


def equip_mod():
    spec = importlib.util.spec_from_file_location("equip", EQUIP)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def cmd_list():
    out = subprocess.run([sys.executable, EQUIP, "state"], capture_output=True, text=True, timeout=10).stdout
    try:
        st = json.loads(out)
    except ValueError:
        st = {}
    print(json.dumps({"modes": modes(), "state": st}), flush=True)


def cmd_cast(mid):
    m = next((x for x in modes() if x.get("id") == mid), None)
    if not m:
        print("error: unknown mode " + mid)
        return
    eq = equip_mod()
    for key in sorted(m.get("set", {}), key=lambda k: ORDER.index(k) if k in ORDER else 99):
        try:
            eq.apply(key, str(m["set"][key]))
        except Exception as e:
            print(f"warn: {key}: {e}", file=sys.stderr)
    if m.get("open"):
        subprocess.Popen(["sh", "-c", m["open"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    subprocess.run(["notify-send", "-a", "Skills", "-i", "preferences-system", m.get("name", mid), "Mode cast"], timeout=3)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "list":
        cmd_list()
    elif len(sys.argv) == 3 and sys.argv[1] == "cast":
        cmd_cast(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(2)
