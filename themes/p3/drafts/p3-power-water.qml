// p3-power: full-screen power menu for the Persona 3 theme.
// Opens with water pouring down the screen (wavy leading edge), the slot image dropping
// in through the surface with a splash, bubbles and surface light, then a tilted stack of
// heavy italic words. Everything is drawn here; the only outside files are the optional
// slots in ~/.local/share/persona-rice/media/p3/ (override with $P3_MEDIA):
//   power-bg.mp4       looping, muted background video (fades in once the water fills)
//   power-cutout.png   image that drops in through the surface
//
// Launch: qs -c p3-power -n -d     (the p3 bar's power button and SUPER+SHIFT+Escape do this)
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: shell

    readonly property string media: Quickshell.env("P3_MEDIA") || (Quickshell.env("HOME") + "/.local/share/persona-rice/media/p3")

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "p3-power"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            id: root

            anchors.fill: parent
            focus: true

            readonly property real u: height / 720
            readonly property color deep: "#030a26"
            readonly property color blue: "#1238d6"
            readonly property color cyan: "#3fd8ff"
            readonly property color ice: "#aaf2ff"
            readonly property color white: "#f2fbff"
            readonly property color red: "#ff1f3a"
            readonly property color pink: "#ff5fae"
            readonly property string face: "Montserrat"

            property real fill: 0        // water level, 0..1 of the height
            property real phase: 0       // wave phase
            property real imgDrop: 0     // 0 = above the screen, 1 = in place
            property real menuIn: 0      // stagger driver for the stack
            property bool closing: false
            property int sel: 0
            property int confirm: -1
            property date now: new Date()

            readonly property var items: [
                { label: "LOCK", hint: "Lock the screen", cmd: ["caelestia", "shell", "lock", "lock"], ask: false, size: 70, dx: 40 },
                { label: "LOG OUT", hint: "End this session", cmd: ["uwsm", "stop"], ask: true, size: 62, dx: 0 },
                { label: "SLEEP", hint: "Suspend", cmd: ["systemctl", "suspend"], ask: false, size: 66, dx: 70 },
                { label: "REBOOT", hint: "Restart the machine", cmd: ["systemctl", "reboot"], ask: true, size: 72, dx: 20 },
                { label: "SHUT DOWN", hint: "Power off", cmd: ["systemctl", "poweroff"], ask: true, size: 64, dx: 60 },
                { label: "BACK", hint: "Return to the desktop", cmd: [], ask: false, size: 40, dx: 150 }
            ]
            readonly property var shades: ["#aaf2ff", "#3fd8ff", "#2fb8ff", "#5fe6ff", "#2f8fff", "#2a74ff"]

            function activate(i) {
                const it = items[i];
                if (it.cmd.length === 0) {
                    close();
                    return;
                }
                if (it.ask && confirm !== i) {
                    confirm = i;
                    return;
                }
                close(it.cmd);
            }
            function move(d) {
                sel = (sel + d + items.length) % items.length;
                confirm = -1;
            }
            property var pending: []
            function close(cmd) {
                if (closing)
                    return;
                closing = true;
                pending = cmd || [];
                closeAnim.start();
            }

            Keys.onUpPressed: move(-1)
            Keys.onDownPressed: move(1)
            Keys.onTabPressed: move(1)
            Keys.onEscapePressed: confirm >= 0 ? (confirm = -1) : close()
            Keys.onReturnPressed: activate(sel)
            Keys.onEnterPressed: activate(sel)
            Keys.onSpacePressed: activate(sel)

            FrameAnimation {
                running: true
                onTriggered: root.phase += frameTime * 2.2
            }
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: root.now = new Date()
            }

            // ── timeline ────────────────────────────────────────────────────
            SequentialAnimation {
                id: openAnim
                running: true
                ParallelAnimation {
                    NumberAnimation { target: dim; property: "opacity"; to: 1; duration: 220 }
                    NumberAnimation { target: root; property: "fill"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 260 }
                        NumberAnimation { target: root; property: "imgDrop"; from: 0; to: 0.62; duration: 260; easing.type: Easing.InQuad }
                        ScriptAction { script: splash.fire(cut.x + cut.width * 0.42, 6 * root.u) }
                        NumberAnimation { target: root; property: "imgDrop"; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 620 }
                        NumberAnimation { target: root; property: "menuIn"; from: 0; to: 1; duration: 620; easing.type: Easing.Linear }
                    }
                }
            }
            SequentialAnimation {
                id: closeAnim
                NumberAnimation { target: root; property: "menuIn"; to: 0; duration: 220 }
                ParallelAnimation {
                    NumberAnimation { target: root; property: "imgDrop"; to: 0; duration: 300; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "fill"; to: 0; duration: 380; easing.type: Easing.InCubic }
                    NumberAnimation { target: dim; property: "opacity"; to: 0; duration: 380 }
                }
                ScriptAction {
                    script: {
                        if (root.pending.length)
                            Quickshell.execDetached(root.pending);
                        Qt.quit();
                    }
                }
            }

            Rectangle {
                id: dim
                anchors.fill: parent
                color: Qt.alpha("#000000", 0.35)
                opacity: 0
            }

            // ── water: pours down from the top with a wavy leading edge ─────
            Shape {
                id: water
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                function edge() {
                    const W = width, H = height, lvl = H * root.fill + 30 * root.u;
                    const amp = (14 + 26 * (1 - root.fill)) * root.u;
                    const pts = [Qt.point(0, 0), Qt.point(W, 0)];
                    const n = 48;
                    for (let i = n; i >= 0; i--) {
                        const x = W * i / n;
                        pts.push(Qt.point(x, lvl + amp * Math.sin(i * 0.55 + root.phase) + amp * 0.5 * Math.sin(i * 0.23 - root.phase * 1.7)));
                    }
                    pts.push(Qt.point(0, 0));
                    return pts;
                }

                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: water.height
                        GradientStop { position: 0.0; color: "#56e6ff" }
                        GradientStop { position: 0.18; color: "#2a9cff" }
                        GradientStop { position: 0.55; color: "#1450e6" }
                        GradientStop { position: 1.0; color: "#0a24a8" }
                    }
                    PathPolyline { path: water.edge() }
                }
            }

            // ── optional background video slot ──────────────────────────────
            MediaPlayer {
                id: player
                source: "file://" + shell.media + "/power-bg.mp4"
                loops: MediaPlayer.Infinite
                videoOutput: vid
                audioOutput: AudioOutput { muted: true }
                Component.onCompleted: play()
            }
            VideoOutput {
                id: vid
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                visible: player.hasVideo
                // fades in behind the menu once the water has poured down
                opacity: Math.max(0, root.fill * 1.6 - 0.6)
            }
            // keep the menu readable over a bright video
            Rectangle {
                anchors.fill: parent
                visible: player.hasVideo
                opacity: vid.opacity
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.45; color: Qt.alpha(root.deep, 0.15) }
                    GradientStop { position: 1.0; color: Qt.alpha(root.deep, 0.6) }
                }
            }

            // surface light: drifting pale patches near the top
            Item {
                anchors.fill: parent
                opacity: Math.max(0, root.fill * 1.4 - 0.4)
                Repeater {
                    model: 16
                    Rectangle {
                        required property int index
                        readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
                        readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12543.123) % 1
                        width: (60 + r1 * 180) * root.u
                        height: (10 + r2 * 22) * root.u
                        radius: height / 2
                        y: (4 + r2 * 120) * root.u
                        x: (r1 * 1.2 - 0.1) * root.width + 30 * root.u * Math.sin(root.phase * 0.35 + index)
                        rotation: -4 + r2 * 8
                        color: root.ice
                        opacity: 0.28 + 0.22 * Math.sin(root.phase * 0.8 + index * 1.3)
                    }
                }
            }

            // light shafts from the surface
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: (50 + index * 30) * root.u
                    height: root.height * 1.5
                    y: -root.height * 0.2
                    x: root.width * (0.42 + index * 0.14) + 30 * root.u * Math.sin(root.phase * 0.2 + index)
                    rotation: 16 + index * 4
                    opacity: 0.08 * root.fill
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.white }
                        GradientStop { position: 0.75; color: "transparent" }
                    }
                }
            }

            // ── slot image, faded into the water on its right side ──────────
            Item {
                id: cutWrap
                anchors.fill: parent
                visible: cut.status === Image.Ready

                Image {
                    id: cut
                    source: "file://" + shell.media + "/power-cutout.png"
                    asynchronous: true
                    height: root.height
                    width: root.width * 0.62
                    fillMode: Image.PreserveAspectCrop
                    horizontalAlignment: Image.AlignLeft
                    x: 0
                    y: -root.height * 1.05 * (1 - root.imgDrop)
                    visible: false
                }
                Rectangle {
                    id: fadeMask
                    width: cut.width
                    height: cut.height
                    visible: false
                    layer.enabled: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "white" }
                        GradientStop { position: 0.7; color: "white" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                MultiEffect {
                    source: cut
                    x: cut.x
                    y: cut.y
                    width: cut.width
                    height: cut.height
                    maskEnabled: true
                    maskSource: fadeMask
                    maskThresholdMin: 0.0
                    maskSpreadAtMin: 1.0
                }
            }

            // ── splash where the image breaks the surface ───────────────────
            Item {
                id: splash
                anchors.fill: parent

                function fire(cx, cy) {
                    for (let i = 0; i < drops.count; i++)
                        drops.itemAt(i).go(cx, cy);
                    for (let j = 0; j < rings.count; j++)
                        rings.itemAt(j).go(cx, cy);
                    flash.go(cx, cy);
                }

                Rectangle {
                    id: flash
                    width: 0
                    radius: width / 2
                    color: root.white
                    opacity: 0
                    function go(cx, cy) {
                        fx.cx = cx; fx.cy = cy;
                        fx.restart();
                    }
                    ParallelAnimation {
                        id: fx
                        property real cx
                        property real cy
                        NumberAnimation { target: flash; property: "width"; from: 0; to: 520 * root.u; duration: 420; easing.type: Easing.OutCubic }
                        NumberAnimation { target: flash; property: "opacity"; from: 0.75; to: 0; duration: 420 }
                    }
                    height: width * 0.32
                    x: fx.cx - width / 2
                    y: fx.cy - height / 2
                }

                Repeater {
                    id: rings
                    model: 3
                    Rectangle {
                        id: ring
                        required property int index
                        property real cx
                        property real cy
                        width: 0
                        height: width * 0.28
                        radius: height / 2
                        x: cx - width / 2
                        y: cy - height / 2
                        color: "transparent"
                        border.color: root.white
                        border.width: (5 - index) * root.u
                        opacity: 0
                        function go(x0, y0) {
                            cx = x0; cy = y0;
                            ra.restart();
                        }
                        SequentialAnimation {
                            id: ra
                            PauseAnimation { duration: ring.index * 110 }
                            ParallelAnimation {
                                NumberAnimation { target: ring; property: "width"; from: 40 * root.u; to: (380 + ring.index * 170) * root.u; duration: 900; easing.type: Easing.OutCubic }
                                NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 900; easing.type: Easing.InQuad }
                            }
                        }
                    }
                }

                // droplets and bubbles flung down and out from the entry point
                Repeater {
                    id: drops
                    model: 46
                    Rectangle {
                        id: dr
                        required property int index
                        readonly property bool bubble: index % 3 === 0
                        property real tx
                        property real ty
                        width: (bubble ? 10 + (index % 5) * 4 : 4 + (index % 4) * 3) * root.u
                        height: width
                        radius: width / 2
                        color: bubble ? "transparent" : root.white
                        border.color: root.white
                        border.width: bubble ? 2 * root.u : 0
                        opacity: 0
                        function go(cx, cy) {
                            const a = Math.PI * (0.05 + 0.9 * Math.random());       // downward fan
                            const dist = (120 + Math.random() * 380) * root.u;
                            x = cx; y = cy;
                            tx = cx + Math.cos(a) * dist * 1.4;
                            ty = cy + Math.sin(a) * dist;
                            da.restart();
                        }
                        ParallelAnimation {
                            id: da
                            NumberAnimation { target: dr; property: "x"; to: dr.tx; duration: 700 + dr.index * 9; easing.type: Easing.OutCubic }
                            SequentialAnimation {
                                NumberAnimation { target: dr; property: "y"; to: dr.ty; duration: 700 + dr.index * 9; easing.type: Easing.OutCubic }
                                // bubbles then drift back up
                                NumberAnimation { target: dr; property: "y"; to: dr.bubble ? dr.ty - 160 * root.u : dr.ty + 20 * root.u; duration: 1400; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation {
                                NumberAnimation { target: dr; property: "opacity"; from: 0; to: 0.95; duration: 80 }
                                NumberAnimation { target: dr; property: "opacity"; to: 0; duration: 1900 + dr.index * 12; easing.type: Easing.InQuad }
                            }
                        }
                    }
                }
            }

            // ambient bubbles rising
            Repeater {
                model: 22
                Rectangle {
                    id: bub
                    required property int index
                    readonly property real r: Math.abs(Math.sin(index * 91.7) * 4375.5) % 1
                    width: (5 + r * 14) * root.u
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.alpha(root.white, 0.7)
                    border.width: 1.5 * root.u
                    x: root.width * (0.08 + 0.9 * ((index * 0.137) % 1)) + 12 * root.u * Math.sin(root.phase * 0.9 + index)
                    opacity: root.fill * 0.8
                    property real t: r
                    y: root.height * (1.05 - t * 1.15)
                    NumberAnimation on t {
                        from: bub.r; to: bub.r + 1
                        duration: 5000 + bub.r * 6000
                        loops: Animation.Infinite
                    }
                    onTChanged: if (t > 1) t -= 1
                }
            }

            // ── big grey numeral + ghost word ───────────────────────────────
            Text {
                x: root.width * 0.5
                y: -root.height * 0.04
                rotation: -6
                text: Qt.formatDateTime(root.now, "h")
                font.family: root.face
                font.weight: Font.Black
                font.italic: true
                font.pixelSize: 540 * root.u
                color: "#8a93b0"
                opacity: 0.4 * root.menuIn
            }
            Text {
                x: root.width * 0.34
                y: root.height * 0.7
                rotation: -11
                text: "GOOD NIGHT"
                font.family: root.face
                font.weight: Font.Black
                font.italic: true
                font.pixelSize: 150 * root.u
                font.letterSpacing: -6 * root.u
                color: root.deep
                opacity: 0.32 * root.menuIn
            }

            // ── menu stack ──────────────────────────────────────────────────
            Item {
                id: stack
                x: root.width * 0.52
                y: 150 * root.u
                rotation: -11
                transformOrigin: Item.TopLeft

                Repeater {
                    model: root.items.length

                    Item {
                        id: it
                        required property int index
                        readonly property var d: root.items[index]
                        readonly property bool on: root.sel === index
                        readonly property bool asking: root.confirm === index
                        readonly property real fs: d.size * root.u
                        // staggered slide-in from the right
                        readonly property real enter: Math.max(0, Math.min(1, root.menuIn * (root.items.length + 2) / 2 - index * 0.5))
                        property real reveal: on ? 1 : 0
                        Behavior on reveal { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        x: d.dx * root.u + (1 - enter) * (1 - enter) * 700 * root.u
                        opacity: enter
                        y: {
                            let yy = 0;
                            for (let k = 0; k < index; k++)
                                yy += root.items[k].size * root.u * 0.92;
                            return yy;
                        }
                        width: label.implicitWidth
                        height: fs
                        z: on ? 10 : 0

                        Shape {
                            id: blade
                            visible: it.reveal > 0.01
                            preferredRendererType: Shape.CurveRenderer
                            readonly property real w: (label.implicitWidth + 90 * root.u) * it.reveal
                            readonly property real h: it.fs
                            ShapePath {
                                fillColor: root.pink
                                strokeWidth: -1
                                PathPolyline {
                                    path: [Qt.point(-100 * root.u, blade.h * 1.02), Qt.point(-40 * root.u + blade.w, -blade.h * 0.34),
                                           Qt.point(-26 * root.u + blade.w, blade.h * 0.86), Qt.point(-100 * root.u, blade.h * 1.02)]
                                }
                            }
                            ShapePath {
                                fillColor: root.white
                                strokeWidth: -1
                                PathPolyline {
                                    path: [Qt.point(-96 * root.u, blade.h * 0.98), Qt.point(-48 * root.u + blade.w, -blade.h * 0.26),
                                           Qt.point(-36 * root.u + blade.w, blade.h * 0.8), Qt.point(-96 * root.u, blade.h * 0.98)]
                                }
                            }
                        }
                        Text {
                            visible: it.on
                            x: 4 * root.u
                            y: 4 * root.u
                            text: label.text
                            font: label.font
                            color: "#000000"
                        }
                        Text {
                            id: label
                            text: it.asking ? "SURE?" : it.d.label
                            font.family: root.face
                            font.weight: Font.Black
                            font.italic: true
                            font.pixelSize: it.fs
                            font.letterSpacing: -it.fs * 0.03
                            color: it.on ? root.red : root.shades[it.index]
                            style: it.on ? Text.Normal : Text.Raised
                            styleColor: Qt.alpha(root.deep, 0.5)
                        }
                        MouseArea {
                            anchors.fill: label
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (root.sel !== it.index) { root.sel = it.index; root.confirm = -1; }
                            onClicked: root.activate(it.index)
                        }
                    }
                }
            }

            // ── bottom-right hint ───────────────────────────────────────────
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 56 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40 * root.u
                spacing: 6 * root.u
                opacity: root.menuIn

                Text {
                    anchors.right: parent.right
                    text: root.confirm >= 0 ? "Press again to confirm" : root.items[root.sel].hint
                    font.family: root.face
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pixelSize: 30 * root.u
                    color: root.white
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 300 * root.u
                    height: 2 * root.u
                    color: root.white
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.bottom
                        anchors.topMargin: 2 * root.u
                        text: "System"
                        font.family: root.face
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 13 * root.u
                        color: root.white
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 18 * root.u
                    topPadding: 22 * root.u
                    Repeater {
                        model: [["↵", "Confirm"], ["↑↓", "Move"], ["Esc", "Back"]]
                        Row {
                            required property var modelData
                            spacing: 6 * root.u
                            Rectangle {
                                width: Math.max(28 * root.u, key.implicitWidth + 12 * root.u)
                                height: 28 * root.u
                                radius: height / 2
                                color: "transparent"
                                border.color: root.white
                                border.width: 2 * root.u
                                Text {
                                    id: key
                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    font.family: root.face
                                    font.weight: Font.Black
                                    font.pixelSize: 13 * root.u
                                    color: root.white
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                font.family: root.face
                                font.weight: Font.ExtraBold
                                font.italic: true
                                font.pixelSize: 22 * root.u
                                color: root.white
                            }
                        }
                    }
                }
            }

            // clicking empty space closes
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.close()
            }
        }
    }
}
