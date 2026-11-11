// p3-equip: "loadout" screen for the Persona 3 theme (local only).
// Left: slot rows (Sound / Power / Display / Link / Focus). Middle: what each slot has
// equipped (navy pill header + icon chip + item). ↵ on an item opens the options to equip,
// with an RPG-style stat comparison; ↵ again equips it (equip.py does the real work:
// pactl/wpctl, power-profiles D-Bus, brightnessctl, hyprsunset, nmcli, bluetoothctl,
// Caelestia IPC for game mode / DND / idle inhibitor).
// Backdrop art slot: ~/.local/share/persona-rice/media/p3/equip-bg.png
//
// Resident like p3-status: hidden = 1x1 click-through window, scene kept alive, intro starts
// once real frames are on screen. Toggle: SUPER+G (Hyprland global p3equip:toggle) or
// qs -c p3-equip ipc call equip toggle
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

ShellRoot {
    id: shell

    // the Dark Hour grades the art green and swaps cyan accents for green (DarkHour.qml)
    DarkHour { id: dh }

    readonly property string media: Quickshell.env("P3_MEDIA") || (Quickshell.env("HOME") + "/.local/share/persona-rice/media/p3")
    readonly property string dir: Quickshell.shellDir
    property bool shown: Quickshell.env("P3_EQUIP_OPEN") === "1"

    function toggle(): void {
        if (!shell.shown)
            shell.shown = true;
        else if (content.item)
            content.item.close();
    }

    // another p3 menu opened: vanish at once (no close animation under/over it)
    GlobalShortcut {
        appid: "p3equip"
        name: "hide"
        description: "Hide immediately (another p3 menu is opening)"
        onPressed: {
            if (!shell.shown)
                return;
            if (content.item)
                content.item.hideNow();
            else
                shell.shown = false;
        }
    }

    GlobalShortcut {
        appid: "p3equip"
        name: "toggle"
        description: "Toggle the p3 loadout screen"
        onPressed: shell.toggle()
    }

    IpcHandler {
        target: "equip"
        function toggle(): void { shell.toggle(); }
        function open(): void { shell.shown = true; }
        function close(): void {
            if (content.item)
                content.item.close();
        }
        // scripting / testing: move (d = ±1), enter, back
        function move(d: int): void { if (content.item) content.item.move(d); }
        function enter(): void { if (content.item) content.item.enter(); }
        function back(): void { if (content.item) content.item.back(); }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; left: true; bottom: shell.shown; right: shell.shown }
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: shell.shown ? null : noInput
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "p3-equip"
        WlrLayershell.keyboardFocus: shell.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Region { id: noInput }

        Loader {
            id: content
            width: win.screen ? win.screen.width : 1280
            height: win.screen ? win.screen.height : 720
            focus: true
            sourceComponent: Component {
        Item {
            id: root

            anchors.fill: parent
            focus: true

            readonly property real u: height / 720
            readonly property color deep: "#030a26"
            readonly property color navy: "#16246e"
            readonly property color ink: "#0a0b10"
            readonly property color cyan: dh.mix("#2ee6ff", dh.green)
            readonly property color white: "#f2fbff"
            readonly property color red: "#ff1f3a"
            readonly property string face: "Montserrat"
            readonly property string icons: "Material Symbols Rounded"

            property real fill: 0
            property real rowsIn: 0
            property real midIn: 0
            property bool closing: false
            property bool warming: false
            property int warmFrames: 0

            // navigation: col 0 = slot rows, 1 = equipped items, 2 = options list
            property int col: 0
            property int cat: 0
            property int item: 0
            property int opt: 0

            property var st: ({})

            // ── slot-selected transition ─────────────────────────────────
            // selP 0 = slot list on the white diamond, 1 = slot selected: navy diamond, the row
            // stretched into the top bar, gear list in the navy area. Every element runs on its
            // own slice of selP, so going back simply plays it in reverse.
            property real selP: 0
            readonly property bool selected: col > 0
            onSelectedChanged: {
                selAnim.stop();
                selAnim.to = selected ? 1 : 0;
                selAnim.duration = selected ? 680 : 520;
                selAnim.start();
            }
            NumberAnimation { id: selAnim; target: root; property: "selP"; easing.type: Easing.Linear }
            function seg(p, a, b) { return Math.max(0, Math.min(1, (p - a) / (b - a))); }
            function eOut(t) { return 1 - Math.pow(1 - t, 3); }
            function eInOut(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
            function lerp(a, b, t) { return a + (b - a) * t; }
            function mixc(a, b, t) {
                // accept colour strings too (Qt.tint with transparent = plain conversion)
                a = Qt.tint(a, "transparent");
                b = Qt.tint(b, "transparent");
                return Qt.rgba(lerp(a.r, b.r, t), lerp(a.g, b.g, t), lerp(a.b, b.b, t), lerp(a.a, b.a, t));
            }
            readonly property real heroP: eInOut(seg(selP, 0.08, 0.60))
            readonly property real wipeP: eInOut(seg(selP, 0.12, 0.75))
            // the list leaves the bar's landing zone early and fast (eOut), and re-colours
            // only as the navy sweep reaches it
            readonly property real midP: eOut(seg(selP, 0.04, 0.62))
            readonly property real midColP: eInOut(seg(selP, 0.32, 0.56))
            readonly property color navyBg: "#0c205b"
            // animation clock (s); only ticks while open
            property real clock: 0
            // ambient motion follows the shared rule (Motion.qml): full speed until the battery
            // limit, then it eases to a halt
            Motion { id: motion }
            FrameAnimation {
                running: shell.shown && motion.speed > 0
                onTriggered: root.clock += frameTime * motion.speed
            }
            property string flashText: ""

            // ── what can be equipped ─────────────────────────────────────
            readonly property var cats: [
                { name: "Sound", col: "#ff5fae", icon: "headphones" },
                { name: "Power", col: "#ffd23f", icon: "bolt" },
                { name: "Display", col: "#3fd8ff", icon: "light_mode" },
                { name: "Link", col: "#3dff8a", icon: "wifi" },
                { name: "Focus", col: "#b06bff", icon: "self_improvement" }
            ]

            function onOff(key, onLabel, offLabel, onStats, offStats, isOn) {
                return [
                    { v: "on", label: onLabel, icon: "toggle_on", stats: onStats, cur: isOn },
                    { v: "off", label: offLabel, icon: "toggle_off", stats: offStats, cur: !isOn }
                ];
            }

            function slots(ci) {
                const t = st;
                switch (ci) {
                case 0: {
                    const vol = t.volume ?? 0;
                    const lv = v => [["LOUDNESS", v / 20], ["PEACE", 5 - v / 20]];
                    return [
                        { key: "output", name: "Output", icon: "speaker",
                          options: (t.sinks ?? []).map(n => ({ v: n.id, label: n.label, icon: n.bt ? "headphones" : "speaker", stats: [], cur: n.id === t.sink })) },
                        { key: "volume", name: "Volume", icon: "volume_up",
                          options: [{ v: "mute", label: "Muted", icon: "volume_off", stats: lv(0), cur: !!t.muted }]
                              .concat([25, 50, 75, 100].map(p => ({ v: String(p), label: p + "%", icon: p < 50 ? "volume_down" : "volume_up", stats: lv(p), cur: !t.muted && vol === p }))),
                          fallback: t.muted ? "Muted" : vol + "%" },
                        { key: "input", name: "Microphone", icon: "mic",
                          options: (t.sources ?? []).map(n => ({ v: n.id, label: n.label, icon: n.bt ? "headset_mic" : "mic", stats: [], cur: !t.micMuted && n.id === t.source }))
                              .concat([{ v: "mute", label: "Muted", icon: "mic_off", stats: [], cur: !!t.micMuted }]) }
                    ];
                }
                case 1: return [
                    { key: "profile", name: "Profile", icon: "speed", options: [
                        { v: "power-saver", label: "Power Saver", icon: "eco", stats: [["SPEED", 2], ["BATTERY", 5], ["HEAT", 1]], cur: t.profile === "power-saver" },
                        { v: "balanced", label: "Balanced", icon: "balance", stats: [["SPEED", 3], ["BATTERY", 3], ["HEAT", 3]], cur: t.profile === "balanced" },
                        { v: "performance", label: "Performance", icon: "local_fire_department", stats: [["SPEED", 5], ["BATTERY", 1], ["HEAT", 5]], cur: t.profile === "performance" }
                    ] },
                    { key: "gamemode", name: "Game Mode", icon: "sports_esports",
                      options: onOff("gamemode", "On", "Off", [["EYE CANDY", 1], ["FRAMES", 5]], [["EYE CANDY", 5], ["FRAMES", 3]], !!t.gamemode) },
                    // the P3 Dark Hour (green desktop): with game mode / at midnight, always, never
                    { key: "darkhour", name: "Dark Hour", icon: "dark_mode", options: [
                        { v: "auto", label: "Game mode + midnight", icon: "sports_esports", stats: [["MYSTERY", 3], ["NORMALCY", 3]], cur: (t.darkMode ?? "auto") === "auto" },
                        { v: "on", label: "Always", icon: "nightlight", stats: [["MYSTERY", 5], ["NORMALCY", 0]], cur: t.darkMode === "on" },
                        { v: "off", label: "Never", icon: "wb_sunny", stats: [["MYSTERY", 0], ["NORMALCY", 5]], cur: t.darkMode === "off" }
                    ] },
                    // every p3 animation (wallpaper, calendar, menus, lock): when it stops
                    { key: "motion", name: "Motion", icon: "animation", options: [
                        { v: "auto:50", label: "Until 50%", icon: "battery_5_bar", stats: [["FLAIR", 3], ["BATTERY", 4]], cur: t.motionMode === "auto" && t.motionThreshold === 50 },
                        { v: "auto:30", label: "Until 30%", icon: "battery_3_bar", stats: [["FLAIR", 4], ["BATTERY", 3]], cur: (t.motionMode ?? "auto") === "auto" && (t.motionThreshold ?? 30) === 30 },
                        { v: "auto:20", label: "Until 20%", icon: "battery_2_bar", stats: [["FLAIR", 4.5], ["BATTERY", 2]], cur: t.motionMode === "auto" && t.motionThreshold === 20 },
                        { v: "always", label: "Always", icon: "all_inclusive", stats: [["FLAIR", 5], ["BATTERY", 1]], cur: t.motionMode === "always" },
                        { v: "still", label: "Still", icon: "pause_circle", stats: [["FLAIR", 0], ["BATTERY", 5]], cur: t.motionMode === "still" }
                    ] }
                ];
                case 2: {
                    const b = t.brightness ?? 0;
                    const temp = t.temperature ?? 6500;
                    const presets = [4500, 3500, 2700];
                    const nl = (w, a) => [["WARMTH", w], ["ACCURACY", a], ["SLEEP", w]];
                    return [
                        { key: "brightness", name: "Brightness", icon: "brightness_6",
                          options: [10, 30, 50, 75, 100].map(p => ({ v: String(p), label: p + "%", icon: p < 50 ? "brightness_low" : "brightness_high",
                              stats: [["GLOW", p / 20], ["BATTERY", 5 - p / 25]], cur: Math.abs(b - p) <= 2 })),
                          fallback: b + "%" },
                        { key: "nightlight", name: "Night Light", icon: "nightlight", options: [
                            { v: "auto", label: "Schedule", icon: "schedule", stats: nl(3, 3), cur: temp < 6000 && presets.indexOf(temp) < 0 },
                            { v: "off", label: "Off", icon: "wb_sunny", stats: nl(0, 5), cur: temp >= 6000 },
                            { v: "4500", label: "Warm 4500K", icon: "nightlight", stats: nl(2, 4), cur: temp === 4500 },
                            { v: "3500", label: "Warmer 3500K", icon: "nightlight", stats: nl(4, 2), cur: temp === 3500 },
                            { v: "2700", label: "Candle 2700K", icon: "candle", stats: nl(5, 1), cur: temp === 2700 }
                        ] }
                    ];
                }
                case 3: return [
                    { key: "wifi", name: "Wi-Fi", icon: "wifi", options: [
                        { v: "off", label: "Off", icon: "wifi_off", stats: [], cur: !t.wifiOn },
                        { v: "on", label: "On", icon: "wifi", stats: [], cur: !!t.wifiOn && !t.wifi }
                      ].concat((t.saved ?? []).map(n => ({ v: n, label: n, icon: "wifi", stats: [], cur: !!t.wifiOn && t.wifi === n }))) },
                    { key: "hotspot", name: "Hotspot", icon: "wifi_tethering", options: [
                        { v: "off", label: "Off", icon: "wifi_tethering_off", stats: [], cur: !t.hotspotOn },
                        { v: "on", label: t.hotspot ? "On · " + t.hotspot : "On", icon: "wifi_tethering", stats: [], cur: !!t.hotspotOn }
                      ] },
                    { key: "bluetooth", name: "Bluetooth", icon: "bluetooth", options: [
                        { v: "off", label: "Off", icon: "bluetooth_disabled", stats: [], cur: !t.btOn },
                        { v: "on", label: "On", icon: "bluetooth", stats: [], cur: !!t.btOn && !(t.devices ?? []).some(d => d.connected) }
                      ].concat((t.devices ?? []).map(d => ({ v: d.id, label: d.label, icon: "headphones",
                          stats: d.battery ? [["CHARGE", parseInt(d.battery) / 20]] : [], cur: !!t.btOn && d.connected }))) }
                ];
                case 4: return [
                    { key: "dnd", name: "Do Not Disturb", icon: "do_not_disturb_on",
                      options: onOff("dnd", "On", "Off", [["CALM", 5], ["AWARENESS", 1]], [["CALM", 2], ["AWARENESS", 5]], !!t.dnd) },
                    { key: "awake", name: "Stay Awake", icon: "coffee",
                      options: onOff("awake", "On", "Off", [["AWAKE", 5], ["BATTERY", 2]], [["AWAKE", 2], ["BATTERY", 4]], !!t.awake) }
                ];
                }
                return [];
            }
            readonly property var curSlots: slots(cat)
            readonly property var curSlot: curSlots[Math.min(item, curSlots.length - 1)]
            readonly property var curOpts: curSlot ? curSlot.options : []
            function equipped(sl) {
                const o = sl.options.find(x => x.cur);
                return o ? o.label : (sl.fallback ?? "—");
            }
            function equippedOpt(sl) {
                return sl.options.find(x => x.cur) ?? null;
            }

            // ── data ─────────────────────────────────────────────────────
            Process {
                id: reader
                command: ["python3", shell.dir + "/equip.py", "state"]
                stdout: SplitParser {
                    onRead: line => {
                        try { root.st = JSON.parse(line); } catch (e) {}
                    }
                }
            }
            function refresh() {
                if (!reader.running)
                    reader.running = true;
            }
            Process {
                id: applier
                onExited: {
                    root.refresh();
                    lateRefresh.restart();   // wifi / bluetooth connect in the background
                }
            }
            Timer { id: lateRefresh; interval: 3500; onTriggered: root.refresh() }

            function equip() {
                if (!shell.shown || closing)
                    return;
                const sl = curSlot;
                const o = curOpts[opt];
                if (!sl || !o)
                    return;
                if (!o.cur) {
                    applier.command = ["python3", shell.dir + "/equip.py", "apply", sl.key, o.v];
                    applier.running = true;
                    // optimistic: mark it equipped right away
                    const ns = Object.assign({}, st);
                    applyLocal(ns, sl.key, o.v);
                    st = ns;
                }
                flashText = "EQUIPPED";
                flash.restart();
                col = 1;
            }
            function applyLocal(t, key, v) {
                switch (key) {
                case "output": t.sink = v; break;
                case "input": if (v === "mute") t.micMuted = true; else { t.source = v; t.micMuted = false; } break;
                case "volume": if (v === "mute") t.muted = true; else { t.muted = false; t.volume = parseInt(v); } break;
                case "profile": t.profile = v; break;
                case "gamemode": t.gamemode = v === "on"; break;
                case "darkhour": t.darkMode = v; break;
                case "motion": t.motionMode = v.split(":")[0]; t.motionThreshold = parseInt(v.split(":")[1] ?? "30"); break;
                case "brightness": t.brightness = parseInt(v); break;
                case "nightlight": t.temperature = v === "off" ? 6500 : v === "auto" ? 4200 : parseInt(v); break;
                case "wifi": t.wifiOn = v !== "off"; if (v !== "on" && v !== "off") t.wifi = v; break;
                case "hotspot": t.hotspotOn = v === "on"; if (v === "on") { t.wifiOn = true; t.wifi = ""; } break;
                case "bluetooth": t.btOn = v !== "off"; break;
                case "dnd": t.dnd = v === "on"; break;
                case "awake": t.awake = v === "on"; break;
                }
            }

            // ── navigation ───────────────────────────────────────────────
            function move(d) {
                if (!shell.shown || closing)
                    return;
                if (col === 0) {
                    cat = (cat + d + cats.length) % cats.length;
                    item = 0;
                } else if (col === 1) {
                    item = (item + d + curSlots.length) % curSlots.length;
                } else if (curOpts.length) {
                    opt = (opt + d + curOpts.length) % curOpts.length;
                }
            }
            function enter() {
                if (!shell.shown || closing)
                    return;
                if (col === 0) {
                    col = 1;
                    item = Math.min(item, curSlots.length - 1);
                } else if (col === 1) {
                    if (!curOpts.length)
                        return;
                    const i = curOpts.findIndex(x => x.cur);
                    opt = i >= 0 ? i : 0;
                    col = 2;
                } else {
                    equip();
                }
            }
            function back() {
                if (!shell.shown || closing)
                    return;
                if (col > 0)
                    col--;
                else
                    close();
            }

            Keys.onUpPressed: move(-1)
            Keys.onDownPressed: move(1)
            Keys.onTabPressed: { if (col === 0) move(1); else { col = 0; move(1); } }
            Keys.onBacktabPressed: { col = 0; move(-1); }
            Keys.onRightPressed: if (col < 2) enter()
            Keys.onLeftPressed: if (col > 0) back()
            Keys.onReturnPressed: enter()
            Keys.onEnterPressed: enter()
            Keys.onSpacePressed: enter()
            Keys.onEscapePressed: back()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_J) move(1);
                else if (e.key === Qt.Key_K) move(-1);
                else if (e.key === Qt.Key_L) { if (col < 2) enter(); }
                else if (e.key === Qt.Key_H) { if (col > 0) back(); }
                else if (e.key === Qt.Key_Q) close();
            }

            // ── open / close (same warm-up as p3-status) ─────────────────
            function hideNow() {
                closeAnim.stop();
                openAnim.stop();
                warming = false;
                closing = false;
                fill = 0; rowsIn = 0; midIn = 0;
                shell.shown = false;
            }
            // only one p3 menu at a time: opening this one hides the others (hyprctl → their
            // "hide" globals, ~10 ms; a qs ipc call would cost ~200 ms each)
            function hideOthers() {
                Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.global(\"p3status:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3items:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3skills:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3links:hide\")' >/dev/null"]);
            }
            function reopen() {
                hideOthers();
                closeAnim.stop();
                openAnim.stop();
                closing = false;
                fill = 0;
                rowsIn = 0;
                midIn = 0;
                col = 0;
                opt = 0;
                selAnim.stop();
                selP = 0;
                refresh();
                warmFrames = 0;
                warming = true;
            }
            Connections {
                target: shell
                function onShownChanged() {
                    if (shell.shown)
                        root.reopen();
                }
            }
            Connections {
                target: root.Window.window
                function onFrameSwapped() {
                    if (!root.warming)
                        return;
                    if (++root.warmFrames >= 2) {
                        root.warming = false;
                        openAnim.restart();
                    } else {
                        root.Window.window.update();
                    }
                }
            }
            Component.onCompleted: {
                refresh();
                if (shell.shown)
                    reopen();
            }
            function close() {
                if (closing)
                    return;
                closing = true;
                closeAnim.start();
            }

            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: root; property: "fill"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 100 }
                    NumberAnimation { target: root; property: "rowsIn"; from: 0; to: 1; duration: 560; easing.type: Easing.Linear }
                }
                SequentialAnimation {
                    PauseAnimation { duration: 260 }
                    NumberAnimation { target: root; property: "midIn"; from: 0; to: 1; duration: 520; easing.type: Easing.Linear }
                }
            }
            SequentialAnimation {
                id: closeAnim
                ParallelAnimation {
                    NumberAnimation { target: root; property: "rowsIn"; to: 0; duration: 200 }
                    NumberAnimation { target: root; property: "midIn"; to: 0; duration: 160 }
                }
                NumberAnimation { target: root; property: "fill"; to: 0; duration: 220; easing.type: Easing.InCubic }
                ScriptAction { script: shell.shown = false }
            }

            // ── backdrop ─────────────────────────────────────────────────
            Item {
                id: backdrop
                layer.enabled: dh.t > 0
                layer.effect: ShaderEffect {
                    property real dark: dh.t
                    fragmentShader: Qt.resolvedUrl("grade.frag.qsb")
                }
                anchors.fill: parent
                opacity: root.warming ? 0.004 : root.fill

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#16b4ff" }
                        GradientStop { position: 1.0; color: "#0a1cb8" }
                    }
                }
                Image {
                    id: bgImg
                    anchors.fill: parent
                    source: "file://" + shell.media + "/equip-bg.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    mipmap: true
                    // shown as-is only if the animation mask is missing
                    visible: maskImg.status !== Image.Ready
                }
                Image {
                    id: imgB
                    anchors.fill: parent
                    source: "file://" + shell.media + "/equip-bg-sel.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    mipmap: true
                    visible: false
                }
                Image {
                    id: maskImg
                    anchors.fill: parent
                    source: "file://" + shell.media + "/equip-mask.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    visible: false
                }
                // living backdrop: water ripple + caustics, character breathing (backdrop.frag)
                ShaderEffect {
                    anchors.fill: parent
                    visible: maskImg.status === Image.Ready && bgImg.status === Image.Ready
                    property variant src: bgImg
                    property variant mask: maskImg
                    property variant srcB: imgB.status === Image.Ready ? imgB : bgImg
                    property real wipe: imgB.status === Image.Ready ? root.wipeP : 0
                    property real time: root.clock
                    property real aspect: width / Math.max(1, height)
                    fragmentShader: Qt.resolvedUrl("backdrop.frag.qsb")
                }

                // drifting glass shards, like the fragments in the art
                Repeater {
                    // x, y (logical, 1280x720 design), size, colour, rise speed, phase
                    model: [
                        [700, 520, 16, "#ff4fd8", 9, 0.0], [780, 610, 11, "#5fe3ff", 7, 1.3],
                        [905, 470, 13, "#ffffff", 8, 2.6], [1010, 640, 18, "#c04bff", 6, 0.7],
                        [1110, 430, 10, "#5fe3ff", 10, 3.4], [1180, 560, 14, "#ff4fd8", 7, 4.1],
                        [640, 650, 9, "#a9c8ff", 8, 5.0], [1240, 660, 12, "#ffffff", 9, 2.0],
                        [860, 690, 15, "#ff4fd8", 5, 3.9], [1060, 520, 8, "#ffffff", 11, 5.6]
                    ]
                    Shape {
                        id: shard
                        required property var modelData
                        readonly property real range: 140
                        // 0..1 progress through one rise, wraps while invisible
                        readonly property real prog: ((root.clock * modelData[4] / range + modelData[5] / 6.2831853) % 1 + 1) % 1
                        readonly property real sz: modelData[2] * 1.7 * root.u
                        x: (modelData[0] + 12 * Math.sin(root.clock * 0.6 + modelData[5])) * root.u
                        y: (modelData[1] - prog * range) * root.u
                        rotation: modelData[5] * 57 + root.clock * (12 + modelData[4] * 2)
                        opacity: Math.sin(Math.PI * prog) * 0.75
                        width: sz
                        height: sz
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: shard.modelData[3]
                            strokeWidth: -1
                            PathPolyline {
                                path: [Qt.point(0, shard.sz * 0.2), Qt.point(shard.sz, 0), Qt.point(shard.sz * 0.65, shard.sz),
                                       Qt.point(0, shard.sz * 0.2)]
                            }
                        }
                        // light facet: reads as a glass chip rather than a flat triangle
                        ShapePath {
                            fillColor: Qt.alpha("#ffffff", 0.55)
                            strokeWidth: -1
                            PathPolyline {
                                path: [Qt.point(0, shard.sz * 0.2), Qt.point(shard.sz, 0), Qt.point(shard.sz * 0.45, shard.sz * 0.42),
                                       Qt.point(0, shard.sz * 0.2)]
                            }
                        }
                    }
                }
            }

            // ── slot rows (left) ─────────────────────────────────────────
            Item {
                id: list
                y: 115 * root.u

                Repeater {
                    model: root.cats.length

                    Item {
                        id: row
                        required property int index
                        readonly property var d: root.cats[index]
                        readonly property bool on: root.cat === index
                        readonly property bool lit: on && root.col === 0
                        readonly property real h: 56 * root.u
                        readonly property real w: 430 * root.u
                        readonly property real enter: Math.max(0, Math.min(1, root.rowsIn * (root.cats.length + 2) / 2 - index * 0.5))

                        readonly property real out: root.eOut(root.seg(root.selP, Math.abs(index - root.cat) * 0.045, 0.30 + Math.abs(index - root.cat) * 0.045))
                        y: index * 60 * root.u
                        x: -(1 - enter) * (1 - enter) * 560 * root.u - out * 520 * root.u
                        width: w
                        height: h
                        z: on ? 10 : 0
                        visible: !(on && root.selP > 0)

                        Shape {
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: row.on ? root.white : root.ink
                                strokeColor: row.on ? root.red : "transparent"
                                strokeWidth: row.on ? 2.5 * root.u : -1
                                joinStyle: ShapePath.MiterJoin
                                PathPolyline {
                                    path: [Qt.point(-4, 0), Qt.point(row.w, 0), Qt.point(row.w - 8 * root.u, row.h),
                                           Qt.point(-4, row.h), Qt.point(-4, 0)]
                                }
                            }
                        }
                        Shape {
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: row.d.col
                                strokeWidth: -1
                                PathPolyline {
                                    path: [Qt.point(96 * root.u, 0), Qt.point(214 * root.u, 0), Qt.point(158 * root.u, row.h * 0.55),
                                           Qt.point(128 * root.u, row.h), Qt.point(96 * root.u, row.h), Qt.point(96 * root.u, 0)]
                                }
                            }
                            ShapePath {
                                fillColor: Qt.darker(row.d.col, 1.6)
                                strokeWidth: -1
                                PathPolyline {
                                    path: [Qt.point(96 * root.u, row.h * 0.62), Qt.point(158 * root.u, row.h * 0.55),
                                           Qt.point(128 * root.u, row.h), Qt.point(96 * root.u, row.h), Qt.point(96 * root.u, row.h * 0.62)]
                                }
                            }
                        }
                        Item {
                            x: 98 * root.u
                            width: 76 * root.u
                            height: row.h
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 3 * root.u
                                anchors.topMargin: 2 * root.u
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: row.d.icon
                                font.family: root.icons
                                font.pixelSize: 38 * root.u
                                font.variableAxes: { "FILL": 1, "wght": 600 }
                                color: root.ink
                            }
                            Text {
                                anchors.fill: parent
                                anchors.rightMargin: 3 * root.u
                                anchors.bottomMargin: 2 * root.u
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: row.d.icon
                                font.family: root.icons
                                font.pixelSize: 38 * root.u
                                font.variableAxes: { "FILL": 1, "wght": 600 }
                                color: root.white
                            }
                        }
                        Text {
                            x: 222 * root.u
                            width: 180 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: row.d.name
                            font.family: "Jost"
                            font.weight: Font.Medium
                            font.pixelSize: 25 * root.u
                            font.letterSpacing: 2 * root.u
                            color: row.on ? root.ink : root.white
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.selP === 0
                            onEntered: if (root.col === 0) { root.cat = row.index; root.item = 0; }
                            onClicked: { root.cat = row.index; root.item = 0; root.col = 1; }
                        }
                    }
                }
            }


            // ── hero bar: the chosen row lifts and stretches into the top bar ──
            Item {
                id: hero
                visible: root.selP > 0
                readonly property var d: root.cats[root.cat]
                readonly property real p: root.heroP
                readonly property real u: root.u
                // start = the row in the list, end = the art's bar (y 88-209 px on 1080p); its
                // slanted end lies on the white band's 45-degree edge (x = 853 + y px)
                readonly property real y0: list.y + root.cat * 60 * u
                readonly property real yy: root.lerp(y0, 57 * u, p)
                readonly property real h: root.lerp(56 * u, 84 * u, p)
                readonly property real wTop: root.lerp(430 * u, (853 / 1.5 + 57 + 4) * u, p)
                readonly property real wBot: root.lerp(422 * u, (853 / 1.5 + 141 + 4) * u, p)
                y: yy
                height: h
                z: 20

                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: root.mixc(root.white, "#ffffff", hero.p)
                        strokeColor: Qt.alpha(root.red, 1 - hero.p)
                        strokeWidth: 2.5 * hero.u
                        joinStyle: ShapePath.MiterJoin
                        PathPolyline {
                            path: [Qt.point(-4, 0), Qt.point(hero.wTop, 0), Qt.point(hero.wBot, hero.h),
                                   Qt.point(-4, hero.h), Qt.point(-4, 0)]
                        }
                    }
                    // black head segment grows in from the left edge
                    ShapePath {
                        fillColor: root.ink
                        strokeWidth: -1
                        PathPolyline {
                            path: [Qt.point(-4, 0), Qt.point(96 * hero.u * hero.p, 0), Qt.point(96 * hero.u * hero.p, hero.h),
                                   Qt.point(-4, hero.h), Qt.point(-4, 0)]
                        }
                    }
                    ShapePath {
                        fillColor: hero.d.col
                        strokeWidth: -1
                        PathPolyline {
                            path: [Qt.point(96 * hero.u, 0), Qt.point(root.lerp(214, 250, hero.p) * hero.u, 0), Qt.point(root.lerp(158, 180, hero.p) * hero.u, hero.h * 0.55),
                                   Qt.point(root.lerp(128, 140, hero.p) * hero.u, hero.h), Qt.point(96 * hero.u, hero.h), Qt.point(96 * hero.u, 0)]
                        }
                    }
                    ShapePath {
                        fillColor: Qt.darker(hero.d.col, 1.6)
                        strokeWidth: -1
                        PathPolyline {
                            path: [Qt.point(96 * hero.u, hero.h * 0.62), Qt.point(root.lerp(158, 180, hero.p) * hero.u, hero.h * 0.55),
                                   Qt.point(root.lerp(128, 140, hero.p) * hero.u, hero.h), Qt.point(96 * hero.u, hero.h), Qt.point(96 * hero.u, hero.h * 0.62)]
                        }
                    }
                }
                Item {
                    x: root.lerp(98, 102, hero.p) * hero.u
                    width: root.lerp(76, 96, hero.p) * hero.u
                    height: hero.h
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 3 * hero.u
                        anchors.topMargin: 2 * hero.u
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: hero.d.icon
                        font.family: root.icons
                        font.pixelSize: root.lerp(38, 54, hero.p) * hero.u
                        font.variableAxes: { "FILL": 1, "wght": 600 }
                        color: root.ink
                    }
                    Text {
                        anchors.fill: parent
                        anchors.rightMargin: 3 * hero.u
                        anchors.bottomMargin: 2 * hero.u
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: hero.d.icon
                        font.family: root.icons
                        font.pixelSize: root.lerp(38, 54, hero.p) * hero.u
                        font.variableAxes: { "FILL": 1, "wght": 600 }
                        color: root.white
                    }
                }
                Text {
                    id: heroName
                    // centred in the row's name box -> left-aligned after the wedge
                    x: root.lerp(222 * hero.u + (180 * hero.u - implicitWidth) / 2, 262 * hero.u, hero.p)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root.lerp(0, 2, hero.p) * hero.u
                    text: hero.d.name
                    font.family: "Jost"
                    font.weight: Font.Medium
                    font.pixelSize: root.lerp(25, 42, hero.p) * hero.u
                    font.letterSpacing: root.lerp(2, 4, hero.p) * hero.u
                    color: root.ink
                }
                // slot count tag after the name, arrives last
                Text {
                    x: heroName.x + heroName.implicitWidth + 18 * hero.u
                    anchors.baseline: heroName.baseline
                    opacity: root.seg(root.selP, 0.55, 0.85)
                    text: root.curSlots.length + " GEAR"
                    font.family: root.face
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 13 * hero.u
                    font.letterSpacing: 2 * hero.u
                    color: hero.d.col === "#ffd23f" ? "#c79a00" : Qt.darker(hero.d.col, 1.25)
                }
            }

            // ── middle: equipped items, or the options for one slot ──────
            Item {
                id: mid
                x: root.lerp(466, 118, root.midP) * root.u
                y: root.lerp(92, 178, root.midP) * root.u
                width: 340 * root.u
                scale: root.lerp(1, 1.16, root.midP)
                transformOrigin: Item.TopLeft
                opacity: Math.min(1, root.midIn * 1.6)
                // above the hero bar: while travelling it passes in front of it, not under
                z: 25
                // colours: on the white diamond (A) -> on the navy diamond (B)
                readonly property color pillBg: root.mixc(root.navy, root.white, root.midColP)
                readonly property color pillFg: root.mixc(root.white, root.navy, root.midColP)
                readonly property color itemFg: root.mixc(root.ink, root.white, root.midColP)
                readonly property color selBg: root.mixc(root.ink, root.white, root.midColP)
                readonly property color selFg: root.mixc(root.white, root.ink, root.midColP)
                readonly property color chipBg: root.mixc(root.navy, "#2b4fd0", root.midColP)

                // "+" crosshair
                Text {
                    x: -22 * root.u
                    y: -30 * root.u
                    opacity: 1 - root.seg(root.selP, 0, 0.25)
                    text: "+"
                    font.family: "Jost"
                    font.weight: Font.Light
                    font.pixelSize: 34 * root.u
                    color: root.ink
                }

                component Pill: Rectangle {
                    property string label
                    width: 168 * root.u
                    height: 18 * root.u
                    radius: height / 2
                    color: mid.pillBg
                    Text {
                        anchors.centerIn: parent
                        text: parent.label
                        font.family: root.face
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 11 * root.u
                        color: mid.pillFg
                    }
                }
                component Chip: Item {
                    id: chip
                    property string icon
                    property bool dark: false
                    width: 78 * root.u
                    height: 22 * root.u
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: mid.chipBg
                            strokeColor: chip.dark ? root.white : "transparent"
                            strokeWidth: chip.dark ? 1.2 * root.u : -1
                            PathPolyline {
                                path: [Qt.point(8 * root.u, 0), Qt.point(78 * root.u, 0), Qt.point(70 * root.u, 22 * root.u),
                                       Qt.point(0, 22 * root.u), Qt.point(8 * root.u, 0)]
                            }
                        }
                    }
                    // light streak through the chip, like the reference's cutout art
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: Qt.alpha(root.cyan, 0.35)
                            strokeWidth: -1
                            PathPolyline {
                                path: [Qt.point(14 * root.u, 22 * root.u), Qt.point(40 * root.u, 0), Qt.point(50 * root.u, 0),
                                       Qt.point(24 * root.u, 22 * root.u), Qt.point(14 * root.u, 22 * root.u)]
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: chip.icon
                        font.family: root.icons
                        font.pixelSize: 17 * root.u
                        font.variableAxes: { "FILL": 1, "wght": 500 }
                        color: root.white
                    }
                }

                // equipped view (col 0/1)
                Column {
                    visible: root.col < 2
                    spacing: 6 * root.u
                    Repeater {
                        model: root.curSlots
                        Column {
                            id: slotView
                            required property var modelData
                            required property int index
                            readonly property bool sel: root.col === 1 && root.item === index
                            readonly property real enter: Math.max(0, Math.min(1, root.midIn * 3 - index * 0.4))
                            spacing: 5 * root.u
                            opacity: enter
                            transform: Translate { x: (1 - slotView.enter) * 40 * root.u }

                            Pill { label: slotView.modelData.name }
                            Item {
                                width: 330 * root.u
                                height: 28 * root.u
                                Rectangle {
                                    visible: slotView.sel
                                    x: 16 * root.u
                                    width: 320 * root.u
                                    height: parent.height
                                    color: mid.selBg
                                    Rectangle { width: 4 * root.u; height: parent.height; color: root.red }
                                }
                                Chip {
                                    x: 24 * root.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: (root.equippedOpt(slotView.modelData) ?? slotView.modelData).icon
                                    dark: slotView.sel
                                }
                                Text {
                                    x: 110 * root.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 220 * root.u
                                    elide: Text.ElideRight
                                    text: root.equipped(slotView.modelData)
                                    font.family: "Jost"
                                    font.weight: Font.Medium
                                    font.pixelSize: 20 * root.u
                                    color: slotView.sel ? mid.selFg : mid.itemFg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.selP === 0 || root.selP === 1
                                    onEntered: if (root.col === 1) root.item = slotView.index
                                    onClicked: { root.col = 1; root.item = slotView.index; root.enter(); }
                                }
                            }
                        }
                    }
                }

                // options view (col 2)
                Column {
                    id: optView
                    visible: root.col === 2
                    spacing: 6 * root.u
                    readonly property int visibleCount: 8
                    readonly property int first: Math.max(0, Math.min(root.opt - 3, root.curOpts.length - visibleCount))

                    Pill { label: root.curSlot ? root.curSlot.name : "" }
                    Repeater {
                        model: root.curOpts.slice(optView.first, optView.first + optView.visibleCount)
                        Item {
                            id: optRow
                            required property var modelData
                            required property int index
                            readonly property int idx: optView.first + index
                            readonly property bool sel: root.opt === idx
                            width: 330 * root.u
                            height: 28 * root.u
                            Rectangle {
                                visible: optRow.sel
                                x: 16 * root.u
                                width: 320 * root.u
                                height: parent.height
                                color: mid.selBg
                                border.color: root.red
                                border.width: 1.5 * root.u
                            }
                            Chip {
                                x: 24 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                icon: optRow.modelData.icon
                                dark: optRow.sel
                            }
                            Text {
                                x: 110 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                width: 190 * root.u
                                elide: Text.ElideRight
                                text: optRow.modelData.label
                                font.family: "Jost"
                                font.weight: Font.Medium
                                font.pixelSize: 20 * root.u
                                color: optRow.sel ? mid.selFg : mid.itemFg
                            }
                            // "E" badge on whatever is equipped now
                            Rectangle {
                                visible: optRow.modelData.cur
                                x: 306 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20 * root.u
                                height: width
                                radius: width / 2
                                color: root.cyan
                                Text {
                                    anchors.centerIn: parent
                                    text: "E"
                                    font.family: root.face
                                    font.weight: Font.Black
                                    font.pixelSize: 12 * root.u
                                    color: root.ink
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.opt = optRow.idx
                                onClicked: { root.opt = optRow.idx; root.equip(); }
                            }
                        }
                    }
                    Text {
                        visible: root.curOpts.length > optView.visibleCount
                        leftPadding: 24 * root.u
                        text: (root.opt + 1) + " / " + root.curOpts.length
                        font.family: root.face
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 11 * root.u
                        color: mid.itemFg
                    }
                }

                // EQUIPPED stamp
                Text {
                    id: stamp
                    x: 190 * root.u
                    y: (root.item * 59 + 6) * root.u
                    rotation: -12
                    text: root.flashText
                    font.family: "Jost"
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 30 * root.u
                    color: root.red
                    style: Text.Outline
                    styleColor: root.white
                    opacity: 0
                    scale: 1
                    SequentialAnimation {
                        id: flash
                        ParallelAnimation {
                            NumberAnimation { target: stamp; property: "opacity"; from: 0; to: 1; duration: 90 }
                            NumberAnimation { target: stamp; property: "scale"; from: 1.6; to: 1; duration: 160; easing.type: Easing.OutBack }
                        }
                        PauseAnimation { duration: 650 }
                        NumberAnimation { target: stamp; property: "opacity"; to: 0; duration: 260 }
                    }
                }
            }

            // ── stat comparison (options view) ───────────────────────────
            Item {
                id: cmp
                readonly property var curOpt: root.curSlot ? root.equippedOpt(root.curSlot) : null
                readonly property var newOpt: root.curOpts[root.opt] ?? null
                readonly property var stats: newOpt ? newOpt.stats : []
                visible: root.col === 2 && stats.length > 0
                x: mid.x + 14 * root.u
                y: mid.y + (optView.height + 30 * root.u) * mid.scale
                z: 16
                rotation: -4
                transformOrigin: Item.TopLeft

                Shape {
                    id: cmpBg
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real w: 320 * root.u
                    readonly property real h: (34 + cmp.stats.length * 24) * root.u
                    ShapePath {
                        fillColor: Qt.alpha("#050a1e", 0.92)
                        strokeColor: Qt.alpha(root.cyan, 0.7)
                        strokeWidth: 1.2 * root.u
                        PathPolyline {
                            path: [Qt.point(-10 * root.u, -4 * root.u), Qt.point(cmpBg.w, -10 * root.u),
                                   Qt.point(cmpBg.w - 14 * root.u, cmpBg.h), Qt.point(0, cmpBg.h + 4 * root.u),
                                   Qt.point(-10 * root.u, -4 * root.u)]
                        }
                    }
                }
                Text {
                    x: 6 * root.u
                    y: 2 * root.u
                    text: "COMPARE"
                    font.family: root.face
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 11 * root.u
                    font.letterSpacing: 2 * root.u
                    color: root.cyan
                }
                Column {
                    x: 6 * root.u
                    y: 24 * root.u
                    spacing: 4 * root.u
                    Repeater {
                        model: cmp.stats
                        Row {
                            id: sr
                            required property var modelData
                            required property int index
                            readonly property real now: {
                                const c = cmp.curOpt ? cmp.curOpt.stats.find(x => x[0] === modelData[0]) : null;
                                return c ? c[1] : modelData[1];
                            }
                            readonly property real next: modelData[1]
                            spacing: 8 * root.u
                            Text {
                                width: 92 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                text: sr.modelData[0]
                                font.family: root.face
                                font.weight: Font.Bold
                                font.italic: true
                                font.pixelSize: 12 * root.u
                                color: root.white
                            }
                            // five slanted pips: filled = new value; ghost outline = current
                            Row {
                                spacing: 3 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: 5
                                    Shape {
                                        id: pip
                                        required property int index
                                        width: 26 * root.u
                                        height: 12 * root.u
                                        readonly property bool filled: index < Math.round(sr.next)
                                        readonly property bool was: index < Math.round(sr.now)
                                        preferredRendererType: Shape.CurveRenderer
                                        ShapePath {
                                            fillColor: pip.filled ? (sr.next > sr.now && !pip.was ? root.cyan : sr.next < sr.now ? "#f2fbff" : "#f2fbff")
                                                     : (pip.was ? Qt.alpha(root.red, 0.55) : Qt.alpha("#ffffff", 0.12))
                                            strokeWidth: -1
                                            PathPolyline {
                                                path: [Qt.point(4 * root.u, 0), Qt.point(26 * root.u, 0), Qt.point(22 * root.u, 12 * root.u),
                                                       Qt.point(0, 12 * root.u), Qt.point(4 * root.u, 0)]
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                width: 18 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                text: sr.next > sr.now ? "▲" : sr.next < sr.now ? "▼" : ""
                                font.pixelSize: 13 * root.u
                                color: sr.next > sr.now ? root.cyan : root.red
                            }
                        }
                    }
                }
            }

            // ── guide (bottom right) ─────────────────────────────────────
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 36 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26 * root.u
                spacing: 4 * root.u
                opacity: root.midIn

                Text {
                    anchors.right: parent.right
                    text: root.col === 0 ? "Which slot do you want to change?"
                        : root.col === 1 ? "Which gear do you want to swap?"
                        : "What will you equip?"
                    font.family: root.face
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pixelSize: 22 * root.u
                    color: root.white
                    // the art puts a white collar under this line: keep it readable
                    style: Text.Outline
                    styleColor: "#0a1cb8"
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 360 * root.u
                    height: 1.5 * root.u
                    color: root.white
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.bottom
                        anchors.topMargin: 1 * root.u
                        text: "Guide"
                        font.family: root.face
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 10 * root.u
                        color: root.white
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 14 * root.u
                    topPadding: 16 * root.u
                    Repeater {
                        model: root.col === 2 ? [["↵", "Equip"], ["Esc", "Back"]] : [["↵", "Select"], ["Esc", "Back"]]
                        Row {
                            required property var modelData
                            spacing: 5 * root.u
                            Rectangle {
                                width: Math.max(22 * root.u, key.implicitWidth + 10 * root.u)
                                height: 22 * root.u
                                radius: height / 2
                                color: root.white
                                Text {
                                    id: key
                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    font.family: root.face
                                    font.weight: Font.Black
                                    font.pixelSize: 11 * root.u
                                    color: "#0a1cb8"
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                font.family: root.face
                                font.weight: Font.ExtraBold
                                font.italic: true
                                font.pixelSize: 18 * root.u
                                color: root.white
                            }
                        }
                    }
                }
            }
        }
            }
        }
    }
}
