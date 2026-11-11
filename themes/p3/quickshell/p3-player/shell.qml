// p3-player: a "now playing" desktop widget for the Persona 3 theme, drawn like a
// cel-shaded anime prop so it sits in the anime wallpaper: two-tone hard shading with a cyan
// rim light, hatch strokes in the shadow, bold navy lineart that is heavier on the shadow side,
// one big clean highlight and white ✦ sparkles. The object is an original stick-style music
// player (generic mid-2000s form; no brand, no game art) standing nearly upright (tilted ~15°)
// with its two round clip-on earphones resting behind it, partly tucked under the stick, the
// cable looping from the player's top end down through a Y-split to each earpiece.
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

    // the Dark Hour recolours the player green (DarkHour.qml)
    DarkHour { id: dh }

    readonly property string face: "Saira"
    readonly property string icons: "Material Symbols Sharp"

    // cel palette (cool, matched to the wallpaper)
    readonly property color line: "#0a1230"
    readonly property color hi: "#ffffff"
    readonly property color light: dh.mix("#e6eef9", "#e2f7e6")
    readonly property color base: dh.mix("#b2c3df", "#9fd8a8")
    readonly property color shade: dh.mix("#5c70a2", "#3f8a50")
    readonly property color rim: dh.mix("#62e8ff", "#50ff82")
    readonly property color dark: dh.mix("#1c2442", "#0f2a18")
    readonly property color darkHi: dh.mix("#3b4a76", "#2a5a36")
    readonly property color lcdText: dh.mix("#b0eaff", "#b4ffcc")

    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    readonly property bool hasTrack: !!player && (player.trackTitle ?? "") !== ""
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool canAnimate: playing && motion.live
    Motion { id: motion }
    readonly property string lcdLine: {
        if (!hasTrack) return "NO MUSIC";
        const a = player.trackArtist ?? "";
        return a ? `${player.trackTitle}  —  ${a}` : player.trackTitle;
    }

    // two-tone cel shading for a horizontal cylinder lit from above, cyan rim underneath
    component CelTube: Gradient {
        GradientStop { position: 0.00; color: root.light }
        GradientStop { position: 0.34; color: root.light }
        GradientStop { position: 0.341; color: root.base }
        GradientStop { position: 0.62; color: root.base }
        GradientStop { position: 0.621; color: root.shade }
        GradientStop { position: 0.85; color: root.shade }
        GradientStop { position: 0.851; color: root.rim }
        GradientStop { position: 1.00; color: root.rim }
    }
    component CelRubber: Gradient {
        GradientStop { position: 0.00; color: root.darkHi }
        GradientStop { position: 0.36; color: root.darkHi }
        GradientStop { position: 0.361; color: root.dark }
        GradientStop { position: 0.84; color: root.dark }
        GradientStop { position: 0.841; color: "#2c79a8" }
        GradientStop { position: 1.00; color: "#2c79a8" }
    }

    // white four-point anime sparkle
    component Sparkle: Shape {
        id: sp
        property real s: 18
        width: s; height: s
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.hi
            strokeColor: "transparent"
            startX: sp.s / 2; startY: 0
            PathQuad { x: sp.s; y: sp.s / 2; controlX: sp.s * 0.56; controlY: sp.s * 0.44 }
            PathQuad { x: sp.s / 2; y: sp.s; controlX: sp.s * 0.56; controlY: sp.s * 0.56 }
            PathQuad { x: 0; y: sp.s / 2; controlX: sp.s * 0.44; controlY: sp.s * 0.56 }
            PathQuad { x: sp.s / 2; y: 0; controlX: sp.s * 0.44; controlY: sp.s * 0.44 }
        }
    }

    // cel-shaded round clip-on earphone (heavy lineart, two tones, rim light, highlight)
    component Earphone: Item {
        id: ep
        property real size: 76
        property bool mirror: false
        width: size
        height: size

        Shape {
            x: -ep.size * 0.18
            y: -ep.size * 0.30
            width: ep.size * 1.36
            height: ep.size * 1.2
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { origin.x: ep.size * 0.68; xScale: ep.mirror ? -1 : 1 }
            ShapePath {
                strokeColor: root.line; strokeWidth: 10; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: ep.size * 0.30; startY: ep.size * 0.64
                PathCubic { x: ep.size * 1.18; y: ep.size * 0.42; control1X: ep.size * 0.04; control1Y: -ep.size * 0.06; control2X: ep.size * 1.06; control2Y: -ep.size * 0.10 }
            }
            ShapePath {
                strokeColor: root.dark; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: ep.size * 0.30; startY: ep.size * 0.64
                PathCubic { x: ep.size * 1.18; y: ep.size * 0.42; control1X: ep.size * 0.04; control1Y: -ep.size * 0.06; control2X: ep.size * 1.06; control2Y: -ep.size * 0.10 }
            }
            ShapePath {
                strokeColor: root.darkHi; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: ep.size * 0.38; startY: ep.size * 0.12
                PathQuad { x: ep.size * 0.84; y: ep.size * 0.06; controlX: ep.size * 0.60; controlY: -ep.size * 0.05 }
            }
        }
        // cable stub
        Rectangle {
            x: ep.size * 0.5 - 6; y: ep.size * 0.84
            width: 12; height: 18; radius: 4
            color: root.line
            Rectangle { x: 2.5; y: 0; width: parent.width - 5; height: parent.height - 3; radius: 3; color: root.dark }
        }
        // heavy lineart disc (offset toward the shadow side)
        Rectangle { x: -3; y: -3; width: parent.width + 6; height: parent.height + 7; radius: width / 2; color: root.line }
        // two-tone body: shade, lit disc offset toward the light, cyan rim
        Rectangle { anchors.fill: parent; radius: width / 2; color: root.rim }
        Rectangle { x: -1; y: -1; width: parent.width - 3; height: width; radius: width / 2; color: root.shade }
        Rectangle { x: -1; y: -1; width: parent.width * 0.86; height: width; radius: width / 2; color: root.base }
        // face plate
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.66; height: width
            radius: width / 2
            color: root.line
            Rectangle { anchors.centerIn: parent; width: parent.width - 4; height: width; radius: width / 2; color: root.light }
            Rectangle {   // hard shadow crescent inside the face
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 3; anchors.verticalCenterOffset: 3
                width: parent.width - 8; height: width; radius: width / 2
                color: "transparent"; border.color: root.base; border.width: 3
            }
        }
        Repeater {
            model: 10
            Rectangle {
                required property int index
                readonly property real a: index / 10 * Math.PI * 2
                x: ep.size / 2 + Math.cos(a) * ep.size * 0.21 - 1.8
                y: ep.size / 2 + Math.sin(a) * ep.size * 0.21 - 1.8
                width: 3.6; height: 3.6; radius: 1.8
                color: root.line
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.2; height: width; radius: width / 2
            color: root.line
            Rectangle { anchors.centerIn: parent; width: parent.width - 4; height: width; radius: width / 2; color: root.base }
        }
        // big highlight + dot
        Rectangle { x: parent.width * 0.16; y: parent.height * 0.15; width: parent.width * 0.3; height: parent.height * 0.1; radius: height / 2; rotation: -38; color: root.hi }
        Rectangle { x: parent.width * 0.48; y: parent.height * 0.09; width: 5; height: 5; radius: 2.5; color: root.hi }
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { left: true; bottom: true }
            margins { left: 20; bottom: 6 }
            implicitWidth: 230
            implicitHeight: 420
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "p3-player"
            color: "transparent"
            mask: Region {}

            readonly property real tilt: 75
            readonly property point stickCenter: Qt.point(112, 250)
            // a point along the stick (level x from centre) after rotation
            function along(vx: real, vy: real): point {
                const a = tilt * Math.PI / 180;
                return Qt.point(stickCenter.x + vx * Math.cos(a) - vy * Math.sin(a),
                                stickCenter.y + vx * Math.sin(a) + vy * Math.cos(a));
            }
            readonly property point plug: along(-stick.width / 2 + 2, 0)
            readonly property point cap: along(stick.width / 2 - 26, -10)

            // earphones resting behind the player: the cable leaves the top end, loops down
            // to a Y-split and runs to both earpieces, which tuck partly under the stick
            readonly property point split: Qt.point(34, 196)
            readonly property point earL: Qt.point(36, 262)    // top-left of the left earpiece
            readonly property point earR: Qt.point(118, 170)   // top-left of the right earpiece
            readonly property real earSize: 76

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                component Wire: ShapePath { fillColor: "transparent"; capStyle: ShapePath.RoundCap }
                // lineart pass
                Wire {
                    strokeColor: root.line; strokeWidth: 6.5
                    startX: win.plug.x; startY: win.plug.y
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.plug.x - 10; control1Y: win.plug.y - 80; control2X: win.split.x - 40; control2Y: win.split.y - 70 }
                }
                Wire {
                    strokeColor: root.line; strokeWidth: 5.5
                    startX: win.split.x; startY: win.split.y + 8
                    PathCubic { x: win.earL.x + win.earSize * 0.5; y: win.earL.y + win.earSize + 14; control1X: win.split.x - 20; control1Y: win.split.y + 80; control2X: win.earL.x + 10; control2Y: win.earL.y + win.earSize + 40 }
                }
                Wire {
                    strokeColor: root.line; strokeWidth: 5.5
                    startX: win.split.x; startY: win.split.y + 8
                    PathCubic { x: win.earR.x + win.earSize * 0.5; y: win.earR.y + win.earSize + 14; control1X: win.split.x + 30; control1Y: win.split.y + 40; control2X: win.earR.x + 20; control2Y: win.earR.y + win.earSize + 50 }
                }
                // core pass
                Wire {
                    strokeColor: root.darkHi; strokeWidth: 2.4
                    startX: win.plug.x; startY: win.plug.y
                    PathCubic { x: win.split.x; y: win.split.y; control1X: win.plug.x - 10; control1Y: win.plug.y - 80; control2X: win.split.x - 40; control2Y: win.split.y - 70 }
                }
                Wire {
                    strokeColor: root.darkHi; strokeWidth: 2
                    startX: win.split.x; startY: win.split.y + 8
                    PathCubic { x: win.earL.x + win.earSize * 0.5; y: win.earL.y + win.earSize + 14; control1X: win.split.x - 20; control1Y: win.split.y + 80; control2X: win.earL.x + 10; control2Y: win.earL.y + win.earSize + 40 }
                }
                Wire {
                    strokeColor: root.darkHi; strokeWidth: 2
                    startX: win.split.x; startY: win.split.y + 8
                    PathCubic { x: win.earR.x + win.earSize * 0.5; y: win.earR.y + win.earSize + 14; control1X: win.split.x + 30; control1Y: win.split.y + 40; control2X: win.earR.x + 20; control2Y: win.earR.y + win.earSize + 50 }
                }
            }
            // Y-split bead
            Rectangle {
                x: win.split.x - 7; y: win.split.y - 10
                width: 14; height: 22; radius: 6
                color: root.line
                Rectangle { x: 2.5; y: 2; width: parent.width - 5; height: parent.height - 5; radius: 4; color: root.dark }
                Rectangle { x: 2.5; y: 9; width: parent.width - 5; height: 3; color: root.base }
            }

            Earphone { x: win.earL.x; y: win.earL.y; size: win.earSize; rotation: -18 }
            Earphone { x: win.earR.x; y: win.earR.y; size: win.earSize; mirror: true; rotation: 24 }

            // ── the stick, drawn level then tilted as one smooth layer ─────────
            Item {
                id: stick
                width: 300
                height: 50
                x: win.stickCenter.x - width / 2
                y: win.stickCenter.y - height / 2
                rotation: win.tilt
                layer.enabled: true
                layer.smooth: true
                layer.samples: 4
                layer.textureSize: Qt.size(width * 3, height * 3)

                // flat contact shadow
                Rectangle {
                    x: 3; y: 8
                    width: parent.width; height: parent.height
                    radius: height / 2
                    color: Qt.alpha("#050d2a", 0.38)
                }
                // heavy lineart: an outline slab offset toward the shadow side
                Rectangle {
                    x: -3; y: -3
                    width: parent.width + 6; height: parent.height + 8
                    radius: height / 2
                    color: root.line
                }
                // back clip (lineart then fill)
                Rectangle {
                    x: 74; y: parent.height - 4
                    width: 140; height: 11; radius: 4
                    color: root.line
                    Rectangle { x: 2.5; y: 0; width: parent.width - 5; height: parent.height - 3; radius: 3; color: root.shade }
                }
                // tube body
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: CelTube {}
                }
                // hatch strokes in the shadow band near the cap
                Repeater {
                    model: 6
                    Rectangle {
                        required property int index
                        x: stick.width - 118 + index * 9
                        y: stick.height * 0.64
                        width: 1.6; height: stick.height * 0.19
                        rotation: 28
                        color: Qt.alpha(root.line, 0.45)
                    }
                }
                // cap grooves
                Repeater {
                    model: [stick.width - 60, stick.width - 52]
                    Rectangle {
                        required property real modelData
                        x: modelData; y: 2
                        width: 2; height: stick.height - 4
                        color: root.line
                    }
                }
                // rubber cable end with ribs
                Rectangle {
                    width: 46; height: parent.height
                    radius: height / 2
                    gradient: CelRubber {}
                }
                Rectangle { x: 30; width: 16; height: parent.height; gradient: CelRubber {} }
                Repeater {
                    model: [12, 20, 28, 36]
                    Rectangle {
                        required property real modelData
                        x: modelData; y: 4
                        width: 2; height: stick.height - 8
                        color: root.line
                    }
                }
                Rectangle { x: 46; width: 2.6; height: parent.height; color: root.line }
                // hold switch
                Rectangle {
                    x: 58; y: -6
                    width: 24; height: 10; radius: 4
                    color: root.line
                    Rectangle { x: 2; y: 2; width: parent.width - 4; height: parent.height - 3; radius: 3; color: root.light }
                }

                // LCD: navy bezel, flat backlit panel
                Rectangle {
                    id: bezel
                    x: 55; y: 9
                    width: parent.width - 55 - 70
                    height: parent.height - 18
                    radius: 4
                    color: root.line

                    Rectangle {
                        id: lcd
                        anchors.fill: parent
                        anchors.margins: 2.5
                        radius: 2
                        clip: true
                        color: "#123479"

                        Rectangle { width: parent.width; height: parent.height * 0.42; color: "#1b4a9e" }
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
                                font.pixelSize: 15
                                color: Qt.alpha(root.lcdText, root.hasTrack ? 0.9 : 0.5)
                            }
                        }
                        Text {
                            id: glyph
                            anchors { left: artBox.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            text: root.playing ? "play_arrow" : root.hasTrack ? "pause" : "stop"
                            font.family: root.icons
                            font.pixelSize: 15
                            color: root.lcdText
                        }
                        ScreenLine {
                            anchors { left: glyph.right; leftMargin: 4; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: root.lcdLine
                            font: Qt.font({ family: root.face, weight: Font.Bold, pixelSize: 14, letterSpacing: 0.6 })
                            color: root.hasTrack ? root.lcdText : Qt.alpha(root.lcdText, 0.55)
                        }
                        // anime screen shine: two parallel diagonal bars
                        Rectangle { x: parent.width * 0.6; y: -10; width: 10; height: parent.height + 20; rotation: 30; color: Qt.alpha(root.hi, 0.3) }
                        Rectangle { x: parent.width * 0.6 + 16; y: -10; width: 4; height: parent.height + 20; rotation: 30; color: Qt.alpha(root.hi, 0.3) }
                    }
                }

                // status light
                Rectangle {
                    x: parent.width - 42
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    width: 8; height: 8; radius: 4
                    color: root.line
                    Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: root.playing ? root.rim : root.base }
                }

                // big clean highlight along the top, and a smaller dash
                Rectangle { x: parent.width - 52; y: 6; width: 30; height: 5; radius: 2.5; color: root.hi }
                Rectangle { x: parent.width - 18; y: 8; width: 5; height: 4; radius: 2; color: root.hi }
                Rectangle { x: 12; y: 6; width: 22; height: 3.5; radius: 1.8; color: Qt.alpha(root.hi, 0.7) }
            }

            // sparkles near the cap's highlight
            Sparkle { s: 22; x: win.cap.x + 8; y: win.cap.y - 18 }
            Sparkle { s: 11; x: win.cap.x + 30; y: win.cap.y + 6 }
        }
    }
}
