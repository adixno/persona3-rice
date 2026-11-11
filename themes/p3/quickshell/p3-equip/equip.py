#!/usr/bin/env python3
"""p3-equip backend.

  equip.py state           -> one JSON object: every slot, what is equipped, what can be equipped
  equip.py apply KEY VALUE -> equip VALUE in slot KEY (prints "ok" / "error: ...")

Slots (KEY): output, volume, input, profile, gamemode, brightness, nightlight,
             wifi, bluetooth, dnd, awake
"""
import json, os, subprocess, sys, glob
from concurrent.futures import ThreadPoolExecutor


def run(*cmd, timeout=4):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def spawn(*cmd):
    # long actions (wifi / bluetooth connects) must not block the menu
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def caelestia(target, fn):
    # straight to the shell's IPC: the `caelestia shell` wrapper costs ~0.9 s per call
    return run("qs", "-c", "caelestia", "ipc", "call", target, fn)


# ── readers ───────────────────────────────────────────────────────────────
def audio():
    def nodes(kind):
        try:
            data = json.loads(run("pactl", "--format=json", "list", kind) or "[]")
        except ValueError:
            data = []
        default = run("pactl", "get-default-sink" if kind == "sinks" else "get-default-source")
        out = []
        for n in data:
            if n.get("monitor_source") is not None and kind == "sources":
                pass
            if kind == "sources" and n.get("name", "").endswith(".monitor"):
                continue
            label = (n.get("description") or n["name"]).replace(" Analog Stereo", "").replace(" Stereo", "")
            out.append({"id": n["name"], "label": label,
                        "bt": n["name"].startswith("bluez")})
        return out, default
    sinks, dsink = nodes("sinks")
    sources, dsource = nodes("sources")
    vol = run("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@").split()
    mic = run("wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@")
    return {
        "sinks": sinks, "sink": dsink, "sources": sources, "source": dsource,
        "volume": round(float(vol[1]) * 100) if len(vol) > 1 else 0,
        "muted": "[MUTED]" in vol, "micMuted": "[MUTED]" in mic,
    }


