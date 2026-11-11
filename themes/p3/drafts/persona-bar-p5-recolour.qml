// Bottom taskbar: punk / ransom-note style, matched to the Caelestia "persona" scheme.
// Colours are read live from Caelestia's scheme.json; shell actions go through the caelestia CLI.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth

ShellRoot {
    id: root

    // ---- theme ----
    property var colours: ({})
    readonly property color red: "#" + (colours.primary ?? "e60012")
    readonly property color redDeep: "#" + (colours.primaryContainer ?? "5c0007")
    readonly property color ink: "#" + (colours.background ?? "0a0a0a")
    readonly property color paper: "#" + (colours.onSurface ?? "f4f4f4")
    readonly property color dim: "#" + (colours.onSurfaceVariant ?? "c8c8c8")
    readonly property color cyan: "#00e5ff" // glitch split only
    readonly property string icons: "Material Symbols Sharp"

    readonly property int barHeight: 50 // reserved space; keep in sync with sync-caelestia.sh
    readonly property int tear: 10 // extra height for the torn bottom edge

    // fonts mixed by the ransom-note lettering: [family, weight, italic]
    readonly property var cutFonts: [
        ["Bebas Neue", Font.Normal, false],
        ["Antonio", Font.Bold, false],
        ["Noto Sans", Font.Black, true],
        ["DejaVu Serif", Font.Bold, false],
        ["Noto Serif", Font.Black, true],
        ["JetBrainsMono NF", Font.ExtraBold, false]
    ]

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colours = JSON.parse(text()).colours;
            } catch (e) {
                console.warn("persona-bar: bad scheme.json", e);
            }
        }
    }

    // deterministic noise in [0, 1)
    function rnd(seed: real, i: real, k: real): real {
        const x = Math.sin(seed * 12.9898 + i * 78.233 + k * 37.719) * 43758.5453;
        return x - Math.floor(x);
    }

    function hash(s: string): int {
        let h = 7;
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 100003;
        return h;
    }

    // jagged starburst outline fitted to w x h
    function burst(w: real, h: real, spikes: int, seed: real, grow: real): var {
        const pts = [];
        const n = spikes * 2;
        for (let i = 0; i <= n; i++) {
            const a = (i % n) / n * Math.PI * 2 - Math.PI / 2;
            const outer = i % 2 === 0;
            const r = (outer ? 1 : 0.68 + 0.14 * rnd(seed, i, 3)) * (0.86 + 0.14 * rnd(seed, i, 4)) + grow;
            pts.push(Qt.point(w / 2 + Math.cos(a) * w / 2 * r, h / 2 + Math.sin(a) * h / 2 * r));
        }
        return pts;
    }

    function caelestia(args: list<string>): void {
        Quickshell.execDetached(["caelestia", ...args]);
    }

    // open Caelestia's settings on a page; needs the openPage IPC from caelestia-patches.py,
    // falls back to the plain settings window if the patched copy isn't running
    function openSettings(page: string): void {
        Quickshell.execDetached(["sh", "-c",
            'if qs -c caelestia ipc show 2>/dev/null | grep -q "openPage"; then caelestia shell nexus openPage "$1"; else caelestia shell nexus open; fi',
            "sh", page]);
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---- reusable pieces ----

    // Ransom-note lettering: every glyph is its own cut-out tile
    component Ransom: Row {
        id: r
        property string text
        property real size: 22
        property int seed: root.hash(text)
        property int forceStyle: -1 // 0 white tile, 1 black tile, 2 red tile, 3 bare
        property bool autoGlitch: false
        property bool glitching: false
        property int tick: 0

        function glitch(): void {
            burstTimer.left = 7;
            burstTimer.restart();
        }

        spacing: -2
        onTextChanged: glitch()

        Timer {
            id: burstTimer
            property int left: 0
            interval: 45
            repeat: true
            onTriggered: {
                r.tick++;
                r.glitching = --left > 0;
                if (left <= 0)
                    stop();
            }
        }
        Timer {
            running: r.autoGlitch
            repeat: true
            interval: 4000 + Math.floor(root.rnd(r.seed, r.tick, 9) * 9000)
            onTriggered: r.glitch()
        }

        Repeater {
            model: r.text.length

            Item {
                id: g
                required property int index
                readonly property string ch: r.text.charAt(index)
                readonly property real n1: root.rnd(r.seed, index, 1)
                readonly property real n2: root.rnd(r.seed, index, 2)
                readonly property real n3: root.rnd(r.seed, index, 5)
                readonly property var face: root.cutFonts[Math.floor(n1 * root.cutFonts.length)]
                readonly property int style: r.forceStyle >= 0 ? r.forceStyle : n2 < 0.36 ? 0 : n2 < 0.66 ? 1 : n2 < 0.86 ? 2 : 3
                readonly property real jitter: r.glitching ? (root.rnd(r.tick, index, 7) - 0.5) * 6 : 0

                width: ch === " " ? r.size * 0.3 : tile.width
                height: r.size * 1.3

                Rectangle {
                    id: tile
                    visible: g.ch !== " "
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: (g.n3 - 0.5) * r.size * 0.18
                    x: g.jitter
                    width: glyph.implicitWidth + r.size * 0.22
                    height: glyph.implicitHeight * 0.92
                    rotation: (g.n3 - 0.5) * 18
                    antialiasing: true
                    color: g.style === 0 ? root.paper : g.style === 1 ? root.ink : g.style === 2 ? root.red : "transparent"
                    border.color: g.style === 1 ? root.paper : root.ink
                    border.width: g.style === 3 ? 0 : 2

                    // red/cyan split while glitching
                    Text {
                        visible: r.glitching
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -3
                        text: g.ch
                        font: glyph.font
                        color: Qt.alpha(root.red, 0.85)
                    }
                    Text {
                        visible: r.glitching
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 3
                        text: g.ch
                        font: glyph.font
                        color: Qt.alpha(root.cyan, 0.75)
                    }
                    Text {
                        id: glyph
                        anchors.centerIn: parent
                        text: g.ch
                        font.family: g.face[0]
                        font.weight: g.face[1]
                        font.italic: g.face[2]
                        font.pixelSize: r.size * (0.86 + g.n1 * 0.3)
                        color: g.style === 0 ? root.ink : root.paper
                        style: g.style === 3 ? Text.Outline : Text.Normal
                        styleColor: root.ink
                    }
                }
            }
        }
    }

    // Starburst sticker: white outline, coloured core
    component Burst: Shape {
        id: b
        property color fill: root.red
        property color edge: root.paper
        property int spikes: 11
        property int seed: 3
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.ink
            strokeWidth: -1
            PathPolyline { path: root.burst(b.width, b.height, b.spikes, b.seed, 0.12) }
        }
        ShapePath {
            fillColor: b.edge
            strokeWidth: -1
            PathPolyline { path: root.burst(b.width, b.height, b.spikes, b.seed, 0.06) }
        }
        ShapePath {
            fillColor: b.fill
            strokeWidth: -1
            PathPolyline { path: root.burst(b.width, b.height, b.spikes, b.seed, -0.04) }
        }
    }

    component Icon: Text {
        font.family: root.icons
        font.pixelSize: 20
        color: root.paper
        verticalAlignment: Text.AlignVCenter
    }

    // Tilted card drawn as a vector path so its edges stay smooth at fractional scaling
    // (rotated Rectangles look jagged at 1.5x). Fill, inner border and a hard offset shadow.
    // The Shape sits inside a plain Item so the shadow never feeds back into the size.
    component Card: Item {
        id: card
        property real tilt: 0
        property color fill: root.ink
        property color outline: root.paper
        property real outlineWidth: 3
        property color shadow: root.red
        property real shadowOffset: 4

        // corners of the item rect rotated by `tilt` around its centre, inset by `inset`, then moved by (dx, dy)
        function box(inset: real, dx: real, dy: real): var {
            const a = tilt * Math.PI / 180, c = Math.cos(a), s = Math.sin(a);
            const cx = width / 2, cy = height / 2, hw = width / 2 - inset, hh = height / 2 - inset;
            const pts = [[-hw, -hh], [hw, -hh], [hw, hh], [-hw, hh], [-hw, -hh]];
            return pts.map(p => Qt.point(cx + p[0] * c - p[1] * s + dx, cy + p[0] * s + p[1] * c + dy));
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: card.shadow
                strokeWidth: -1
                PathPolyline { path: card.box(0, card.shadowOffset, card.shadowOffset) }
            }
            ShapePath {
                fillColor: card.fill
                strokeColor: card.outlineWidth > 0 ? card.outline : "transparent"
                strokeWidth: card.outlineWidth > 0 ? card.outlineWidth : -1
                joinStyle: ShapePath.MiterJoin
                PathPolyline { path: card.box(card.outlineWidth / 2, 0, 0) }
            }
        }
    }

    // Tilted sticker chip: black card, white border, red offset shadow
    component Chip: Item {
        id: chip
        property string icon
        property string label
        property bool hot: false
        property real tilt: -3
        // icon only (label hidden) when the bar runs out of room; hot chips keep their label
        property bool compact: false
        // width the label adds when shown, so the bar can work out what fits
        readonly property real labelExtra: label !== "" ? lbl.implicitWidth + row.spacing : 0
        // width with the label shown, independent of compact (no binding loop)
        readonly property real fullWidth: 22 + (icon !== "" ? ic.implicitWidth : 0) + labelExtra
        signal clicked(var mouse)
        signal scrolled(int delta)

        implicitWidth: row.implicitWidth + 22
        implicitHeight: 34
        scale: area.containsMouse ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

        Card {
            anchors.fill: parent
            tilt: chip.tilt
            fill: chip.hot || area.containsMouse ? root.red : root.ink
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            rotation: chip.tilt
            spacing: 4

            Icon {
                id: ic
                visible: chip.icon !== ""
                text: chip.icon
                color: chip.hot || area.containsMouse ? root.paper : root.red
            }
            Ransom {
                id: lbl
                visible: chip.label !== "" && (!chip.compact || chip.hot)
                text: chip.label
                size: 17
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onEntered: lbl.glitch()
            onClicked: mouse => chip.clicked(mouse)
            onWheel: wheel => chip.scrolled(wheel.angleDelta.y)
        }
    }

    // ---- the bar ----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors { left: true; right: true; top: true }
            implicitHeight: root.barHeight + root.tear
            exclusiveZone: root.barHeight
            color: "transparent"

            readonly property var monitor: Hyprland.monitorFor(modelData)

            // torn-paper background: red under-layer peeking out below the black (drawn top-up, then flipped)
            Shape {
                id: torn
                anchors.fill: parent
                transform: Scale { yScale: -1; origin.y: torn.height / 2 }
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.red
                    strokeWidth: -1
                    PathPolyline { path: torn.tornEdge(bar.width, bar.height, 0, 41) }
                }
                ShapePath {
                    fillColor: root.paper
                    strokeWidth: -1
                    PathPolyline { path: torn.tornEdge(bar.width, bar.height, 4, 17) }
                }
                ShapePath {
                    fillColor: root.ink
                    strokeWidth: -1
                    PathPolyline { path: torn.tornEdge(bar.width, bar.height, 7, 5) }
                }

                function tornEdge(w: real, h: real, base: real, seed: real): var {
                    const pts = [Qt.point(0, h)];
                    let x = 0, i = 0;
                    while (x < w) {
                        pts.push(Qt.point(x, base + root.rnd(seed, i, 1) * (root.tear - 2)));
                        x += 14 + root.rnd(seed, i, 2) * 34;
                        i++;
                    }
                    pts.push(Qt.point(w, base + root.tear / 2), Qt.point(w, h), Qt.point(0, h));
                    return pts;
                }
            }

            // halftone dots fading in from both ends
            Canvas {
                anchors { fill: parent; bottomMargin: root.tear + 4 }
                opacity: 0.35
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.redDeep;
                    const step = 9;
                    for (let y = 2; y < height; y += step)
                        for (let x = (y / step % 2) * step / 2; x < width; x += step) {
                            const t = Math.max(0, 1 - Math.min(x, width - x) / (width * 0.22));
                            if (t <= 0)
                                continue;
                            ctx.beginPath();
                            ctx.arc(x, y, 3.6 * t, 0, Math.PI * 2);
                            ctx.fill();
                        }
                }
            }

            // red slash behind the clock
            Shape {
                id: clockSlash
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: 280; height: root.barHeight - 10
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.red
                    strokeWidth: -1
                    PathPolyline { path: [Qt.point(26, 0), Qt.point(280, 6), Qt.point(256, 40), Qt.point(0, 34), Qt.point(26, 0)] }
                }
            }

            Item {
                anchors { fill: parent; bottomMargin: root.tear }

                // left: launcher burst, workspaces, window title
                RowLayout {
                    id: leftRow
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 }
                    spacing: 10

                    Item {
                        implicitWidth: 96
                        implicitHeight: root.barHeight + 4
                        scale: launchArea.containsMouse ? 1.1 : 1
                        rotation: launchArea.containsMouse ? -6 : -3
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                        Burst {
                            anchors.fill: parent
                            spikes: 13
                            seed: 21
                        }
                        Ransom {
                            id: menuText
                            anchors.centerIn: parent
                            text: "MENU"
                            size: 17
                            seed: 8
                        }
                        MouseArea {
                            id: launchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: menuText.glitch()
                            onClicked: root.caelestia(["shell", "drawers", "toggle", "launcher"])
                        }
                    }

                    Row {
                        spacing: 2

                        Repeater {
                            model: 5

                            Item {
                                id: ws
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)

                                width: active ? 52 : 32
                                height: root.barHeight - 4
                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                                Burst {
                                    anchors.centerIn: parent
                                    width: 52; height: 48
                                    visible: ws.active
                                    seed: 40 + ws.wsId
                                    spikes: 9
                                    rotation: ws.wsId * 23
                                }
                                Ransom {
                                    id: wsNum
                                    anchors.centerIn: parent
                                    text: String(ws.wsId)
                                    seed: ws.wsId * 13
                                    size: ws.active ? 26 : 19
                                    forceStyle: ws.active ? 1 : ws.occupied ? 0 : 3
                                    opacity: ws.active || ws.occupied || wsArea.containsMouse ? 1 : 0.45
                                }
                                onActiveChanged: if (active) wsNum.glitch()

                                MouseArea {
                                    id: wsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: wsNum.glitch()
                                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws.wsId}" })`)
                                }
                            }
                        }
                    }

                    // window title on a torn white label
                    Item {
                        id: titleBox
                        // never reach the clock: stop before the red slash behind it
                        readonly property real room: Math.min(clockSlash.x, clockBox.x) - leftRow.x - x - 14
                        visible: titleText.text !== "" && room > 60
                        Layout.leftMargin: 6
                        implicitWidth: Math.max(0, Math.min(titleText.implicitWidth + 22, room))
                        implicitHeight: 26

                        Card {
                            anchors.fill: parent
                            tilt: -2
                            fill: root.paper
                            outlineWidth: 0
                            shadowOffset: 3
                        }
                        Text {
                            id: titleText
                            anchors { fill: parent; leftMargin: 11; rightMargin: 11 }
                            rotation: -2
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: (Hyprland.activeToplevel?.title ?? "").toUpperCase()
                            font.family: "Antonio"
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: root.ink
                        }
                    }
                }

                // centre: ransom clock + weekday, opens the dashboard
                Item {
                    id: clockBox
                    anchors.centerIn: parent
                    implicitWidth: clockRow.implicitWidth
                    implicitHeight: root.barHeight
                    scale: clockArea.containsMouse ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                    RowLayout {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 10

                        Ransom {
                            id: clockText
                            text: Qt.formatDateTime(clock.date, "hh:mm")
                            size: 30
                            autoGlitch: true
                        }
                        ColumnLayout {
                            spacing: -6
                            Ransom {
                                text: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
                                size: 18
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignRight
                                implicitWidth: dateText.implicitWidth + 10
                                implicitHeight: dateText.implicitHeight - 4
                                color: root.ink
                                border.color: root.paper
                                border.width: 2
                                rotation: -5
                                antialiasing: true
                                Text {
                                    id: dateText
                                    anchors.centerIn: parent
                                    text: Qt.formatDateTime(clock.date, "dd/MM")
                                    font.family: "Bebas Neue"
                                    font.pixelSize: 18
                                    font.italic: true
                                    color: root.paper
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: clockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: clockText.glitch()
                        onClicked: root.caelestia(["shell", "drawers", "toggle", "dashboard"])
                    }
                }

                // right: tray, network/bluetooth, volume, battery, power
                RowLayout {
                    id: rightRow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
                    spacing: 16

                    // never reach the clock: drop chip labels (bluetooth, then wifi, then volume)
                    // until the row fits right of the red slash
                    readonly property var squeezable: [btChip, netChip, volChip]
                    readonly property real room: parent.width - (clockSlash.x + clockSlash.width) - 14
                    readonly property var chips: [netChip, btChip, volChip, batChip]
                    // width the row needs with every label shown, built from parts (not implicitWidth)
                    readonly property real fullWidth: {
                        const shown = chips.filter(c => c.visible);
                        const n = SystemTray.items.values.length + shown.length + 1;
                        return SystemTray.items.values.length * 26 + shown.reduce((a, c) => a + c.fullWidth, 0)
                            + powerBox.implicitWidth + spacing * (n - 1);
                    }
                    readonly property int squeeze: {
                        let w = fullWidth, n = 0;
                        for (const c of squeezable) {
                            if (w <= room) break;
                            if (c.visible && !c.hot) w -= c.labelExtra;
                            n++;
                        }
                        return n;
                    }

                    Repeater {
                        model: SystemTray.items

                        Item {
                            id: trayItem
                            required property SystemTrayItem modelData
                            implicitWidth: 26
                            implicitHeight: 26

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 20
                                source: trayItem.modelData.icon
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    const item = trayItem.modelData;
                                    if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                        if (item.hasMenu) {
                                            const p = trayItem.mapToItem(null, 0, 0);
                                            item.display(bar, p.x, p.y - 8);
                                        }
                                    } else {
                                        item.activate();
                                    }
                                }
                            }
                        }
                    }

                    // wifi: left click = network settings, right click = wifi on/off
                    Chip {
                        id: netChip
                        compact: rightRow.squeeze >= 2
                        readonly property var devs: Networking.devices.values
                        readonly property var wired: devs.find(d => d.type === DeviceType.Wired && d.connected)
                        readonly property var wifiNet: {
                            for (const d of devs)
                                if (d.type === DeviceType.Wifi)
                                    for (const n of d.networks.values)
                                        if (n.connected) return n;
                            return null;
                        }
                        visible: Networking.backend !== NetworkBackendType.None
                        readonly property real strength: { const v = wifiNet?.signalStrength ?? 0; return v > 1 ? v / 100 : v; }
                        tilt: 2
                        hot: !wired && !wifiNet
                        icon: wired ? "lan" : !Networking.wifiEnabled ? "wifi_off" : !wifiNet ? "signal_wifi_bad"
                            : strength > 0.75 ? "signal_wifi_4_bar" : strength > 0.5 ? "network_wifi_3_bar"
                            : strength > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                        label: wired ? "LAN" : !Networking.wifiEnabled ? "OFF" : !wifiNet ? "NO NET"
                            : wifiNet.name.length > 10 ? wifiNet.name.slice(0, 9).toUpperCase() + "…" : wifiNet.name.toUpperCase()
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                            else
                                root.openSettings("network");
                        }
                    }

                    // bluetooth: left click = bluetooth settings, right click = adapter on/off
                    Chip {
                        id: btChip
                        compact: rightRow.squeeze >= 1
                        readonly property var adapter: Bluetooth.defaultAdapter
                        readonly property var conn: adapter ? adapter.devices.values.filter(d => d.connected) : []
                        visible: adapter !== null
                        tilt: -2
                        icon: !adapter?.enabled ? "bluetooth_disabled" : conn.length ? "bluetooth_connected" : "bluetooth"
                        label: !adapter?.enabled ? "OFF" : conn.length === 1
                            ? (conn[0].name.length > 10 ? conn[0].name.slice(0, 9).toUpperCase() + "…" : conn[0].name.toUpperCase())
                            : conn.length > 1 ? `${conn.length} DEV` : "ON"
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (adapter) adapter.enabled = !adapter.enabled;
                            } else {
                                root.openSettings("bluetooth");
                            }
                        }
                    }

                    Chip {
                        id: volChip
                        compact: rightRow.squeeze >= 3
                        readonly property var audio: Pipewire.defaultAudioSink?.audio
                        readonly property int pct: Math.round((audio?.volume ?? 0) * 100)
                        tilt: -3
                        icon: !audio || audio.muted ? "volume_off" : pct > 50 ? "volume_up" : pct > 0 ? "volume_down" : "volume_mute"
                        label: !audio ? "--" : audio.muted ? "MUTE" : `${pct}%`
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                Quickshell.execDetached(["pavucontrol"]);
                            else if (audio)
                                audio.muted = !audio.muted;
                        }
                        onScrolled: delta => {
                            if (audio)
                                audio.volume = Math.max(0, Math.min(1, audio.volume + (delta > 0 ? 0.05 : -0.05)));
                        }
                    }

                    Chip {
                        id: batChip
                        readonly property var dev: UPower.displayDevice
                        readonly property int pct: Math.round((dev?.percentage ?? 0) * (dev?.percentage > 1 ? 1 : 100))
                        readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged
                        visible: dev?.isLaptopBattery ?? false
                        tilt: 2
                        hot: pct <= 15 && !charging
                        icon: charging ? "bolt" : pct > 15 ? "battery_full" : "battery_alert"
                        label: hot ? `LOW!! ${pct}%` : `${pct}%`
                    }

                    Item {
                        id: powerBox
                        implicitWidth: 58
                        implicitHeight: root.barHeight + 2
                        scale: powerArea.containsMouse ? 1.12 : 1
                        rotation: powerArea.containsMouse ? 12 : 0
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                        Burst {
                            anchors.fill: parent
                            spikes: 10
                            seed: 77
                            fill: powerArea.containsMouse ? root.paper : root.red
                        }
                        Icon {
                            anchors.centerIn: parent
                            text: "power_settings_new"
                            font.pixelSize: 24
                            color: powerArea.containsMouse ? root.red : root.paper
                        }
                        MouseArea {
                            id: powerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["sh", "-c", "pgrep -f '^qs -c p3-power' >/dev/null || qs -c p3-power -n -d"])
                        }
                    }
                }
            }
        }
    }
}
