// p3-player: a "now playing" desktop widget for the Persona 3 theme, drawn like a
// cel-shaded anime prop so it sits in the anime wallpaper: flat colour blocks with hard-edged
// shadow bands, bold navy lineart, sharp white highlights and a cyan rim light, in the
// wallpaper's blue palette. The object is an original stick-style music player (generic
// mid-2000s form; no brand, no game art) standing nearly upright (tilted ~15°), with two round
// clip-on earphones on a Y cable.
// The LCD shows the active MPRIS player's album art (tiny), a state glyph and "TITLE — ARTIST".
// Display only. Idle: "NO MUSIC". The LCD line scrolls only while music plays on AC power;
// otherwise it is elided, so the widget never redraws when idle. The stick is drawn level and
// tilted as one supersampled layer so lineart stays smooth at fractional scale.
// Bottom-left corner, Bottom layer: above the wallpaper, below windows.
// Earlier designs: themes/p3/drafts/p3-player-*.qml
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

    // cel palette (cool, matched to the wallpaper)
    readonly property color line: "#0b1433"        // lineart
    readonly property real lw: 2.2                 // lineart width
    readonly property color hi: "#ffffff"          // highlight
    readonly property color light: "#e3ecf8"
    readonly property color base: "#b9c9e2"
    readonly property color mid: "#8399bd"
    readonly property color shade: "#56699a"
    readonly property color rim: "#5fe6ff"         // cyan rim light
    readonly property color dark: "#1d2540"        // rubber / hooks
    readonly property color darkHi: "#3a4870"
    readonly property color lcdText: "#a8e6ff"

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

    // hard-banded cel shading for a horizontal cylinder lit from above
    component CelTube: Gradient {
        GradientStop { position: 0.00; color: root.light }
        GradientStop { position: 0.14; color: root.light }
        GradientStop { position: 0.141; color: root.hi }
        GradientStop { position: 0.25; color: root.hi }
        GradientStop { position: 0.251; color: root.base }
        GradientStop { position: 0.58; color: root.base }
        GradientStop { position: 0.581; color: root.mid }
        GradientStop { position: 0.80; color: root.mid }
        GradientStop { position: 0.801; color: root.shade }
        GradientStop { position: 0.90; color: root.shade }
        GradientStop { position: 0.901; color: root.rim }
        GradientStop { position: 1.00; color: root.rim }
    }
    component CelRubber: Gradient {
        GradientStop { position: 0.00; color: root.darkHi }
        GradientStop { position: 0.30; color: root.darkHi }
        GradientStop { position: 0.301; color: root.dark }
        GradientStop { position: 0.85; color: root.dark }
        GradientStop { position: 0.851; color: "#2b6f9a" }
        GradientStop { position: 1.00; color: "#2b6f9a" }
    }

    component ScreenLine: Item {
        id: sl
        property string text
        property font font
        property color color
        readonly property bool overflow: full.implicitWidth > width + 1
        readonly property bool scroll: overflow && root.canAnimate
        property real offset: 0
        clip: true
        implicitHeight: full.implicitHeight

        Text { width: sl.width; visible: !sl.scroll; text: sl.text; font: sl.font; color: sl.color; elide: Text.ElideRight }
        Text { id: full; x: -sl.offset; visible: sl.scroll; text: sl.text; font: sl.font; color: sl.color }
        SequentialAnimation {
            running: sl.scroll
            loops: Animation.Infinite
            onRunningChanged: if (!running) sl.offset = 0
            PauseAnimation { duration: 1800 }
            NumberAnimation {
                target: sl; property: "offset"; from: 0
                to: Math.max(0, full.implicitWidth - sl.width)
                duration: Math.max(1500, (full.implicitWidth - sl.width) * 40)
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 1400 }
            NumberAnimation { target: sl; property: "offset"; to: 0; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    // cel-shaded round clip-on earphone
    component Earphone: Item {
        id: ep
        property real size: 78
        property bool mirror: false
        width: size
        height: size

        // ear hook: lineart stroke, fill stroke, highlight stroke
        Shape {
            x: -ep.size * 0.18
            y: -ep.size * 0.30
            width: ep.size * 1.36
            height: ep.size * 1.2
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { origin.x: ep.size * 0.68; xScale: ep.mirror ? -1 : 1 }
            ShapePath {
                strokeColor: root.line; strokeWidth: 9; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: ep.size * 0.30; startY: ep.size * 0.64
                PathCubic { x: ep.size * 1.18; y: ep.size * 0.42; control1X: ep.size * 0.04; control1Y: -ep.size * 0.06; control2X: ep.size * 1.06; control2Y: -ep.size * 0.10 }
            }
            ShapePath {
                strokeColor: root.dark; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: ep.size * 0.30; startY: ep.size * 0.64
                PathCubic { x: ep.size * 1.18; y: ep.size * 0.42; control1X: ep.size * 0.04; control1Y: -ep.size * 0.06; control2X: ep.size * 1.06; control2Y: -ep.size * 0.10 }
            }
            ShapePath {
                strokeColor: root.darkHi; strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: ep.size * 0.36; startY: ep.size * 0.12
                PathQuad { x: ep.size * 0.86; y: ep.size * 0.06; controlX: ep.size * 0.60; controlY: -ep.size * 0.05 }
            }
        }
        // cable stub
        Rectangle {
            x: ep.size * 0.44 - 4; y: ep.size * 0.84
            width: 8; height: 15; radius: 3
            color: root.dark
            border.color: root.line; border.width: root.lw
        }
        // body: shadow tone, then the lit tone offset toward the light (hard crescent shadow)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.mid
        }
        Rectangle {
            x: -2; y: -2
            width: parent.width * 0.92; height: width
            radius: width / 2
            color: root.base
        }
        // cyan rim light along the lower-right edge
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.rim; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: ep.size / 2; centerY: ep.size / 2; radiusX: ep.size / 2 - 3; radiusY: ep.size / 2 - 3; startAngle: 10; sweepAngle: 75 }
            }
        }
        // inner face plate
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.7; height: width
            radius: width / 2
            color: root.light
            border.color: root.line; border.width: 1.4
        }
        Rectangle {   // face shadow band (hard)
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 3
            anchors.verticalCenterOffset: 3
            width: parent.width * 0.62; height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.alpha(root.mid, 0.9); border.width: 3
        }
        // grille holes
        Repeater {
            model: 12
            Rectangle {
                required property int index
                readonly property real a: index / 12 * Math.PI * 2
                x: ep.size / 2 + Math.cos(a) * ep.size * 0.24 - 1.7
                y: ep.size / 2 + Math.sin(a) * ep.size * 0.24 - 1.7
                width: 3.4; height: 3.4; radius: 1.7
                color: root.line
            }
        }
        // centre badge
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.2; height: width
            radius: width / 2
            color: root.base
            border.color: root.line; border.width: 1.4
        }
        // lineart outline
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: root.line; border.width: root.lw
        }
        // sharp anime highlight: a bold streak and a dot
        Rectangle {
            x: parent.width * 0.17; y: parent.height * 0.15
            width: parent.width * 0.3; height: parent.height * 0.1
            radius: height / 2
            rotation: -38
            color: root.hi
        }
        Rectangle {
            x: parent.width * 0.47; y: parent.height * 0.1
            width: 5; height: 5; radius: 2.5
            color: root.hi
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
            mask: Region {}

            readonly property real earSize: 78
            readonly property point leftEar: Qt.point(14, 22)
            readonly property point rightEar: Qt.point(176, 10)
            readonly property point split: Qt.point(116, 150)
            readonly property real tilt: 75
            readonly property point stickCenter: Qt.point(150, 318)
            readonly property point plug: {
                const a = tilt * Math.PI / 180, vx = 4 - stick.width / 2;
                return Qt.point(stickCenter.x + vx * Math.cos(a), stickCenter.y + vx * Math.sin(a));
            }

            // cables: navy lineart with a lighter core
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                component Cable: ShapePath {
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap
                }
                Cable {
                    strokeColor: root.line; strokeWidth: 4
                    startX: win.leftEar.x + win.earSize * 0.44; startY: win.leftEar.y + win.earSize + 12
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.leftEar.x + 34; control1Y: win.leftEar.y + 140; control2X: win.split.x - 30; control2Y: win.split.y - 10 }
                }
                Cable {
                    strokeColor: root.line; strokeWidth: 4
                    startX: win.rightEar.x + win.earSize * 0.44; startY: win.rightEar.y + win.earSize + 12
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.rightEar.x + 20; control1Y: win.rightEar.y + 150; control2X: win.split.x + 40; control2Y: win.split.y - 20 }
                }
                Cable {
                    strokeColor: root.line; strokeWidth: 4.6
                    startX: win.split.x; startY: win.split.y + 8
                    PathCubic { x: win.plug.x; y: win.plug.y; control1X: win.split.x - 6; control1Y: win.split.y + 40; control2X: win.plug.x - 18; control2Y: win.plug.y - 40 }
                }
                Cable {
                    strokeColor: root.darkHi; strokeWidth: 1.4
                    startX: win.leftEar.x + win.earSize * 0.44; startY: win.leftEar.y + win.earSize + 12
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.leftEar.x + 34; control1Y: win.leftEar.y + 140; control2X: win.split.x - 30; control2Y: win.split.y - 10 }
                }
                Cable {
                    strokeColor: root.darkHi; strokeWidth: 1.4
                    startX: win.rightEar.x + win.earSize * 0.44; startY: win.rightEar.y + win.earSize + 12
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.rightEar.x + 20; control1Y: win.rightEar.y + 150; control2X: win.split.x + 40; control2Y: win.split.y - 20 }
                }
                Cable {
                    strokeColor: root.darkHi; strokeWidth: 1.8
                    startX: win.split.x; startY: win.split.y + 8
                    PathCubic { x: win.plug.x; y: win.plug.y; control1X: win.split.x - 6; control1Y: win.split.y + 40; control2X: win.plug.x - 18; control2Y: win.plug.y - 40 }
                }
            }
            // Y-split bead
            Rectangle {
                x: win.split.x - 6; y: win.split.y - 10
                width: 12; height: 20; radius: 5
                color: root.dark
                border.color: root.line; border.width: root.lw
                Rectangle { x: 2; y: 7; width: parent.width - 4; height: 3; color: root.base }
                Rectangle { x: 3; y: 3; width: 2; height: 3; radius: 1; color: root.darkHi }
            }

            Earphone { x: win.leftEar.x; y: win.leftEar.y; size: win.earSize; mirror: false }
            Earphone { x: win.rightEar.x; y: win.rightEar.y; size: win.earSize; mirror: true }

            // ── the stick, drawn level then tilted as one smooth layer ─────────
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
                layer.textureSize: Qt.size(width * 3, height * 3)

                // flat cel "contact" shadow offset below
                Rectangle {
                    x: 2; y: 7
                    width: parent.width; height: parent.height
                    radius: height / 2
                    color: Qt.alpha("#06102e", 0.35)
                }
                // back clip
                Rectangle {
                    x: 70; y: parent.height - 6
                    width: 150; height: 8; radius: 3
                    color: root.mid
                    border.color: root.line; border.width: root.lw
                }
                // tube body
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: CelTube {}
                }
                // grooves by the cap
                Repeater {
                    model: [stick.width - 58, stick.width - 51]
                    Rectangle {
                        required property real modelData
                        x: modelData; y: 3
                        width: 1.6; height: stick.height - 6
                        color: root.line
                    }
                }
                // rubber cable end with ribs
                Rectangle {
                    width: 44; height: parent.height
                    radius: height / 2
                    gradient: CelRubber {}
                }
                Rectangle { x: 30; width: 14; height: parent.height; gradient: CelRubber {} }
                Repeater {
                    model: [12, 19, 26, 33]
                    Rectangle {
                        required property real modelData
                        x: modelData; y: 4
                        width: 1.6; height: stick.height - 8
                        color: root.line
                    }
                }
                Rectangle { x: 44; width: root.lw; height: parent.height; color: root.line }
                // hold switch
                Rectangle {
                    x: 56; y: -4
                    width: 22; height: 8; radius: 3
                    color: root.light
                    border.color: root.line; border.width: 1.6
                }

                // LCD: navy bezel, flat backlit panel
                Rectangle {
                    id: bezel
                    x: 52; y: 8
                    width: parent.width - 52 - 68
                    height: parent.height - 16
                    radius: 4
                    color: root.line

                    Rectangle {
                        id: lcd
                        anchors.fill: parent
                        anchors.margins: 2.5
                        radius: 2
                        clip: true
                        color: "#123479"

                        Rectangle {   // lighter top band of the backlight (hard edge)
                            width: parent.width; height: parent.height * 0.4
                            color: "#1a4596"
                        }
                        Rectangle {
                            id: artBox
                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.height - 6; height: width
                            radius: 2
                            color: "#0d2160"
                            border.color: root.line; border.width: 1
                            Image {
                                id: art
                                anchors.fill: parent
                                anchors.margins: 1
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
                                color: Qt.alpha(root.lcdText, root.hasTrack ? 0.9 : 0.5)
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
                        Text {
                            id: batt
                            anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                            text: "battery_full"
                            rotation: 90
                            font.family: root.icons
                            font.pixelSize: 13
                            color: Qt.alpha(root.lcdText, 0.75)
                        }
                        ScreenLine {
                            anchors { left: glyph.right; leftMargin: 4; right: batt.left; rightMargin: 3; verticalCenter: parent.verticalCenter }
                            text: root.lcdLine
                            font: Qt.font({ family: root.face, weight: Font.Bold, pixelSize: 13, letterSpacing: 0.5 })
                            color: root.hasTrack ? root.lcdText : Qt.alpha(root.lcdText, 0.55)
                        }
                        // classic anime screen shine: two parallel diagonal white bars
                        Rectangle { x: parent.width * 0.62; y: -10; width: 9; height: parent.height + 20; rotation: 30; color: Qt.alpha(root.hi, 0.28) }
                        Rectangle { x: parent.width * 0.62 + 14; y: -10; width: 3.5; height: parent.height + 20; rotation: 30; color: Qt.alpha(root.hi, 0.28) }
                    }
                }

                // status light
                Rectangle {
                    x: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: root.playing ? root.rim : root.mid
                    border.color: root.line; border.width: 1.2
                }

                // lineart outline over everything
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.color: root.line; border.width: root.lw
                }
                // sharp highlight streaks along the top of the tube
                Rectangle { x: parent.width - 46; y: 5; width: 22; height: 3; radius: 1.5; color: root.hi }
                Rectangle { x: parent.width - 20; y: 6; width: 4; height: 3; radius: 1.5; color: root.hi }
                Rectangle { x: 10; y: 5; width: 16; height: 2.5; radius: 1.2; color: Qt.alpha(root.hi, 0.6) }
            }
        }
    }
}
