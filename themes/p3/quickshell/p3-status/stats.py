#!/usr/bin/env python3
"""p3-status data feed: prints one JSON line every ~1.5 s while the menu is open."""
import json, os, glob, time, subprocess, datetime, sys, threading

def rd(p, d=""):
    try:
        with open(p) as f: return f.read().strip()
    except OSError: return d

def cpu_times():
    v = list(map(int, rd("/proc/stat").splitlines()[0].split()[1:]))
    idle = v[3] + v[4]
    return idle, sum(v)

def net_bytes():
    rx = tx = 0
    for line in rd("/proc/net/dev").splitlines()[2:]:
        name, data = line.split(":", 1)
        if name.strip() == "lo": continue
        f = data.split(); rx += int(f[0]); tx += int(f[8])
    return rx, tx

def coretemp():
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        if rd(h + "/name") == "coretemp":
            t = rd(h + "/temp1_input")
            if t: return int(t) // 1000
    t = rd("/sys/class/thermal/thermal_zone0/temp")
    return int(t) // 1000 if t else 0

def ssid():
    """(network name, signal %) of the connected Wi-Fi. iw + /proc/net/wireless answer in a few
    ms; `nmcli dev wifi` takes ~4 s here (it rescans), which used to time out to "Offline"."""
    for l in rd("/proc/net/wireless").splitlines()[2:]:
        dev, rest = l.split(":", 1)
        dev = dev.strip()
        try:
            out = subprocess.run(["iw", "dev", dev, "link"], capture_output=True, text=True, timeout=2).stdout
        except Exception:
            out = ""
        name = next((x.split("SSID:", 1)[1].strip() for x in out.splitlines() if "SSID:" in x), "")
        if not name:
            try:
                name = subprocess.run(["nmcli", "-t", "-g", "GENERAL.CONNECTION", "dev", "show", dev],
                                      capture_output=True, text=True, timeout=2).stdout.strip()
            except Exception:
                name = ""
        if name:
            q = float(rest.split()[1].rstrip("."))   # link quality, out of 70
            return name, max(0, min(100, round(q * 100 / 70)))
    return "", 0

def volume():
    try:
        out = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
                             capture_output=True, text=True, timeout=2).stdout.split()
        return round(float(out[1]) * 100), "[MUTED]" in out
    except Exception: return 0, False

def brightness():
    for b in glob.glob("/sys/class/backlight/*"):
        m = int(rd(b + "/max_brightness", "0") or 0)
        if m: return round(int(rd(b + "/brightness", "0")) * 100 / m)
    return 0

TASKS = os.environ.get("P3_TASKS") or os.path.expanduser("~/.local/share/persona-rice/tasks.txt")

def tasks():
    items = []
    for l in rd(TASKS).splitlines():
        s = l.strip()
        if s.startswith("- [x]") or s.startswith("- [X]"): items.append({"t": s[5:].strip(), "d": True})
        elif s.startswith("- [ ]"): items.append({"t": s[5:].strip(), "d": False})
        elif s.startswith("- "): items.append({"t": s[2:].strip(), "d": False})
    return items

if len(sys.argv) == 3 and sys.argv[1] == "toggle":
    # flip the Nth task between "- [ ]" and "- [x]"
    n, k, out = int(sys.argv[2]), -1, []
    for l in rd(TASKS).splitlines():
        s = l.lstrip()
        if s.startswith("- "):
            k += 1
            if k == n:
                pad = l[:len(l) - len(s)]
                if s[:5].lower() == "- [x]": l = pad + "- [ ]" + s[5:]
                elif s.startswith("- [ ]"): l = pad + "- [x]" + s[5:]
                else: l = pad + "- [x] " + s[2:]
        out.append(l)
    with open(TASKS, "w") as f: f.write("\n".join(out) + "\n")
    sys.exit(0)

