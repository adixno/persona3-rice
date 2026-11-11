// p3-skills: MODES, as the Persona 3 SKILL screen.
// A mode is a bundle of p3-equip settings (modes.json, or ~/.config/p3-skills/modes.json).
// List of modes top-right with a COST box (SP; negative = restores); the party rows on the left
// are Battery / Heat / Focus / Noise, previewing now → after-cast; ↵ casts: Evoker-style
// flash + streaks, the mode name slams in, settings apply (skills.py → equip.py), menu closes.
// Backdrop art slot: ~/.local/share/persona-rice/media/p3/skills-bg.png (+ skills-mask.png).
//
// Resident like the other p3 menus; one menu at a time. Toggle: SUPER+K (global p3skills:toggle)
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
    property bool shown: Quickshell.env("P3_SKILLS_OPEN") === "1"

    function toggle(): void {
        if (!shell.shown)
            shell.shown = true;
        else if (content.item)
            content.item.close();
    }

    GlobalShortcut {
        appid: "p3skills"
        name: "toggle"
        description: "Toggle the p3 modes (SKILL) screen"
        onPressed: shell.toggle()
    }
    // another p3 menu opened: vanish at once
    GlobalShortcut {
        appid: "p3skills"
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
        target: "skills"
        function toggle(): void { shell.toggle(); }
        function open(): void { shell.shown = true; }
        function close(): void { if (content.item) content.item.close(); }
        // testing: move the selection / preview a cast without applying anything
        function move(d: int): void { if (content.item) content.item.move(d); }
        function rehearse(): void { if (content.item) content.item.cast(true); }
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
        WlrLayershell.namespace: "p3-skills"
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

            property var modes: []
            property var st: ({})
            property int sel: 0
            readonly property var cur: modes.length ? modes[Math.min(sel, modes.length - 1)] : null

            // ── settings model ───────────────────────────────────────────
            // current settings from p3-equip's state, and the same shape after a mode
            function nowSettings() {
                const t = st;
                return { profile: t.profile ?? "balanced", gamemode: !!t.gamemode, dnd: !!t.dnd, awake: !!t.awake,
                         brightness: t.brightness ?? 75, volume: t.volume ?? 50, muted: !!t.muted,
                         temperature: t.temperature ?? 6500, btOn: !!t.btOn };
            }
            function after(m) {
                const s = nowSettings();
                const set = m ? (m.set ?? {}) : {};
                for (const k in set) {
                    const v = String(set[k]);
                    switch (k) {
                    case "profile": s.profile = v; break;
                    case "gamemode": case "dnd": case "awake": s[k] = v === "on"; break;
                    case "brightness": s.brightness = parseInt(v); break;
                    case "volume": if (v === "mute") s.muted = true; else { s.muted = false; s.volume = parseInt(v); } break;
                    case "nightlight": s.temperature = v === "off" ? 6500 : v === "auto" ? 4200 : parseInt(v); break;
                    case "bluetooth": s.btOn = v !== "off"; break;
                    }
                }
                return s;
            }
            // four vitals, 0..100
            function vitals(s) {
                const pf = { "power-saver": 0, "balanced": 1, "performance": 2.5 }[s.profile] ?? 1;
                const heat = { "power-saver": 1, "balanced": 2, "performance": 4 }[s.profile] ?? 2;
                const drain = pf + s.brightness / 50 + (s.gamemode ? 0.5 : 0) + (s.btOn ? 0.3 : 0) + (s.awake ? 0.3 : 0);
                const c = v => Math.round(Math.max(0, Math.min(5, v)) * 20);
                return [
                    c(5 - drain),
                    c(heat + (s.gamemode ? 1 : 0)),
                    c((s.dnd ? 2.5 : 0) + (s.awake ? 1 : 0) + (s.gamemode ? 0.5 : 0) + (!s.muted && s.volume <= 30 ? 1 : 0)),
                    s.muted ? 0 : c(s.volume / 20)
                ];
            }
            readonly property var vNow: vitals(nowSettings())
            readonly property var vAfter: vitals(after(cur))
            readonly property int focusRow: {
                let best = 0, bd = -1;
                for (let i = 0; i < 4; i++) {
                    const d = Math.abs(vAfter[i] - vNow[i]);
                    if (d > bd) { bd = d; best = i; }
                }
                return best;
            }
            function isActive(m) {
                const s = nowSettings(), set = m.set ?? {};
                for (const k in set) {
                    const v = String(set[k]);
                    switch (k) {
                    case "profile": if (s.profile !== v) return false; break;
                    case "gamemode": case "dnd": case "awake": if (s[k] !== (v === "on")) return false; break;
                    case "brightness": if (Math.abs(s.brightness - parseInt(v)) > 3) return false; break;
                    case "volume": if (v === "mute" ? !s.muted : (s.muted || Math.abs(s.volume - parseInt(v)) > 3)) return false; break;
                    case "nightlight":
                        if (v === "off" ? s.temperature < 6000 : v === "auto" ? s.temperature !== 4200 : s.temperature !== parseInt(v)) return false;
                        break;
                    case "bluetooth": if ((v !== "off") !== s.btOn) return false; break;
                    }
                }
                return true;
            }
            function summary(m) {
                if (!m)
                    return "";
                const names = { profile: { "power-saver": "Power Saver", "balanced": "Balanced", "performance": "Performance" } };
                const parts = [];
                const set = m.set ?? {};
                for (const k in set) {
                    const v = String(set[k]);
                    switch (k) {
                    case "profile": parts.push(names.profile[v] ?? v); break;
                    case "gamemode": parts.push("Game Mode " + v); break;
                    case "dnd": parts.push(v === "on" ? "Do Not Disturb" : "Notifications on"); break;
                    case "awake": parts.push(v === "on" ? "Stay awake" : "Auto sleep"); break;
                    case "brightness": parts.push("Brightness " + v + "%"); break;
                    case "volume": parts.push(v === "mute" ? "Muted" : "Volume " + v + "%"); break;
                    case "nightlight": parts.push(v === "off" ? "Night light off" : v === "auto" ? "Night light on schedule" : "Night light " + v + "K"); break;
                    case "bluetooth": parts.push("Bluetooth " + (v === "off" ? "off" : "on")); break;
                    case "wifi": parts.push("Wi-Fi " + v); break;
                    }
                }
                return parts.join("  ·  ");
            }

            // ── data ─────────────────────────────────────────────────────
            Process {
                id: reader
                command: ["python3", shell.dir + "/skills.py", "list"]
                stdout: SplitParser {
                    onRead: line => {
                        try {
                            const d = JSON.parse(line);
                            root.modes = d.modes ?? [];
                            root.st = d.state ?? {};
                        } catch (e) {}
                    }
                }
            }
            function refresh() { if (!reader.running) reader.running = true; }

            // ── cast ─────────────────────────────────────────────────────
            property real castP: 0
            property bool casting: false
            property bool rehearsal: false
            property var castMode: null
            function cast(dry) {
                if (!cur || casting || !shell.shown || closing)
                    return;
                rehearsal = !!dry;
                castMode = cur;
                casting = true;
                castAnim.restart();
            }
            SequentialAnimation {
                id: castAnim
                NumberAnimation { target: root; property: "castP"; from: 0; to: 0.15; duration: 160 }
                ScriptAction {
                    script: {
                        if (!root.rehearsal)
                            Quickshell.execDetached(["python3", shell.dir + "/skills.py", "cast", root.castMode.id]);
                    }
                }
                NumberAnimation { target: root; property: "castP"; from: 0.15; to: 1; duration: 1050 }
                ScriptAction { script: root.close() }
            }
            function seg(p, a, b) { return Math.max(0, Math.min(1, (p - a) / (b - a))); }
            function eOut(t) { return 1 - Math.pow(1 - t, 3); }

            function move(d) {
                if (!shell.shown || closing || casting || !modes.length)
                    return;
                sel = (sel + d + modes.length) % modes.length;
            }

            Keys.onUpPressed: move(-1)
            Keys.onDownPressed: move(1)
            Keys.onTabPressed: move(1)
            Keys.onBacktabPressed: move(-1)
            Keys.onReturnPressed: cast(false)
            Keys.onEnterPressed: cast(false)
            Keys.onSpacePressed: cast(false)
            Keys.onEscapePressed: close()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_J) move(1);
                else if (e.key === Qt.Key_K) move(-1);
            }

            // ── open / close ─────────────────────────────────────────────
            function hideNow() {
                closeAnim.stop();
                openAnim.stop();
                castAnim.stop();
                warming = false;
                closing = false;
                casting = false;
                castP = 0;
                fill = 0; rowsIn = 0; listIn = 0;
                shell.shown = false;
            }
            function hideOthers() {
                Quickshell.execDetached(["sh", "-c", "for m in p3status p3equip p3items p3links; do hyprctl dispatch \"hl.dsp.global(\\\"$m:hide\\\")\" >/dev/null; done"]);
            }
            function reopen() {
                hideOthers();
                closeAnim.stop();
                openAnim.stop();
                castAnim.stop();
                closing = false;
                casting = false;
                castP = 0;
                fill = 0;
                rowsIn = 0;
                listIn = 0;
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
                ScriptAction { script: { root.casting = false; root.castP = 0; shell.shown = false; } }
            }

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
                // a tiny Evoker kick on cast
                transform: Translate {
                    x: root.casting ? Math.sin(root.castP * 90) * 5 * (1 - root.seg(root.castP, 0.12, 0.4)) * root.u : 0
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1238d6" }
                        GradientStop { position: 1.0; color: "#06115e" }
                    }
                }
                Image {
                    id: bgImg
                    anchors.fill: parent
                    source: "file://" + shell.media + "/skills-bg.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    mipmap: true
                    visible: maskImg.status !== Image.Ready
                }
                Image {
                    id: maskImg
                    anchors.fill: parent
                    source: "file://" + shell.media + "/skills-mask.png"
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

                // light streaks crossing the frame (as in the reference), drifting slowly
                Repeater {
                    model: [[700, 0.8, 0.0], [930, 1.4, 1.7], [1120, 0.6, 3.1]]
                    Rectangle {
                        required property var modelData
                        x: (modelData[0] + 18 * Math.sin(root.clock * 0.25 + modelData[2])) * root.u
                        y: -120 * root.u
                        width: modelData[1] * root.u
                        height: 980 * root.u
                        rotation: 31
                        transformOrigin: Item.Top
                        antialiasing: true
                        color: "#ffffff"
                        opacity: 0.35 + 0.25 * Math.sin(root.clock * 0.9 + modelData[2])
                    }
                }
                // shards
                Repeater {
                    model: [
                        [560, 210, 14, "#ff4fd8", 8, 0.0], [700, 330, 10, "#ff8fb0", 7, 1.3], [840, 520, 12, "#ffffff", 9, 2.6],
                        [430, 160, 15, "#c04bff", 6, 0.7], [960, 640, 9, "#ff4fd8", 10, 3.4], [1100, 420, 13, "#5fe3ff", 7, 4.1],
                        [620, 600, 9, "#ff8fb0", 8, 5.0]
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

            // ── party rows: Battery / Heat / Focus / Noise (now → after cast) ─
            Item {
                id: partyList
                y: 312 * root.u
                readonly property var defs: [
                    { name: "Battery", col: "#3dff8a", icon: "battery_full" },
                    { name: "Heat", col: "#ff3d5a", icon: "local_fire_department" },
                    { name: "Focus", col: "#b06bff", icon: "center_focus_strong" },
                    { name: "Noise", col: "#ffd23f", icon: "graphic_eq" }
                ]
                Repeater {
                    model: 4
                    Item {
                        id: row
                        required property int index
                        readonly property var d: partyList.defs[index]
                        readonly property bool on: root.focusRow === index
                        readonly property real h: 54 * root.u
                        readonly property real w: (on ? 584 : 562) * root.u
                        readonly property real enter: Math.max(0, Math.min(1, root.rowsIn * 3 - index * 0.5))
                        property real shift: on ? 18 * root.u : 0
                        Behavior on shift { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        readonly property int now: root.vNow[index]
                        readonly property int next: root.vAfter[index]
                        // during a cast the NOW numbers roll over to the new values
                        readonly property real roll: root.casting ? root.eOut(root.seg(root.castP, 0.3, 0.75)) : 0
                        readonly property real shownNow: now + (next - now) * roll
                        y: index * 61 * root.u
                        x: -(1 - enter) * (1 - enter) * 640 * root.u
                        width: w
                        height: h
                        z: on ? 10 : 0

                        Shape {
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: row.on ? root.white : root.ink
                                strokeColor: row.on ? root.red : "transparent"
                                strokeWidth: row.on ? 2.5 * root.u : -1
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
                            horizontalAlignment: Text.AlignHCenter
                            text: row.d.name
                            font.family: "Jost"
                            font.weight: Font.Medium
                            font.pixelSize: 22 * root.u
                            color: row.on ? root.ink : root.white
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
                        // Lv = the change this mode makes (arrow + amount)
                        Text {
                            x: 306 * root.u + row.shift
                            anchors.baseline: lv.baseline
                            text: "Lv"
                            font.family: "Jost"
                            font.italic: true
                            font.pixelSize: 10 * root.u
                            color: row.on ? root.ink : root.white
                        }
                        Text {
                            id: lv
                            x: 320 * root.u + row.shift
                            y: row.h - height + 4 * root.u
                            text: Math.round(Math.abs(row.next - row.now) / 10) === 0 ? "=" : (row.next > row.now ? "▲" : "▼") + Math.round(Math.abs(row.next - row.now) / 10)
                            font.family: "Jost"
                            font.italic: true
                            font.pixelSize: 22 * root.u
                            color: row.next === row.now ? (row.on ? root.ink : root.white) : row.next > row.now ? (row.on ? "#0a8fb0" : root.hp) : root.red
                        }
                        Repeater {
                            model: [["NOW", row.shownNow, root.hp, 370], ["CAST", row.next, root.sp, 458]]
                            Item {
                                id: bar
                                required property var modelData
                                x: modelData[3] * root.u + row.shift
                                width: 80 * root.u
                                height: row.h
                                Text {
                                    anchors.baseline: num.baseline
                                    text: bar.modelData[0]
                                    font.family: root.face
                                    font.weight: Font.Bold
                                    font.italic: true
                                    font.pixelSize: 8 * root.u
                                    color: bar.modelData[2]
                                }
                                Text {
                                    id: num
                                    anchors.right: parent.right
                                    y: row.h - height - 2 * root.u
                                    text: String(Math.round(bar.modelData[1])).padStart(3, "0")
                                    font.family: "Jost"
                                    font.weight: Font.Light
                                    font.italic: true
                                    font.pixelSize: 32 * root.u
                                    font.letterSpacing: -1 * root.u
                                    color: row.on ? root.ink : bar.modelData[2]
                                }
                                Shape {
                                    id: track
                                    y: row.h - 9 * root.u
                                    preferredRendererType: Shape.CurveRenderer
                                    readonly property real bw: bar.width
                                    readonly property real fw: Math.max(0, Math.min(1, bar.modelData[1] / 100)) * bw
                                    ShapePath {
                                        fillColor: row.on ? "#9aa3b5" : "#30343f"
                                        strokeWidth: -1
                                        PathPolyline { path: [Qt.point(3 * root.u, 0), Qt.point(track.bw, 0), Qt.point(track.bw - 3 * root.u, 5 * root.u), Qt.point(0, 5 * root.u), Qt.point(3 * root.u, 0)] }
                                    }
                                    ShapePath {
                                        fillColor: bar.modelData[2]
                                        strokeWidth: -1
                                        PathPolyline { path: [Qt.point(3 * root.u, 0), Qt.point(track.fw, 0), Qt.point(track.fw - 3 * root.u, 5 * root.u), Qt.point(0, 5 * root.u), Qt.point(3 * root.u, 0)] }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── COST box (top right) ─────────────────────────────────────
            Item {
                id: costBox
                x: 1110 * root.u
                y: 40 * root.u
                opacity: root.listIn
                transform: Translate { y: (1 - root.listIn) * -20 * root.u }
                readonly property int cost: root.cur ? (root.cur.cost ?? 0) : 0
                // the number drains to 0 as the cast fires
                readonly property real shownCost: root.casting ? cost * (1 - root.seg(root.castP, 0, 0.3)) : cost
                Text {
                    x: 6 * root.u
                    text: costBox.cost < 0 ? "REGEN" : "COST"
                    font.family: root.face
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 38 * root.u
                    color: root.white
                    style: Text.Outline
                    styleColor: root.ink
                }
                Rectangle {
                    x: 22 * root.u
                    y: 48 * root.u
                    width: 110 * root.u
                    height: 28 * root.u
                    radius: 3 * root.u
                    color: root.ink
                    Text {
                        anchors.right: spTag.left
                        anchors.rightMargin: 10 * root.u
                        anchors.verticalCenter: parent.verticalCenter
                        text: (costBox.cost < 0 ? "+" : "") + Math.round(Math.abs(costBox.shownCost))
                        font.family: "Jost"
                        font.italic: true
                        font.pixelSize: 24 * root.u
                        color: costBox.cost < 0 ? "#3dff8a" : root.sp
                    }
                    Shape {
                        id: spTag
                        anchors.right: parent.right
                        anchors.rightMargin: 4 * root.u
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30 * root.u
                        height: 18 * root.u
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: costBox.cost < 0 ? "#3dff8a" : root.sp
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(6 * root.u, 0), Qt.point(30 * root.u, 0), Qt.point(24 * root.u, 18 * root.u), Qt.point(0, 18 * root.u), Qt.point(6 * root.u, 0)] }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "SP"
                            font.family: root.face
                            font.weight: Font.Black
                            font.italic: true
                            font.pixelSize: 11 * root.u
                            color: root.ink
                        }
                    }
                }
            }

            // ── mode list ────────────────────────────────────────────────
            Item {
                id: list
                x: 770 * root.u
                y: 80 * root.u
                readonly property real pitch: 38 * root.u

                Item {
                    id: slab
                    y: root.sel * list.pitch
                    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    opacity: root.listIn
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: root.white
                            strokeColor: root.red
                            strokeWidth: 2 * root.u
                            joinStyle: ShapePath.MiterJoin
                            PathPolyline { path: [Qt.point(10 * root.u, 0), Qt.point(320 * root.u, 0), Qt.point(310 * root.u, 32 * root.u), Qt.point(0, 32 * root.u), Qt.point(10 * root.u, 0)] }
                        }
                    }
                    // cast pop
                    Rectangle {
                        x: 4 * root.u
                        width: 312 * root.u
                        height: 32 * root.u
                        color: root.cyan
                        opacity: root.casting ? 0.9 * (1 - root.seg(root.castP, 0, 0.35)) : 0
                    }
                }
                Repeater {
                    model: root.modes
                    Item {
                        id: mr
                        required property var modelData
                        required property int index
                        readonly property bool on: root.sel === index
                        readonly property bool active: root.isActive(modelData)
                        readonly property real enter: Math.max(0, Math.min(1, root.listIn * 3 - index * 0.25))
                        y: index * list.pitch
                        width: 330 * root.u
                        height: 32 * root.u
                        opacity: enter
                        transform: Translate { x: (1 - mr.enter) * 60 * root.u }
                        Item {
                            x: 16 * root.u
                            width: 64 * root.u
                            height: 24 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            Shape {
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    fillColor: root.ink
                                    strokeWidth: -1
                                    PathPolyline { path: [Qt.point(8 * root.u, 0), Qt.point(64 * root.u, 0), Qt.point(56 * root.u, 24 * root.u), Qt.point(0, 24 * root.u), Qt.point(8 * root.u, 0)] }
                                }
                                ShapePath {
                                    fillColor: Qt.alpha(mr.modelData.color ?? "#5ee6ff", 0.5)
                                    strokeWidth: -1
                                    PathPolyline { path: [Qt.point(40 * root.u, 0), Qt.point(50 * root.u, 0), Qt.point(24 * root.u, 24 * root.u), Qt.point(14 * root.u, 24 * root.u), Qt.point(40 * root.u, 0)] }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: mr.modelData.icon ?? "bolt"
                                font.family: root.icons
                                font.pixelSize: 18 * root.u
                                font.variableAxes: { "FILL": 1, "wght": 600 }
                                color: mr.modelData.color ?? root.cyan
                            }
                        }
                        Text {
                            x: 90 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            width: 160 * root.u
                            elide: Text.ElideRight
                            text: mr.modelData.name
                            font.family: "Jost"
                            font.weight: Font.Medium
                            font.pixelSize: 23 * root.u
                            color: mr.on ? root.ink : root.cyan
                            style: mr.on ? Text.Normal : Text.Raised
                            styleColor: Qt.alpha("#06115e", 0.8)
                        }
                        // ACTIVE tag on the mode your settings currently match
                        Rectangle {
                            visible: mr.active
                            x: 252 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            width: 54 * root.u
                            height: 16 * root.u
                            radius: height / 2
                            color: root.cyan
                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                font.family: root.face
                                font.weight: Font.Black
                                font.pixelSize: 9 * root.u
                                color: root.ink
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (!root.casting) root.sel = mr.index
                            onClicked: { root.sel = mr.index; root.cast(false); }
                        }
                    }
                }
            }

            // ── info ─────────────────────────────────────────────────────
            Item {
                x: 770 * root.u
                y: list.y + Math.max(6, root.modes.length) * list.pitch + 16 * root.u
                opacity: root.listIn
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
                Column {
                    x: 58 * root.u
                    y: -4 * root.u
                    spacing: 6 * root.u
                    Text {
                        width: 420 * root.u
                        wrapMode: Text.WordWrap
                        text: root.cur ? root.cur.desc ?? "" : ""
                        font.family: root.face
                        font.weight: Font.DemiBold
                        font.pixelSize: 17 * root.u
                        color: root.white
                        style: Text.Raised
                        styleColor: Qt.alpha("#06115e", 0.8)
                    }
                    Text {
                        width: 420 * root.u
                        wrapMode: Text.WordWrap
                        text: root.summary(root.cur)
                        font.family: root.face
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 12 * root.u
                        color: root.cyan
                        style: Text.Raised
                        styleColor: Qt.alpha("#06115e", 0.8)
                    }
                }
            }

            // ── cast FX: streak burst from the Evoker, white flash, the name slams in ─
            Item {
                anchors.fill: parent
                visible: root.casting
                z: 50
                // streaks fanning out from the gun
                Repeater {
                    model: [[-28, 0.0], [-12, 0.04], [6, 0.02], [22, 0.07], [38, 0.05], [-44, 0.09]]
                    Rectangle {
                        required property var modelData
                        readonly property real k: root.eOut(root.seg(root.castP, 0.1 + modelData[1], 0.42 + modelData[1]))
                        x: 735 * root.u
                        y: 120 * root.u
                        width: (2.5 + 3 * (1 - k)) * root.u
                        height: k * 1500 * root.u
                        rotation: 180 + 31 + modelData[0]
                        transformOrigin: Item.Top
                        antialiasing: true
                        color: "#ffffff"
                        opacity: (1 - root.seg(root.castP, 0.45 + modelData[1], 0.8)) * 0.95
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    color: "#ffffff"
                    opacity: 0.6 * Math.max(0, 1 - Math.abs(root.castP - 0.2) / 0.12)
                }
                // the mode name, slammed in across the middle
                Item {
                    readonly property real k: root.seg(root.castP, 0.22, 0.38)
                    x: 300 * root.u
                    y: 220 * root.u
                    rotation: -9
                    opacity: Math.min(1, k * 2) * (1 - root.seg(root.castP, 0.85, 1))
                    scale: 1.5 - 0.5 * root.eOut(k)
                    transformOrigin: Item.Left
                    Text {
                        x: 7 * root.u
                        y: 7 * root.u
                        text: root.castMode ? root.castMode.name : ""
                        font.family: root.face
                        font.weight: Font.Black
                        font.italic: true
                        font.pixelSize: 104 * root.u
                        color: root.castMode ? root.castMode.color ?? root.cyan : root.cyan
                    }
                    Text {
                        text: root.castMode ? root.castMode.name : ""
                        font.family: root.face
                        font.weight: Font.Black
                        font.italic: true
                        font.pixelSize: 104 * root.u
                        color: root.white
                        style: Text.Outline
                        styleColor: root.ink
                    }
                    Text {
                        y: 118 * root.u
                        x: 20 * root.u
                        text: root.rehearsal ? "REHEARSAL" : "MODE CAST"
                        font.family: root.face
                        font.weight: Font.Black
                        font.italic: true
                        font.pixelSize: 26 * root.u
                        font.letterSpacing: 8 * root.u
                        color: root.red
                        style: Text.Outline
                        styleColor: root.white
                    }
                }
            }

            // ── guide ────────────────────────────────────────────────────
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 36 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26 * root.u
                spacing: 4 * root.u
                opacity: root.listIn * (root.casting ? 0 : 1)
                Text {
                    anchors.right: parent.right
                    text: "Which mode do you want to cast?"
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
                        model: [["↵", "Cast"], ["↑↓", "Select"], ["Esc", "Back"]]
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
