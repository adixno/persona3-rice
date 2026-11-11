// Motion: the one rule every animated p3 piece follows (wallpaper video, calendar waves,
// player scroll, menu backdrops, power-menu and lock videos).
//   mode "auto"   → move fully (on mains or battery) until the battery, unplugged, is at or
//                   below `threshold` %, then stop
//   mode "always" → always move;  mode "still" → never move
// Set from the Loadout (SUPER+G → Power → Motion), stored in ~/.local/state/p3-motion.json.
// `speed` eases to 0 when stopping (things slow to a halt where they are) and back to 1.
// IDENTICAL COPIES live in every p3 config dir (and caelestia-overlay/modules/lock): keep them in sync.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: m

    property string mode: "auto"
    property int threshold: 30

    readonly property bool known: UPower.displayDevice.ready
    readonly property real percent: {
        const p = UPower.displayDevice.percentage;
        return p <= 1 ? p * 100 : p;
    }
    readonly property bool low: known && UPower.onBattery && percent <= threshold
    readonly property bool live: mode === "always" || (mode === "auto" && !low)

    property real speed: live ? 1 : 0
    Behavior on speed {
        NumberAnimation {
            duration: m.live ? 900 : 1600
            easing.type: m.live ? Easing.InOutQuad : Easing.OutCubic
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/p3-motion.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                m.mode = ["auto", "always", "still"].includes(o.mode) ? o.mode : "auto";
                m.threshold = Math.max(1, Math.min(99, parseInt(o.threshold ?? 30)));
            } catch (e) {
                m.mode = "auto";
                m.threshold = 30;
            }
        }
        onLoadFailed: { m.mode = "auto"; m.threshold = 30; }
    }
}
