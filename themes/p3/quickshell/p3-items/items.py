#!/usr/bin/env python3
"""p3-items backend (the toolkit / ITEM screen).

  items.py state     -> JSON: vitals for the party rows + use counts per tool
  items.py use ID    -> run tool ID and count the use

Tools are listed in shell.qml (names, icons, descriptions); this file only knows how to run
them. Use counts live in ~/.local/state/p3-items.json.
"""
import json, os, subprocess, sys, shutil, time, re

HOME = os.path.expanduser("~")
STATE = os.path.join(HOME, ".local/state/p3-items.json")
SHOTS = os.path.join(HOME, "Pictures/Screenshots")
THUMBS = os.path.join(HOME, ".cache/thumbnails")
TRASH = os.path.join(HOME, ".local/share/Trash")


def run(*cmd, timeout=5, input=None):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, input=input).stdout.strip()
    except Exception:
        return ""


def sh(script):
    # long / interactive tools: fully detached so the menu never waits on them
    subprocess.Popen(["sh", "-c", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def notify(title, body="", icon="dialog-information"):
    run("notify-send", "-a", "Toolkit", "-i", icon, title, body)


def du(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}"
        n /= 1024


def counts():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def bump(tool):
    c = counts()
    c[tool] = c.get(tool, 0) + 1
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(c, f)


def recording():
    return bool(run("pgrep", "-f", "gpu-screen-recorder"))


def state():
    st = os.statvfs("/")
    total, free = st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
    trash_files = os.path.join(TRASH, "files")
    try:
        trash_n = len(os.listdir(trash_files))
    except OSError:
        trash_n = 0
    trash_b = du(trash_files)
    thumbs_b = du(THUMBS)
    try:
        shots = len([f for f in os.listdir(SHOTS) if not f.startswith(".")])
    except OSError:
        shots = 0
    # clipboard: history size (cliphist, if it's recording) + what's on it right now
    hist = run("cliphist", "list", timeout=2)
    clip_n = 0 if (not hist or hist.startswith("opening db")) else len(hist.splitlines())
    try:
        clip_len = len(subprocess.run(["wl-paste", "-n"], capture_output=True, timeout=1).stdout)
    except Exception:
        clip_len = 0
    # system: load (% of all cores), uptime, hourglass timers still pending
    try:
        load = float(open("/proc/loadavg").read().split()[0])
        up = float(open("/proc/uptime").read().split()[0])
    except (OSError, ValueError):
        load, up = 0.0, 0.0
    timers = sum(1 for l in run("systemctl", "--user", "list-timers", "--no-legend").splitlines() if "run-" in l)
    print(json.dumps({
        "clipN": clip_n, "clipLen": clip_len,
        "load": round(100 * load / (os.cpu_count() or 1)), "uptimeH": int(up // 3600), "timers": timers,
        "diskFree": free, "diskTotal": total, "diskFreeH": human(free),
        "trashN": trash_n, "trashB": trash_b, "trashH": human(trash_b),
        "cacheB": thumbs_b, "cacheH": human(thumbs_b),
        "recording": recording(), "shots": shots,
        "counts": counts(),
    }), flush=True)


# ── tools ───────────────────────────────────────────────────────────────────
def shot_name(kind):
    os.makedirs(SHOTS, exist_ok=True)
    return os.path.join(SHOTS, time.strftime(f"{kind}_%Y%m%d_%H%M%S.png"))


def use(tool):
    q = "qs -c caelestia ipc call"
    if tool == "snap":
        sh(f"{q} picker openFreeze")
    elif tool == "panorama":
        sh("caelestia screenshot")
    elif tool == "window":
        try:
            w = json.loads(run("hyprctl", "-j", "activewindow") or "{}")
            x, y = w["at"]
            ww, hh = w["size"]
        except (ValueError, KeyError):
            notify("Window Prism", "No window to capture")
            return
        out = shot_name("window")
        sh(f"grim -g '{x},{y} {ww}x{hh}' '{out}' && wl-copy < '{out}' && "
           f"notify-send -a Toolkit -i '{out}' 'Window Prism' 'Window saved and copied'")
    elif tool == "sketch":
        out = shot_name("sketch")
        sh(f"g=$(slurp) && grim -g \"$g\" - | satty --filename - --output-filename '{out}' --copy-command wl-copy --early-exit")
    elif tool in ("reel", "reel-area", "echo"):
        args = {"reel": "", "reel-area": "-r", "echo": "-s"}[tool]
        sh(f"caelestia record {args}")
    elif tool == "prism":
        sh("hyprpicker -a -n")
    elif tool == "glyph":
        sh("caelestia emoji -p")
    elif tool == "recall":
        sh("caelestia clipboard")
    elif tool == "abacus":
        sh("kitty --class p3-calc -e qalc")
    elif tool in ("hourglass5", "hourglass25"):
        m = 5 if tool == "hourglass5" else 25
        run("systemd-run", "--user", f"--on-active={m}m", "--timer-property=AccuracySec=1s",
            "notify-send", "-a", "Toolkit", "-u", "critical", "-i", "alarm-symbolic",
            "Hourglass", f"{m} minutes are up")
        notify("Hourglass", f"Timer set for {m} minutes", "alarm-symbolic")
    elif tool == "address":
        m = re.search(r"src (\S+)", run("ip", "-4", "route", "get", "1.1.1.1"))
        if m:
            run("wl-copy", m.group(1))
            notify("Address Card", f"Copied {m.group(1)}")
        else:
            notify("Address Card", "Not connected")
    elif tool == "signal":
        out = run("nmcli", "dev", "wifi", "show-password")
        ssid = re.search(r"SSID:\s*(.+)", out)
        pw = re.search(r"Password:\s*(.+)", out)
        if pw:
            run("wl-copy", pw.group(1).strip())
            notify("Signal Key", f"Password for {ssid.group(1).strip() if ssid else 'this network'} copied")
        else:
            notify("Signal Key", "No Wi-Fi password available")
    elif tool == "purify":
        before = du(os.path.join(TRASH, "files"))
        run("gio", "trash", "--empty", timeout=60)
        notify("Purify Salt", f"Trash emptied, {human(before)} freed", "user-trash")
    elif tool == "satchel":
        sh(f"xdg-open '{os.path.join(HOME, 'Downloads')}'")
    elif tool == "album":
        os.makedirs(SHOTS, exist_ok=True)
        sh(f"xdg-open '{SHOTS}'")
    elif tool == "survey":
        # the five biggest folders in home, as a notification
        out = run("sh", "-c", "du -xsh \"$HOME\"/* \"$HOME\"/.cache \"$HOME\"/.local 2>/dev/null | sort -rh | head -5", timeout=30)
        lines = [l.split("\t") for l in out.splitlines() if "\t" in l]
        body = "\n".join(f"{size}  {os.path.relpath(path, HOME)}" for size, path in lines) or "Nothing found"
        notify("Disk Survey", body, "drive-harddisk")
    elif tool == "clearwater":
        sh(f"{q} notifs clear")
    elif tool == "blank":
        run("cliphist", "wipe")
        run("wl-copy", "--clear")
        notify("Blank Page", "Clipboard cleared")
    elif tool == "ash":
        before = du(THUMBS)
        shutil.rmtree(THUMBS, ignore_errors=True)
        notify("Ash Broom", f"Thumbnail cache cleared, {human(before)} freed")
    elif tool == "revival":
        sh("pkill -f '^qs -c caelestia'; sleep 0.6; caelestia shell -d")
    elif tool == "tonic":
        run("hyprctl", "reload")
        notify("Hyper Tonic", "Hyprland config reloaded")
    elif tool == "lock":
        sh(f"{q} lock lock")
    elif tool == "banish":
        sh("hyprctl kill")
    elif tool == "sleep":
        sh("systemctl suspend")
    else:
        print("error: unknown tool " + tool)
        return
    bump(tool)
    print("ok", flush=True)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "state":
        state()
    elif len(sys.argv) == 3 and sys.argv[1] == "use":
        use(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(2)
