# p3-hud helper: prints the global cursor position ("x,y") whenever it changes, polling
# Hyprland's request socket directly (no hyprctl process per poll). Interval in seconds
# is argv[1]. Exits when the parent goes away (stdout closes).
import os, socket, sys, time

interval = float(sys.argv[1]) if len(sys.argv) > 1 else 0.12
path = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket.sock"
last = None
while True:
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.connect(path)
            s.sendall(b"cursorpos")
            reply = s.recv(64).decode().replace(" ", "").strip()
    except OSError:
        reply = "-1,-1"
    if reply != last:
        last = reply
        print(reply, flush=True)
    time.sleep(interval)
