// Top bar for the Persona 3 theme: midnight panel with a cyan/white edge,
// workspaces as slanted list cards with numeral tabs, the active one cut by the same white
// blade + red bar as the power menu, heavy italic cyan type with a dark offset layer.
// Colours come live from Caelestia's scheme.json; shell actions go through the caelestia CLI.
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
    readonly property color cyan: "#" + (colours.primary ?? "3fd8ff")
    readonly property color blue: "#" + (colours.primaryContainer ?? "1238d6")
    readonly property color deep: "#" + (colours.background ?? "030a26")
    readonly property color navy: "#" + (colours.surfaceContainer ?? "071648")
    readonly property color white: "#" + (colours.onSurface ?? "f2fbff")
    readonly property color ice: "#" + (colours.primaryFixed ?? "aaf2ff")
    readonly property color red: "#" + (colours.tertiary ?? "ff1f3a")
    readonly property color pink: "#ff5fae"
    readonly property color offset: "#1660d2"     // dark layer under cyan type
    readonly property string face: "Jost"
    readonly property string icons: "Material Symbols Sharp"

    readonly property int barHeight: 50 // reserved space; sync-caelestia.sh reads this
    readonly property int edge: 6       // extra height for the cyan/white bottom edge
    readonly property int hang: 16      // how far the calendar hangs below the bar
    readonly property int hudWidth: 440 // p3-hud corner clock sits over the right end of the bar

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

    // time-of-day phrase and the sky tint behind the calendar
    function dayPart(h: int): string {
        return h < 5 ? "Late Night" : h < 8 ? "Early Morning" : h < 12 ? "Morning" : h < 14 ? "Midday"
            : h < 17 ? "Afternoon" : h < 20 ? "Evening" : "Night";
    }
    function skyTint(h: int): color {
        return h < 5 ? "#2a1d6e" : h < 8 ? "#e08aa8" : h < 12 ? "#9fc8ff" : h < 14 ? "#bfe3ff"
            : h < 17 ? "#f0a6c0" : h < 20 ? "#ff9f7a" : "#3a2a8f";
    }
    // moon age as a fraction of the synodic month: 0 new, 0.5 full
    function moonPhase(d: date): real {
        const ref = Date.UTC(2000, 0, 6, 18, 14) / 86400000;
        const days = d.getTime() / 86400000 - ref;
        const p = (days % 29.530588853) / 29.530588853;
        return p < 0 ? p + 1 : p;
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---- reusable pieces ----

    component Icon: Text {
        font.family: root.icons
        font.pixelSize: 20
        color: root.cyan
        verticalAlignment: Text.AlignVCenter
    }

    // Heavy italic word: face colour over a darker copy offset down-right, plus a forward shear.
    component Word: Item {
        id: w
        property string text
        property real size: 22
        property color face: root.cyan
        property color back: root.offset
        property bool flat: false   // no offset layer
        property int weight: Font.Black
        implicitWidth: t.implicitWidth + size * 0.12
        implicitHeight: t.implicitHeight
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, -0.14, 0, w.implicitHeight * 0.07, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }
        Text {
            visible: !w.flat
            x: w.size * 0.06
            y: w.size * 0.08
            text: w.text
            font: t.font
            color: w.back
        }
        Text {
            id: t
            text: w.text
            font.family: root.face
            font.weight: w.weight
            font.italic: true
            font.pixelSize: w.size
            font.letterSpacing: -w.size * 0.04
            color: w.face
        }
    }

    // Slanted card: parallelogram with an optional outline and a hard offset shadow.
    // Drawn as a vector path inside a plain Item so it stays crisp at 1.5x and the
    // shadow never feeds back into the size.
    component Slant: Item {
        id: s
        property real skew: 10
        property color fill: root.navy
        property color outline: root.cyan
        property real outlineWidth: 2
        property color shadow: "transparent"
        property real shadowOffset: 3
        function quad(dx: real, dy: real, inset: real): var {
            const k = skew, w = width - shadowOffset, h = height - shadowOffset, i = inset;
            return [Qt.point(k + dx + i, dy + i), Qt.point(w + dx - i, dy + i), Qt.point(w - k + dx - i, h + dy - i),
                    Qt.point(dx + i, h + dy - i), Qt.point(k + dx + i, dy + i)];
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: s.shadow
                strokeWidth: -1
                PathPolyline { path: s.quad(s.shadowOffset, s.shadowOffset, 0) }
            }
            ShapePath {
                fillColor: s.fill
                strokeColor: s.outlineWidth > 0 ? s.outline : "transparent"
                strokeWidth: s.outlineWidth > 0 ? s.outlineWidth : -1
                joinStyle: ShapePath.MiterJoin
                PathPolyline { path: s.quad(0, 0, s.outlineWidth / 2) }
            }
        }
    }

    // The power menu's highlight in miniature: pink edge, white blade, red bar.
    component Blade: Shape {
        id: bl
        property real w
        property real h
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.pink
            strokeWidth: -1
            PathPolyline { path: [Qt.point(-bl.h * 0.6, bl.h * 0.98), Qt.point(bl.w - 2, -bl.h * 0.18), Qt.point(bl.w + bl.h * 0.22, -bl.h * 0.02), Qt.point(bl.w + 2, bl.h * 0.84), Qt.point(-bl.h * 0.6, bl.h * 0.98)] }
        }
        ShapePath {
            fillColor: root.white
            strokeWidth: -1
            PathPolyline { path: [Qt.point(-bl.h * 0.55, bl.h * 0.94), Qt.point(bl.w - 6, -bl.h * 0.12), Qt.point(bl.w + bl.h * 0.14, bl.h * 0.02), Qt.point(bl.w - 2, bl.h * 0.8), Qt.point(-bl.h * 0.55, bl.h * 0.94)] }
        }
        ShapePath {
            fillColor: root.red
            strokeWidth: -1
            PathPolyline { path: [Qt.point(-bl.h * 0.15, bl.h * 0.42), Qt.point(bl.w - bl.h * 0.25, bl.h * 0.26), Qt.point(bl.w - bl.h * 0.3, bl.h * 0.66), Qt.point(-bl.h * 0.22, bl.h * 0.8), Qt.point(-bl.h * 0.15, bl.h * 0.42)] }
        }
    }

    // Status chip: slanted navy card, cyan outline, icon + italic label.
    component Chip: Item {
        id: chip
        property string icon
        property string label
        property bool hot: false
        // icon only (label hidden) when the bar runs out of room; hot chips keep their label
        property bool compact: false
        // width the label adds when shown, so the bar can work out what fits
        readonly property real labelExtra: label !== "" ? lbl.implicitWidth + row.spacing : 0
        // width with the label shown, independent of compact (no binding loop)
        readonly property real fullWidth: 30 + (icon !== "" ? ic.implicitWidth : 0) + labelExtra
        readonly property bool lit: hot || area.containsMouse
        signal clicked(var mouse)
        signal scrolled(int delta)

        implicitWidth: row.implicitWidth + 30
        implicitHeight: 32
        y: area.containsMouse ? -2 : 0
        Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        Slant {
            anchors.fill: parent
            skew: 9
            fill: chip.hot ? root.red : area.containsMouse ? root.white : Qt.alpha(root.navy, 0.9)
            outline: chip.hot ? root.white : root.cyan
            shadow: chip.lit ? root.cyan : root.blue
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -1
            anchors.verticalCenterOffset: -2
            spacing: 4

            Icon {
                id: ic
                visible: chip.icon !== ""
                text: chip.icon
                font.pixelSize: 19
                color: chip.hot ? root.white : area.containsMouse ? root.blue : root.cyan
            }
            Word {
                id: lbl
                visible: chip.label !== "" && (!chip.compact || chip.hot)
                text: chip.label
                size: 16
                weight: Font.ExtraBold
                flat: true
                face: chip.hot ? root.white : area.containsMouse ? root.deep : root.white
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
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
            implicitHeight: root.barHeight + root.edge + root.hang
            exclusiveZone: root.barHeight
            color: "transparent"

            readonly property var monitor: Hyprland.monitorFor(modelData)

            // midnight panel, a touch of blue in the middle, cyan + white edge under it
            Rectangle {
                id: panel
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root.barHeight
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(root.deep, 0.96) }
                    GradientStop { position: 0.5; color: Qt.alpha(root.navy, 0.94) }
                    GradientStop { position: 1.0; color: Qt.alpha(root.deep, 0.96) }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: panel.bottom }
                height: 3
                color: root.cyan
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: panel.bottom; topMargin: 4 }
                height: 1.5
                color: Qt.alpha(root.white, 0.7)
            }

            // calendar panel: slanted, sky tint on the left fading into blue, giant faint
            // WEEKDAY/WEEKEND behind, hangs a little below the bar
            Item {
                id: clockBand
                visible: false   // replaced by the p3-hud corner clock
                readonly property int hour: clock.date.getHours()
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: 300
                height: root.barHeight + root.hang

                Shape {
                    id: calShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // cyan rim
                    ShapePath {
                        fillColor: root.cyan
                        strokeWidth: -1
                        PathPolyline { path: [Qt.point(26, 0), Qt.point(300, 0), Qt.point(276, clockBand.height), Qt.point(0, clockBand.height), Qt.point(26, 0)] }
                    }
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: LinearGradient {
                            x1: 0; y1: clockBand.height; x2: 300; y2: 0
                            GradientStop { position: 0.0; color: root.skyTint(clockBand.hour) }
                            GradientStop { position: 0.42; color: "#3f6dff" }
                            GradientStop { position: 1.0; color: root.blue }
                        }
                        PathPolyline { path: [Qt.point(26, 0), Qt.point(297, 0), Qt.point(274, clockBand.height - 3), Qt.point(3, clockBand.height - 3), Qt.point(26, 0)] }
                    }
                }

                // soft cloud puffs low on the left, ghost word across the top
                Item {
                    anchors.fill: parent
                    anchors.bottomMargin: 3
                    clip: true
                    Repeater {
                        model: 7
                        Rectangle {
                            required property int index
                            width: 46 + (index % 3) * 22
                            height: width * 0.45
                            radius: height / 2
                            x: 6 + index * 26
                            y: clockBand.height - 14 - (index % 2) * 10 - (index % 3) * 3
                            color: Qt.alpha(root.white, 0.22 - index * 0.025)
                        }
                    }
                    Text {
                        x: 34
                        y: -12
                        text: clockBand.hour >= 0 && (clock.date.getDay() === 0 || clock.date.getDay() === 6) ? "WEEKEND" : "WEEKDAY"
                        font.family: root.face
                        font.weight: Font.Black
                        font.italic: true
                        font.pixelSize: 48
                        font.letterSpacing: -2
                        color: Qt.alpha(root.ice, 0.22)
                    }
                }
            }

            Item {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root.barHeight

                // left: launcher, workspaces, window title
                RowLayout {
                    id: leftRow
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                    spacing: 8

                    // launcher: white slanted card with a red sliver
                    Item {
                        implicitWidth: 80
                        implicitHeight: 34
                        y: launchArea.containsMouse ? -2 : 0
                        Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        Slant {
                            anchors.fill: parent
                            skew: 10
                            fill: launchArea.containsMouse ? root.cyan : root.white
                            outlineWidth: 0
                            shadow: root.red
                            shadowOffset: 4
                        }
                        Word {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            text: "MENU"
                            size: 19
                            face: root.deep
                            flat: true
                        }
                        MouseArea {
                            id: launchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.caelestia(["shell", "drawers", "toggle", "launcher"])
                        }
                    }

                    // workspaces: slanted list cards with a white numeral tab
                    Row {
                        spacing: -4

                        Repeater {
                            model: 5

                            Item {
                                id: ws
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)
                                readonly property var numerals: ["I", "II", "III", "IV", "V"]

                                width: active ? 66 : 44
                                height: root.barHeight
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                Slant {
                                    id: wsCard
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 32
                                    skew: 10
                                    fill: ws.active ? "transparent" : wsArea.containsMouse ? Qt.alpha(root.blue, 0.9) : Qt.alpha(root.navy, 0.85)
                                    outline: ws.occupied || ws.active ? root.cyan : Qt.alpha(root.cyan, 0.35)
                                    outlineWidth: ws.active ? 0 : 1.5
                                    shadowOffset: 0
                                }

                                // active: white card, cyan offset shadow, red bar cut across it
                                Slant {
                                    visible: ws.active
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 34
                                    skew: 10
                                    fill: root.white
                                    outlineWidth: 0
                                    shadow: root.cyan
                                    shadowOffset: 3
                                }
                                Shape {
                                    visible: ws.active
                                    anchors.fill: parent
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        fillColor: root.red
                                        strokeWidth: -1
                                        PathPolyline {
                                            path: [Qt.point(12, 27), Qt.point(ws.width - 8, 19), Qt.point(ws.width - 11, 29), Qt.point(9, 36), Qt.point(12, 27)]
                                        }
                                    }
                                }

                                // numeral tab: thin white sliver on the card's left edge
                                Slant {
                                    visible: !ws.active
                                    x: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15
                                    height: 32
                                    skew: 10
                                    fill: ws.occupied ? root.white : Qt.alpha(root.white, 0.25)
                                    outlineWidth: 0
                                    shadowOffset: 0
                                }
                                Word {
                                    x: ws.active ? 20 : 19
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -2
                                    text: ws.numerals[ws.index]
                                    size: ws.active ? 25 : 18
                                    face: ws.active ? "#0a0a0a" : ws.occupied ? root.cyan : Qt.alpha(root.cyan, 0.45)
                                    flat: ws.active
                                    Behavior on size { NumberAnimation { duration: 160 } }
                                }

                                MouseArea {
                                    id: wsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws.wsId}" })`)
                                }
                            }
                        }
                    }

                    // window title: italic white on a translucent slanted card
                    Item {
                        id: titleBox
                        // never reach the clock band
                        readonly property real room: rightRow.x - leftRow.x - x - 24
                        visible: titleText.text !== "" && room > 60
                        Layout.leftMargin: 4
                        implicitWidth: Math.max(0, Math.min(titleText.implicitWidth + 30, room))
                        implicitHeight: 28

                        Slant {
                            anchors.fill: parent
                            skew: 8
                            fill: Qt.alpha(root.blue, 0.35)
                            outline: Qt.alpha(root.cyan, 0.5)
                            outlineWidth: 1
                            shadowOffset: 0
                        }
                        Text {
                            id: titleText
                            anchors { fill: parent; leftMargin: 15; rightMargin: 13 }
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: Hyprland.activeToplevel?.title ?? ""
                            font.family: root.face
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.italic: true
                            color: root.white
                        }
                    }
                }

                // centre: calendar text + moon, sits on clockBand; opens the dashboard
                Item {
                    id: clockBox
                    visible: false
                    x: clockBand.x
                    y: 0
                    width: clockBand.width
                    height: clockBand.height
                    scale: clockArea.containsMouse ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Word {
                        id: dateWord
                        x: 64
                        y: 5
                        text: Qt.formatDateTime(clock.date, "M/d")
                        size: 36
                        face: root.white
                        back: Qt.alpha(root.deep, 0.75)
                    }
                    Text {
                        anchors.left: dateWord.right
                        anchors.leftMargin: 4
                        y: 9
                        text: Qt.formatDateTime(clock.date, "ddd")
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        color: root.white
                    }
                    Row {
                        x: 70
                        y: 44
                        spacing: 8
                        Text {
                            text: root.dayPart(clockBand.hour)
                            font.family: root.face
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            color: root.cyan
                            style: Text.Raised
                            styleColor: Qt.alpha(root.deep, 0.6)
                        }
                        Text {
                            text: Qt.formatDateTime(clock.date, "hh:mm")
                            font.family: root.face
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            color: root.white
                            style: Text.Raised
                            styleColor: Qt.alpha(root.deep, 0.6)
                        }
                    }

                    // moon: today's real phase, gold lit side, dark side, thin outline
                    Canvas {
                        id: moon
                        readonly property real phase: root.moonPhase(clock.date)
                        x: 218
                        y: (parent.height - height) / 2 - 2
                        width: 34
                        height: 34
                        onPhaseChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const cx = width / 2, cy = height / 2, r = width / 2 - 2;
                            ctx.fillStyle = "#14141c";
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.fill();
                            // lit region: one half disc + an elliptical terminator
                            const waxing = phase < 0.5;
                            const k = Math.cos(phase * 2 * Math.PI);   // 1 new, -1 full
                            ctx.fillStyle = "#ffd23f";
                            ctx.beginPath();
                            const side = waxing ? 1 : -1;
                            for (let i = 0; i <= 32; i++) {
                                const t = -Math.PI / 2 + Math.PI * i / 32;
                                ctx.lineTo(cx + side * r * Math.cos(t), cy + r * Math.sin(t));
                            }
                            for (let i = 32; i >= 0; i--) {
                                const t = -Math.PI / 2 + Math.PI * i / 32;
                                ctx.lineTo(cx + side * k * r * Math.cos(t), cy + r * Math.sin(t));
                            }
                            ctx.closePath();
                            ctx.fill();
                            ctx.strokeStyle = "#f2fbff";
                            ctx.lineWidth = 1.5;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.stroke();
                        }
                    }

                    MouseArea {
                        id: clockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.caelestia(["shell", "drawers", "toggle", "dashboard"])
                    }
                }

                // right: tray, network/bluetooth, volume, battery, power
                RowLayout {
                    id: rightRow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 + root.hudWidth }
                    spacing: 10

                    // never reach the clock band: drop chip labels (bluetooth, then wifi, then volume)
                    readonly property var squeezable: [btChip, netChip, volChip]
                    readonly property real room: parent.width * 0.42
                    readonly property var chips: [netChip, btChip, volChip, batChip]
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
                                            item.display(bar, p.x, p.y + 30);
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
                        hot: pct <= 15 && !charging
                        icon: charging ? "bolt" : pct > 15 ? "battery_full" : "battery_alert"
                        label: hot ? `LOW ${pct}%` : `${pct}%`
                    }

                    // power: white blade card, opens the p3 power menu
                    Item {
                        id: powerBox
                        implicitWidth: 54
                        implicitHeight: 34
                        y: powerArea.containsMouse ? -2 : 0
                        Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        Slant {
                            anchors.fill: parent
                            skew: 10
                            fill: powerArea.containsMouse ? root.red : root.white
                            outlineWidth: 0
                            shadow: powerArea.containsMouse ? root.white : root.red
                            shadowOffset: 4
                        }
                        Icon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            text: "power_settings_new"
                            font.pixelSize: 22
                            color: powerArea.containsMouse ? root.white : root.blue
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
