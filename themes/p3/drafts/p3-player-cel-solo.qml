// p3-player: a "now playing" desktop widget for the Persona 3 theme, drawn like a
// cel-shaded anime prop so it sits in the anime wallpaper: two-tone hard shading with a cyan
// rim light, hatch strokes in the shadow, bold navy lineart that is heavier on the shadow side,
// one big clean highlight and white ✦ sparkles. The object is an original stick-style music
// player (generic mid-2000s form; no brand, no game art) standing nearly upright (tilted ~15°)
// with a short cable curling out of its top end.
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
    readonly property color line: "#0a1230"
    readonly property color hi: "#ffffff"
    readonly property color light: "#e6eef9"
    readonly property color base: "#b2c3df"
    readonly property color shade: "#5c70a2"
    readonly property color rim: "#62e8ff"
    readonly property color dark: "#1c2442"
    readonly property color darkHi: "#3b4a76"
    readonly property color lcdText: "#b0eaff"

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

            // short cable curling out of the top end: lineart stroke + lighter core
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.line; strokeWidth: 6.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.plug.x; startY: win.plug.y
                    PathCubic { x: win.plug.x + 40; y: win.plug.y - 52; control1X: win.plug.x - 22; control1Y: win.plug.y - 50; control2X: win.plug.x + 6; control2Y: win.plug.y - 72 }
                    PathCubic { x: win.plug.x + 64; y: 4; control1X: win.plug.x + 64; control1Y: win.plug.y - 40; control2X: win.plug.x + 30; control2Y: 40 }
                }
                ShapePath {
                    strokeColor: root.darkHi; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: win.plug.x; startY: win.plug.y
                    PathCubic { x: win.plug.x + 40; y: win.plug.y - 52; control1X: win.plug.x - 22; control1Y: win.plug.y - 50; control2X: win.plug.x + 6; control2Y: win.plug.y - 72 }
                    PathCubic { x: win.plug.x + 64; y: 4; control1X: win.plug.x + 64; control1Y: win.plug.y - 40; control2X: win.plug.x + 30; control2Y: 40 }
                }
            }

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
