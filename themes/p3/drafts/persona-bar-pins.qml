// Top bar for the Persona 3 theme, map-HUD style: no solid strip, just a soft
// dark fade; round blue pin badges with white rims and pointer tails; condensed white labels
// with a dark-blue outline; circle-and-label button hints for status. The p3-hud corner
// clock sits over the right end, so the right row stays clear of it.
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
    readonly property color white: "#ffffff"
    readonly property color red: "#" + (colours.tertiary ?? "ff1f3a")
    readonly property color outline: "#0a2a9a"   // dark blue text outline
    readonly property string label: "Open Sans Condensed ExtraBold"
    readonly property string icons: "Material Symbols Sharp"

    readonly property int barHeight: 50 // reserved space; sync-caelestia.sh reads this
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

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // ---- reusable pieces ----

    component Icon: Text {
        font.family: root.icons
        font.pixelSize: 18
        color: root.white
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // Condensed white label with a dark-blue outline
    component Label: Text {
        font.family: root.label
        font.weight: Font.ExtraBold
        font.italic: true
        font.pixelSize: 17
        color: root.white
        style: Text.Outline
        styleColor: root.outline
        verticalAlignment: Text.AlignVCenter
    }

    // Round map pin: blue disc, white rim, pointer tail; optional glow ring
    component Pin: Item {
        id: pin
        property real size: 30
        property bool glow: false
        property color fill: root.blue
        property color rim: root.white
        default property alias content: inner.data
        width: size
        height: size + size * 0.28

        Rectangle {
            visible: pin.glow
            anchors.horizontalCenter: parent.horizontalCenter
            y: -pin.size * 0.18
            width: pin.size * 1.36
            height: width
            radius: width / 2
            color: Qt.alpha("#b48cff", 0.28)
            border.color: Qt.alpha("#d6c4ff", 0.6)
            border.width: 2
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: pin.rim
                strokeWidth: -1
                PathPolyline {
                    path: [Qt.point(pin.size * 0.3, pin.size * 0.8), Qt.point(pin.size * 0.7, pin.size * 0.8),
                           Qt.point(pin.size * 0.5, pin.height), Qt.point(pin.size * 0.3, pin.size * 0.8)]
                }
            }
        }
        Rectangle {
            width: pin.size
            height: pin.size
            radius: width / 2
            color: pin.rim
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.max(2, pin.size * 0.08)
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(pin.fill, 1.35) }
                    GradientStop { position: 1.0; color: pin.fill }
                }
            }
            Item {
                id: inner
                anchors.fill: parent
            }
        }
    }

    // Button-hint style status: white ring with an icon, then a label
    component Hint: Item {
        id: hint
        property string icon
        property string text
        property bool hot: false
        // icon only (label hidden) when the bar runs out of room; hot hints keep their label
        property bool compact: false
        readonly property real labelExtra: text !== "" ? lbl.implicitWidth + row.spacing : 0
        readonly property real fullWidth: 26 + labelExtra + 6
        signal clicked(var mouse)
        signal scrolled(int delta)

        implicitWidth: row.implicitWidth + 6
        implicitHeight: 30
        scale: area.containsMouse ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: hint.hot ? root.red : area.containsMouse ? root.blue : Qt.alpha(root.deep, 0.55)
                border.color: root.white
                border.width: 2
                Icon {
                    anchors.centerIn: parent
                    text: hint.icon
                    font.pixelSize: 16
                }
            }
            Label {
                id: lbl
                visible: hint.text !== "" && (!hint.compact || hint.hot)
                text: hint.text
                color: hint.hot ? "#ffd0d4" : root.white
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => hint.clicked(mouse)
            onWheel: wheel => hint.scrolled(wheel.angleDelta.y)
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
            implicitHeight: root.barHeight + 8
            exclusiveZone: root.barHeight
            color: "transparent"

            readonly property var monitor: Hyprland.monitorFor(modelData)

            // soft dark fade instead of a solid strip; stops where the corner clock begins
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; rightMargin: root.hudWidth - 40 }
                height: root.barHeight + 8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(root.deep, 0.78) }
                    GradientStop { position: 0.75; color: Qt.alpha(root.deep, 0.35) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Item {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root.barHeight

                // left: launcher pin, workspace pins, window title as a map label
                RowLayout {
                    id: leftRow
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12; verticalCenterOffset: 2 }
                    spacing: 6

                    Pin {
                        size: 32
                        scale: launchArea.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                        Icon {
                            anchors.centerIn: parent
                            text: "apps"
                            font.pixelSize: 19
                        }
                        MouseArea {
                            id: launchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.caelestia(["shell", "drawers", "toggle", "launcher"])
                        }
                    }

                    Item { implicitWidth: 6 }

                    Repeater {
                        model: 5

                        Pin {
                            id: ws
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)
                            size: active ? 34 : 26
                            glow: active
                            fill: active ? root.blue : occupied ? "#1a49e6" : "#14245e"
                            rim: active || occupied ? root.white : Qt.alpha(root.white, 0.45)
                            Layout.alignment: Qt.AlignVCenter
                            scale: wsArea.containsMouse && !active ? 1.12 : 1
                            Behavior on size { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                            Label {
                                anchors.centerIn: parent
                                text: String(ws.wsId)
                                font.pixelSize: ws.active ? 19 : 15
                                font.italic: false
                                style: Text.Normal
                                color: ws.active || ws.occupied ? root.white : Qt.alpha(root.white, 0.5)
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

                    // window title, like a place name next to its pin
                    Label {
                        id: titleText
                        readonly property real room: rightRow.x - leftRow.x - x - 24
                        visible: text !== "" && room > 60
                        Layout.leftMargin: 8
                        Layout.maximumWidth: Math.max(0, room)
                        elide: Text.ElideRight
                        text: Hyprland.activeToplevel?.title ?? ""
                        font.pixelSize: 19
                    }
                }

                // right (left of the corner clock): tray, status hints, power pin
                RowLayout {
                    id: rightRow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 + root.hudWidth }
                    spacing: 12

                    // drop hint labels (bluetooth, then wifi, then volume) when space runs out
                    readonly property var squeezable: [btHint, netHint, volHint]
                    readonly property real room: parent.width * 0.42
                    readonly property var hints: [netHint, btHint, volHint, batHint]
                    readonly property real fullWidth: {
                        const shown = hints.filter(c => c.visible);
                        const n = SystemTray.items.values.length + shown.length + 1;
                        return SystemTray.items.values.length * 26 + shown.reduce((a, c) => a + c.fullWidth, 0)
                            + powerPin.width + spacing * (n - 1);
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
                    Hint {
                        id: netHint
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
                        text: wired ? "LAN" : !Networking.wifiEnabled ? "Wi-Fi Off" : !wifiNet ? "No Network"
                            : wifiNet.name.length > 12 ? wifiNet.name.slice(0, 11) + "…" : wifiNet.name
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                            else
                                root.openSettings("network");
                        }
                    }

                    // bluetooth: left click = bluetooth settings, right click = adapter on/off
                    Hint {
                        id: btHint
                        compact: rightRow.squeeze >= 1
                        readonly property var adapter: Bluetooth.defaultAdapter
                        readonly property var conn: adapter ? adapter.devices.values.filter(d => d.connected) : []
                        visible: adapter !== null
                        icon: !adapter?.enabled ? "bluetooth_disabled" : conn.length ? "bluetooth_connected" : "bluetooth"
                        text: !adapter?.enabled ? "Off" : conn.length === 1
                            ? (conn[0].name.length > 12 ? conn[0].name.slice(0, 11) + "…" : conn[0].name)
                            : conn.length > 1 ? `${conn.length} Devices` : "On"
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (adapter) adapter.enabled = !adapter.enabled;
                            } else {
                                root.openSettings("bluetooth");
                            }
                        }
                    }

                    Hint {
                        id: volHint
                        compact: rightRow.squeeze >= 3
                        readonly property var audio: Pipewire.defaultAudioSink?.audio
                        readonly property int pct: Math.round((audio?.volume ?? 0) * 100)
                        icon: !audio || audio.muted ? "volume_off" : pct > 50 ? "volume_up" : pct > 0 ? "volume_down" : "volume_mute"
                        text: !audio ? "--" : audio.muted ? "Mute" : `${pct}%`
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

                    Hint {
                        id: batHint
                        readonly property var dev: UPower.displayDevice
                        readonly property int pct: Math.round((dev?.percentage ?? 0) * (dev?.percentage > 1 ? 1 : 100))
                        readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged
                        visible: dev?.isLaptopBattery ?? false
                        hot: pct <= 15 && !charging
                        icon: charging ? "bolt" : pct > 15 ? "battery_full" : "battery_alert"
                        text: `${pct}%`
                    }

                    // power: red pin, opens the p3 power menu
                    Pin {
                        id: powerPin
                        size: 30
                        fill: powerArea.containsMouse ? "#ff4a58" : root.red
                        Layout.alignment: Qt.AlignVCenter
                        scale: powerArea.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                        Icon {
                            anchors.centerIn: parent
                            text: "power_settings_new"
                            font.pixelSize: 17
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
