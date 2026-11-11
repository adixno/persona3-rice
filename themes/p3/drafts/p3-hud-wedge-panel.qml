// p3-hud: top-right corner calendar for the Persona 3 theme.
// Blue panel hanging from the top-right (bottom edge runs diagonally down to the corner,
// left end fades into a pale haze), huge dark WEEKDAY/WEEKEND with lighter wave bands
// flowing across the whole panel (GPU shader, waves.frag), outlined date with the weekday in a red downward triangle, a cyan
// time-of-day phrase, the time as a yellow number, and today's real moon phase.
// Purely visual: the window is click-through. It fades out while the cursor is over the
// panel (position polled over Hyprland's socket by cursorpos.py, since a click-through window gets no hover events).
// Drawn in code.
//
// Launch: qs -c p3-hud -n -d   (persona-theme autostarts it while p3 is active)
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

ShellRoot {
    id: root

    Motion { id: motion }

    readonly property color deep: "#030a26"
    readonly property color white: "#ffffff"
    readonly property color cyan: "#2ff3ff"
    readonly property color red: "#ff2a3a"
    readonly property color gold: "#ffe600"
    readonly property string face: "Jost"

    // global cursor position, polled ~8 times a second (4 on battery) by one long-running
    // helper that talks to Hyprland's socket directly and only prints when it changes
    property point cursor: Qt.point(-1, -1)
    Process {
        id: cursorProc
        running: true
        command: ["python3", "-I", Qt.resolvedUrl("cursorpos.py").toString().replace("file://", ""), UPower.onBattery ? "0.25" : "0.12"]
        onCommandChanged: { running = false; running = true; }
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(",");
                if (p.length === 2)
                    root.cursor = Qt.point(parseFloat(p[0]), parseFloat(p[1]));
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function dayPart(h: int): string {
        return h < 5 ? "Late Night" : h < 7 ? "Early Morning" : h < 11 ? "Morning" : h < 14 ? "Daytime"
            : h < 18 ? "Afternoon" : h < 21 ? "Evening" : "Night";
    }
    // moon age as a fraction of the synodic month: 0 new, 0.5 full
    function moonPhase(d: date): real {
        const ref = Date.UTC(2000, 0, 6, 18, 14) / 86400000;
        const p = ((d.getTime() / 86400000 - ref) % 29.530588853) / 29.530588853;
        return p < 0 ? p + 1 : p;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; right: true }
            implicitWidth: 440
            implicitHeight: 118
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // Overlay layer so Caelestia's frame (Top layer) can never end up above it,
            // whatever order things start in; hidden while a fullscreen window is focused
            // Top, not Overlay: above the bar and windows, below the p3 menus (status / equip / items)
            WlrLayershell.layer: WlrLayer.Top
            visible: !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            WlrLayershell.namespace: "p3-hud"
            mask: Region {}   // click-through: input goes to whatever is underneath

            // cursor in this window's coordinates; over the panel = above its slanted bottom edge
            readonly property real cx: root.cursor.x - (modelData.x + modelData.width - implicitWidth)
            readonly property real cy: root.cursor.y - modelData.y
            readonly property bool hovered: cx >= 0 && cx <= implicitWidth && cy >= 0 && cy <= cal.bottomAt(cx)

            Item {
                id: cal
                anchors.fill: parent
                opacity: win.hovered ? 0.12 : 1
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                readonly property real pw: width
                readonly property real ph: height
                readonly property bool weekend: clock.date.getDay() === 0 || clock.date.getDay() === 6
                // bottom edge: from (0, leftY) down to the bottom-right corner
                readonly property real leftY: ph * 0.5
                function bottomAt(x: real): real {
                    return leftY + (ph - leftY) * x / pw;
                }

                // the panel
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: cal.pw; y2: 0
                            GradientStop { position: 0.0; color: Qt.alpha("#dfe9ff", 0.0) }
                            GradientStop { position: 0.12; color: Qt.alpha("#8fb0ff", 0.55) }
                            GradientStop { position: 0.3; color: "#1830f0" }
                            GradientStop { position: 1.0; color: "#0a1ee0" }
                        }
                        PathPolyline { path: [Qt.point(0, 0), Qt.point(cal.pw, 0), Qt.point(cal.pw, cal.ph), Qt.point(0, cal.leftY), Qt.point(0, 0)] }
                    }
                }

                // ghost word: huge, upright, darker than the panel
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    y: -14
                    text: cal.weekend ? "WEEKEND" : "WEEKDAY"
                    font.family: root.face
                    font.weight: Font.Black
                    font.pixelSize: 78
                    font.letterSpacing: -1
                    color: Qt.alpha("#06128f", 0.55)
                }

                // lighter wave bands flowing across the whole panel, over the ghost word.
                // GPU shader (waves.frag). Animates at 30 fps only on AC power and while the
                // calendar is visible: each frame redraws the whole window (~5% of a core at
                // 15 fps, measured), so on battery the waves hold still (~0.5%).
                ShaderEffect {
                    anchors.fill: parent
                    property real phase: 0
                    property real leftY: cal.leftY
                    property size size: Qt.size(width, height)
                    fragmentShader: Qt.resolvedUrl("waves.frag.qsb")

                    Timer {
                        interval: 33
                        repeat: true
                        // one cycle every 9 s at full speed; eases to a stop with Motion
                        running: win.visible && motion.speed > 0
                        onTriggered: parent.phase = (parent.phase + Math.PI * 2 * interval / 9000 * motion.speed) % (Math.PI * 2)
                    }
                }

                // date: white, dark outline
                Text {
                    id: dateText
                    x: 104
                    // fits between its x and the time block (minus the weekday triangle); shrinks only if needed
                    width: timeCol.x - 10 - dayTri.width - 2 - x
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 34
                    y: 12
                    text: Qt.formatDateTime(clock.date, "M/d")
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 50
                    font.letterSpacing: -1
                    color: root.white
                    style: Text.Outline
                    styleColor: Qt.alpha(root.deep, 0.7)
                }

                // weekday in a red downward-pointing triangle
                Item {
                    id: dayTri
                    x: dateText.x + dateText.contentWidth + 2
                    y: 22
                    width: 44
                    height: 34
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: root.red
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(0, 0), Qt.point(dayTri.width, 0), Qt.point(dayTri.width / 2, dayTri.height), Qt.point(0, 0)] }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -1
                        text: Qt.formatDateTime(clock.date, "ddd")
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 17
                        color: root.white
                        style: Text.Outline
                        styleColor: Qt.alpha("#7a0010", 0.6)
                    }
                }

                // time-of-day phrase: cyan, dark outline, centred under the date
                Text {
                    x: dateText.x + dateText.contentWidth / 2 + 18 - width / 2
                    y: 66
                    text: root.dayPart(clock.date.getHours())
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 22
                    color: root.cyan
                    style: Text.Outline
                    styleColor: Qt.alpha(root.deep, 0.75)
                }

                // the time: spaced label over a big yellow number
                Column {
                    id: timeCol
                    // pinned left of the moon so wide dates (11/10, 12/28) never push it under it
                    anchors.right: moon.left
                    anchors.rightMargin: 10
                    y: 20
                    spacing: -4
                    Text {
                        text: "T I M E"
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 11
                        color: "#fff6c0"
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 30
                        color: root.gold
                        style: Text.Outline
                        styleColor: Qt.alpha(root.deep, 0.55)
                    }
                }

                // moon: today's real phase, gold lit side, dark face, gold ring
                Canvas {
                    id: moon
                    readonly property real phase: root.moonPhase(clock.date)
                    x: cal.pw - 64
                    y: 14
                    width: 56
                    height: 56
                    onPhaseChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cx = width / 2, cy = height / 2, r = width / 2 - 3;
                        const g = ctx.createLinearGradient(0, 0, width, 0);
                        g.addColorStop(0, "#1c1c26");
                        g.addColorStop(1, "#3a3a48");
                        ctx.fillStyle = g;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.fill();
                        const side = phase < 0.5 ? 1 : -1;            // waxing: lit on the right
                        const k = Math.cos(phase * 2 * Math.PI);      // terminator bulge
                        ctx.fillStyle = "#ffe600";
                        ctx.beginPath();
                        for (let i = 0; i <= 48; i++) {
                            const t = -Math.PI / 2 + Math.PI * i / 48;
                            ctx.lineTo(cx + side * r * Math.cos(t), cy + r * Math.sin(t));
                        }
                        for (let i = 48; i >= 0; i--) {
                            const t = -Math.PI / 2 + Math.PI * i / 48;
                            ctx.lineTo(cx + side * k * r * Math.cos(t), cy + r * Math.sin(t));
                        }
                        ctx.closePath();
                        ctx.fill();
                        ctx.strokeStyle = "#ffe600";
                        ctx.lineWidth = 3;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                }
            }
        }
    }
}