def power():
    # D-Bus directly: powerprofilesctl is a python wrapper that takes ~0.8 s
    prof = run("busctl", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile").split('"')
    return {"profile": prof[1] if len(prof) > 1 else "balanced",
            "gamemode": caelestia("gameMode", "isEnabled") == "true"}


def display():
    b = 0
    for d in glob.glob("/sys/class/backlight/*"):
        try:
            m = int(open(d + "/max_brightness").read())
            b = round(int(open(d + "/brightness").read()) * 100 / m) if m else 0
        except (OSError, ValueError):
            pass
    t = run("hyprctl", "hyprsunset", "temperature")
    try:
        temp = int(t)
    except ValueError:
        temp = 6500
    return {"brightness": b, "temperature": temp, "sunset": bool(run("pgrep", "-x", "hyprsunset"))}


def link():
    radio = run("nmcli", "radio", "wifi") == "enabled"
    saved, current = [], ""
    for l in run("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show").splitlines():
        parts = l.rsplit(":", 2)
        if len(parts) == 3 and parts[1] == "802-11-wireless":
            saved.append(parts[0].replace("\\:", ":"))
            if parts[2]:
                current = parts[0].replace("\\:", ":")
    bt_on = "Powered: yes" in run("bluetoothctl", "show")
    devs = []
    for l in run("bluetoothctl", "devices", "Paired").splitlines():
        p = l.split(" ", 2)
        if len(p) == 3:
            info = run("bluetoothctl", "info", p[1])
            batt = ""
            for x in info.splitlines():
                if "Battery Percentage" in x:
                    batt = x.split("(")[-1].rstrip(")")
            devs.append({"id": p[1], "label": p[2], "connected": "Connected: yes" in info, "battery": batt})
    return {"wifiOn": radio, "wifi": current, "saved": saved, "btOn": bt_on, "devices": devs}


MOTION = os.path.expanduser("~/.local/state/p3-motion.json")


DARKHOUR = os.path.expanduser("~/.local/state/p3-darkhour.json")


def darkhour():
    try:
        with open(DARKHOUR) as f:
            return {"darkMode": json.load(f).get("mode", "auto")}
    except (OSError, ValueError):
        return {"darkMode": "auto"}


def motion():
    try:
        with open(MOTION) as f:
            o = json.load(f)
    except (OSError, ValueError):
        o = {}
    return {"motionMode": o.get("mode", "auto"), "motionThreshold": int(o.get("threshold", 30))}


def focus():
    return {"dnd": caelestia("notifs", "isDndEnabled") == "true",
            "awake": caelestia("idleInhibitor", "isEnabled") == "true"}


def state():
    with ThreadPoolExecutor(5) as ex:
        parts = list(ex.map(lambda f: f(), [audio, power, display, link, focus, motion, darkhour]))
    out = {}
    for p in parts:
        out.update(p)
    print(json.dumps(out), flush=True)


# ── writers ───────────────────────────────────────────────────────────────
def apply(key, val):
    if key == "output":
        run("pactl", "set-default-sink", val)
    elif key == "input":
        if val == "mute":
            run("wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1")
        else:
            run("pactl", "set-default-source", val)
            run("wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "0")
    elif key == "volume":
        if val == "mute":
            run("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1")
        else:
            run("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0")
            run("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{int(val) / 100:.2f}")
    elif key == "profile":
        run("busctl", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", val)
    elif key == "gamemode":
        caelestia("gameMode", "enable" if val == "on" else "disable")
    elif key == "brightness":
        run("brightnessctl", "-q", "set", f"{int(val)}%")
    elif key == "nightlight":
        if val == "auto":
            # back to the hyprsunset.conf schedule: restart the daemon
            run("pkill", "-x", "hyprsunset")
            spawn("hyprsunset")
        elif val == "off":
            if not run("pgrep", "-x", "hyprsunset"):
                return
            run("hyprctl", "hyprsunset", "identity")
        else:
            if not run("pgrep", "-x", "hyprsunset"):
                spawn("hyprsunset")
                import time; time.sleep(0.6)
            run("hyprctl", "hyprsunset", "temperature", val)
    elif key == "wifi":
        if val == "off":
            run("nmcli", "radio", "wifi", "off")
        else:
            run("nmcli", "radio", "wifi", "on")
            if val != "on":
                spawn("nmcli", "connection", "up", "id", val)
    elif key == "bluetooth":
        if val == "off":
            run("bluetoothctl", "power", "off")
        else:
            run("rfkill", "unblock", "bluetooth")
            run("bluetoothctl", "power", "on")
            if val != "on":
                spawn("bluetoothctl", "connect", val)
    elif key == "darkhour":
        if val not in ("auto", "on", "off"):
            print("error: bad darkhour " + val)
            return
        os.makedirs(os.path.dirname(DARKHOUR), exist_ok=True)
        with open(DARKHOUR + ".tmp", "w") as f:
            json.dump({"mode": val}, f)
        os.replace(DARKHOUR + ".tmp", DARKHOUR)
    elif key == "motion":
        mode, _, thr = val.partition(":")
        if mode not in ("auto", "always", "still"):
            print("error: bad motion " + val)
            return
        os.makedirs(os.path.dirname(MOTION), exist_ok=True)
        tmp = MOTION + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"mode": mode, "threshold": int(thr or 30)}, f)
        os.replace(tmp, MOTION)
    elif key == "dnd":
        caelestia("notifs", "enableDnd" if val == "on" else "disableDnd")
    elif key == "awake":
        caelestia("idleInhibitor", "enable" if val == "on" else "disable")
    else:
        print("error: unknown slot " + key)
        return
    print("ok", flush=True)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "state":
        state()
    elif len(sys.argv) == 4 and sys.argv[1] == "apply":
        apply(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)
