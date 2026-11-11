// p3-player: a "now playing" desktop widget for the Persona 3 theme, drawn as an
// original stick-style music player (generic mid-2000s form; no brand, no game art): a chrome
// capsule lying on its side with a black cable end and a long thin blue backlit LCD strip, and
// two round chrome clip-on earphones with ear hooks, wired through a Y-split cable.
// The LCD shows the active MPRIS player's album art (tiny, at the strip's left end), a state
// glyph and "TITLE — ARTIST". Display only (no controls). Idle: "NO MUSIC". The LCD line
// scrolls slowly only while music plays on AC power; otherwise it is elided, so the widget
// never redraws when idle. Bottom-left corner, Bottom layer: above the wallpaper, below windows.
// Previous handheld design: themes/p3/drafts/p3-player-handheld.qml
//
// Launch: qs -c p3-player -n -d   (persona-theme autostarts it while p3 is active)
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

ShellRoot {
    id: root

    readonly property string face: "Saira"
    readonly property string icons: "Material Symbols Sharp"
    readonly property color lcdText: "#8fd3ff"
    readonly property color lcdBg: "#071a3f"
    readonly property color hookColor: "#2f343c"
    readonly property color cableColor: "#22262d"

    // the player to show: one that is playing, else the first one with a track
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    readonly property bool hasTrack: !!player && (player.trackTitle ?? "") !== ""
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool canAnimate: playing && (UPower.displayDevice?.ready ?? false) && !UPower.onBattery
    readonly property string lcdLine: {
        if (!hasTrack) return "NO MUSIC";
        const a = player.trackArtist ?? "";
        return a ? `${player.trackTitle}  —  ${a}` : player.trackTitle;
    }

    // one line of LCD text: scrolls when too long and allowed to animate, else elides.
    // Two Texts (static elided / full-length sliding) so switching modes never glitches.
    component ScreenLine: Item {
        id: line
        property string text
        property font font
        property color color
        readonly property bool overflow: full.implicitWidth > width + 1
        readonly property bool scroll: overflow && root.canAnimate
        property real offset: 0
        clip: true
        implicitHeight: full.implicitHeight

        Text {
            width: line.width
            visible: !line.scroll
            text: line.text
            font: line.font
            color: line.color
            elide: Text.ElideRight
        }
        Text {
            id: full
            x: -line.offset
            visible: line.scroll
            text: line.text
            font: line.font
            color: line.color
        }
        SequentialAnimation {
            running: line.scroll
            loops: Animation.Infinite
            onRunningChanged: if (!running) line.offset = 0
            PauseAnimation { duration: 1800 }
            NumberAnimation {
                target: line; property: "offset"; from: 0
                to: Math.max(0, full.implicitWidth - line.width)
                duration: Math.max(1500, (full.implicitWidth - line.width) * 40)
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 1400 }
            NumberAnimation { target: line; property: "offset"; to: 0; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    // round chrome clip-on earphone with an ear hook arcing over its top
    component Earphone: Item {
        id: ep
        property real size: 74
        property bool mirror: false
        width: size
        height: size

        // ear hook: a thick dark arc around the upper back of the earpiece
        Shape {
            x: -ep.size * 0.18
            y: -ep.size * 0.28
            width: ep.size * 1.36
            height: ep.size * 1.2
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { origin.x: ep.size * 0.68; xScale: ep.mirror ? -1 : 1 }
            ShapePath {
                strokeColor: root.hookColor
                strokeWidth: 6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: ep.size * 0.30; startY: ep.size * 0.62
                PathCubic {
                    x: ep.size * 1.18; y: ep.size * 0.40
                    control1X: ep.size * 0.05; control1Y: -ep.size * 0.05
                    control2X: ep.size * 1.05; control2Y: -ep.size * 0.10
                }
            }
        }
        // chrome back shell
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f5f7fa" }
                GradientStop { position: 0.35; color: "#c4cbd5" }
                GradientStop { position: 0.6; color: "#7e8794" }
                GradientStop { position: 0.85; color: "#c9d0d9" }
                GradientStop { position: 1.0; color: "#59616c" }
            }
            border.color: "#4c535d"
            border.width: 1
        }
        // brushed inner face
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#dfe4ea" }
                GradientStop { position: 0.5; color: "#aeb6c1" }
                GradientStop { position: 1.0; color: "#e7ebf0" }
            }
            border.color: Qt.alpha("#ffffff", 0.6)
            border.width: 1
        }
        // small centre badge (no text)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.22
            height: width
            radius: width / 2
            color: "#8b94a1"
            border.color: Qt.alpha("#ffffff", 0.5)
            border.width: 1
        }
        // specular glint
        Rectangle {
            x: parent.width * 0.2
            y: parent.height * 0.12
            width: parent.width * 0.32
            height: parent.height * 0.14
            radius: height / 2
            rotation: -28
            color: Qt.alpha("#ffffff", 0.75)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { left: true; bottom: true }
            margins { left: 18; bottom: 8 }
            implicitWidth: 340
            implicitHeight: 250
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "p3-player"
            color: "transparent"
            mask: Region {}   // display only: clicks pass through to the desktop

            // positions
            readonly property point leftEar: Qt.point(48, 18)
            readonly property point rightEar: Qt.point(212, 6)
            readonly property real earSize: 74
            readonly property point split: Qt.point(112, 150)     // Y-split bead
            readonly property point plug: Qt.point(stick.x + 6, stick.y + stick.height / 2)

            // cables: each earpiece down to the split, then one cable into the stick's end
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.cableColor; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.leftEar.x + win.earSize * 0.45; startY: win.leftEar.y + win.earSize * 0.95
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.leftEar.x + 20; control1Y: win.leftEar.y + 130; control2X: win.split.x - 20; control2Y: win.split.y - 40 }
                }
                ShapePath {
                    strokeColor: root.cableColor; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.rightEar.x + win.earSize * 0.4; startY: win.rightEar.y + win.earSize * 0.95
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.rightEar.x + 10; control1Y: win.rightEar.y + 150; control2X: win.split.x + 50; control2Y: win.split.y - 70 }
                }
                ShapePath {
                    strokeColor: root.cableColor; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.split.x; startY: win.split.y
                    PathCubic { x: win.plug.x; y: win.plug.y; control1X: win.split.x - 10; control1Y: win.split.y + 40; control2X: win.plug.x - 40; control2Y: win.plug.y }
                }
            }
            // Y-split bead
            Rectangle {
                x: win.split.x - 5; y: win.split.y - 9
                width: 10; height: 18
                radius: 4
                color: "#15181d"
            }

            Earphone { x: win.leftEar.x; y: win.leftEar.y; size: win.earSize; mirror: false }
            Earphone { x: win.rightEar.x; y: win.rightEar.y; size: win.earSize; mirror: true }

            // ── the stick player ─────────────────────────────────────────────
            Item {
                id: stick
                x: 22
                y: 176
                width: 300
                height: 46

                // soft shadow
                Rectangle {
                    x: 3; y: 6
                    width: parent.width; height: parent.height
                    radius: height / 2
                    color: Qt.alpha("#000814", 0.35)
                }
                // chrome tube (rounded cap on the right)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#6d7582" }
                        GradientStop { position: 0.12; color: "#f8fafc" }
                        GradientStop { position: 0.30; color: "#cdd3dc" }
                        GradientStop { position: 0.55; color: "#8d96a3" }
                        GradientStop { position: 0.80; color: "#5b6370" }
                        GradientStop { position: 0.92; color: "#b3bbc6" }
                        GradientStop { position: 1.0; color: "#454c56" }
                    }
                    border.color: "#3f454e"
                    border.width: 1
                }
                // black end where the cable goes in (left), with a seam ring
                Rectangle {
                    width: 40
                    height: parent.height
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2b2f36" }
                        GradientStop { position: 0.2; color: "#5a606a" }
                        GradientStop { position: 0.5; color: "#1c1f24" }
                        GradientStop { position: 1.0; color: "#0d0f12" }
                    }
                }
                Rectangle {
                    x: 30
                    width: 12
                    height: parent.height
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2b2f36" }
                        GradientStop { position: 0.2; color: "#5a606a" }
                        GradientStop { position: 0.5; color: "#1c1f24" }
                        GradientStop { position: 1.0; color: "#0d0f12" }
                    }
                }
                Rectangle { x: 42; width: 2; height: parent.height; color: Qt.alpha("#ffffff", 0.35) }

                // LCD strip: dark bezel, blue backlit panel
                Rectangle {
                    id: bezel
                    x: 52
                    y: 8
                    width: parent.width - 52 - 34
                    height: parent.height - 16
                    radius: 4
                    color: "#1a2030"
                    border.color: "#0c0f16"
                    border.width: 1

                    Rectangle {
                        id: lcd
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 3
                        clip: true
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#0b2552" }
                            GradientStop { position: 1.0; color: root.lcdBg }
                        }

                        // tiny album art at the strip's left end
                        Rectangle {
                            id: artBox
                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.height - 6
                            height: width
                            radius: 2
                            color: "#0d2160"
                            Image {
                                id: art
                                anchors.fill: parent
                                source: root.hasTrack ? (root.player.trackArtUrl ?? "") : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(64, 64)
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !art.visible
                                text: "music_note"
                                font.family: root.icons
                                font.pixelSize: 14
                                color: Qt.alpha(root.lcdText, root.hasTrack ? 0.9 : 0.45)
                            }
                        }
                        // state glyph
                        Text {
                            id: glyph
                            anchors { left: artBox.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            text: root.playing ? "play_arrow" : root.hasTrack ? "pause" : "stop"
                            font.family: root.icons
                            font.pixelSize: 14
                            color: root.lcdText
                        }
                        // scrolling line
                        ScreenLine {
                            anchors { left: glyph.right; leftMargin: 4; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: root.lcdLine
                            font: Qt.font({ family: root.face, weight: Font.DemiBold, pixelSize: 13, letterSpacing: 0.5 })
                            color: root.hasTrack ? root.lcdText : Qt.alpha(root.lcdText, 0.5)
                        }
                        // glass glare on the LCD
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: parent.height * 0.45
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.alpha("#ffffff", 0.12) }
                                GradientStop { position: 1.0; color: Qt.alpha("#ffffff", 0.0) }
                            }
                        }
                    }
                }

                // small status light near the cap: cyan while playing
                Rectangle {
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    width: 5; height: 5
                    radius: 2.5
                    color: root.playing ? "#2ff3ff" : "#59616c"
                }
            }
        }
    }
}
