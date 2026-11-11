// Top bar for the Persona 3 theme, Portable-inspired: bright blue gradient
// panel with a white line along the bottom, white rounded workspace tabs (active one solid
// white), solid white status pills with blue text, red power button. The p3-hud corner
// calendar sits over the right end, so the right row stays clear of it.
// Colours come live from Caelestia's scheme.json; shell actions go through the caelestia CLI.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
    readonly property color top: "#3f86ff"
    readonly property color bottom: "#1240d8"
    readonly property color ink: "#1240d8"      // blue text on white
    readonly property color navy: "#0a2a9a"
    readonly property color white: "#ffffff"
    readonly property color red: "#ff3a5a"
    readonly property string face: "Jost"
    readonly property string icons: "Material Symbols Sharp"

    readonly property int barHeight: 50 // reserved space; sync-caelestia.sh reads this
    readonly property int hudWidth: 440 // p3-hud corner calendar sits over the right end of the bar

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
        font.pixelSize: 16
        color: root.ink
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // Status pill: solid white, blue icon + text; red when something needs attention,
    // blue with white text on hover
    component Pill: Item {
        id: pill
        property string icon
        property string text
        property bool hot: false
        // icon only (label hidden) when the bar runs out of room; hot pills keep their label
        property bool compact: false
        readonly property real labelExtra: text !== "" ? lbl.implicitWidth + row.spacing : 0
        readonly property real fullWidth: 18 + ic.implicitWidth + labelExtra
        readonly property color fg: hot || area.containsMouse ? root.white : root.ink
        signal clicked(var mouse)
        signal scrolled(int delta)

        implicitWidth: row.implicitWidth + 18
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: pill.hot ? root.red : area.containsMouse ? root.navy : root.white
            border.color: root.white
            border.width: pill.hot || area.containsMouse ? 1.5 : 0
            Behavior on color { ColorAnimation { duration: 110 } }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 4
            Icon {
                id: ic
                text: pill.icon
                font.pixelSize: 15
                color: pill.fg
            }
            Text {
                id: lbl
                visible: pill.text !== "" && (!pill.compact || pill.hot)
                text: pill.text
                font.family: root.face
                font.weight: Font.Bold
                font.pixelSize: 13
                color: pill.fg
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => pill.clicked(mouse)
            onWheel: wheel => pill.scrolled(wheel.angleDelta.y)
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
            // reach over Caelestia's 6px frame border so the bar sits flush with the screen edges,
            // and draw 6px past the reserved space to cover the frame's top border (otherwise a
            // dark strip shows between the bar and the windows)
            implicitHeight: root.barHeight + 6
            exclusiveZone: root.barHeight
            margins { top: -6; left: -6; right: -6 }
            color: "transparent"

            readonly property var monitor: Hyprland.monitorFor(modelData)

            // bright blue gradient panel + white line along the bottom, fading out to the
            // right so the bar blends into the corner calendar sitting in front of it
            Item {
                id: panel
                anchors.fill: parent
                visible: false
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.top }
                        GradientStop { position: 1.0; color: root.bottom }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 3
                    color: root.white
                }
            }
            Rectangle {
                id: fadeMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "white" }
                    GradientStop { position: Math.max(0, (bar.width - root.hudWidth - 60) / bar.width); color: "white" }
                    GradientStop { position: Math.min(1, (bar.width - root.hudWidth + 140) / bar.width); color: "transparent" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: panel
                maskEnabled: true
                maskSource: fadeMask
                maskThresholdMin: 0.0
                maskSpreadAtMin: 1.0
            }

            Item {
                anchors { fill: parent; bottomMargin: 3 }

                // left: launcher, workspace tabs, window title
                RowLayout {
                    id: leftRow
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                    spacing: 6

                    // launcher: white circle, blue grid icon
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: launchArea.containsMouse ? root.navy : root.white
                        border.color: root.white
                        border.width: 1.5
                        Icon {
                            anchors.centerIn: parent
                            text: "apps"
                            font.pixelSize: 17
                            color: launchArea.containsMouse ? root.white : root.ink
                        }
                        MouseArea {
                            id: launchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.caelestia(["shell", "drawers", "toggle", "launcher"])
                        }
                    }

                    Item { implicitWidth: 4 }

                    Repeater {
                        model: 5

                        Rectangle {
                            id: ws
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)

                            implicitWidth: active ? 46 : 32
                            implicitHeight: 26
                            radius: 13
                            color: active ? root.white : Qt.alpha(root.white, wsArea.containsMouse ? 0.35 : occupied ? 0.22 : 0.08)
                            border.color: root.white
                            border.width: active ? 0 : 1.5
                            opacity: active || occupied || wsArea.containsMouse ? 1 : 0.7
                            Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 110 } }

                            Text {
                                anchors.centerIn: parent
                                text: ws.wsId
                                font.family: root.face
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: ws.active ? root.ink : root.white
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

                    Text {
                        id: titleText
                        readonly property real room: rightRow.x - leftRow.x - x - 24
                        visible: text !== "" && room > 60
                        Layout.leftMargin: 10
                        Layout.maximumWidth: Math.max(0, room)
                        elide: Text.ElideRight
                        text: Hyprland.activeToplevel?.title ?? ""
                        font.family: root.face
                        font.weight: Font.DemiBold
                        font.pixelSize: 15
                        color: root.white
                    }
                }

                // right (left of the corner calendar): tray, status pills, power
                RowLayout {
                    id: rightRow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 + root.hudWidth }
                    spacing: 8

                    // drop pill labels (bluetooth, then wifi, then volume) when space runs out
                    readonly property var squeezable: [btPill, netPill, volPill]
                    readonly property real room: parent.width * 0.42
                    readonly property var pills: [netPill, btPill, volPill, batPill]
                    readonly property real fullWidth: {
                        const shown = pills.filter(c => c.visible);
                        const n = SystemTray.items.values.length + shown.length + 1;
                        return SystemTray.items.values.length * 26 + shown.reduce((a, c) => a + c.fullWidth, 0)
                            + powerBtn.implicitWidth + spacing * (n - 1);
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
                    Pill {
                        id: netPill
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
                        text: wired ? "LAN" : !Networking.wifiEnabled ? "OFF" : !wifiNet ? "NO NET"
                            : wifiNet.name.length > 12 ? wifiNet.name.slice(0, 11) + "…" : wifiNet.name
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                            else
                                root.openSettings("network");
                        }
                    }

                    // bluetooth: left click = bluetooth settings, right click = adapter on/off
                    Pill {
                        id: btPill
                        compact: rightRow.squeeze >= 1
                        readonly property var adapter: Bluetooth.defaultAdapter
                        readonly property var conn: adapter ? adapter.devices.values.filter(d => d.connected) : []
                        visible: adapter !== null
                        icon: !adapter?.enabled ? "bluetooth_disabled" : conn.length ? "bluetooth_connected" : "bluetooth"
                        text: !adapter?.enabled ? "OFF" : conn.length === 1
                            ? (conn[0].name.length > 12 ? conn[0].name.slice(0, 11) + "…" : conn[0].name)
                            : conn.length > 1 ? `${conn.length} DEV` : "ON"
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (adapter) adapter.enabled = !adapter.enabled;
                            } else {
                                root.openSettings("bluetooth");
                            }
                        }
                    }

                    Pill {
                        id: volPill
                        compact: rightRow.squeeze >= 3
                        readonly property var audio: Pipewire.defaultAudioSink?.audio
                        readonly property int pct: Math.round((audio?.volume ?? 0) * 100)
                        icon: !audio || audio.muted ? "volume_off" : pct > 50 ? "volume_up" : pct > 0 ? "volume_down" : "volume_mute"
                        text: !audio ? "--" : audio.muted ? "MUTE" : `${pct}%`
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

                    Pill {
                        id: batPill
                        readonly property var dev: UPower.displayDevice
                        readonly property int pct: Math.round((dev?.percentage ?? 0) * (dev?.percentage > 1 ? 1 : 100))
                        readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged
                        visible: dev?.isLaptopBattery ?? false
                        hot: pct <= 15 && !charging
                        icon: charging ? "bolt" : pct > 15 ? "battery_full" : "battery_alert"
                        text: `${pct}%`
                    }

                    // power: red circle, white rim; opens the p3 power menu
                    Rectangle {
                        id: powerBtn
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: powerArea.containsMouse ? "#ff6077" : root.red
                        border.color: root.white
                        border.width: 2
                        Icon {
                            anchors.centerIn: parent
                            text: "power_settings_new"
                            font.pixelSize: 16
                            color: root.white
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