prev_cpu, prev_net, prev_t = cpu_times(), net_bytes(), time.time()
# nmcli is slow (~0.5-1 s): look the network up in the background so the first line is instant
# start from the last known network (cached) so the row never flashes "Offline"
CACHE = os.path.expanduser("~/.cache/p3-status-wifi")
try:
    _n, _sig = rd(CACHE).split("\t")
    wifi = (_n, int(_sig))
except ValueError:
    wifi = ("", 0)
wtick = 0
def _wifi():
    global wifi
    while True:
        wifi = ssid()
        try:
            os.makedirs(os.path.dirname(CACHE), exist_ok=True)
            with open(CACHE, "w") as f: f.write(f"{wifi[0]}\t{wifi[1]}")
        except OSError: pass
        time.sleep(9)
threading.Thread(target=_wifi, daemon=True).start()
ncpu = os.cpu_count() or 1
time.sleep(0.25)
while True:
    now = time.time(); dt = max(0.1, now - prev_t)
    idle, tot = cpu_times()
    cpu = 100 * (1 - (idle - prev_cpu[0]) / max(1, tot - prev_cpu[1]))
    rx, tx = net_bytes()
    down, up = (rx - prev_net[0]) / dt / 1024, (tx - prev_net[1]) / dt / 1024
    prev_cpu, prev_net, prev_t = (idle, tot), (rx, tx), now

    mem = {}
    for l in rd("/proc/meminfo").splitlines():
        k, v = l.split(":"); mem[k] = int(v.split()[0])
    mt, ma = mem["MemTotal"], mem["MemAvailable"]
    st, sf = mem.get("SwapTotal", 0), mem.get("SwapFree", 0)

    fs = os.statvfs("/")
    dtot = fs.f_blocks * fs.f_frsize; dfree = fs.f_bavail * fs.f_frsize

    bat = "/sys/class/power_supply/BAT0"
    full = int(rd(bat + "/charge_full", rd(bat + "/energy_full", "0")) or 0)
    design = int(rd(bat + "/charge_full_design", rd(bat + "/energy_full_design", "0")) or 0)
    curr = int(rd(bat + "/current_now", rd(bat + "/power_now", "0")) or 0)
    cnow = int(rd(bat + "/charge_now", rd(bat + "/energy_now", "0")) or 0)
    status = rd(bat + "/status", "Unknown")
    mins = 0
    if curr > 5000:
        mins = int(60 * (cnow / curr if status == "Discharging" else max(0, full - cnow) / curr))

    wtick += 1
    vol, muted = volume()
    up_s = float(rd("/proc/uptime", "0 0").split()[0])
    load = float(rd("/proc/loadavg", "0").split()[0])
    t = datetime.datetime.now()

    print(json.dumps({
        "cpu": round(cpu), "cores": ncpu, "temp": coretemp(), "load": load,
        "memPct": round(100 * (mt - ma) / mt), "memUsed": round((mt - ma) / 1048576, 1), "memTotal": round(mt / 1048576),
        "swapPct": round(100 * (st - sf) / st) if st else 0, "swapUsed": round((st - sf) / 1048576, 1),
        "diskPct": round(100 * (dtot - dfree) / dtot), "diskFree": round(dfree / 1e9), "diskTotal": round(dtot / 1e9),
        "bat": int(rd(bat + "/capacity", "0") or 0), "batStatus": status,
        "batHealth": round(100 * full / design) if design else 0, "batMins": mins,
        "ssid": wifi[0], "signal": wifi[1], "down": round(down), "up": round(up),
        "vol": vol, "muted": muted, "bright": brightness(),
        "uptime": int(up_s), "tasks": tasks(), "tasksFile": TASKS,
        "dayPct": round(100 * (t.hour * 3600 + t.minute * 60 + t.second) / 86400),
        "weekPct": round(100 * (t.weekday() * 86400 + t.hour * 3600 + t.minute * 60) / 604800),
    }), flush=True)
    time.sleep(1.5)
