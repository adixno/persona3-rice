// DarkHour: whether the p3 Dark Hour is on (decided by p3-wall/darkhour.py, which writes
// ~/.local/state/p3-darkhour-active.json), plus `t`, an eased 0 → 1 blend every widget mixes
// its colours with, so the whole desktop turns green (and back) together.
// IDENTICAL COPIES live in every p3 config dir (and caelestia-overlay/modules/lock): keep in sync.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: dh

    property bool active: false
    property string reason: ""
    property real t: active ? 1 : 0
    Behavior on t { NumberAnimation { duration: 1100; easing.type: Easing.InOutCubic } }

    // the Dark Hour palette (measured from P3R)
    readonly property color green: "#50ff82"      // accents (was cyan)
    readonly property color lime: "#55fc26"
    readonly property color mid: "#1e8b29"
    readonly property color deep: "#04140c"

    // blend helper: dh.mix(normalColour, darkHourColour)
    function mix(a, b) {
        a = Qt.tint(a, "transparent");
        b = Qt.tint(b, "transparent");
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/p3-darkhour-active.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                dh.active = !!o.active;
                dh.reason = o.reason ?? "";
            } catch (e) {}
        }
    }
}
