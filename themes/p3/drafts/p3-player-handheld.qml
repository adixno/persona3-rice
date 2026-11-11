// p3-player: a "now playing" desktop widget for the Persona 3 theme, drawn as an
// original slim portable music player on a neck strap (inspired by mid-2000s neck-strap
// players; no brand, no game art): silver-white rounded body, a small dark screen showing the
// album art, title and artist of whatever MPRIS player is active, a round control wheel, the
// strap rising off the top and an earphone cable curling out of the bottom.
// Display only (no controls). Idle: "NO MUSIC". Long titles scroll slowly only while music
// plays on AC power; otherwise they are elided, so the widget never redraws when idle.
// Bottom-left corner, Bottom layer: above the wallpaper, below windows.
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
    readonly property color cyan: "#2ff3ff"
    readonly property color lcd: "#061238"

    // the player to show: one that is playing, else the first one with a track
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    readonly property bool hasTrack: !!player && (player.trackTitle ?? "") !== ""
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool canAnimate: playing && (UPower.displayDevice?.ready ?? false) && !UPower.onBattery

    // one line of screen text: scrolls when too long and allowed to animate, else elides
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

        // static, elided (shown unless scrolling)
        Text {
            width: line.width
            visible: !line.scroll
            text: line.text
            font: line.font
            color: line.color
            elide: Text.ElideRight
        }
        // full length, slid by `offset` (shown only while scrolling)
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { left: true; bottom: true }
            margins { left: 26; bottom: 0 }
            implicitWidth: 230
            implicitHeight: 330
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "p3-player"
            color: "transparent"
            mask: Region { item: body }   // only the player body takes clicks/hover

            // strap: two cords rising off the top of the window
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#1b2340"
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: body.x + body.width * 0.42; startY: body.y + 6
                    PathCubic { x: body.x + body.width * 0.30; y: -4; control1X: body.x + body.width * 0.40; control1Y: body.y - 30; control2X: body.x + body.width * 0.30; control2Y: 30 }
                }
                ShapePath {
                    strokeColor: "#1b2340"
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: body.x + body.width * 0.58; startY: body.y + 6
                    PathCubic { x: body.x + body.width * 0.72; y: -4; control1X: body.x + body.width * 0.60; control1Y: body.y - 30; control2X: body.x + body.width * 0.72; control2Y: 30 }
                }
                // earphone cable curling out of the bottom and off the screen edge
                ShapePath {
                    strokeColor: "#e9eef6"
                    strokeWidth: 2.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: body.x + body.width * 0.5; startY: body.y + body.height - 2
                    PathCubic { x: body.x + body.width + 40; y: win.height + 4; control1X: body.x + body.width * 0.5; control1Y: body.y + body.height + 26; control2X: body.x + body.width + 10; control2Y: body.y + body.height - 4 }
                }
            }

            // ── the player ──────────────────────────────────────────────────
            Item {
                id: body
                x: 34
                y: 64
                width: 150
                height: 236

                // soft shadow
                Rectangle {
                    x: 4; y: 6
                    width: parent.width; height: parent.height
                    radius: 30
                    color: Qt.alpha("#000814", 0.35)
                }
                // silver-white shell
                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#fbfcfe" }
                        GradientStop { position: 0.55; color: "#dfe5ee" }
                        GradientStop { position: 1.0; color: "#b9c3d1" }
                    }
                    border.color: "#9aa6b8"
                    border.width: 1
                }
                // glossy highlight down the left side
                Rectangle {
                    x: 7; y: 14
                    width: 10; height: parent.height - 44
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha("#ffffff", 0.9) }
                        GradientStop { position: 1.0; color: Qt.alpha("#ffffff", 0.0) }
                    }
                }
                // strap loop on top
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -5
                    width: 40; height: 12
                    radius: 6
                    color: "#c7cfdb"
                    border.color: "#9aa6b8"
                    border.width: 1
                }

                // screen
                Rectangle {
                    id: screenFrame
                    x: 14; y: 18
                    width: parent.width - 28
                    height: 118
                    radius: 10
                    color: "#2a3346"
                    Rectangle {
                        id: screen
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 7
                        color: root.lcd
                        clip: true

                        // album art (or a note when there is none / nothing playing)
                        Rectangle {
                            id: artBox
                            x: 7; y: 7
                            width: 50; height: 50
                            radius: 4
                            color: "#0d2160"
                            Image {
                                id: art
                                anchors.fill: parent
                                source: root.hasTrack ? (root.player.trackArtUrl ?? "") : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(100, 100)
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !art.visible
                                text: "music_note"
                                font.family: root.icons
                                font.pixelSize: 26
                                color: Qt.alpha(root.cyan, root.hasTrack ? 0.9 : 0.4)
                            }
                        }
                        // play state + small label next to the art
                        Column {
                            anchors { left: artBox.right; leftMargin: 6; right: parent.right; rightMargin: 3; top: artBox.top }
                            spacing: 1
                            Text {
                                text: root.playing ? "play_arrow" : root.hasTrack ? "pause" : "stop"
                                font.family: root.icons
                                font.pixelSize: 18
                                color: root.cyan
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.playing ? "PLAYING" : root.hasTrack ? "PAUSED" : "IDLE"
                                font.family: root.face
                                font.weight: Font.DemiBold
                                font.pixelSize: 9
                                font.letterSpacing: 0.4
                                color: Qt.alpha(root.cyan, 0.75)
                            }
                        }
                        // title + artist
                        ScreenLine {
                            anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
                            y: artBox.y + artBox.height + 7
                            text: root.hasTrack ? root.player.trackTitle : "NO MUSIC"
                            font: Qt.font({ family: root.face, weight: Font.Bold, pixelSize: 14 })
                            color: root.hasTrack ? "#ffffff" : Qt.alpha("#ffffff", 0.5)
                        }
                        ScreenLine {
                            anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
                            y: artBox.y + artBox.height + 26
                            text: root.hasTrack ? (root.player.trackArtist ?? "") : "play something"
                            font: Qt.font({ family: root.face, weight: Font.Medium, pixelSize: 11 })
                            color: Qt.alpha(root.cyan, root.hasTrack ? 0.85 : 0.4)
                        }
                        // faint screen glare
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: parent.height * 0.45
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.alpha("#ffffff", 0.07) }
                                GradientStop { position: 1.0; color: Qt.alpha("#ffffff", 0.0) }
                            }
                        }
                    }
                }

                // round control wheel (decorative)
                Item {
                    id: wheel
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: screenFrame.y + screenFrame.height + 12
                    width: 78; height: 78
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#c3ccd9" }
                            GradientStop { position: 1.0; color: "#eef2f7" }
                        }
                        border.color: "#9aa6b8"
                        border.width: 1
                    }
                    // little marks on the ring
                    Repeater {
                        model: [["skip_previous", -26, 0], ["skip_next", 26, 0], ["add", 0, -26], ["remove", 0, 26]]
                        Text {
                            required property var modelData
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: modelData[1]
                            anchors.verticalCenterOffset: modelData[2]
                            text: modelData[0]
                            font.family: root.icons
                            font.pixelSize: 12
                            color: "#7d8899"
                        }
                    }
                    // centre button
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#f8fafd" }
                            GradientStop { position: 1.0; color: "#cfd7e2" }
                        }
                        border.color: "#9aa6b8"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "play_pause"
                            font.family: root.icons
                            font.pixelSize: 14
                            color: "#7d8899"
                        }
                    }
                }

                // small status light on the shell: cyan while playing
                Rectangle {
                    anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 14 }
                    width: 6; height: 6
                    radius: 3
                    color: root.playing ? root.cyan : "#8a95a6"
                }
            }
        }
    }
}
