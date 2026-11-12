// p3-hud: top-right corner calendar for the Persona 3 theme.
// No panel: it floats over the wallpaper. Huge, tall, stretched dark WEEKDAY/WEEKEND ghost word
// running off the top edge, two flat wavy blue layers over it (GPU shader, ribbon.frag), the date in big
// outlined figures with the weekday in a downward triangle (black on weekdays, red on
// weekends), a cyan time-of-day phrase (P3 style: After School, Daytime…), the time as a
// yellow number, and today's real moon phase. (Old wedge panel + waves.frag: drafts.)
// DARK HOUR (DarkHour.qml / darkhour.py: game mode, 00:00-00:59 or the Loadout switch): the
// whole thing blends to P3R's green twin: DARK HOUR ghost word, green waves with a lime crest,
// "Dark Hour" in mint, and LIMIT = days to the next full moon in place of TIME.
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
    DarkHour { id: dh }

    // Dark Hour brain (darkhour.py): decides when it's on (game mode, 00:00-00:59, or the
    // Loadout switch) and writes the state DarkHour.qml reads; it lives as long as this does
    Process {
        running: true
        command: ["python3", "-I", Qt.resolvedUrl("darkhour.py").toString().replace("file://", "")]
    }

    // days until the next full moon: P3's "LIMIT" countdown during the Dark Hour
    function daysToFull(d: date): int {
        const p = moonPhase(d);
        return Math.round(((0.5 - p + 1) % 1) * 29.530588853);
    }

    readonly property color deep: "#030a26"
    readonly property color white: "#ffffff"
    readonly property color cyan: "#2ff3ff"
    readonly property color red: "#ff2a3a"
    readonly property color gold: "#ffe600"
    readonly property string face: "Jost"
    // overall size: everything is laid out at 440x150 and scaled from the top-right corner.
    // persona-bar's hudWidth must be 440 * this
    readonly property real hudScale: 0.8

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

    // P3 time-of-day names: school days run Lunchtime / Afternoon / After School,
    // weekends are just Daytime
    function dayPart(h: int, weekend: bool): string {
        if (h < 5) return "Late Night";
        if (h < 7) return "Early Morning";
        if (weekend)
            return h < 11 ? "Morning" : h < 17 ? "Daytime" : h < 21 ? "Evening" : "Night";
        return h < 12 ? "Morning" : h < 13 ? "Lunchtime" : h < 15 ? "Afternoon" : h < 18 ? "After School"
            : h < 21 ? "Evening" : "Night";
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
            implicitWidth: Math.round(440 * root.hudScale)
            implicitHeight: Math.round(150 * root.hudScale)   // 118 of layout + room for the waves' fade-out (before scaling)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // Overlay layer so Caelestia's frame (Top layer) can never end up above it,
            // whatever order things start in; hidden while a fullscreen window is focused
            // Top, not Overlay: above the bar and windows, below the p3 menus (status / equip / items)
            WlrLayershell.layer: WlrLayer.Top
            visible: !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            WlrLayershell.namespace: "p3-hud"
            mask: Region {}   // click-through: input goes to whatever is underneath

            // cursor in this window's coordinates
            readonly property real cx: root.cursor.x - (modelData.x + modelData.width - implicitWidth)
            readonly property real cy: root.cursor.y - modelData.y
            readonly property bool hovered: cx >= 0 && cx <= implicitWidth && cy >= 0 && cy <= implicitHeight

            Item {
                id: cal
                anchors.top: parent.top
                anchors.right: parent.right
                width: 440
                height: 150
                scale: root.hudScale
                transformOrigin: Item.TopRight
                opacity: win.hovered ? 0.12 : 1
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                readonly property real pw: width
                readonly property real ph: height
                readonly property bool weekend: clock.date.getDay() === 0 || clock.date.getDay() === 6

                // ghost word: huge, stretched tall, cut off by the top edge (P3R style). Drawn
                // only as a mask: ribbon.frag colours it per zone (navy above the waves,
                // inverted to light azure inside the main band)
                Item {
                    id: ghostWrap
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    y: -52
                    transform: Scale { origin.y: 0; yScale: 1.7 }
                    opacity: 1 - dh.t
                    text: cal.weekend ? "WEEKEND" : "WEEKDAY"
                    font.family: root.face
                    font.weight: Font.Black
                    font.pixelSize: 80
                    font.letterSpacing: -2
                    color: "white"
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignRight
                    fontSizeMode: Text.HorizontalFit
                    y: -52
                    transform: Scale { origin.y: 0; yScale: 1.7 }
                    opacity: dh.t
                    text: "DARK HOUR"
                    font.family: root.face
                    font.weight: Font.Black
                    font.pixelSize: 80
                    font.letterSpacing: -3
                    color: "white"
                }
                }

                // ghost word + waves in one shader (ribbon.frag), so the waves invert the word.
                // GPU shader (waves.frag). Animates at 30 fps only on AC power and while the
                // calendar is visible: each frame redraws the whole window (~5% of a core at
                // 15 fps, measured), so on battery the waves hold still (~0.5%).
                ShaderEffect {
                    anchors.fill: parent
                    property real phase: 0
                    property size size: Qt.size(width, height)
                    property variant word: ghostWrap
                    property real dark: dh.t
                    fragmentShader: Qt.resolvedUrl("ribbon.frag.qsb")

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
                    y: 14
                    transform: Scale { origin.y: dateText.height; yScale: 1.14 }
                    text: Qt.formatDateTime(clock.date, "M/d")
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 50
                    font.letterSpacing: -1
                    color: "#ffffff"
                    style: Text.Raised
                    styleColor: Qt.alpha("#0a1a70", 0.35)
                }

                // weekday in a downward-pointing triangle (black on school days, red on weekends)
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
                            // black on school days, red on weekends (as in P3)
                            fillColor: cal.weekend ? root.red : "#070b24"
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
                        styleColor: cal.weekend ? Qt.alpha("#7a0010", 0.6) : Qt.alpha("#000000", 0.5)
                    }
                }

                // time-of-day phrase: cyan, dark outline, centred under the date
                Text {
                    // centred on the date's glyphs, tucked right under them
                    x: dateText.x + dateText.contentWidth / 2 - width / 2
                    y: 60
                    opacity: 1 - dh.t
                    text: root.dayPart(clock.date.getHours(), cal.weekend)
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 22
                    color: "#00ffff"
                    style: Text.Outline
                    styleColor: Qt.alpha("#0a1f6e", 0.85)
                }
                // Dark Hour: the phrase becomes "Dark Hour" in mint green
                Text {
                    x: dateText.x + dateText.contentWidth / 2 - width / 2
                    y: 60
                    opacity: dh.t
                    text: "Dark Hour"
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 22
                    color: dh.green
                    style: Text.Outline
                    styleColor: Qt.alpha("#06301a", 0.9)
                }

                // the time: spaced label over a big yellow number
                Column {
                    id: timeCol
                    // pinned left of the moon so wide dates (11/10, 12/28) never push it under it
                    anchors.right: moon.left
                    anchors.rightMargin: 10
                    y: 20
                    spacing: -4
                    opacity: 1 - dh.t
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

                // Dark Hour: TIME becomes LIMIT, the days left until the next full moon
                Column {
                    anchors.right: moon.left
                    anchors.rightMargin: 10
                    y: 20
                    spacing: -4
                    opacity: dh.t
                    Text {
                        text: "L I M I T"
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 11
                        color: "#f2fff4"
                    }
                    Text {
                        anchors.right: parent.right
                        text: String(root.daysToFull(clock.date))
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 34
                        color: root.gold
                        style: Text.Outline
                        styleColor: Qt.alpha("#06301a", 0.6)
                    }
                }

                // moon: today's real phase, drawn in black on a yellow disc (P3 style), darker rim shadow
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
                        // P3 style: the yellow disc is the blank, the moon itself is drawn in
                        // black on it (new moon = all yellow, full moon = all black)
                        ctx.fillStyle = "#f5e200";
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.fill();
                        const side = phase < 0.5 ? 1 : -1;            // waxing: lit on the right
                        const k = Math.cos(phase * 2 * Math.PI);      // terminator bulge
                        ctx.fillStyle = "#151826";
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
                        // edge shadow: a thin darker crescent hugging the rim (P3R moon)
                        ctx.strokeStyle = Qt.rgba(0.42, 0.37, 0.0, 0.85);
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r - 0.5, Math.PI * 0.55, Math.PI * 1.45);
                        ctx.stroke();
                    }
                }
            }
        }
    }
}
