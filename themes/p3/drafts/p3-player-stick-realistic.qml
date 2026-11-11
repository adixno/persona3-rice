// p3-player: a "now playing" desktop widget for the Persona 3 theme, drawn as an
// original stick-style music player (generic mid-2000s form; no brand, no game art): a chrome
// capsule standing nearly upright (tilted ~15°) with a black, ribbed cable end at the top, a
// hold switch, a back clip, grooves by the rounded cap and a long thin blue backlit LCD strip;
// above it two round chrome clip-on earphones (grille holes, rings, padded ear hooks, cable
// stubs) wired through a Y-split with a chrome ring.
// The LCD shows the active MPRIS player's album art (tiny), a state glyph and "TITLE — ARTIST",
// reading along the stick. Display only (no controls). Idle: "NO MUSIC". The LCD line scrolls
// slowly only while music plays on AC power; otherwise it is elided, so the widget never
// redraws when idle. The stick is drawn level and tilted as one supersampled, multisampled
// layer, so its edges stay smooth at fractional scale.
// Bottom-left corner, Bottom layer: above the wallpaper, below windows.
// Earlier designs: themes/p3/drafts/p3-player-handheld.qml, p3-player-stick-flat.qml
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

    // chrome gradient for a horizontal cylinder (light from above)
    component Chrome: Gradient {
        GradientStop { position: 0.0; color: "#6d7582" }
        GradientStop { position: 0.12; color: "#f8fafc" }
        GradientStop { position: 0.30; color: "#cdd3dc" }
        GradientStop { position: 0.55; color: "#8d96a3" }
        GradientStop { position: 0.80; color: "#5b6370" }
        GradientStop { position: 0.92; color: "#b3bbc6" }
        GradientStop { position: 1.0; color: "#454c56" }
    }
    component Rubber: Gradient {
        GradientStop { position: 0.0; color: "#2b2f36" }
        GradientStop { position: 0.2; color: "#5a606a" }
        GradientStop { position: 0.5; color: "#1c1f24" }
        GradientStop { position: 1.0; color: "#0d0f12" }
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

    // round chrome clip-on earphone: padded ear hook, rings, grille holes, cable stub
    component Earphone: Item {
        id: ep
        property real size: 78
        property bool mirror: false
        width: size
        height: size

        // ear hook (dark arc) with a softer pad where it rests on the ear
        Shape {
            x: -ep.size * 0.18
            y: -ep.size * 0.30
            width: ep.size * 1.36
            height: ep.size * 1.2
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { origin.x: ep.size * 0.68; xScale: ep.mirror ? -1 : 1 }
            ShapePath {
                strokeColor: root.hookColor
                strokeWidth: 6.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: ep.size * 0.30; startY: ep.size * 0.64
                PathCubic {
                    x: ep.size * 1.18; y: ep.size * 0.42
                    control1X: ep.size * 0.04; control1Y: -ep.size * 0.06
                    control2X: ep.size * 1.06; control2Y: -ep.size * 0.10
                }
            }
            ShapePath {   // pad: lighter, thicker segment over the top of the arc
                strokeColor: "#4a515b"
                strokeWidth: 9
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: ep.size * 0.40; startY: ep.size * 0.10
                PathQuad { x: ep.size * 0.86; y: ep.size * 0.08; controlX: ep.size * 0.62; controlY: -ep.size * 0.04 }
            }
            ShapePath {   // highlight along the pad
                strokeColor: Qt.alpha("#ffffff", 0.25)
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: ep.size * 0.45; startY: ep.size * 0.06
                PathQuad { x: ep.size * 0.80; y: ep.size * 0.04; controlX: ep.size * 0.62; controlY: -ep.size * 0.06 }
            }
        }
        // cable stub (strain relief) at the bottom
        Rectangle {
            x: ep.size * 0.44 - 3
            y: ep.size * 0.86
            width: 7; height: 14
            radius: 3
            gradient: Rubber {}
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
        // bevel ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.alpha("#3c434d", 0.55)
            border.width: 1.2
        }
        // brushed inner face
        Rectangle {
            id: face
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
        // fine concentric rings on the face
        Repeater {
            model: [0.64, 0.5]
            Rectangle {
                required property real modelData
                anchors.centerIn: parent
                width: ep.size * modelData
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Qt.alpha("#7a8390", 0.35)
                border.width: 0.8
            }
        }
        // grille: a ring of small holes
        Repeater {
            model: 16
            Rectangle {
                required property int index
                readonly property real a: index / 16 * Math.PI * 2
                x: ep.size / 2 + Math.cos(a) * ep.size * 0.285 - 1.6
                y: ep.size / 2 + Math.sin(a) * ep.size * 0.285 - 1.6
                width: 3.2; height: 3.2
                radius: 1.6
                color: "#5d6672"
                border.color: Qt.alpha("#ffffff", 0.35)
                border.width: 0.5
            }
        }
        // small centre badge (no text)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.2
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#a3acb8" }
                GradientStop { position: 1.0; color: "#6f7885" }
            }
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
            margins { left: 14; bottom: 4 }
            implicitWidth: 290
            implicitHeight: 470
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "p3-player"
            color: "transparent"
            mask: Region {}   // display only: clicks pass through to the desktop

            // layout
            readonly property real earSize: 78
            readonly property point leftEar: Qt.point(14, 22)
            readonly property point rightEar: Qt.point(176, 10)
            readonly property point split: Qt.point(116, 150)       // Y-split bead
            readonly property real tilt: 75                          // stick rotation (deg), ~15° off upright
            readonly property point stickCenter: Qt.point(150, 318)
            // where the cable enters the stick's top (black) end, after rotation
            readonly property point plug: {
                const a = tilt * Math.PI / 180, vx = 4 - stick.width / 2;
                return Qt.point(stickCenter.x + vx * Math.cos(a), stickCenter.y + vx * Math.sin(a));
            }

            // cables: each earpiece down to the split, then one cable into the stick's end
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.cableColor; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.leftEar.x + win.earSize * 0.44; startY: win.leftEar.y + win.earSize + 12
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.leftEar.x + 34; control1Y: win.leftEar.y + 140; control2X: win.split.x - 30; control2Y: win.split.y - 10 }
                }
                ShapePath {
                    strokeColor: root.cableColor; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.rightEar.x + win.earSize * 0.44; startY: win.rightEar.y + win.earSize + 12
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.rightEar.x + 20; control1Y: win.rightEar.y + 150; control2X: win.split.x + 40; control2Y: win.split.y - 20 }
                }
                ShapePath {
                    strokeColor: root.cableColor; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.split.x; startY: win.split.y + 8
                    PathCubic { x: win.plug.x; y: win.plug.y; control1X: win.split.x - 6; control1Y: win.split.y + 40; control2X: win.plug.x - 18; control2Y: win.plug.y - 40 }
                }
            }
            // Y-split bead with a chrome ring
            Rectangle {
                x: win.split.x - 5.5; y: win.split.y - 10
                width: 11; height: 20
                radius: 4.5
                gradient: Rubber {}
                Rectangle {
                    y: 6
                    width: parent.width; height: 3
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#f2f5f8" }
                        GradientStop { position: 1.0; color: "#7c8592" }
                    }
                }
            }

            Earphone { x: win.leftEar.x; y: win.leftEar.y; size: win.earSize; mirror: false }
            Earphone { x: win.rightEar.x; y: win.rightEar.y; size: win.earSize; mirror: true }

            // ── the stick player, drawn level then tilted as one smooth layer ─────
            Item {
                id: stick
                width: 300
                height: 46
                x: win.stickCenter.x - width / 2
                y: win.stickCenter.y - height / 2
                rotation: win.tilt
                layer.enabled: true
                layer.smooth: true
                layer.samples: 4
                layer.textureSize: Qt.size(width * 3, height * 3)   // supersampled for crisp text

                // back clip, peeking out along the lower side
                Rectangle {
                    x: 70; y: parent.height - 6
                    width: 150; height: 7
                    radius: 3
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#8e97a4" }
                        GradientStop { position: 1.0; color: "#3e454f" }
                    }
                }
                // chrome tube (rounded cap at the far end)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Chrome {}
                    border.color: "#3f454e"
                    border.width: 1
                }
                // grooves by the cap
                Repeater {
                    model: [parent.width - 58, parent.width - 52]
                    Item {
                        required property real modelData
                        x: modelData; width: 2; height: stick.height
                        Rectangle { width: 1; height: parent.height; color: Qt.alpha("#2f353d", 0.6) }
                        Rectangle { x: 1; width: 1; height: parent.height; color: Qt.alpha("#ffffff", 0.55) }
                    }
                }
                // black ribbed cable end, with a seam ring
                Rectangle {
                    width: 40; height: parent.height
                    radius: height / 2
                    gradient: Rubber {}
                }
                Rectangle {
                    x: 30; width: 12; height: parent.height
                    gradient: Rubber {}
                }
                Repeater {
                    model: [12, 18, 24, 30]
                    Rectangle {
                        required property real modelData
                        x: modelData; y: 3
                        width: 1.2; height: stick.height - 6
                        color: Qt.alpha("#ffffff", 0.16)
                    }
                }
                Rectangle { x: 42; width: 2; height: parent.height; color: Qt.alpha("#ffffff", 0.4) }
                Rectangle { x: 44; width: 1; height: parent.height; color: Qt.alpha("#000000", 0.35) }
                // hold switch on the upper side
                Rectangle {
                    x: 56; y: -3
                    width: 22; height: 7
                    radius: 3
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#e9edf2" }
                        GradientStop { position: 1.0; color: "#6b7380" }
                    }
                    border.color: "#3f454e"
                    border.width: 0.8
                    Rectangle { x: 4; y: 2; width: 7; height: 3; radius: 1.5; color: "#2ff3ff"; opacity: 0.0 }
                }

                // LCD strip: engraved outline, dark bezel, blue backlit panel
                Rectangle {
                    x: 51; y: 7
                    width: parent.width - 51 - 66
                    height: parent.height - 14
                    radius: 5
                    color: "transparent"
                    border.color: Qt.alpha("#ffffff", 0.45)
                    border.width: 1
                }
                Rectangle {
                    id: bezel
                    x: 52; y: 8
                    width: parent.width - 52 - 67
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

                        // tiny album art at the strip's start
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
                        Text {
                            id: glyph
                            anchors { left: artBox.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            text: root.playing ? "play_arrow" : root.hasTrack ? "pause" : "stop"
                            font.family: root.icons
                            font.pixelSize: 14
                            color: root.lcdText
                        }
                        // battery icon at the end of the strip
                        Text {
                            id: batt
                            anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                            text: "battery_full"
                            rotation: 90
                            font.family: root.icons
                            font.pixelSize: 13
                            color: Qt.alpha(root.lcdText, 0.7)
                        }
                        ScreenLine {
                            anchors { left: glyph.right; leftMargin: 4; right: batt.left; rightMargin: 3; verticalCenter: parent.verticalCenter }
                            text: root.lcdLine
                            font: Qt.font({ family: root.face, weight: Font.DemiBold, pixelSize: 13, letterSpacing: 0.5 })
                            color: root.hasTrack ? root.lcdText : Qt.alpha(root.lcdText, 0.5)
                        }
                        // faint scanlines
                        Column {
                            anchors.fill: parent
                            spacing: 1
                            Repeater {
                                model: Math.ceil(lcd.height / 2)
                                Rectangle { width: lcd.width; height: 1; color: Qt.alpha("#000000", 0.13) }
                            }
                        }
                        // glass glare
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

                // status light near the cap: cyan while playing
                Rectangle {
                    x: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5
                    radius: 2.5
                    color: root.playing ? "#2ff3ff" : "#59616c"
                    border.color: Qt.alpha("#000000", 0.3)
                    border.width: 0.5
                }
            }
        }
    }
}
