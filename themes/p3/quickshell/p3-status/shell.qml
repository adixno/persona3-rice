// p3-status: "daily status" screen for the Persona 3 theme.
// Left: a stack of tilted black stat rows (colour wedge + icon, name, Lv, two bars).
// Right: the selected stat blown up: giant icon silhouette, ring, detail slab.
// Data comes from stats.py (one JSON line every 1.5 s while open). Tasks live in
// ~/.local/share/persona-rice/tasks.txt ("- [ ] todo" / "- [x] done").
// Optional backdrop slots (media/p3): status-bg.mp4, else the status-bg/ folder (*.png/*.jpg,
// sorted by name; moving the selection crossfades to the next/previous one), else
// status-bg.png. With any of them,
// the built-in ring + giant icon are hidden so the art shows through.
//
// Resident: started hidden at login (a fresh qs process needs ~1.2 s to map, too slow for a
// keybind) and the scene is built once up front, so opening only maps the window and replays
// the intro. While hidden nothing renders and the data feed / clock are stopped (0 CPU).
// Toggle: SUPER+I (Hyprland global shortcut p3status:toggle), or qs -c p3-status ipc call status toggle
import QtQuick
import QtQuick.Shapes
import QtMultimedia
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: shell

    // the Dark Hour grades the art green and swaps cyan accents for green (DarkHour.qml)
    DarkHour { id: dh }

    readonly property string media: Quickshell.env("P3_MEDIA") || (Quickshell.env("HOME") + "/.local/share/persona-rice/media/p3")
    readonly property string dir: Quickshell.shellDir

    property bool shown: Quickshell.env("P3_STATUS_OPEN") === "1"
    property bool hasVideo: false

    // the video backdrop only exists if its slot file does (QtMultimedia init is slow)
    Process {
        running: true
        command: ["test", "-e", shell.media + "/status-bg.mp4"]
        onExited: code => shell.hasVideo = code === 0
    }

    function toggle(): void {
        if (!shell.shown)
            shell.shown = true;
        else if (content.item)
            content.item.close();
    }

    // SUPER+I → hl.dsp.global("p3status:toggle"): Hyprland signals us directly, no
    // `qs ipc` client process (that alone costs ~220 ms)
    // another p3 menu opened: vanish at once (no close animation under/over it)
    GlobalShortcut {
        appid: "p3status"
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
        appid: "p3status"
        name: "toggle"
        description: "Toggle the p3 daily status screen"
        onPressed: shell.toggle()
    }

    IpcHandler {
        target: "status"
        function toggle(): void { shell.toggle(); }
        function open(): void { shell.shown = true; }
        // move the selection (testing / scripting): qs -c p3-status ipc call status step 1
        function step(d: int): void {
            if (content.item)
                content.item.move(d);
        }
        function close(): void {
            if (content.item)
                content.item.close();
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        // Never unmapped: unmapping throws the scene away and every open then spends
        // 250-450 ms rebuilding it and re-uploading the art. "Hidden" = a transparent,
        // click-through 1x1 window with no keyboard focus; the scene (at full screen size,
        // so nothing re-lays out) and its textures stay alive. Nothing draws while hidden.
        anchors { top: true; left: true; bottom: shell.shown; right: shell.shown }
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: shell.shown ? null : noInput
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "p3-status"
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
            readonly property color navy: "#0b1fc7"
            readonly property color cyan: dh.mix("#3fd8ff", dh.green)
            readonly property color hp: dh.mix("#2ee6ff", dh.green)
            readonly property color sp: "#ffe23a"
            readonly property color white: "#f2fbff"
            readonly property color red: "#ff1f3a"
            readonly property string face: "Montserrat"
            readonly property string icons: "Material Symbols Rounded"

            property real fill: 0
            property real rowsIn: 0
            property bool closing: false
            property int sel: 0
            property int lastSel: 0
            onSelChanged: {
                const n = rows.length;
                const fwd = (sel - lastSel + n) % n;
                lastSel = sel;
                if (fwd !== 0)
                    slides.go(fwd <= n / 2 ? 1 : -1);
            }
            property bool taskMode: false
            property int taskSel: 0
            property var s: ({})
            property int feedLines: 0
            readonly property bool art: shell.hasVideo || arts.count > 0 || bgImg.status === Image.Ready
            property date now: new Date()

            readonly property var days: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            readonly property var tasks: s.tasks ?? []
            readonly property int tasksDone: tasks.filter(t => t.d).length

            function pad(n, w) { return n === undefined || isNaN(n) ? "---" : String(Math.max(0, Math.round(n))).padStart(w || 3, "0"); }
            function clamp(v) { return Math.max(0, Math.min(1, v || 0)); }
            function rate(k) { return k >= 1024 ? (k / 1024).toFixed(1) + " MB/s" : Math.round(k) + " KB/s"; }
            function logp(k) { return clamp(Math.log10(1 + k) / 5); }   // 100 MB/s ≈ full
            function hm(sec) { return Math.floor(sec / 3600) + "h " + String(Math.floor(sec / 60) % 60).padStart(2, "0") + "m"; }

            // one entry per row: colour, icon, name, Lv, bar a/b {l, v (text), p (0..1)}
            readonly property var rows: [
                { col: "#3fd8ff", icon: "calendar_today", name: days[now.getDay()], lv: now.getDate(),
                  a: { l: "DAY", v: pad(s.dayPct), p: (s.dayPct || 0) / 100 }, b: { l: "WK", v: pad(s.weekPct), p: (s.weekPct || 0) / 100 } },
                { col: "#ffd23f", icon: s.batStatus === "Charging" ? "battery_charging_full" : "battery_full", name: "Battery", lv: s.bat ?? 0,
                  a: { l: "CHG", v: pad(s.bat), p: (s.bat || 0) / 100 }, b: { l: "HLT", v: pad(s.batHealth), p: (s.batHealth || 0) / 100 } },
                { col: "#ff3d5a", icon: "memory", name: "Processor", lv: s.cores ?? 0,
                  a: { l: "USE", v: pad(s.cpu), p: (s.cpu || 0) / 100 }, b: { l: "°C", v: pad(s.temp), p: (s.temp || 0) / 100 } },
                { col: "#b06bff", icon: "memory_alt", name: "Memory", lv: s.memTotal ?? 0,
                  a: { l: "RAM", v: pad(s.memPct), p: (s.memPct || 0) / 100 }, b: { l: "SWP", v: pad(s.swapPct), p: (s.swapPct || 0) / 100 } },
                { col: "#ff8a3d", icon: "hard_drive", name: "Storage", lv: s.diskTotal ?? 0,
                  a: { l: "USE", v: pad(s.diskPct), p: (s.diskPct || 0) / 100 }, b: { l: "GB", v: pad(s.diskFree), p: (s.diskFree || 0) / Math.max(1, s.diskTotal || 1) } },
                { col: "#3dff8a", icon: s.ssid ? "wifi" : "wifi_off", name: s.ssid || "Offline", lv: s.signal ?? 0,
                  a: { l: "DN", v: pad(s.down), p: logp(s.down) }, b: { l: "UP", v: pad(s.up), p: logp(s.up) } },
                { col: "#ff5fae", icon: s.muted ? "volume_off" : "volume_up", name: "Sound", lv: s.vol ?? 0,
                  a: { l: "VOL", v: pad(s.vol), p: (s.vol || 0) / 100 }, b: { l: "LIT", v: pad(s.bright), p: (s.bright || 0) / 100 } },
                { col: "#c9d6e8", icon: "schedule", name: "Uptime", lv: Math.floor((s.uptime || 0) / 3600),
                  a: { l: "MIN", v: pad(Math.floor((s.uptime || 0) / 60) % 60), p: (Math.floor((s.uptime || 0) / 60) % 60) / 60 },
                  b: { l: "LD", v: pad((s.load || 0) * 100 / Math.max(1, s.cores || 1)), p: (s.load || 0) / Math.max(1, s.cores || 1) } },
                { col: "#3d8cff", icon: "checklist", name: "Tasks", lv: tasks.length - tasksDone,
                  a: { l: "DONE", v: pad(tasksDone), p: tasks.length ? tasksDone / tasks.length : 0 },
                  b: { l: "LEFT", v: pad(tasks.length - tasksDone), p: tasks.length ? (tasks.length - tasksDone) / tasks.length : 0 } }
            ]
            readonly property int taskRow: 8

            function details(i) {
                const t = s;
                switch (i) {
                case 0: return [["DATE", (art ? months[now.getMonth()].slice(0, 3) : months[now.getMonth()]) + " " + now.getDate() + ", " + now.getFullYear()],
                                ["TIME", Qt.formatTime(now, "hh:mm")], ["DAY DONE", (t.dayPct ?? 0) + "%"], ["WEEK DONE", (t.weekPct ?? 0) + "%"]];
                case 1: return [["CHARGE", (t.bat ?? 0) + "%"], ["STATE", t.batStatus ?? "—"],
                                ["TIME", t.batMins ? hm(t.batMins * 60) + (t.batStatus === "Charging" ? " to full" : " left") : "—"],
                                ["HEALTH", (t.batHealth ?? 0) + "%"]];
                case 2: return [["USAGE", (t.cpu ?? 0) + "%"], ["TEMP", (t.temp ?? 0) + " °C"], ["LOAD", (t.load ?? 0).toFixed(2)], ["CORES", t.cores ?? 0]];
                case 3: return [["USED", (t.memUsed ?? 0) + " / " + (t.memTotal ?? 0) + " GB"], ["RAM", (t.memPct ?? 0) + "%"],
                                ["SWAP", (t.swapUsed ?? 0) + " GB"]];
                case 4: return [["USED", (t.diskPct ?? 0) + "%"], ["FREE", (t.diskFree ?? 0) + " GB"], ["SIZE", (t.diskTotal ?? 0) + " GB"]];
                case 5: return [["NETWORK", t.ssid || "Offline"], ["SIGNAL", (t.signal ?? 0) + "%"], ["DOWN", rate(t.down ?? 0)], ["UP", rate(t.up ?? 0)]];
                case 6: return [["VOLUME", (t.vol ?? 0) + "%" + (t.muted ? "  MUTED" : "")], ["BRIGHTNESS", (t.bright ?? 0) + "%"]];
                case 7: return [["AWAKE", hm(t.uptime ?? 0)], ["LOAD", (t.load ?? 0).toFixed(2)]];
                }
                return [];
            }

            Process {
                id: feed
                running: shell.shown
                command: ["python3", shell.dir + "/stats.py"]
                stdout: SplitParser {
                    onRead: line => {
                        try {
                            const o = JSON.parse(line);
                            // the Wi-Fi name arrives a moment after a fresh start; keep the
                            // last known one for the first few lines instead of "Offline"
                            if (root.feedLines < 3 && !o.ssid && root.s.ssid) {
                                o.ssid = root.s.ssid;
                                o.signal = root.s.signal;
                            }
                            root.feedLines++;
                            root.s = o;
                        } catch (e) {}
                    }
                }
            }
            Process {
                id: toggler
                property int idx: 0
                command: ["python3", shell.dir + "/stats.py", "toggle", String(idx)]
            }
            function toggleTask(i) {
                if (i < 0 || i >= tasks.length)
                    return;
                // flip locally right away, the file write follows
                const copy = tasks.map(t => ({ t: t.t, d: t.d }));
                copy[i].d = !copy[i].d;
                const ns = Object.assign({}, s);
                ns.tasks = copy;
                s = ns;
                toggler.idx = i;
                toggler.running = true;
            }
            function editTasks() {
                Quickshell.execDetached(["kitty", "--class", "p3-tasks", "-e", Quickshell.env("EDITOR") || "micro", s.tasksFile || (Quickshell.env("HOME") + "/.local/share/persona-rice/tasks.txt")]);
                close();
            }

            function move(d) {
                if (!shell.shown || closing)
                    return;
                if (taskMode) {
                    if (tasks.length)
                        taskSel = (taskSel + d + tasks.length) % tasks.length;
                    return;
                }
                sel = (sel + d + rows.length) % rows.length;
            }
            function enter() {
                if (!shell.shown || closing)
                    return;
                if (taskMode)
                    toggleTask(taskSel);
                else if (sel === taskRow && tasks.length) {
                    taskMode = true;
                    taskSel = Math.min(taskSel, tasks.length - 1);
                }
            }
            function back() {
                if (taskMode)
                    taskMode = false;
                else
                    close();
            }
            function hideNow() {
                closeAnim.stop();
                openAnim.stop();
                warming = false;
                closing = false;
                fill = 0; rowsIn = 0;
                shell.shown = false;
            }
            // only one p3 menu at a time: opening this one hides the others (hyprctl → their
            // "hide" globals, ~10 ms; a qs ipc call would cost ~200 ms each)
            function hideOthers() {
                Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.global(\"p3equip:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3items:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3skills:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3links:hide\")' >/dev/null"]);
            }
            function reopen() {
                hideOthers();
                closeAnim.stop();
                closing = false;
                fill = 0;
                rowsIn = 0;
                taskMode = false;
                feedLines = 0;
                lastSel = 0;   // back to the top row without stepping the slideshow
                sel = 0;
                now = new Date();
                // don't start the clock yet: after a while hidden, the first frame takes
                // ~250 ms (art re-uploads to the GPU) and would eat most of the intro.
                // Wait until real frames are on screen, then play it.
                openAnim.stop();
                warmFrames = 0;
                warming = true;
            }
            property bool warming: false
            property int warmFrames: 0
            Connections {
                target: root.Window.window
                function onFrameSwapped() {
                    if (!root.warming)
                        return;
                    // 2 frames: the first carries the texture uploads
                    if (++root.warmFrames >= 2) {
                        root.warming = false;
                        openAnim.restart();
                    } else {
                        root.Window.window.update();
                    }
                }
            }
            Component.onCompleted: if (shell.shown) reopen()
            Connections {
                target: shell
                function onShownChanged() {
                    if (shell.shown)
                        root.reopen();
                }
            }
            function close() {
                if (closing)
                    return;
                closing = true;
                closeAnim.start();
            }

            Keys.onUpPressed: move(-1)
            Keys.onDownPressed: move(1)
            Keys.onTabPressed: move(1)
            Keys.onBacktabPressed: move(-1)
            Keys.onEscapePressed: back()
            Keys.onLeftPressed: if (taskMode) taskMode = false
            Keys.onRightPressed: enter()
            Keys.onReturnPressed: enter()
            Keys.onEnterPressed: enter()
            Keys.onSpacePressed: enter()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_E) editTasks();
                else if (e.key === Qt.Key_Q) close();
                else if (e.key === Qt.Key_J) move(1);
                else if (e.key === Qt.Key_K) move(-1);
            }

            Timer {
                interval: 1000
                running: shell.shown
                repeat: true
                onTriggered: root.now = new Date()
            }

            // ── timeline ────────────────────────────────────────────────────
            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: root; property: "fill"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 120 }
                    NumberAnimation { target: root; property: "rowsIn"; from: 0; to: 1; duration: 620; easing.type: Easing.Linear }
                }
            }
            SequentialAnimation {
                id: closeAnim
                NumberAnimation { target: root; property: "rowsIn"; to: 0; duration: 200 }
                NumberAnimation { target: root; property: "fill"; to: 0; duration: 220; easing.type: Easing.InCubic }
                ScriptAction { script: shell.shown = false }
            }

            // ── backdrop ────────────────────────────────────────────────────
            Item {
                id: backdrop
                layer.enabled: dh.t > 0
                layer.effect: ShaderEffect {
                    property real dark: dh.t
                    fragmentShader: Qt.resolvedUrl("grade.frag.qsb")
                }
                anchors.fill: parent
                // never exactly 0 while warming, so the art is drawn (and uploaded) in the
                // invisible first frame instead of hitching the fade
                opacity: root.warming ? 0.004 : root.fill

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#16b4ff" }
                        GradientStop { position: 0.35; color: "#1667ea" }
                        GradientStop { position: 1.0; color: "#0a1cb8" }
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: shell.hasVideo
                    sourceComponent: Component {
                        Item {
                            MediaPlayer {
                                id: player
                                source: "file://" + shell.media + "/status-bg.mp4"
                                loops: MediaPlayer.Infinite
                                videoOutput: vid
                                audioOutput: AudioOutput { muted: true }
                                Component.onCompleted: play()
                            }
                            VideoOutput {
                                id: vid
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectCrop
                            }
                        }
                    }
                }
                Image {
                    id: bgImg
                    anchors.fill: parent
                    visible: !shell.hasVideo && arts.count === 0 && status === Image.Ready
                    source: "file://" + shell.media + "/status-bg.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    mipmap: true
                }

                // slideshow: every frame is the same composition, so a crossfade reads as only
                // the changed bits (eyes, ring text) morphing. The frames are moments of an
                // animation though, so the character bobs between them; status-bg/offsets.json
                // ("next"[i] = character shift from frame i to i+1, source px; made by the
                // offsets script) lets both frames slide during the fade so the character stays
                // registered instead of ghosting. topIdx fades in over prevIdx (opaque below).
                FolderListModel {
                    id: arts
                    folder: "file://" + shell.media + "/status-bg"
                    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                    showDirs: false
                    sortField: FolderListModel.Name
                }
                FileView {
                    path: shell.media + "/status-bg/offsets.json"
                    onLoaded: {
                        try { slides.offs = JSON.parse(text()).next || []; } catch (e) { slides.offs = []; }
                    }
                }
                Item {
                    id: slides
                    anchors.fill: parent
                    visible: !shell.hasVideo && arts.count > 0
                    property int topIdx: 0
                    property int prevIdx: -1
                    property real fade: 1
                    property var offs: []
                    property real sx: 0      // character shift prev → top, source px
                    property real sy: 0
                    readonly property real k: width / 1920
                    NumberAnimation { id: fadeAnim; target: slides; property: "fade"; from: 0; to: 1; duration: 380; easing.type: Easing.InOutSine }
                    // summed character shift walking from frame a to frame b in direction d
                    function path(a, b, d) {
                        const n = arts.count;
                        let x = 0, y = 0, i = a, guard = 0;
                        if (offs.length !== n)
                            return [0, 0];
                        while (i !== b && guard++ < n) {
                            if (d > 0) { x += offs[i][0]; y += offs[i][1]; i = (i + 1) % n; }
                            else { i = (i - 1 + n) % n; x -= offs[i][0]; y -= offs[i][1]; }
                        }
                        return [x, y];
                    }
                    function go(d) {
                        if (arts.count < 2)
                            return;
                        // mid-fade: keep whichever frame currently dominates as the base
                        prevIdx = fade >= 0.5 ? topIdx : prevIdx;
                        topIdx = (topIdx + d + arts.count) % arts.count;
                        const s = prevIdx >= 0 ? path(prevIdx, topIdx, d) : [0, 0];
                        sx = s[0];
                        sy = s[1];
                        fadeAnim.restart();
                    }
                    Repeater {
                        id: slidesRep
                        model: arts
                        Image {
                            id: frame
                            required property int index
                            required property url fileUrl
                            anchors.fill: parent
                            source: fileUrl
                            fillMode: Image.PreserveAspectCrop
                            // only the opening frame blocks; the rest decode in the background
                            asynchronous: index !== 0
                            smooth: true
                            mipmap: true
                            // a hair of overscan so the sliding never exposes an edge
                            scale: 1.04
                            readonly property bool isTop: index === slides.topIdx
                            readonly property bool isPrev: index === slides.prevIdx
                            z: isTop ? 2 : isPrev ? 1 : 0
                            opacity: isTop ? slides.fade : isPrev ? 1 : 0
                            visible: opacity > 0
                            // outgoing drifts forward onto the incoming pose, incoming starts on
                            // the outgoing pose and settles home
                            readonly property real m: isTop ? -(1 - slides.fade) : isPrev ? slides.fade : 0
                            transform: Translate {
                                x: frame.m * slides.sx * slides.k
                                y: frame.m * slides.sy * slides.k
                            }
                        }
                    }
                }
                // water caustics: a few soft pale slabs drifting in the top-left
                Repeater {
                    model: root.art ? [] : [[40, 20, 300, 26, -4], [220, 70, 220, 18, 3], [-30, 110, 260, 14, -2], [380, 30, 180, 12, 5], [120, 160, 160, 10, -6]]
                    Rectangle {
                        required property var modelData
                        x: modelData[0] * root.u; y: modelData[1] * root.u
                        width: modelData[2] * root.u; height: modelData[3] * root.u
                        rotation: modelData[4]
                        antialiasing: true
                        color: Qt.alpha("#bff3ff", 0.18)
                    }
                }
                // deep shade towards the bottom-right so white type reads
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.55; color: Qt.alpha("#06115e", root.art ? 0.0 : 0.15) }
                        GradientStop { position: 1.0; color: Qt.alpha("#06115e", root.art ? 0.12 : 0.45) }
                    }
                }
            }

            // ── big ring + icon silhouette (right half) ─────────────────────
            Item {
                id: stage
                x: 600 * root.u
                y: 70 * root.u
                width: parent.width - x
                height: 560 * root.u
                opacity: root.rowsIn
                visible: !root.art
                readonly property var row: root.rows[root.sel]

                Shape {
                    id: ring
                    readonly property real cx: 420 * root.u
                    readonly property real cy: 250 * root.u
                    readonly property real r: 220 * root.u
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Qt.alpha("#ffffff", 0.55)
                        strokeWidth: 34 * root.u
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        PathAngleArc { centerX: ring.cx; centerY: ring.cy; radiusX: ring.r; radiusY: ring.r; startAngle: 200; sweepAngle: 250 }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha("#bfe9ff", 0.35)
                        strokeWidth: 10 * root.u
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        PathAngleArc { centerX: ring.cx; centerY: ring.cy; radiusX: ring.r + 44 * root.u; radiusY: ring.r + 44 * root.u; startAngle: 120; sweepAngle: 110 }
                    }
                }

                // giant icon, swaps with a quick slide when the selection changes
                Item {
                    id: hero
                    x: 430 * root.u - width / 2
                    y: 250 * root.u - height / 2 - 20 * root.u
                    width: 330 * root.u
                    height: 330 * root.u
                    rotation: -10
                    property string icon: stage.row.icon
                    property color col: stage.row.col
                    onIconChanged: { heroIn.restart(); }
                    property real k: 1
                    NumberAnimation { id: heroIn; target: hero; property: "k"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    opacity: k
                    transform: Translate { x: (1 - hero.k) * 60 * root.u }

                    Text {
                        x: 16 * root.u; y: 16 * root.u
                        text: hero.icon
                        font.family: root.icons
                        font.pixelSize: 320 * root.u
                        font.variableAxes: { "FILL": 1, "wght": 600 }
                        color: "#0a1a8a"
                    }
                    Text {
                        x: -8 * root.u; y: -6 * root.u
                        text: hero.icon
                        font.family: root.icons
                        font.pixelSize: 320 * root.u
                        font.variableAxes: { "FILL": 1, "wght": 600 }
                        color: hero.col
                    }
                    Text {
                        text: hero.icon
                        font.family: root.icons
                        font.pixelSize: 320 * root.u
                        font.variableAxes: { "FILL": 1, "wght": 600 }
                        color: root.white
                    }
                }
            }

            // ── header band: "Daily Status" + date, tilted ─────────────────
            Item {
                x: 560 * root.u
                y: 0
                width: parent.width - x
                height: 200 * root.u
                opacity: root.rowsIn
                Shape {
                    visible: !root.art
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Qt.alpha("#e9f2ff", 0.82)
                        strokeWidth: -1
                        PathPolyline {
                            readonly property real w: 760 * root.u
                            path: [Qt.point(60 * root.u, 120 * root.u), Qt.point(w, -10 * root.u), Qt.point(w, 50 * root.u), Qt.point(70 * root.u, 168 * root.u), Qt.point(60 * root.u, 120 * root.u)]
                        }
                    }
                }
                Text {
                    visible: !root.art
                    x: 120 * root.u
                    y: 112 * root.u
                    rotation: -10.5
                    transformOrigin: Item.TopLeft
                    text: "Daily Status"
                    font.family: "Jost"
                    font.weight: Font.Medium
                    font.italic: true
                    font.pixelSize: 30 * root.u
                    color: "#5aa8f5"
                }
                Item {
                    x: 380 * root.u
                    y: 28 * root.u
                    rotation: -10.5
                    transformOrigin: Item.TopLeft
                    Row {
                        spacing: 12 * root.u
                        Text {
                            visible: false
                            text: ""
                            font.family: "Jost"
                            font.weight: Font.Medium
                            font.italic: true
                            font.pixelSize: 30 * root.u
                            color: "#7ec2ff"
                        }
                        Text {
                            text: Qt.formatDate(root.now, "MM/dd")
                            font.family: "Jost"
                            font.weight: Font.Black
                            font.italic: true
                            font.pixelSize: 58 * root.u
                            color: root.white
                            style: Text.Outline
                            styleColor: "#0a0a0a"
                        }
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10 * root.u
                            text: root.days[root.now.getDay()].slice(0, 3).toUpperCase()
                            font.family: "Jost"
                            font.weight: Font.Black
                            font.italic: true
                            font.pixelSize: 34 * root.u
                            color: root.red
                        }
                    }
                }
            }

            // ── detail slab (bottom of the right half) ──────────────────────
            Item {
                id: detail
                x: (root.art ? 600 : 650) * root.u
                y: (root.art ? 462 : 455) * root.u
                rotation: -5
                transformOrigin: Item.TopLeft
                opacity: root.rowsIn
                readonly property var lines: root.details(root.sel)
                readonly property bool tasksView: root.sel === root.taskRow

                Shape {
                    id: slab
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real w: (root.art ? 330 : 470) * root.u
                    readonly property real h: col.height + 26 * root.u
                    ShapePath {
                        fillColor: Qt.alpha("#050a1e", 0.86)
                        strokeWidth: -1
                        PathPolyline {
                            path: [Qt.point(-14 * root.u, -6 * root.u), Qt.point(slab.w, -16 * root.u),
                                   Qt.point(slab.w - 18 * root.u, slab.h), Qt.point(-4 * root.u, slab.h + 6 * root.u),
                                   Qt.point(-14 * root.u, -6 * root.u)]
                        }
                    }
                }
                // name tab sticking out above the slab
                Text {
                    x: 0
                    y: -56 * root.u
                    text: root.rows[root.sel].name
                    font.family: "Jost"
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 52 * root.u
                    font.letterSpacing: -1.5 * root.u
                    color: root.white
                    style: Text.Outline
                    styleColor: "#0a0a0a"
                    width: slab.w
                    elide: Text.ElideRight
                }

                Column {
                    id: col
                    x: 10 * root.u
                    y: 6 * root.u
                    width: slab.w - 10 * root.u
                    spacing: (root.art ? 0 : 2) * root.u

                    Repeater {
                        model: detail.tasksView ? [] : detail.lines
                        Row {
                            required property var modelData
                            spacing: 14 * root.u
                            Text {
                                width: (root.art ? 92 : 130) * root.u
                                horizontalAlignment: Text.AlignRight
                                anchors.baseline: val.baseline
                                text: modelData[0]
                                font.family: root.face
                                font.weight: Font.Bold
                                font.italic: true
                                font.pixelSize: 13 * root.u
                                color: root.rows[root.sel].col
                            }
                            Text {
                                id: val
                                text: modelData[1]
                                font.family: "Jost"
                                font.weight: Font.Medium
                                font.italic: true
                                font.pixelSize: (root.art ? 22 : 26) * root.u
                                color: root.white
                                width: slab.w - (root.art ? 120 : 160) * root.u
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // tasks: checklist (↵ on the Tasks row to step in, ↵ toggles)
                    Text {
                        visible: detail.tasksView && root.tasks.length === 0
                        text: "No tasks — press E to write some"
                        font.family: "Jost"
                        font.italic: true
                        font.pixelSize: 22 * root.u
                        color: root.white
                    }
                    Repeater {
                        model: detail.tasksView ? root.tasks.slice(0, 9) : []
                        Item {
                            id: tk
                            required property var modelData
                            required property int index
                            readonly property bool on: root.taskMode && root.taskSel === index
                            width: slab.w - 10 * root.u
                            height: 32 * root.u
                            Rectangle {
                                visible: tk.on
                                x: -6 * root.u
                                width: parent.width
                                height: parent.height
                                color: root.white
                                antialiasing: true
                                Rectangle { anchors.left: parent.left; width: 5 * root.u; height: parent.height; color: root.red }
                            }
                            Rectangle {
                                id: box
                                x: 8 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18 * root.u
                                height: width
                                rotation: 45
                                antialiasing: true
                                color: tk.modelData.d ? root.hp : "transparent"
                                border.color: tk.on ? "#0a0a0a" : root.hp
                                border.width: 2 * root.u
                            }
                            Text {
                                x: 40 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - 8 * root.u
                                elide: Text.ElideRight
                                text: tk.modelData.t
                                font.family: "Jost"
                                font.weight: Font.Medium
                                font.italic: true
                                font.pixelSize: 21 * root.u
                                font.strikeout: tk.modelData.d
                                color: tk.on ? "#0a0a0a" : (tk.modelData.d ? Qt.alpha(root.white, 0.45) : root.white)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.taskMode = true; root.taskSel = tk.index; root.toggleTask(tk.index); }
                            }
                        }
                    }
                }
            }

            // ── stat rows (left) ────────────────────────────────────────────
            Item {
                id: list
                x: 0
                y: 72 * root.u

                Repeater {
                    id: rep
                    model: root.rows.length

                    Item {
                        id: row
                        required property int index
                        readonly property var d: root.rows[index]
                        readonly property bool on: root.sel === index
                        readonly property real h: 52 * root.u
                        readonly property real w: (on ? 588 : 560) * root.u
                        readonly property real enter: Math.max(0, Math.min(1, root.rowsIn * (root.rows.length + 3) / 3 - index * 0.33))
                        property real shift: on ? 26 * root.u : 0
                        Behavior on shift { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        y: index * 60 * root.u
                        x: -(1 - enter) * (1 - enter) * 720 * root.u
                        width: w
                        height: h
                        z: on ? 10 : 0

                        // body (+ red frame when selected)
                        Shape {
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: row.on ? root.white : "#07080c"
                                strokeColor: row.on ? root.red : "transparent"
                                strokeWidth: row.on ? 2.5 * root.u : -1
                                joinStyle: ShapePath.MiterJoin
                                PathPolyline {
                                    path: [Qt.point(-4, 0), Qt.point(row.w, 0), Qt.point(row.w - 12 * root.u, row.h),
                                           Qt.point(-4, row.h), Qt.point(-4, 0)]
                                }
                            }
                        }
                        // colour wedge fanning out from the icon
                        Shape {
                            x: row.shift
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: row.d.col
                                strokeWidth: -1
                                PathPolyline {
                                    path: [Qt.point(78 * root.u, 0), Qt.point(206 * root.u, 0), Qt.point(150 * root.u, row.h * 0.55),
                                           Qt.point(118 * root.u, row.h), Qt.point(78 * root.u, row.h), Qt.point(78 * root.u, 0)]
                                }
                            }
                            ShapePath {
                                fillColor: Qt.darker(row.d.col, 1.6)
                                strokeWidth: -1
                                PathPolyline {
                                    path: [Qt.point(78 * root.u, row.h * 0.62), Qt.point(150 * root.u, row.h * 0.55),
                                           Qt.point(118 * root.u, row.h), Qt.point(78 * root.u, row.h), Qt.point(78 * root.u, row.h * 0.62)]
                                }
                            }
                        }
                        // icon "portrait": white silhouette with a black offset, centred in a
                        // fixed box over the wedge (glyphs differ in width, so no left-align)
                        Item {
                            x: 82 * root.u + row.shift
                            width: 80 * root.u
                            height: row.h
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 3 * root.u
                                anchors.topMargin: 2 * root.u
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: row.d.icon
                                font.family: root.icons
                                font.pixelSize: 40 * root.u
                                font.variableAxes: { "FILL": 1, "wght": 600 }
                                color: "#07080c"
                            }
                            Text {
                                anchors.fill: parent
                                anchors.rightMargin: 3 * root.u
                                anchors.bottomMargin: 2 * root.u
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: row.d.icon
                                font.family: root.icons
                                font.pixelSize: 40 * root.u
                                font.variableAxes: { "FILL": 1, "wght": 600 }
                                color: root.white
                            }
                        }
                        // name
                        Text {
                            x: 172 * root.u + row.shift
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120 * root.u
                            elide: Text.ElideRight
                            text: row.d.name
                            font.family: "Jost"
                            font.weight: Font.Medium
                            font.pixelSize: 22 * root.u
                            color: row.on ? "#07080c" : root.white
                        }
                        // slash in the row colour
                        Shape {
                            x: 300 * root.u + row.shift
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: row.d.col
                                strokeWidth: 1.6 * root.u
                                fillColor: "transparent"
                                PathPolyline { path: [Qt.point(16 * root.u, 8 * root.u), Qt.point(0, row.h - 8 * root.u)] }
                            }
                        }
                        // Lv
                        Text {
                            x: 318 * root.u + row.shift
                            anchors.baseline: lv.baseline
                            text: "Lv"
                            font.family: "Jost"
                            font.italic: true
                            font.pixelSize: 10 * root.u
                            color: row.on ? "#07080c" : root.white
                        }
                        Text {
                            id: lv
                            x: 332 * root.u + row.shift
                            y: row.h - height + 4 * root.u
                            text: String(row.d.lv)
                            font.family: "Jost"
                            font.italic: true
                            font.pixelSize: 26 * root.u
                            color: row.on ? "#07080c" : root.white
                        }
                        // two bars
                        Repeater {
                            model: [[row.d.a, root.hp, 378], [row.d.b, root.sp, 466]]
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
                                    text: bar.v.v
                                    font.family: "Jost"
                                    font.weight: Font.Light
                                    font.italic: true
                                    font.pixelSize: 34 * root.u
                                    font.letterSpacing: -1 * root.u
                                    color: row.on ? "#07080c" : bar.modelData[1]
                                }
                                // track + fill, slanted ends
                                Shape {
                                    id: track
                                    y: row.h - 9 * root.u
                                    preferredRendererType: Shape.CurveRenderer
                                    readonly property real bw: bar.width
                                    readonly property real fw: Math.max(0, Math.min(1, bar.v.p || 0)) * bw
                                    ShapePath {
                                        fillColor: row.on ? "#9aa3b5" : "#30343f"
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
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (!root.taskMode) root.sel = row.index
                            onClicked: { root.sel = row.index; root.enter(); }
                        }
                    }
                }
            }

            // ── bottom-right guide ──────────────────────────────────────────
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 36 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26 * root.u
                spacing: 4 * root.u
                opacity: root.rowsIn

                Text {
                    anchors.right: parent.right
                    text: root.taskMode ? "Which task did you finish?" : "What do you want to check today?"
                    font.family: root.face
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pixelSize: 24 * root.u
                    color: root.white
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 380 * root.u
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
                        model: root.taskMode ? [["↵", "Toggle"], ["E", "Edit"], ["Esc", "Back"]]
                             : root.sel === root.taskRow ? [["↵", "Tasks"], ["E", "Edit"], ["Esc", "Back"]]
                             : [["↑↓", "Select"], ["E", "Tasks"], ["Esc", "Back"]]
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
