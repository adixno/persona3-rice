// p3-calendar: the month calendar, as the Persona 3 CALENDAR screen.
// A huge disc of water on the left holds the month: giant month number, the months either
// side (Q / E), a grid of days (Sundays red, Saturdays cyan), a flat lopsided triangle as the cursor, the real
// moon (gold disc = full, ring = new, half discs = quarters) and a dot under days with plans.
// The paper on the right shows what is coming up next and the selected day's plans.
// Plans live in a plain text file (cal.py: ~/.local/share/persona-rice/calendar.txt):
//   2026-11-20 DBMS exam        *-12-25 Christmas (every year)
// Keys: arrows / hjkl move, Q E (PgUp PgDn) month, T today, ↵ add a plan, Tab pick a plan,
// Del remove it (asks twice), O open the file in an editor, Esc back.
// Everything is drawn in code (water.frag); no art slot.
//
// Resident like the other p3 menus; one menu at a time. Toggle: SUPER+Y (global p3calendar:toggle)
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: shell

    // the Dark Hour grades the screen green and swaps cyan accents for green (DarkHour.qml)
    DarkHour { id: dh }

    readonly property string dir: Quickshell.shellDir
    property bool shown: Quickshell.env("P3_CALENDAR_OPEN") === "1"

    function toggle(): void {
        if (!shell.shown)
            shell.shown = true;
        else if (content.item)
            content.item.close();
    }

    GlobalShortcut {
        appid: "p3calendar"
        name: "toggle"
        description: "Toggle the p3 calendar screen"
        onPressed: shell.toggle()
    }
    // another p3 menu opened: vanish at once
    GlobalShortcut {
        appid: "p3calendar"
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

    IpcHandler {
        target: "calendar"
        function toggle(): void { shell.toggle(); }
        function open(): void { shell.shown = true; }
        function close(): void { if (content.item) content.item.close(); }
        // testing: move the selection by days / months, jump to today
        function move(d: int): void { if (content.item) content.item.step(d); }
        function month(d: int): void { if (content.item) content.item.stepMonth(d); }
        function today(): void { if (content.item) content.item.goToday(); }
        // add a plan from a script: qs -c p3-calendar ipc call calendar add 2026-11-20 "DBMS exam"
        function add(date: string, text: string): void { if (content.item) content.item.run(["add", date, text]); }
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
        WlrLayershell.namespace: "p3-calendar"
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
            readonly property color navy: "#0a1466"
            readonly property color ink: "#141a2e"
            readonly property color cyan: dh.mix("#35e0ff", dh.green)
            readonly property color chip: dh.mix("#4fe3f7", dh.green)
            readonly property color white: "#ffffff"
            readonly property color red: "#ff2d4f"
            readonly property color pink: "#ff7ae0"
            readonly property color gold: "#c9a227"
            readonly property color slate: "#3a4049"
            readonly property color grey: "#6b7480"
            // Archivo (variable: width 62-125, weight 100-900) at full width is close to the
            // reference's wide grotesque; the day's plans are set in a serif, as there
            readonly property string face: "Archivo"
            readonly property string serif: "Noto Serif"
            function ax(w, wd) { return ({ "wdth": wd === undefined ? 125 : wd, "wght": w }); }
            readonly property color mark: "#ff3f74"     // the cursor triangle

            property real fill: 0      // backdrop fade + disc swell
            property real gridIn: 0    // days cascade in
            property real sideIn: 0    // right-hand paper content slides in
            property bool closing: false
            property bool warming: false
            property int warmFrames: 0

            // ── dates ────────────────────────────────────────────────────
            SystemClock { id: clock; precision: SystemClock.Minutes; enabled: shell.shown }
            readonly property int tY: clock.date.getFullYear()
            readonly property int tM: clock.date.getMonth()
            readonly property int tD: clock.date.getDate()

            property int selY: new Date().getFullYear()
            property int selM: new Date().getMonth()
            property int selD: new Date().getDate()

            readonly property int daysInMonth: new Date(selY, selM + 1, 0).getDate()
            readonly property int firstDow: new Date(selY, selM, 1).getDay()
            readonly property int rows: Math.ceil((firstDow + daysInMonth) / 7)
            readonly property real rowH: (rows > 5 ? 66 : 73) * u
            readonly property real colW: 73 * u
            // height of a day figure (flat-topped "1"), for centring the numbers vertically
            TextMetrics { id: digitM; font.family: root.face; font.variableAxes: root.ax(400); font.italic: true; font.pixelSize: 30 * root.u; text: "1" }
            readonly property real digitH: digitM.tightBoundingRect.height

            readonly property var dows: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            function pad(n) { return n < 10 ? "0" + n : "" + n; }
            function dayNo(y, m, d) { return Math.round(Date.UTC(y, m, d) / 86400000); }
            function dayLabel(y, m, d) { return (m + 1) + "/" + d + " (" + dows[new Date(y, m, d).getDay()] + ")"; }
            function relative(n) {
                return n === 0 ? "Today" : n === 1 ? "Tomorrow" : n === -1 ? "Yesterday"
                    : n > 0 ? "in " + n + " days" : (-n) + " days ago";
            }

            // month-change animation: the grid slides in from the side you moved towards
            property int mDir: 1
            property real mAnim: 1
            NumberAnimation { id: monthAnim; target: root; property: "mAnim"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }

            function setSel(y, m, d) {
                const nd = new Date(y, m, d);
                const changed = nd.getFullYear() !== selY || nd.getMonth() !== selM;
                if (changed) {
                    mDir = (nd.getFullYear() * 12 + nd.getMonth()) > (selY * 12 + selM) ? 1 : -1;
                    monthAnim.restart();
                }
                selY = nd.getFullYear();
                selM = nd.getMonth();
                selD = nd.getDate();
                entrySel = 0;
                confirm = false;
            }
            function step(d) {
                if (!shell.shown || closing || adding)
                    return;
                setSel(selY, selM, selD + d);
            }
            function stepMonth(d) {
                if (!shell.shown || closing || adding)
                    return;
                const max = new Date(selY, selM + d + 1, 0).getDate();
                setSel(selY, selM + d, Math.min(selD, max));
            }
            function goToday() {
                if (!shell.shown || closing || adding)
                    return;
                setSel(tY, tM, tD);
            }

            // ── moon ─────────────────────────────────────────────────────
            // moon age as a fraction of the synodic month: 0 new, 0.5 full
            // (Sun–Moon elongation with the main periodic terms: good to well under an hour,
            // so quarters land on the right day)
            function moonPhase(date) {
                const d = date.getTime() / 86400000 - 10957.5;      // days since J2000
                const r = Math.PI / 180;
                const Lm = 218.316 + 13.176396 * d, Mm = (134.963 + 13.064993 * d) * r, F = (93.272 + 13.229350 * d) * r;
                const Ls = 280.460 + 0.9856474 * d, Ms = (357.528 + 0.9856003 * d) * r;
                const D = (Lm - Ls) * r;
                const moon = Lm + 6.289 * Math.sin(Mm) + 1.274 * Math.sin(2 * D - Mm) + 0.658 * Math.sin(2 * D)
                    + 0.214 * Math.sin(2 * Mm) - 0.186 * Math.sin(Ms) - 0.114 * Math.sin(2 * F);
                const sun = Ls + 1.915 * Math.sin(Ms) + 0.020 * Math.sin(2 * Ms);
                const p = ((moon - sun) / 360) % 1;
                return p < 0 ? p + 1 : p;
            }
            // which quarter (if any) falls on this day
            function moonMark(y, m, d) {
                const p0 = moonPhase(new Date(y, m, d)), p1 = moonPhase(new Date(y, m, d + 1));
                const span = (p1 - p0 + 1) % 1;
                const names = ["new", "first", "full", "last"];
                for (let i = 0; i < 4; i++)
                    if ((i / 4 - p0 + 1) % 1 < span)
                        return names[i];
                return "";
            }
            readonly property var moonNames: ({ "new": "New moon", "first": "First quarter", "full": "Full moon", "last": "Last quarter" })
            function daysToFull(y, m, d) {
                for (let i = 0; i < 31; i++)
                    if (moonMark(y, m, d + i) === "full")
                        return i;
                return -1;
            }

            // ── plans ────────────────────────────────────────────────────
            property var events: []
            property string file: ""
            readonly property var byKey: {
                const o = {};
                for (const e of events)
                    (o[e.date] = o[e.date] || []).push(e);
                return o;
            }
            function eventsOn(y, m, d) {
                const md = pad(m + 1) + "-" + pad(d);
                return (byKey[y + "-" + md] || []).concat(byKey["*-" + md] || []);
            }
            readonly property var selEvents: eventsOn(selY, selM, selD)
            readonly property string selMoon: moonMark(selY, selM, selD)
            readonly property int selAway: dayNo(selY, selM, selD) - dayNo(tY, tM, tD)
            // the next few plans from today on (yearly ones at their next occurrence)
            readonly property var upcoming: {
                const t0 = dayNo(tY, tM, tD), out = [];
                for (const e of events) {
                    const p = e.date.split("-");
                    const m = parseInt(p[1]) - 1, d = parseInt(p[2]);
                    let y = p[0] === "*" ? tY : parseInt(p[0]);
                    if (p[0] === "*" && dayNo(y, m, d) < t0)
                        y++;
                    const n = dayNo(y, m, d) - t0;
                    if (n >= 0)
                        out.push({ text: e.text, days: n, label: dayLabel(y, m, d), y: y, m: m, d: d });
                }
                out.sort((a, b) => a.days - b.days);
                return out.slice(0, 3);
            }

            Process {
                id: reader
                command: ["python3", "-I", shell.dir + "/cal.py", "list"]
                stdout: SplitParser {
                    onRead: line => {
                        try {
                            const o = JSON.parse(line);
                            root.events = o.events ?? [];
                            root.file = o.file ?? "";
                        } catch (e) {}
                    }
                }
            }
            function refresh() { if (!reader.running) reader.running = true; }
            Process {
                id: writer
                stdout: SplitParser {
                    onRead: line => {
                        try {
                            const o = JSON.parse(line);
                            root.events = o.events ?? [];
                        } catch (e) {}
                    }
                }
            }
            function run(args) {
                if (writer.running)
                    return;
                writer.command = ["python3", "-I", shell.dir + "/cal.py"].concat(args);
                writer.running = true;
            }

            // adding / removing
            property bool adding: false
            property int entrySel: 0
            property bool confirm: false
            function startAdd() {
                if (!shell.shown || closing || adding)
                    return;
                confirm = false;
                adding = true;
                input.text = "";
                input.forceActiveFocus();
            }
            function endAdd(save) {
                const text = input.text.trim();
                if (save && text !== "")
                    run(["add", selY + "-" + pad(selM + 1) + "-" + pad(selD), text]);
                adding = false;
                input.text = "";
                root.forceActiveFocus();
            }
            function remove() {
                if (!shell.shown || closing || adding || !selEvents.length)
                    return;
                if (!confirm) {
                    confirm = true;
                    return;
                }
                const e = selEvents[Math.min(entrySel, selEvents.length - 1)];
                run(["del", String(e.line), e.text]);
                confirm = false;
                entrySel = 0;
            }
            function openFile() {
                if (!file)
                    return;
                Quickshell.execDetached(["sh", "-c", 'python3 -I "$2" touch >/dev/null; exec kitty --class p3-calendar-file -e "${EDITOR:-micro}" "$1"',
                    "sh", file, shell.dir + "/cal.py"]);
                close();
            }

            Keys.onPressed: e => {
                if (adding)
                    return;
                const k = e.key;
                if (k === Qt.Key_Left || k === Qt.Key_H) step(-1);
                else if (k === Qt.Key_Right || k === Qt.Key_L) step(1);
                else if (k === Qt.Key_Up || k === Qt.Key_K) step(-7);
                else if (k === Qt.Key_Down || k === Qt.Key_J) step(7);
                else if (k === Qt.Key_Q || k === Qt.Key_PageUp || k === Qt.Key_BracketLeft) stepMonth(-1);
                else if (k === Qt.Key_E || k === Qt.Key_PageDown || k === Qt.Key_BracketRight) stepMonth(1);
                else if (k === Qt.Key_T || k === Qt.Key_Home) goToday();
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_A) startAdd();
                else if (k === Qt.Key_Delete || k === Qt.Key_Backspace || k === Qt.Key_X) remove();
                else if (k === Qt.Key_Tab) {
                    if (selEvents.length > 1) {
                        entrySel = (entrySel + 1) % selEvents.length;
                        confirm = false;
                    }
                } else if (k === Qt.Key_O) openFile();
                else if (k === Qt.Key_Escape) {
                    if (confirm)
                        confirm = false;
                    else
                        close();
                } else
                    return;
                e.accepted = true;
            }

            // ── open / close ─────────────────────────────────────────────
            function resetState() {
                closeAnim.stop();
                openAnim.stop();
                closing = false;
                adding = false;
                confirm = false;
                entrySel = 0;
                input.text = "";
                fill = 0; gridIn = 0; sideIn = 0;
            }
            function hideNow() {
                resetState();
                warming = false;
                shell.shown = false;
            }
            function hideOthers() {
                Quickshell.execDetached(["sh", "-c", "for m in p3status p3equip p3items p3skills p3links; do hyprctl dispatch \"hl.dsp.global(\\\"$m:hide\\\")\" >/dev/null; done"]);
            }
            function reopen() {
                hideOthers();
                resetState();
                // always open on today
                const now = new Date();
                selY = now.getFullYear(); selM = now.getMonth(); selD = now.getDate();
                mAnim = 1;
                root.forceActiveFocus();
                refresh();
                warmFrames = 0;
                warming = true;
            }
            Connections {
                target: shell
                function onShownChanged() { if (shell.shown) root.reopen(); }
            }
            // after a while hidden the first frame is slow (textures re-upload): let two
            // frames through, nearly invisible, before the intro starts
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
                if (adding)
                    endAdd(false);
                closing = true;
                closeAnim.start();
            }
            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: root; property: "fill"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 90 }
                    NumberAnimation { target: root; property: "gridIn"; from: 0; to: 1; duration: 520 }
                }
                SequentialAnimation {
                    PauseAnimation { duration: 160 }
                    NumberAnimation { target: root; property: "sideIn"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                }
            }
            SequentialAnimation {
                id: closeAnim
                ParallelAnimation {
                    NumberAnimation { target: root; property: "gridIn"; to: 0; duration: 170 }
                    NumberAnimation { target: root; property: "sideIn"; to: 0; duration: 170 }
                }
                NumberAnimation { target: root; property: "fill"; to: 0; duration: 200; easing.type: Easing.InCubic }
                ScriptAction { script: { root.closing = false; shell.shown = false; } }
            }
            function seg(p, a, b) { return Math.max(0, Math.min(1, (p - a) / (b - a))); }
            function eOut(t) { return 1 - Math.pow(1 - t, 3); }

            property real clock: 0
            // ambient motion follows the shared rule (Motion.qml)
            Motion { id: motion }
            FrameAnimation { running: shell.shown && motion.speed > 0; onTriggered: root.clock += frameTime * motion.speed }

            // ── everything, graded green in the Dark Hour ────────────────
            Item {
                id: scene
                anchors.fill: parent
                opacity: root.warming ? 0.004 : root.fill
                layer.enabled: dh.t > 0
                layer.effect: ShaderEffect {
                    property real dark: dh.t
                    fragmentShader: Qt.resolvedUrl("grade.frag.qsb")
                }

                // paper + water disc
                ShaderEffect {
                    anchors.fill: parent
                    property real time: root.clock
                    property real u: root.u
                    property real grow: root.fill
                    property size size: Qt.size(width, height)
                    fragmentShader: Qt.resolvedUrl("water.frag.qsb")
                }

                // pale glass shards drifting over the paper
                Repeater {
                    model: [
                        [1196, 470, 62, 3.6, 0.08], [1130, 536, 40, 1.4, 0.10], [1226, 566, 30, 5.2, 0.12],
                        [1160, 330, 28, 2.9, 0.06], [1238, 372, 20, 0.9, 0.08]
                    ]
                    Item {
                        id: shard
                        required property var modelData
                        readonly property real s: modelData[2] * root.u
                        x: (modelData[0] + 10 * Math.sin(root.clock * 0.21 + modelData[3])) * root.u
                        y: (modelData[1] - 14 * Math.sin(root.clock * 0.16 + modelData[3] * 1.7)) * root.u
                        width: s
                        height: s
                        rotation: modelData[3] * 40 + 9 * Math.sin(root.clock * 0.13 + modelData[3])
                        opacity: root.sideIn
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: -1
                                fillColor: Qt.alpha("#3f9bf2", shard.modelData[4])
                                PathPolyline {
                                    path: [Qt.point(0, shard.s * 0.3), Qt.point(shard.s * 0.62, 0), Qt.point(shard.s, shard.s * 0.55),
                                        Qt.point(shard.s * 0.38, shard.s), Qt.point(0, shard.s * 0.3)]
                                }
                            }
                        }
                    }
                }

                // ── left: the month ──────────────────────────────────────
                Item {
                    id: monthSide
                    anchors.fill: parent

                    // giant month number: a background figure cut off by the top edge; the
                    // weekday names and key hints sit on top of it (centred by its ink)
                    TextMetrics { id: bigM; font: bigMonth.font; text: bigMonth.text }
                    Text {
                        id: bigMonth
                        x: 458 * root.u - (bigM.tightBoundingRect.x + bigM.tightBoundingRect.width / 2)
                            + (1 - root.mAnim) * 26 * root.mDir * root.u
                        y: 233 * root.u - baselineOffset
                        text: root.selM + 1
                        font.family: root.face
                        // two-digit months are set narrower so they stay between the side months
                        font.variableAxes: root.ax(900, root.selM >= 9 ? 74 : 125)
                        font.pixelSize: 340 * root.u
                        color: "#0b1259"
                        opacity: root.seg(root.gridIn, 0, 0.5) * (0.35 + 0.65 * root.mAnim)
                    }

                    // title + year
                    Text {
                        id: title
                        x: 6 * root.u
                        y: 44 * root.u - baselineOffset
                        text: "CALENDAR"
                        font.family: root.face
                        font.variableAxes: root.ax(900)
                        font.italic: true
                        font.pixelSize: 52 * root.u
                        color: root.white
                        opacity: root.gridIn
                    }
                    Text {
                        x: title.x + title.width - width - 2 * root.u
                        y: 54 * root.u
                        text: String(root.selY).split("").join(" ")
                        font.family: root.face
                        font.variableAxes: root.ax(700)
                        font.italic: true
                        font.pixelSize: 15 * root.u
                        color: root.white
                        opacity: root.gridIn
                    }

                    // the months either side, standing on the same line as the key hints
                    Repeater {
                        model: [-1, 1]
                        Text {
                            required property int modelData
                            readonly property int m: (root.selM + 12 + modelData) % 12 + 1
                            // hugging the key hint: the left one ends at 132, the right one starts at 622
                            x: modelData < 0 ? 132 * root.u - width : 622 * root.u
                            y: 190 * root.u - baselineOffset
                            text: m
                            font.family: root.face
                            font.variableAxes: root.ax(900, m >= 10 ? 80 : 125)
                            font.italic: true
                            font.pixelSize: 104 * root.u
                            color: "#0b1259"
                            opacity: root.gridIn
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.stepMonth(parent.modelData) }
                        }
                    }
                    // key hints: ◂ Q   E ▸  (red arrowheads with a white edge)
                    Repeater {
                        model: [-1, 1]
                        Row {
                            id: hint
                            required property int modelData
                            x: (modelData < 0 ? 172 : 582) * root.u - width / 2
                            y: 132 * root.u
                            spacing: 6 * root.u
                            layoutDirection: modelData < 0 ? Qt.LeftToRight : Qt.RightToLeft
                            opacity: root.gridIn
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 15 * root.u
                                height: 22 * root.u
                                Shape {
                                    anchors.fill: parent
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        fillColor: root.red
                                        strokeColor: root.white
                                        strokeWidth: 2 * root.u
                                        joinStyle: ShapePath.RoundJoin
                                        PathPolyline {
                                            path: hint.modelData < 0
                                                ? [Qt.point(14 * root.u, 2 * root.u), Qt.point(2 * root.u, 11 * root.u), Qt.point(14 * root.u, 20 * root.u), Qt.point(14 * root.u, 2 * root.u)]
                                                : [Qt.point(1 * root.u, 2 * root.u), Qt.point(13 * root.u, 11 * root.u), Qt.point(1 * root.u, 20 * root.u), Qt.point(1 * root.u, 2 * root.u)]
                                        }
                                    }
                                }
                            }
                            Text {
                                text: hint.modelData < 0 ? "Q" : "E"
                                font.family: root.face
                                font.variableAxes: root.ax(900)
                                font.italic: true
                                font.pixelSize: 46 * root.u
                                color: root.white
                                style: Text.Outline
                                styleColor: "#0b1259"
                            }
                        }
                    }

                    // weekday names
                    Repeater {
                        model: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
                        Text {
                            required property string modelData
                            required property int index
                            x: (118 + 73 * index) * root.u + (root.colW - width) / 2
                            y: 205 * root.u - height / 2
                            text: modelData
                            font.family: root.face
                            font.variableAxes: root.ax(800)
                            font.pixelSize: 16 * root.u
                            color: index === 0 ? root.red : index === 6 ? root.cyan : root.white
                            opacity: root.gridIn
                        }
                    }

                    // the days
                    Item {
                        id: grid
                        x: 118 * root.u + (1 - root.mAnim) * 44 * root.mDir * root.u
                        y: 222 * root.u
                        width: root.colW * 7
                        height: root.rowH * root.rows
                        opacity: root.mAnim

                        // selection cursor: one flat, lopsided triangle behind the day's number,
                        // gliding from day to day (Tri.qml)
                        Tri {
                            id: cursor
                            readonly property int cell: root.firstDow + root.selD - 1
                            u: root.u
                            c: root.mark
                            x: (cell % 7 + 0.5) * root.colW
                            y: (Math.floor(cell / 7) + 0.5) * root.rowH
                            opacity: root.gridIn
                            Behavior on x { enabled: root.mAnim === 1; NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: root.mAnim === 1; NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        }

                        Repeater {
                            model: 42
                            Item {
                                id: cell
                                required property int index
                                readonly property int day: index - root.firstDow + 1
                                readonly property bool real_: day >= 1 && day <= root.daysInMonth
                                readonly property int dow: index % 7
                                readonly property bool picked: real_ && day === root.selD
                                readonly property bool today: real_ && day === root.tD && root.selM === root.tM && root.selY === root.tY
                                readonly property string moon: real_ ? root.moonMark(root.selY, root.selM, day) : ""
                                readonly property int plans: real_ ? root.eventsOn(root.selY, root.selM, day).length : 0
                                // each day drops in a touch after the one before it
                                readonly property real appear: root.eOut(root.seg(root.gridIn, 0.012 * index, 0.012 * index + 0.5))

                                visible: real_
                                x: dow * root.colW
                                y: Math.floor(index / 7) * root.rowH - (1 - appear) * 12 * root.u
                                width: root.colW
                                height: root.rowH
                                opacity: appear

                                // moon: gold disc = full, ring = new, half disc = quarter
                                Rectangle {
                                    visible: cell.moon !== ""
                                    anchors.centerIn: parent
                                    width: Math.min(56 * root.u, root.rowH - 8 * root.u)
                                    height: width
                                    radius: width / 2
                                    color: cell.moon === "full" ? root.gold : cell.moon === "new" ? "transparent" : Qt.alpha(root.white, 0.14)
                                    border.width: 1.5 * root.u
                                    border.color: cell.moon === "full" || cell.moon === "new" ? Qt.lighter(root.gold, 1.25) : Qt.alpha(root.white, 0.55)
                                    Item {
                                        visible: cell.moon === "first" || cell.moon === "last"
                                        x: cell.moon === "first" ? parent.width / 2 : 0
                                        width: parent.width / 2
                                        height: parent.height
                                        clip: true
                                        Rectangle {
                                            x: cell.moon === "first" ? -parent.width : 0
                                            width: parent.width * 2
                                            height: parent.height
                                            radius: width / 2
                                            color: Qt.alpha(root.white, 0.3)
                                        }
                                    }
                                }

                                // today: a small label over the day (the red triangle is the cursor)
                                Text {
                                    visible: cell.today
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: parent.height / 2 - 36 * root.u
                                    text: "TODAY"
                                    font.family: root.face
                                    font.variableAxes: root.ax(900)
                                    font.pixelSize: 9.5 * root.u
                                    font.letterSpacing: 0.6 * root.u
                                    color: root.white
                                }

                                // the number, centred on its ink (italic figures of different
                                // widths look off-centre when centred by their advance box)
                                TextMetrics { id: numM; font: num.font; text: num.text }
                                Text {
                                    id: num
                                    x: cell.width / 2 - (numM.tightBoundingRect.x + numM.tightBoundingRect.width / 2)
                                    y: cell.height / 2 - (baselineOffset - root.digitH / 2)
                                    text: cell.day
                                    font.family: root.face
                                    font.variableAxes: root.ax(cell.picked ? 600 : cell.today ? 700 : 400)
                                    font.italic: true
                                    font.pixelSize: 30 * root.u
                                    color: cell.picked ? "#0a0c18" : cell.moon === "full" ? root.white : cell.dow === 0 ? root.red : cell.dow === 6 ? root.cyan : root.white
                                }

                                // plans: up to three dots under the number
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: parent.height / 2 + 19 * root.u
                                    spacing: 3 * root.u
                                    Repeater {
                                        model: Math.min(3, cell.plans)
                                        Rectangle {
                                            width: 6 * root.u
                                            height: width
                                            radius: width / 2
                                            color: "#ffe23a"
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: cell.real_ && !root.adding
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setSel(root.selY, root.selM, cell.day)
                                }
                            }
                        }
                    }
                }

                // ── right: what's coming, and the selected day ───────────
                Item {
                    id: side
                    anchors.fill: parent
                    opacity: root.sideIn
                    transform: Translate { x: (1 - root.sideIn) * 60 * root.u }

                    Text {
                        x: plansWord.x - width - 8 * root.u
                        y: 40 * root.u
                        text: "Coming"
                        font.family: root.face
                        font.variableAxes: root.ax(900)
                        font.pixelSize: 15 * root.u
                        color: root.ink
                    }
                    Text {
                        id: plansWord
                        x: 1010 * root.u
                        y: 80 * root.u - baselineOffset
                        text: "PLANS"
                        font.family: root.face
                        font.variableAxes: root.ax(900, 100)
                        font.pixelSize: 77 * root.u
                        color: "#0b1259"
                    }

                    // the next plans: slate cards with a countdown
                    Column {
                        x: 932 * root.u
                        y: 112 * root.u
                        spacing: 6 * root.u
                        Repeater {
                            model: root.upcoming.length ? root.upcoming : [null]
                            Rectangle {
                                id: card
                                required property var modelData
                                required property int index
                                width: 334 * root.u
                                height: 60 * root.u
                                color: root.slate
                                opacity: 1 - index * 0.14
                                Rectangle { width: 5 * root.u; height: parent.height; color: root.chip }
                                // countdown
                                Column {
                                    visible: card.modelData !== null
                                    x: 14 * root.u
                                    width: 62 * root.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: -5 * root.u
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: card.modelData ? (card.modelData.days === 0 ? "NOW" : card.modelData.days) : ""
                                        font.family: root.face
                                        font.variableAxes: root.ax(900, 104)
                                        font.italic: true
                                        font.pixelSize: (card.modelData && card.modelData.days === 0 ? 20 : 28) * root.u
                                        color: card.modelData && card.modelData.days <= 2 ? "#ffe23a" : root.white
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: card.modelData && card.modelData.days > 0
                                        text: card.modelData && card.modelData.days === 1 ? "day" : "days"
                                        font.family: root.face
                                        font.variableAxes: root.ax(700, 104)
                                        font.pixelSize: 10 * root.u
                                        color: Qt.alpha(root.white, 0.75)
                                    }
                                }
                                Text {
                                    x: (card.modelData ? 88 : 20) * root.u
                                    y: 7 * root.u
                                    width: 322 * root.u - x
                                    elide: Text.ElideRight
                                    text: card.modelData ? card.modelData.text : "Nothing planned"
                                    font.family: root.face
                                    font.variableAxes: root.ax(600, 104)
                                    font.pixelSize: 18 * root.u
                                    color: root.white
                                }
                                Rectangle {
                                    visible: card.modelData !== null
                                    x: 88 * root.u
                                    y: 35 * root.u
                                    width: when.implicitWidth + 12 * root.u
                                    height: 17 * root.u
                                    color: root.white
                                    Text {
                                        id: when
                                        anchors.centerIn: parent
                                        text: card.modelData ? card.modelData.label : ""
                                        font.family: root.face
                                        font.variableAxes: root.ax(700, 104)
                                        font.pixelSize: 11.5 * root.u
                                        color: root.ink
                                    }
                                }
                                Text {
                                    visible: card.modelData === null
                                    x: 20 * root.u
                                    y: 34 * root.u
                                    text: "Pick a day and press ↵ to add one"
                                    font.family: root.face
                                    font.variableAxes: root.ax(500, 104)
                                    font.pixelSize: 12 * root.u
                                    color: Qt.alpha(root.white, 0.7)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: card.modelData !== null && !root.adding
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setSel(card.modelData.y, card.modelData.m, card.modelData.d)
                                }
                            }
                        }
                    }

                    // the selected day
                    Rectangle {
                        id: dayChip
                        // starts on the water and runs out onto the paper
                        x: 786 * root.u
                        y: 395 * root.u
                        width: 178 * root.u
                        height: 30 * root.u
                        color: root.chip
                        Text {
                            anchors.centerIn: parent
                            text: root.dayLabel(root.selY, root.selM, root.selD)
                            font.family: root.serif
                            font.weight: Font.Bold
                            font.pixelSize: 18 * root.u
                            color: root.ink
                        }
                    }
                    Text {
                        x: dayChip.x + dayChip.width + 14 * root.u
                        anchors.verticalCenter: dayChip.verticalCenter
                        text: root.relative(root.selAway)
                        font.family: root.serif
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 16 * root.u
                        color: root.selAway === 0 ? "#d6249f" : root.grey
                    }

                    Column {
                        x: 836 * root.u
                        y: 442 * root.u
                        spacing: 7 * root.u

                        // moon line
                        Text {
                            visible: root.selMoon !== ""
                            text: "☾  " + (root.moonNames[root.selMoon] ?? "")
                            font.family: root.serif
                            font.weight: Font.Bold
                            font.pixelSize: 19 * root.u
                            color: "#9a7400"
                        }
                        Repeater {
                            model: root.selEvents
                            Text {
                                required property var modelData
                                required property int index
                                readonly property bool picked: index === Math.min(root.entrySel, root.selEvents.length - 1)
                                    && (root.selEvents.length > 1 || root.confirm)
                                width: 320 * root.u
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                text: "•  " + modelData.text + (modelData.date.startsWith("*") ? "  ↻" : "")
                                font.family: root.serif
                                font.weight: Font.Bold
                                font.pixelSize: 19 * root.u
                                color: picked && root.confirm ? root.red : picked ? root.ink : "#4a5260"
                            }
                        }
                        Text {
                            visible: root.selEvents.length === 0 && root.selMoon === "" && !root.adding
                            text: "•  Nothing in particular"
                            font.family: root.serif
                            font.weight: Font.Bold
                            font.pixelSize: 19 * root.u
                            color: "#a3abb6"
                        }

                        // new plan
                        Item {
                            visible: root.adding
                            width: 320 * root.u
                            height: 34 * root.u
                            Text {
                                id: bullet
                                anchors.verticalCenter: parent.verticalCenter
                                text: "•  "
                                font.family: root.serif
                                font.weight: Font.Bold
                                font.pixelSize: 19 * root.u
                                color: root.navy
                            }
                            TextInput {
                                id: input
                                anchors.left: bullet.right
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                maximumLength: 80
                                font.family: root.serif
                                font.weight: Font.Bold
                                font.pixelSize: 19 * root.u
                                color: root.navy
                                selectionColor: root.chip
                                selectedTextColor: root.ink
                                onAccepted: root.endAdd(true)
                                Keys.onEscapePressed: root.endAdd(false)
                                Text {
                                    visible: input.text === ""
                                    text: "New plan…"
                                    font: input.font
                                    color: "#a3abb6"
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 2 * root.u
                                color: root.navy
                            }
                        }
                    }

                    // days to the full moon, tucked under the day
                    Text {
                        readonly property int n: root.daysToFull(root.selY, root.selM, root.selD)
                        visible: n > 0
                        x: 836 * root.u
                        y: 590 * root.u
                        text: "Full moon " + (n === 1 ? "the next day" : n + " days later")
                        font.family: root.face
                        font.variableAxes: root.ax(600)
                        font.italic: true
                        font.pixelSize: 13 * root.u
                        color: "#8a93a0"
                    }

                    // guide line + keys
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 26 * root.u
                        y: 636 * root.u
                        width: 420 * root.u
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        text: root.adding ? "What's the plan for " + (root.selM + 1) + "/" + root.selD + "?"
                            : root.confirm ? "Press Del again to remove it"
                            : "Which day do you want to view?"
                        font.family: root.face
                        font.variableAxes: root.ax(900, 108)
                        font.italic: true
                        font.pixelSize: 19 * root.u
                        color: root.confirm ? root.red : root.navy
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 26 * root.u
                        y: 668 * root.u
                        spacing: 16 * root.u
                        Repeater {
                            model: root.adding ? [["↵", "Save"], ["Esc", "Cancel"]]
                                : root.confirm ? [["Del", "Remove"], ["Esc", "Keep"]]
                                : root.selEvents.length ? [["↵", "Add plan"], ["Del", "Remove"], ["T", "Today"], ["Esc", "Back"]]
                                : [["↵", "Add plan"], ["T", "Today"], ["O", "Open file"], ["Esc", "Back"]]
                            Row {
                                required property var modelData
                                spacing: 5 * root.u
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(22 * root.u, key.implicitWidth + 10 * root.u)
                                    height: 20 * root.u
                                    radius: 10 * root.u
                                    color: root.navy
                                    Text {
                                        id: key
                                        anchors.centerIn: parent
                                        text: modelData[0]
                                        font.family: root.face
                                        font.variableAxes: root.ax(700, 108)
                                        font.pixelSize: 11.5 * root.u
                                        color: root.white
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[1]
                                    font.family: root.face
                                    font.variableAxes: root.ax(700, 108)
                                    font.italic: true
                                    font.pixelSize: 15 * root.u
                                    color: root.ink
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
}
