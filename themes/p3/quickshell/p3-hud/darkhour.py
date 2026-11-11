#!/usr/bin/env python3
"""Dark Hour for the Persona 3 theme: decides when it's on and switches the non-Quickshell parts.

  mode (from ~/.local/state/p3-darkhour.json, set in SUPER+G → Power → Dark Hour):
    auto   on while Hyprland game mode is on (Caelestia turns animations off) or 00:00-00:59
    on     always on
    off    never
  output: ~/.local/state/p3-darkhour-active.json  {"active": bool, "reason": ...}, written only
          when it changes. Every p3 Quickshell piece (DarkHour.qml) watches that file.
  side effects on change: Hyprland window borders go green / back, kitty's palette swaps
          (~/.config/kitty/themes/darkhour-overlay.conf, included after the theme, + SIGUSR1).

Started and owned by p3-hud (the corner calendar, which runs while the p3 theme is active). Polls once a second
over Hyprland's request socket (~2 ms, no process spawns).
"""
import json, os, signal, socket, subprocess, sys, time

HOME = os.path.expanduser("~")
STATE = os.path.join(HOME, ".local/state")
MODE_F = os.path.join(STATE, "p3-darkhour.json")
ACTIVE_F = os.path.join(STATE, "p3-darkhour-active.json")
KITTY_OVERLAY = os.path.join(HOME, ".config/kitty/themes/darkhour-overlay.conf")
SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr",
                    os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""), ".socket.sock")

KITTY_GREEN = """# written by p3 darkhour.py while the Dark Hour is on (empty otherwise)
background            #04140c
foreground            #d8ffe4
cursor                #50ff82
cursor_trail_color    #50ff82
selection_background  #1e8b29
url_color             #50ff82
active_border_color   #50ff82
inactive_border_color #12371c
active_tab_background #50ff82
active_tab_foreground #04140c
inactive_tab_background #0b2614
tab_bar_background    #04140c
color0  #0b2614
color8  #2e5a3c
color4  #2fae5a
color12 #7fe0a0
color6  #50ff82
color14 #b4ffcc
color7  #c9f5d6
"""
BORDERS = {   # (active gradient colours, inactive) — p3 look.lua values when off
    True: (["rgba(50ff82ff)", "rgba(1e8b29ff)", "rgba(d8ffe4ff)"], "rgba(0b2614ee)"),
    False: (["rgba(3fd8ffff)", "rgba(1238d6ff)", "rgba(f2fbffff)"], "rgba(071648ee)"),
}


def hypr(cmd):
    try:
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(1)
        s.connect(SOCK)
        s.sendall(cmd.encode())
        out = b""
        while True:
            b = s.recv(8192)
            if not b:
                break
            out += b
        s.close()
        return out.decode(errors="ignore")
    except OSError:
        return ""


def game_mode():
    try:
        return json.loads(hypr("j/getoption animations:enabled")).get("bool") is False
    except ValueError:
        return False


def mode():
    try:
        with open(MODE_F) as f:
            m = json.load(f).get("mode", "auto")
        return m if m in ("auto", "on", "off") else "auto"
    except (OSError, ValueError):
        return "auto"


def decide():
    m = mode()
    if m == "on":
        return True, "manual"
    if m == "off":
        return False, "off"
    if game_mode():
        return True, "game"
    if time.localtime().tm_hour == 0:
        return True, "midnight"
    return False, "auto"


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f)
    os.replace(tmp, path)


def apply(active, first):
    # window borders (Hyprland's Lua config: runtime changes go through `eval`, not `keyword`)
    a, i = BORDERS[active]
    cols = ", ".join(f'"{c}"' for c in a)
    hypr(f'eval hl.config({{ general = {{ col = {{ active_border = {{ colors = {{ {cols} }}, angle = 120 }}, inactive_border = "{i}" }} }} }})')
    # kitty palette
    try:
        os.makedirs(os.path.dirname(KITTY_OVERLAY), exist_ok=True)
        with open(KITTY_OVERLAY, "w") as f:
            f.write(KITTY_GREEN if active else "# written by p3 darkhour.py (Dark Hour off)\n")
        subprocess.run(["pkill", "-USR1", "-x", "kitty"], capture_output=True)
    except OSError:
        pass



def shutdown(*_):
    """Leaving (theme switch, p3-hud gone): never leave the rest of the desktop green."""
    try:
        write_json(ACTIVE_F, {"active": False, "reason": "stopped"})
        apply(False, True)
    finally:
        os._exit(0)


def main():
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, shutdown)
    parent = os.getppid()
    last = None
    while True:
        if os.getppid() != parent:          # p3-hud died without stopping us
            shutdown()
        active, reason = decide()
        if active != (last[0] if last else None) or (last and reason != last[1]):
            write_json(ACTIVE_F, {"active": active, "reason": reason})
            if last is None or active != last[0]:
                apply(active, last is None)
            last = (active, reason)
        time.sleep(1)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        print(json.dumps(dict(zip(("active", "reason"), decide()))))
    else:
        main()
