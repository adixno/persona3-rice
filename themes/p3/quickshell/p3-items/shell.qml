// p3-items: the toolkit, as the Persona 3 ITEM screen.
// Tabs (Q/E, ←/→) = pouches of tools, one per party row; list = tools with use counts; info box = what the
// highlighted tool does; left "party" rows = the vitals the tools act on (the targeted row
// lights up). ↵ uses a tool (destructive ones ask twice). items.py runs them.
// Backdrop art slot: ~/.local/share/persona-rice/media/p3/items-bg.png (+ items-mask.png from
// tools/make-mask.py for the underwater ripple).
//
// Resident like p3-status / p3-equip. Toggle: SUPER+U (Hyprland global p3items:toggle) or
// qs -c p3-items ipc call items toggle
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
    property bool shown: Quickshell.env("P3_ITEMS_OPEN") === "1"

    function toggle(): void {
        if (!shell.shown)
            shell.shown = true;
        else if (content.item)
            content.item.close();
    }

    // another p3 menu opened: vanish at once (no close animation under/over it)
    GlobalShortcut {
        appid: "p3items"
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
        appid: "p3items"
        name: "toggle"
        description: "Toggle the p3 toolkit (ITEM) screen"
        onPressed: shell.toggle()
    }

    IpcHandler {
        target: "items"
        function toggle(): void { shell.toggle(); }
        function open(): void { shell.shown = true; }
        function close(): void { if (content.item) content.item.close(); }
        // scripting / testing
        function move(d: int): void { if (content.item) content.item.move(d); }
        function tab(d: int): void { if (content.item) content.item.switchTab(d); }
        function use(): void { if (content.item) content.item.use(); }
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
        WlrLayershell.namespace: "p3-items"
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
            readonly property color ink: "#07080c"
            readonly property color navy: "#16246e"
            readonly property color cyan: dh.mix("#5ee6ff", dh.green)
            readonly property color hp: dh.mix("#2ee6ff", dh.green)
            readonly property color sp: "#ffe23a"
            readonly property color white: "#f2fbff"
            readonly property color red: "#ff1f3a"
            readonly property string face: "Montserrat"
            readonly property string icons: "Material Symbols Rounded"

            property real fill: 0
            property real rowsIn: 0
            property real listIn: 0
            property bool closing: false
            property bool warming: false
            property int warmFrames: 0

            property int tab: 0
            property int sel: 0
            property string confirmId: ""
            property var st: ({})
            property var localCounts: ({})

            // ── the tools ────────────────────────────────────────────────
            // target = party row the tool acts on (0 Screen, 1 Clipboard, 2 Storage, 3 System);
            // every tool has one, so a row is always selected. close = hide the menu first
            // (captures / pickers / anything that grabs the screen); confirm = ask twice
            // one pouch per party row: switching pouch moves the left selection with it
            readonly property var tabs: [
                { title: "Screen Items", tools: [
                    { id: "snap", name: "Snap Shard", icon: "screenshot_region", target: 0, close: true, desc: "Freeze the screen and capture a region. Saved and copied." },
                    { id: "panorama", name: "Panorama Lens", icon: "fullscreen", target: 0, close: true, desc: "Capture the whole screen." },
                    { id: "window", name: "Window Prism", icon: "select_window", target: 0, close: true, desc: "Capture the window you were just using. Saved and copied." },
                    { id: "sketch", name: "Sketch Quill", icon: "draw", target: 0, close: true, desc: "Capture a region and draw on it in Satty before saving." },
                    { id: "reel", name: "Memory Reel", icon: "videocam", target: 0, close: true, desc: "Record the whole screen. Use it again to stop." },
                    { id: "reel-area", name: "Frame Reel", icon: "crop_free", target: 0, close: true, desc: "Record a region of the screen. Use a reel again to stop." },
                    { id: "echo", name: "Echo Reel", icon: "mic", target: 0, close: true, desc: "Record the screen with sound. Use a reel again to stop." }
                ] },
                { title: "Clipboard Items", tools: [
                    { id: "recall", name: "Recall Scroll", icon: "content_paste", target: 1, close: true, desc: "Open your clipboard history." },
                    { id: "prism", name: "Prism Drop", icon: "colorize", target: 1, close: true, desc: "Pick any colour on screen; its hex code is copied." },
                    { id: "glyph", name: "Glyph Charm", icon: "mood", target: 1, close: true, desc: "Pick an emoji or glyph; it's copied." },
                    { id: "address", name: "Address Card", icon: "lan", target: 1, close: false, desc: "Copy this machine's local IP address." },
                    { id: "signal", name: "Signal Key", icon: "key", target: 1, close: false, desc: "Copy the password of the Wi-Fi you're on." },
                    { id: "blank", name: "Blank Page", icon: "content_paste_off", target: 1, close: false, confirm: true, desc: "Wipe the clipboard and its history." }
                ] },
                { title: "Storage Items", tools: [
                    { id: "purify", name: "Purify Salt", icon: "delete_forever", target: 2, close: false, confirm: true, desc: "Empty the trash. This can't be undone." },
                    { id: "ash", name: "Ash Broom", icon: "mop", target: 2, close: false, desc: "Clear the thumbnail cache." },
                    { id: "survey", name: "Disk Survey", icon: "data_usage", target: 2, close: false, desc: "Show the five biggest folders in your home as a notification." },
                    { id: "satchel", name: "Satchel", icon: "download", target: 2, close: true, desc: "Open your Downloads folder." },
                    { id: "album", name: "Snapshot Album", icon: "photo_library", target: 2, close: true, desc: "Open the folder your screenshots are saved in." }
                ] },
                { title: "System Items", tools: [
                    { id: "hourglass5", name: "Hourglass", icon: "hourglass_bottom", target: 3, close: false, desc: "Get a notification in 5 minutes." },
                    { id: "hourglass25", name: "Focus Hourglass", icon: "hourglass_top", target: 3, close: false, desc: "A 25-minute focus timer, with a notification at the end." },
                    { id: "abacus", name: "Abacus Bead", icon: "calculate", target: 3, close: true, desc: "Open a calculator (qalc) in a terminal." },
                    { id: "clearwater", name: "Clear Water", icon: "notifications_off", target: 3, close: false, desc: "Dismiss every notification." },
                    { id: "tonic", name: "Hyper Tonic", icon: "refresh", target: 3, close: false, desc: "Reload the Hyprland config." },
                    { id: "revival", name: "Revival Bead", icon: "restart_alt", target: 3, close: true, confirm: true, desc: "Restart the desktop shell (bar, panels, notifications)." },
                    { id: "lock", name: "Lock Charm", icon: "lock", target: 3, close: true, desc: "Lock the screen." },
                    { id: "banish", name: "Banish Talisman", icon: "dangerous", target: 3, close: true, confirm: true, desc: "Click any window to force-close it." },
                    { id: "sleep", name: "Sleep Draught", icon: "bedtime", target: 3, close: true, confirm: true, desc: "Suspend the computer." }
                ] }
            ]
            property int shownTab: 0          // what the list draws (swaps mid-transition)
            readonly property var tools: tabs[shownTab].tools
            readonly property var cur: tools[Math.min(sel, tools.length - 1)]

            function count(id) {
                const c = (st.counts ?? {})[id] ?? 0;
                return c + (localCounts[id] ?? 0);
            }
            function detail(t) {
                if (!t)
                    return "";
                if (confirmId === t.id)
                    return "Press ↵ again to use it.";
                switch (t.id) {
                case "purify": return t.desc + "\nTrash: " + (st.trashN ?? 0) + " items, " + (st.trashH ?? "0 B") + ".";
                case "ash": return t.desc + " Currently " + (st.cacheH ?? "0 B") + ".";
                case "recall": return (st.clipN ?? 0) > 0 ? t.desc + " " + st.clipN + " entries." : t.desc + " (Nothing is recording history yet.)";
                case "hourglass5": case "hourglass25": return (st.timers ?? 0) > 0 ? t.desc + " " + st.timers + " running." : t.desc;
                case "reel": case "reel-area": case "echo":
                    return st.recording ? "Recording now. Use any reel to stop it." : t.desc;
                }
                return t.desc;
            }

            // party rows: the vitals the tools act on
            readonly property var party: {
                const gb = 1024 * 1024 * 1024;
                const free = st.diskFree ?? 0, total = Math.max(1, st.diskTotal ?? 1);
                const junk = (st.trashB ?? 0) + (st.cacheB ?? 0);
                return [
                    { name: "Screen", col: "#ff3d5a", icon: st.recording ? "radio_button_checked" : "screenshot_monitor", lv: st.shots ?? 0,
                      a: { l: "REC", v: st.recording ? 100 : 0, p: st.recording ? 1 : 0 },
                      b: { l: "SHOT", v: st.shots ?? 0, p: (st.shots ?? 0) / 100 } },
                    { name: "Clipboard", col: "#3fd8ff", icon: "content_paste", lv: st.clipN ?? 0,
                      a: { l: "CLIP", v: st.clipN ?? 0, p: (st.clipN ?? 0) / 100 },
                      b: { l: "TXT", v: Math.min(999, st.clipLen ?? 0), p: Math.min(1, (st.clipLen ?? 0) / 999) } },
                    { name: "Storage", col: "#ff8a3d", icon: "hard_drive", lv: Math.round(free / gb),
                      a: { l: "FREE", v: Math.round(100 * free / total), p: free / total },
                      b: { l: "MB", v: Math.min(999, Math.round(junk / 1048576)), p: junk / gb } },
                    { name: "System", col: "#b06bff", icon: "memory", lv: st.uptimeH ?? 0,
                      a: { l: "LOAD", v: st.load ?? 0, p: (st.load ?? 0) / 100 },
                      b: { l: "TIMER", v: st.timers ?? 0, p: Math.min(1, (st.timers ?? 0) / 3) } }
                ];
            }
            function pad(n) { return String(Math.max(0, Math.round(n))).padStart(3, "0"); }

            // ── data / use ───────────────────────────────────────────────
            Process {
                id: reader
                command: ["python3", shell.dir + "/items.py", "state"]
                stdout: SplitParser {
                    onRead: line => {
                        try {
                            root.st = JSON.parse(line);
                            root.localCounts = ({});
                        } catch (e) {}
                    }
                }
            }
            function refresh() { if (!reader.running) reader.running = true; }
            Process {
                id: runner
                onExited: root.refresh()
            }

            function use() {
                const t = cur;
                // only while actually open: never act from the hidden (resident) state
                if (!t || swapAnim.running || !shell.shown || closing)
                    return;
                if (t.confirm && confirmId !== t.id) {
                    confirmId = t.id;
                    return;
                }
                confirmId = "";
                const lc = Object.assign({}, localCounts);
                lc[t.id] = (lc[t.id] ?? 0) + 1;
                localCounts = lc;
                usedFlash.restart();
                if (t.close) {
                    // out of the way first, so captures / pickers never see the menu
                    Quickshell.execDetached(["sh", "-c", "sleep 0.55; exec python3 \"$0\" use \"$1\"", shell.dir + "/items.py", t.id]);
                    closeTimer.restart();
                } else {
                    runner.command = ["python3", shell.dir + "/items.py", "use", t.id];
                    runner.running = true;
                }
            }
            Timer { id: closeTimer; interval: 160; onTriggered: root.close() }
            Timer { interval: 3000; repeat: true; running: shell.shown; onTriggered: root.refresh() }

            // ── navigation + tab transition ──────────────────────────────
            property int pendingTab: 0
            property int swapDir: 1
            property real outP: 0       // old tab leaving
            property real inP: 1        // new tab arriving
            function move(d) {
                if (swapAnim.running || !shell.shown || closing)
                    return;
                confirmId = "";
                sel = (sel + d + tools.length) % tools.length;
            }
            property int queuedTab: 0   // presses made mid-transition play right after it
            function switchTab(d) {
                if (!shell.shown || closing)
                    return;
                if (swapAnim.running) {
                    queuedTab += d;
                    return;
                }
                confirmId = "";
                swapDir = d;
                pendingTab = (tab + d + tabs.length) % tabs.length;
                tab = pendingTab;          // dots + arrows move right away
                swapAnim.restart();
            }
            SequentialAnimation {
                id: swapAnim
                NumberAnimation { target: root; property: "outP"; from: 0; to: 1; duration: 170; easing.type: Easing.InCubic }
                ScriptAction { script: { root.shownTab = root.pendingTab; root.sel = 0; root.inP = 0; root.outP = 0; } }
                NumberAnimation { target: root; property: "inP"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                ScriptAction {
                    script: {
                        if (root.queuedTab !== 0) {
                            const d = root.queuedTab > 0 ? 1 : -1;
                            root.queuedTab -= d;
                            Qt.callLater(() => root.switchTab(d));
                        }
                    }
                }
            }
            function seg(p, a, b) { return Math.max(0, Math.min(1, (p - a) / (b - a))); }

            Keys.onUpPressed: move(-1)
            Keys.onDownPressed: move(1)
            Keys.onLeftPressed: switchTab(-1)
            Keys.onRightPressed: switchTab(1)
            Keys.onTabPressed: switchTab(1)
            Keys.onBacktabPressed: switchTab(-1)
            Keys.onReturnPressed: use()
            Keys.onEnterPressed: use()
            Keys.onSpacePressed: use()
            Keys.onEscapePressed: confirmId !== "" ? (confirmId = "") : close()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Q) switchTab(-1);
                else if (e.key === Qt.Key_E) switchTab(1);
                else if (e.key === Qt.Key_J) move(1);
                else if (e.key === Qt.Key_K) move(-1);
            }

            // ── open / close (warm-up as in p3-status) ───────────────────
            function hideNow() {
                closeAnim.stop();
                openAnim.stop();
                warming = false;
                closing = false;
                fill = 0; rowsIn = 0; listIn = 0;
                shell.shown = false;
            }
            // only one p3 menu at a time: opening this one hides the others (hyprctl → their
            // "hide" globals, ~10 ms; a qs ipc call would cost ~200 ms each)
            function hideOthers() {
                Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.global(\"p3status:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3equip:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3skills:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3links:hide\")' >/dev/null"]);
            }
            function reopen() {
                hideOthers();
                closeAnim.stop();
                openAnim.stop();
                closing = false;
                queuedTab = 0;
                fill = 0;
                rowsIn = 0;
                listIn = 0;
                confirmId = "";
                sel = 0;
                refresh();
                warmFrames = 0;
                warming = true;
            }
            Connections {
                target: shell
                function onShownChanged() { if (shell.shown) root.reopen(); }
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
            Component.onCompleted: { refresh(); if (shell.shown) reopen(); }
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
                    NumberAnimation { target: root; property: "rowsIn"; from: 0; to: 1; duration: 520 }
                }
                SequentialAnimation {
                    PauseAnimation { duration: 180 }
                    NumberAnimation { target: root; property: "listIn"; from: 0; to: 1; duration: 560 }
                }
            }
            SequentialAnimation {
                id: closeAnim
                ParallelAnimation {
                    NumberAnimation { target: root; property: "rowsIn"; to: 0; duration: 200 }
                    NumberAnimation { target: root; property: "listIn"; to: 0; duration: 180 }
                }
                NumberAnimation { target: root; property: "fill"; to: 0; duration: 220; easing.type: Easing.InCubic }
                ScriptAction { script: shell.shown = false }
            }

            // animation clock: vsync on AC, 30 fps on battery
            property real clock: 0
            // ambient motion follows the shared rule (Motion.qml): full speed until the battery
            // limit, then it eases to a halt
            Motion { id: motion }
            FrameAnimation { running: shell.shown && motion.speed > 0; onTriggered: root.clock += frameTime * motion.speed }

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
                        GradientStop { position: 0.0; color: "#1667ea" }
                        GradientStop { position: 1.0; color: "#06115e" }
                    }
                }
                Image {
                    id: bgImg
                    anchors.fill: parent
                    source: "file://" + shell.media + "/items-bg.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    mipmap: true
                    visible: maskImg.status !== Image.Ready
                }
                Image {
                    id: maskImg
                    anchors.fill: parent
                    source: "file://" + shell.media + "/items-mask.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    visible: false
                }
                ShaderEffect {
                    anchors.fill: parent
                    visible: maskImg.status === Image.Ready && bgImg.status === Image.Ready
                    property variant src: bgImg
                    property variant mask: maskImg
                    property variant srcB: bgImg
                    property real time: root.clock
                    property real aspect: width / Math.max(1, height)
                    property real wipe: 0
                    fragmentShader: Qt.resolvedUrl("backdrop.frag.qsb")
                }
                // drifting shards (the art's own fragments, brought to life)
                Repeater {
                    model: [
                        [560, 470, 14, "#ff4fd8", 8, 0.0], [640, 560, 10, "#ff8fb0", 7, 1.3], [880, 520, 12, "#ffffff", 9, 2.6],
                        [470, 600, 15, "#c04bff", 6, 0.7], [760, 640, 9, "#ff4fd8", 10, 3.4], [980, 640, 13, "#5fe3ff", 7, 4.1],
                        [380, 520, 9, "#ff8fb0", 8, 5.0], [1040, 560, 11, "#ffffff", 9, 2.0]
                    ]
                    Shape {
                        id: shard
                        required property var modelData
                        readonly property real range: 150
                        readonly property real prog: ((root.clock * modelData[4] / range + modelData[5] / 6.2831853) % 1 + 1) % 1
                        readonly property real sz: modelData[2] * 1.6 * root.u
                        x: (modelData[0] + 12 * Math.sin(root.clock * 0.6 + modelData[5])) * root.u
                        y: (modelData[1] - prog * range) * root.u
                        rotation: modelData[5] * 57 + root.clock * (12 + modelData[4] * 2)
                        opacity: Math.sin(Math.PI * prog) * 0.7
                        width: sz
                        height: sz
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: shard.modelData[3]
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(0, shard.sz * 0.2), Qt.point(shard.sz, 0), Qt.point(shard.sz * 0.65, shard.sz), Qt.point(0, shard.sz * 0.2)] }
                        }
                        ShapePath {
                            fillColor: Qt.alpha("#ffffff", 0.5)
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(0, shard.sz * 0.2), Qt.point(shard.sz, 0), Qt.point(shard.sz * 0.45, shard.sz * 0.42), Qt.point(0, shard.sz * 0.2)] }
                        }
                    }
                }
            }

            // ── party rows: the vitals ───────────────────────────────────
            Item {
                id: partyList
                y: 222 * root.u
                Repeater {
                    model: root.party.length
                    Item {
                        id: row
                        required property int index
                        readonly property var d: root.party[index]
                        readonly property bool target: root.cur && root.cur.target === index
                        readonly property real h: 50 * root.u
                        readonly property real w: (target ? 586 : 566) * root.u
                        readonly property real enter: Math.max(0, Math.min(1, root.rowsIn * (root.party.length + 2) / 2 - index * 0.5))
                        property real shift: target ? 18 * root.u : 0
                        Behavior on shift { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        y: index * 57 * root.u
                        x: -(1 - enter) * (1 - enter) * 640 * root.u
                        width: w
                        height: h
                        z: target ? 10 : 0

                        Shape {
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: row.target ? root.white : root.ink
                                strokeColor: row.target ? root.red : "transparent"
                                strokeWidth: row.target ? 2.5 * root.u : -1
                                joinStyle: ShapePath.MiterJoin
                                PathPolyline { path: [Qt.point(-4, 0), Qt.point(row.w, 0), Qt.point(row.w - 12 * root.u, row.h), Qt.point(-4, row.h), Qt.point(-4, 0)] }
                            }
                        }
                        Shape {
                            x: row.shift
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: row.d.col
                                strokeWidth: -1
                                PathPolyline { path: [Qt.point(70 * root.u, 0), Qt.point(196 * root.u, 0), Qt.point(140 * root.u, row.h * 0.55), Qt.point(108 * root.u, row.h), Qt.point(70 * root.u, row.h), Qt.point(70 * root.u, 0)] }
                            }
                            ShapePath {
                                fillColor: Qt.darker(row.d.col, 1.6)
                                strokeWidth: -1
                                PathPolyline { path: [Qt.point(70 * root.u, row.h * 0.62), Qt.point(140 * root.u, row.h * 0.55), Qt.point(108 * root.u, row.h), Qt.point(70 * root.u, row.h), Qt.point(70 * root.u, row.h * 0.62)] }
                            }
                        }
                        Item {
                            x: 72 * root.u + row.shift
                            width: 70 * root.u
                            height: row.h
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 3 * root.u
                                anchors.topMargin: 2 * root.u
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: row.d.icon
                                font.family: root.icons
                                font.pixelSize: 36 * root.u
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
                                font.pixelSize: 36 * root.u
                                font.variableAxes: { "FILL": 1, "wght": 600 }
                                color: root.white
                            }
                        }
                        Text {
                            x: 160 * root.u + row.shift
                            width: 118 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.d.name
                            font.family: "Jost"
                            font.weight: Font.Medium
                            font.pixelSize: 21 * root.u
                            color: row.target ? root.ink : root.white
                        }
                        Shape {
                            x: 290 * root.u + row.shift
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: row.d.col
                                strokeWidth: 1.6 * root.u
                                fillColor: "transparent"
                                PathPolyline { path: [Qt.point(15 * root.u, 8 * root.u), Qt.point(0, row.h - 8 * root.u)] }
                            }
                        }
                        Text {
                            x: 306 * root.u + row.shift
                            anchors.baseline: lv.baseline
                            text: "Lv"
                            font.family: "Jost"
                            font.italic: true
                            font.pixelSize: 10 * root.u
                            color: row.target ? root.ink : root.white
                        }
                        Text {
                            id: lv
                            x: 320 * root.u + row.shift
                            y: row.h - height + 4 * root.u
                            text: String(row.d.lv)
                            font.family: "Jost"
                            font.italic: true
                            font.pixelSize: 24 * root.u
                            color: row.target ? root.ink : root.white
                        }
                        Repeater {
                            model: [[row.d.a, root.hp, 370], [row.d.b, root.sp, 458]]
                            Item {
                                id: bar
                                required property var modelData
                                readonly property var v: modelData[0]
                                x: modelData[2] * root.u + row.shift
                                width: 80 * root.u
                                height: row.h
                                Text {
                                    anchors.baseline: num.baseline
                                    text: bar.v.l
                                    font.family: root.face
                                    font.weight: Font.Bold
                                    font.italic: true
                                    font.pixelSize: 8 * root.u
                                    color: bar.modelData[1]
                                }
                                Text {
                                    id: num
                                    anchors.right: parent.right
                                    y: row.h - height - 2 * root.u
                                    text: root.pad(bar.v.v)
                                    font.family: "Jost"
                                    font.weight: Font.Light
                                    font.italic: true
                                    font.pixelSize: 32 * root.u
                                    font.letterSpacing: -1 * root.u
                                    color: row.target ? root.ink : bar.modelData[1]
                                }
                                Shape {
                                    id: track
                                    y: row.h - 9 * root.u
                                    preferredRendererType: Shape.CurveRenderer
                                    readonly property real bw: bar.width
                                    readonly property real fw: Math.max(0, Math.min(1, bar.v.p || 0)) * bw
                                    ShapePath {
                                        fillColor: row.target ? "#9aa3b5" : "#30343f"
                                        strokeWidth: -1
                                        PathPolyline { path: [Qt.point(3 * root.u, 0), Qt.point(track.bw, 0), Qt.point(track.bw - 3 * root.u, 5 * root.u), Qt.point(0, 5 * root.u), Qt.point(3 * root.u, 0)] }
                                    }
                                    ShapePath {
                                        fillColor: bar.modelData[1]
                                        strokeWidth: -1
                                        PathPolyline { path: [Qt.point(3 * root.u, 0), Qt.point(track.fw, 0), Qt.point(track.fw - 3 * root.u, 5 * root.u), Qt.point(0, 5 * root.u), Qt.point(3 * root.u, 0)] }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── header: ‹ Q  pouch title + dots  E › ──────────────────────
            Item {
                id: header
                x: 700 * root.u
                y: 10 * root.u
                width: 540 * root.u
                height: 90 * root.u
                opacity: root.listIn
                transform: Translate { y: (1 - root.listIn) * -24 * root.u }

                component KeyCap: Row {
                    id: kc
                    property string key
                    property bool isLeft: true
                    spacing: 2 * root.u
                    Text {
                        visible: kc.isLeft
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹"
                        font.family: root.face
                        font.weight: Font.Black
                        font.pixelSize: 48 * root.u
                        color: root.white
                        style: Text.Outline
                        styleColor: root.red
                    }
                    Text {
                        text: kc.key
                        font.family: root.face
                        font.weight: Font.Black
                        font.italic: true
                        font.pixelSize: 56 * root.u
                        color: root.white
                        style: Text.Outline
                        styleColor: root.ink
                    }
                    Text {
                        visible: !kc.isLeft
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        font.family: root.face
                        font.weight: Font.Black
                        font.pixelSize: 48 * root.u
                        color: root.white
                        style: Text.Outline
                        styleColor: root.red
                    }
                }
                KeyCap { x: 0; key: "Q"; isLeft: true }
                KeyCap { anchors.right: parent.right; key: "E"; isLeft: false }

                Text {
                    id: tabTitle
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: (root.outP * -36 * root.swapDir + (1 - root.inP) * 36 * root.swapDir) * root.u
                    y: 12 * root.u
                    opacity: (1 - root.outP) * root.inP
                    text: root.tabs[root.shownTab].title
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 21 * root.u
                    color: root.ink
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 48 * root.u
                    spacing: 10 * root.u
                    Repeater {
                        model: root.tabs.length
                        Item {
                            required property int index
                            readonly property bool on: root.tab === index
                            width: 14 * root.u
                            height: 14 * root.u
                            Rectangle {
                                anchors.centerIn: parent
                                width: (parent.on ? 13 : 8) * root.u
                                height: width
                                radius: width / 2
                                color: parent.on ? root.white : root.ink
                                border.color: root.ink
                                border.width: parent.on ? 2.5 * root.u : 0
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Rectangle {
                                    visible: parent.parent.on
                                    anchors.centerIn: parent
                                    width: 5 * root.u
                                    height: width
                                    radius: width / 2
                                    color: root.ink
                                }
                            }
                        }
                    }
                }
            }

            // ── tool list ────────────────────────────────────────────────
            Item {
                id: list
                x: 700 * root.u
                y: 122 * root.u
                width: 560 * root.u
                readonly property real pitch: 37 * root.u

                // selected slab: white, red rule running off to the right edge
                Item {
                    id: slab
                    y: root.sel * list.pitch
                    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    opacity: root.listIn * root.inP * (1 - root.outP)
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: root.white
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(10 * root.u, 0), Qt.point(560 * root.u, 0), Qt.point(560 * root.u, 32 * root.u), Qt.point(0, 32 * root.u), Qt.point(10 * root.u, 0)] }
                        }
                    }
                    Rectangle {
                        x: 10 * root.u
                        y: -3 * root.u
                        width: root.width - list.x - 10 * root.u
                        height: 3.5 * root.u
                        color: root.red
                    }
                    // flash on use
                    Rectangle {
                        id: flashRect
                        x: 4 * root.u
                        width: 556 * root.u
                        height: 32 * root.u
                        color: root.cyan
                        opacity: 0
                        SequentialAnimation {
                            id: usedFlash
                            NumberAnimation { target: flashRect; property: "opacity"; from: 0.9; to: 0; duration: 380; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Repeater {
                    model: root.tools
                    Item {
                        id: tr
                        required property var modelData
                        required property int index
                        readonly property bool on: root.sel === index
                        readonly property bool asking: root.confirmId === modelData.id
                        // cascades: intro, old pouch leaving, new pouch arriving
                        readonly property real enterIntro: Math.max(0, Math.min(1, root.listIn * 3 - index * 0.18))
                        readonly property real kOut: root.seg(root.outP, index * 0.06, 0.55 + index * 0.06)
                        readonly property real kIn: root.seg(root.inP, index * 0.07, 0.5 + index * 0.07)
                        y: index * list.pitch
                        width: 560 * root.u
                        height: 32 * root.u
                        opacity: enterIntro * (1 - kOut) * kIn
                        transform: Translate {
                            x: ((1 - tr.enterIntro) * 60 - tr.kOut * 50 * root.swapDir + (1 - tr.kIn) * 50 * root.swapDir) * root.u
                        }

                        // icon chip: flips (x-scale) through the pouch swap
                        Item {
                            x: 14 * root.u
                            width: 64 * root.u
                            height: 26 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            transform: Scale {
                                origin.x: 32 * root.u
                                xScale: Math.max(0.02, Math.abs(Math.cos(Math.PI * (tr.kOut > 0 ? tr.kOut : 1 - tr.kIn) / 2)))
                            }
                            Shape {
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    fillColor: tr.on ? root.navy : root.white
                                    strokeWidth: -1
                                    PathPolyline { path: [Qt.point(8 * root.u, 0), Qt.point(64 * root.u, 0), Qt.point(56 * root.u, 26 * root.u), Qt.point(0, 26 * root.u), Qt.point(8 * root.u, 0)] }
                                }
                                ShapePath {
                                    fillColor: Qt.alpha(root.cyan, tr.on ? 0.45 : 0.6)
                                    strokeWidth: -1
                                    PathPolyline { path: [Qt.point(40 * root.u, 0), Qt.point(50 * root.u, 0), Qt.point(24 * root.u, 26 * root.u), Qt.point(14 * root.u, 26 * root.u), Qt.point(40 * root.u, 0)] }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: tr.modelData.icon
                                font.family: root.icons
                                font.pixelSize: 19 * root.u
                                font.variableAxes: { "FILL": 1, "wght": 600 }
                                color: tr.on ? root.white : root.navy
                            }
                        }
                        Text {
                            x: 88 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            width: 290 * root.u
                            elide: Text.ElideRight
                            text: tr.modelData.name
                            font.family: "Jost"
                            font.weight: Font.Medium
                            font.pixelSize: 23 * root.u
                            color: tr.on ? root.ink : root.cyan
                            style: tr.on ? Text.Normal : Text.Raised
                            styleColor: Qt.alpha("#06115e", 0.7)
                        }
                        // × count pill (turns red while asking for confirmation)
                        Rectangle {
                            x: 392 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            width: 96 * root.u
                            height: 24 * root.u
                            radius: height / 2
                            color: tr.asking ? root.red : root.ink
                            Text {
                                anchors.centerIn: parent
                                text: tr.asking ? "USE?" : "×  " + root.count(tr.modelData.id)
                                font.family: root.face
                                font.weight: Font.Bold
                                font.pixelSize: 15 * root.u
                                color: root.white
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (!swapAnim.running && root.sel !== tr.index) { root.sel = tr.index; root.confirmId = ""; }
                            onClicked: { root.sel = tr.index; root.use(); }
                        }
                    }
                }
                // scroll-style rail on the right, like the reference
                Rectangle {
                    x: 500 * root.u
                    width: 5 * root.u
                    height: root.tools.length * list.pitch - 6 * root.u
                    color: root.ink
                    opacity: root.listIn
                    Rectangle {
                        width: parent.width
                        height: parent.height * 0.45
                        y: (parent.height - height) * (root.tools.length > 1 ? root.sel / (root.tools.length - 1) : 0)
                        color: root.white
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // ── info box ─────────────────────────────────────────────────
            Item {
                x: 760 * root.u
                y: list.y + Math.max(8, root.tools.length) * list.pitch + 14 * root.u
                opacity: root.listIn * root.inP * (1 - root.outP)
                Rectangle {
                    width: 46 * root.u
                    height: 16 * root.u
                    radius: height / 2
                    color: root.navy
                    border.color: root.cyan
                    border.width: 1 * root.u
                    Text {
                        anchors.centerIn: parent
                        text: "Info"
                        font.family: root.face
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 10 * root.u
                        color: root.white
                    }
                }
                Text {
                    x: 58 * root.u
                    y: -4 * root.u
                    width: 420 * root.u
                    wrapMode: Text.WordWrap
                    lineHeight: 1.05
                    text: root.detail(root.cur)
                    font.family: root.face
                    font.weight: Font.DemiBold
                    font.pixelSize: 17 * root.u
                    color: root.confirmId !== "" ? "#ffd0d6" : root.white
                    style: Text.Raised
                    styleColor: Qt.alpha("#06115e", 0.8)
                }
            }

            // ── guide ────────────────────────────────────────────────────
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 36 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26 * root.u
                spacing: 4 * root.u
                opacity: root.listIn
                Text {
                    anchors.right: parent.right
                    text: root.confirmId !== "" ? "Are you sure?" : "Which item do you want to use?"
                    font.family: root.face
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pixelSize: 22 * root.u
                    color: root.white
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
                        model: [["↵", "Use"], ["Q E", "Pouch"], ["Esc", "Back"]]
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
