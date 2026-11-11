// Ransom-note lettering: every glyph is its own tilted cut-out tile.
// Mirrors the Ransom component in persona-bar/shell.qml.
import QtQuick
import qs.services

Row {
    id: root

    property string text
    property real size: 22
    property int seed: hash(text)
    property int forceStyle: -1 // 0 white tile, 1 black tile, 2 red tile, 3 bare
    property bool autoGlitch: false
    property bool glitching: false
    property int tick: 0

    readonly property color red: Colours.palette.m3primary
    readonly property color ink: Colours.palette.m3background
    readonly property color paper: Colours.palette.m3onSurface
    readonly property var cutFonts: [
        ["Bebas Neue", Font.Normal, false],
        ["Antonio", Font.Bold, false],
        ["Noto Sans", Font.Black, true],
        ["DejaVu Serif", Font.Bold, false],
        ["Noto Serif", Font.Black, true],
        ["JetBrainsMono NF", Font.ExtraBold, false]
    ]

    function rnd(s: real, i: real, k: real): real {
        const x = Math.sin(s * 12.9898 + i * 78.233 + k * 37.719) * 43758.5453;
        return x - Math.floor(x);
    }

    function hash(s: string): int {
        let h = 7;
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 100003;
        return h;
    }

    function glitch(): void {
        burstTimer.left = 7;
        burstTimer.restart();
    }

    spacing: -size * 0.08
    onTextChanged: glitch()

    Timer {
        id: burstTimer

        property int left: 0

        interval: 45
        repeat: true
        onTriggered: {
            root.tick++;
            root.glitching = --left > 0;
            if (left <= 0)
                stop();
        }
    }

    Timer {
        running: root.autoGlitch
        repeat: true
        interval: 4000 + Math.floor(root.rnd(root.seed, root.tick, 9) * 9000)
        onTriggered: root.glitch()
    }

    Repeater {
        model: root.text.length

        Item {
            id: g

            required property int index
            readonly property string ch: root.text.charAt(index)
            readonly property real n1: root.rnd(root.seed, index, 1)
            readonly property real n2: root.rnd(root.seed, index, 2)
            readonly property real n3: root.rnd(root.seed, index, 5)
            readonly property var face: root.cutFonts[Math.floor(n1 * root.cutFonts.length)]
            readonly property int style: root.forceStyle >= 0 ? root.forceStyle : n2 < 0.36 ? 0 : n2 < 0.66 ? 1 : n2 < 0.86 ? 2 : 3
            readonly property real jitter: root.glitching ? (root.rnd(root.tick, index, 7) - 0.5) * root.size * 0.25 : 0

            width: ch === " " ? root.size * 0.3 : tile.width
            height: root.size * 1.3

            Rectangle {
                id: tile

                visible: g.ch !== " "
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: (g.n3 - 0.5) * root.size * 0.18
                x: g.jitter
                width: glyph.implicitWidth + root.size * 0.22
                height: glyph.implicitHeight * 0.92
                rotation: (g.n3 - 0.5) * 18
                antialiasing: true
                color: g.style === 0 ? root.paper : g.style === 1 ? root.ink : g.style === 2 ? root.red : "transparent"
                border.color: g.style === 1 ? root.paper : root.ink
                border.width: g.style === 3 ? 0 : Math.max(2, root.size * 0.04)

                // red/cyan split while glitching
                Text {
                    visible: root.glitching
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -root.size * 0.1
                    text: g.ch
                    font: glyph.font
                    color: Qt.alpha(root.red, 0.85)
                }
                Text {
                    visible: root.glitching
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.size * 0.1
                    text: g.ch
                    font: glyph.font
                    color: Qt.alpha("#00e5ff", 0.75)
                }
                Text {
                    id: glyph

                    anchors.centerIn: parent
                    text: g.ch
                    font.family: g.face[0]
                    font.weight: g.face[1]
                    font.italic: g.face[2]
                    font.pixelSize: root.size * (0.86 + g.n1 * 0.3)
                    color: g.style === 0 ? root.ink : root.paper
                    style: g.style === 3 ? Text.Outline : Text.Normal
                    styleColor: root.ink
                }
            }
        }
    }
}
