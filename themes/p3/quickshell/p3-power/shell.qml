// p3-power: full-screen power menu for the Persona 3 theme.
// Fades in over a looping, muted background video, then a tilted stack of heavy italic
// words slides in. The video is the slot file ~/.local/share/persona-rice/media/p3/power-bg.mp4
// (override the folder with $P3_MEDIA); without it the backdrop is a navy gradient.
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

    // the Dark Hour grades the art green and swaps cyan accents for green (DarkHour.qml)
    DarkHour { id: dh }

    Motion {
        id: motion
        onSpeedChanged: {
            if (speed <= 0.03 && player.playbackState === MediaPlayer.PlayingState) player.pause();
            else if (speed > 0.03 && player.playbackState !== MediaPlayer.PlayingState) player.play();
        }
    }

    readonly property string media: Quickshell.env("P3_MEDIA") || (Quickshell.env("HOME") + "/.local/share/persona-rice/media/p3")

    // only one p3 menu at a time: clear status / equip / items when the power menu opens
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.global(\"p3status:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3equip:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3items:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3skills:hide\")' >/dev/null; hyprctl dispatch 'hl.dsp.global(\"p3links:hide\")' >/dev/null"])

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
            readonly property color cyan: dh.mix("#3fd8ff", dh.green)
            readonly property color ice: dh.mix("#aaf2ff", dh.green)
            readonly property color white: "#f2fbff"
            readonly property color red: "#ff1f3a"
            readonly property color pink: "#ff5fae"
            readonly property string face: "Montserrat"

            property real fill: 0        // backdrop fade, 0..1
            property real menuIn: 0      // stagger driver for the stack
            property bool closing: false
            property int sel: 0
            property int confirm: -1
            property date now: new Date()

            readonly property var items: [
                { label: "LOCK", hint: "Lock the screen", cmd: ["caelestia", "shell", "lock", "lock"], ask: false, size: 78, dx: 30 },
                { label: "LOG OUT", hint: "End this session", cmd: ["uwsm", "stop"], ask: true, size: 64, dx: 74 },
                { label: "SLEEP", hint: "Suspend", cmd: ["systemctl", "suspend"], ask: false, size: 66, dx: 40 },
                { label: "REBOOT", hint: "Restart the machine", cmd: ["systemctl", "reboot"], ask: true, size: 66, dx: 84 },
                { label: "SHUT DOWN", hint: "Power off", cmd: ["systemctl", "poweroff"], ask: true, size: 62, dx: 20 },
                { label: "BACK", hint: "Return to the desktop", cmd: [], ask: false, size: 58, dx: 70 }
            ]
            readonly property var shades: ["#8ff4ff", "#62e8ff", "#46dcff", "#3cc8ff", "#3aa9ff", "#3d8cff"]
            readonly property var backs: ["#1f8fe6", "#1a7fe0", "#176fda", "#1660d2", "#1652c8", "#1646bd"]

            component Blade: Shape {
                id: bl
                property real w
                property real h
                property color cWhite
                property color cPink
                property color cRed
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: bl.cPink
                    strokeWidth: -1
                    PathPolyline {
                        path: [Qt.point(-70 * root.u, bl.h * 0.98), Qt.point(bl.w - 10 * root.u, -bl.h * 0.62),
                               Qt.point(bl.w + 12 * root.u, -bl.h * 0.44), Qt.point(bl.w - 6 * root.u, bl.h * 0.66),
                               Qt.point(-70 * root.u, bl.h * 0.98)]
                    }
                }
                ShapePath {
                    fillColor: bl.cWhite
                    strokeWidth: -1
                    PathPolyline {
                        path: [Qt.point(-64 * root.u, bl.h * 0.94), Qt.point(bl.w - 18 * root.u, -bl.h * 0.56),
                               Qt.point(bl.w + 2 * root.u, -bl.h * 0.40), Qt.point(bl.w - 14 * root.u, bl.h * 0.62),
                               Qt.point(-64 * root.u, bl.h * 0.94)]
                    }
                }
                ShapePath {
                    fillColor: bl.cRed
                    strokeWidth: -1
                    PathPolyline {
                        path: [Qt.point(-26 * root.u, bl.h * 0.40), Qt.point(bl.w - 40 * root.u, bl.h * 0.14),
                               Qt.point(bl.w - 46 * root.u, bl.h * 0.56), Qt.point(-32 * root.u, bl.h * 0.82),
                               Qt.point(-26 * root.u, bl.h * 0.40)]
                    }
                }
            }

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
                    NumberAnimation { target: dim; property: "opacity"; to: 1; duration: 200 }
                    NumberAnimation { target: root; property: "fill"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 220 }
                        NumberAnimation { target: root; property: "menuIn"; from: 0; to: 1; duration: 560; easing.type: Easing.Linear }
                    }
                }
            }
            SequentialAnimation {
                id: closeAnim
                NumberAnimation { target: root; property: "menuIn"; to: 0; duration: 220 }
                ParallelAnimation {
                    NumberAnimation { target: root; property: "fill"; to: 0; duration: 300; easing.type: Easing.InCubic }
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

            // ── backdrop: drops down from the top like a curtain ─────────────
            Item {
                id: curtain
                layer.enabled: dh.t > 0
                layer.effect: ShaderEffect {
                    property real dark: dh.t
                    fragmentShader: Qt.resolvedUrl("grade.frag.qsb")
                }
                width: parent.width
                height: parent.height
                y: -height * (1 - root.fill)
                clip: true

                // ── backdrop: looping video slot, or a navy gradient without one ─
                Rectangle {
                    anchors.fill: parent
                    visible: !player.hasVideo
                    opacity: root.fill
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a4fe0" }
                        GradientStop { position: 1.0; color: root.deep }
                    }
                }
                MediaPlayer {
                    id: player
                    source: "file://" + shell.media + "/power-bg.mp4"
                    loops: MediaPlayer.Infinite
                    videoOutput: vid
                    audioOutput: AudioOutput { muted: true }
                    playbackRate: Math.max(0.1, Math.round(motion.speed * 20) / 20)
                    // follows Motion: a still first frame when animations are stopped
                    Component.onCompleted: { play(); if (motion.speed <= 0.03) pause(); }
                }
                VideoOutput {
                    id: vid
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                    visible: player.hasVideo
                    opacity: root.fill
                }
                // keep the menu readable over a bright video
                Rectangle {
                    anchors.fill: parent
                    visible: player.hasVideo
                        gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.45; color: Qt.alpha(root.deep, 0.15) }
                        GradientStop { position: 1.0; color: Qt.alpha(root.deep, 0.6) }
                    }
                }
            }

            // ── menu stack ──────────────────────────────────────────────────
            Item {
                id: stack
                x: root.width * 0.52
                y: 150 * root.u
                rotation: -11
                transformOrigin: Item.TopLeft

                // the highlight: white blade + pink edge + red bar, shared by all words.
                // It slides to the selected word; while moving it glitches (inverted
                // colours, cyan/red split copies jittering sideways).
                Item {
                    id: hl
                    readonly property Item target: rep.count > root.sel ? rep.itemAt(root.sel) : null
                    visible: target !== null && root.menuIn > 0.05
                    opacity: Math.min(1, root.menuIn * 2)
                    x: target ? target.x : 0
                    y: target ? target.y : 0
                    property real w: target ? target.width + 70 * root.u : 0
                    property real h: target ? target.fs : 0
                    Behavior on y { enabled: root.menuIn >= 1; NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                    Behavior on x { enabled: root.menuIn >= 1; NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                    Behavior on w { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                    Behavior on h { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

                    // secondary inverted panel: sits behind the highlight at a different
                    // offset/angle for each word, and trails it a little when moving
                    readonly property var echoes: [
                        [-26, 16, -5], [34, -12, 4], [-14, -18, 7], [28, 14, -6], [-30, -8, 3], [20, 18, -4]
                    ]
                    readonly property var e: echoes[root.sel % echoes.length]
                    Blade {
                        id: echo
                        w: hl.w; h: hl.h
                        x: hl.e[0] * root.u
                        y: hl.e[1] * root.u
                        rotation: hl.e[2]
                        transformOrigin: Item.Left
                        cWhite: root.deep
                        cPink: root.cyan
                        cRed: root.cyan
                        opacity: 0.85
                        Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                        Behavior on rotation { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                    }
                    Blade {
                        w: hl.w; h: hl.h
                        cWhite: root.white
                        cPink: root.pink
                        cRed: "transparent"
                    }

                    // red bar: own offset/tilt per word, arrives after the blade
                    readonly property var bars: [
                        [-10, 2, 0], [24, -8, -4], [-30, 10, 5], [14, 6, -3], [-18, -10, 4], [30, 8, -5]
                    ]
                    readonly property var bb: bars[root.sel % bars.length]
                    Shape {
                        id: bar
                        x: hl.bb[0] * root.u
                        y: hl.bb[1] * root.u
                        rotation: hl.bb[2]
                        transformOrigin: Item.Left
                        preferredRendererType: Shape.CurveRenderer
                        Behavior on x { NumberAnimation { duration: 440; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on y { NumberAnimation { duration: 440; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on rotation { NumberAnimation { duration: 440; easing.type: Easing.OutCubic } }
                        ShapePath {
                            fillColor: root.red
                            strokeWidth: -1
                            PathPolyline {
                                path: [Qt.point(-26 * root.u, hl.h * 0.40), Qt.point(hl.w - 40 * root.u, hl.h * 0.14),
                                       Qt.point(hl.w - 46 * root.u, hl.h * 0.56), Qt.point(-32 * root.u, hl.h * 0.82),
                                       Qt.point(-26 * root.u, hl.h * 0.40)]
                            }
                        }
                    }
                }

                Repeater {
                    id: rep
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

                        x: d.dx * root.u
                        opacity: enter
                        y: {
                            // even rows: fixed step, each word centred on its row
                            const step = 62 * root.u;
                            const yy = index * step + (step - fs) / 2;
                            return yy - (1 - enter) * (1 - enter) * 520 * root.u;
                        }
                        width: label.implicitWidth
                        height: fs
                        z: on ? 10 : 0

                        // the word: extra forward shear on top of the italic, face + offset back layer
                        Item {
                            id: word
                            width: label.implicitWidth
                            height: label.implicitHeight
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, -0.16, 0, word.height * 0.16 * 0.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                            Text {
                                x: 3 * root.u
                                y: 4 * root.u
                                text: label.text
                                font: label.font
                                color: it.on ? Qt.alpha(root.white, 0.0) : root.backs[it.index]
                            }
                            Text {
                                id: label
                                text: it.asking ? "SURE?" : it.d.label
                                font.family: "Jost"
                                font.weight: Font.Black
                                font.italic: true
                                font.pixelSize: it.fs
                                font.letterSpacing: -it.fs * 0.045
                                color: it.on ? "#0a0a0a" : root.shades[it.index]
                            }
                        }
                        MouseArea {
                            anchors.fill: word
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
