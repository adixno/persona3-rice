// Top bar for the Persona 3 theme, "deep glass": a slim, dark, see-through navy
// strip (Hyprland blurs what is behind it: layer rule on namespace "persona-bar" in
// themes/p3/hypr/look.lua) with a single cyan line along the bottom. Quiet on purpose, the
// corner calendar stays the bright piece. Bold white workspace numbers (the active one dark
// on a solid cyan tab that runs into the glowing cyan edge), a huge faint time-of-day ghost
// word behind everything (like the calendar's WEEKDAY), bold white labels with cyan icons,
// battery in the calendar's yellow, a red power icon. No animation: costs nothing idle.
// Earlier versions: themes/p3/drafts/persona-bar-portable.qml (bright blue pills),
// persona-bar-calendar.qml (calendar-style panel with waves).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    readonly property color deep: "#030a26"     // text outline
    readonly property color white: "#ffffff"
    readonly property color cyan: "#2ff3ff"
    readonly property color red: "#ff2a3a"
    readonly property color gold: "#ffe600"

    function dayPart(h: int): string {
        return h < 5 ? "LATE NIGHT" : h < 7 ? "EARLY MORNING" : h < 11 ? "MORNING" : h < 14 ? "DAYTIME"
            : h < 18 ? "AFTERNOON" : h < 21 ? "EVENING" : "NIGHT";
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string face: "Jost"
    readonly property string icons: "Material Symbols Sharp"

    readonly property int barHeight: 44 // reserved space; sync-caelestia.sh reads this
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
        color: root.cyan
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // label: white Jost
    component Label: Text {
        font.family: root.face
        font.weight: Font.Bold
        font.pixelSize: 14
        color: root.white
    }

    // Status item: cyan icon + white label, no background; red when something needs
    // attention, faint highlight on hover
    component Pill: Item {
        id: pill
        property string icon
        property string text
        property bool hot: false
        // icon only (label hidden) when the bar runs out of room; hot pills keep their label
        property bool compact: false
        property color labelColor: root.white
        readonly property real labelExtra: text !== "" ? lbl.implicitWidth + row.spacing : 0
        readonly property real fullWidth: 14 + ic.implicitWidth + labelExtra
        signal clicked(var mouse)
        signal scrolled(int delta)

        implicitWidth: row.implicitWidth + 14
        implicitHeight: 28

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Qt.alpha(root.white, area.containsMouse ? 0.16 : 0)
            Behavior on color { ColorAnimation { duration: 110 } }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 4
            Icon {
                id: ic
                text: pill.icon
                font.pixelSize: 17
                color: pill.hot ? root.red : root.cyan
            }
            Label {
                id: lbl
                visible: pill.text !== "" && (!pill.compact || pill.hot)
                text: pill.text
                color: pill.hot ? "#ffb3bd" : pill.labelColor
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
            WlrLayershell.namespace: "persona-bar"   // blurred behind by a Hyprland layer rule

            readonly property var monitor: Hyprland.monitorFor(modelData)

            // dark see-through navy strip
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha("#050d33", 0.62)
            }
            // huge faint time-of-day word behind everything, like the calendar's ghost WEEKDAY
            Item {
                anchors.fill: parent
                clip: true
                Text {
                    x: bar.width * 0.36
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    text: root.dayPart(clock.date.getHours())
                    font.family: root.face
                    font.weight: Font.Black
                    font.pixelSize: 62
                    font.letterSpacing: 4
                    color: Qt.alpha("#3a8dff", 0.16)
                }
            }
            // glowing edge: soft cyan light rising from a cyan-to-blue line along the bottom
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(root.cyan, 0.16) }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(root.cyan, 0.55) }
                    GradientStop { position: 0.25; color: root.cyan }
                    GradientStop { position: 0.75; color: "#3a8dff" }
                    GradientStop { position: 1.0; color: "#1830f0" }
                }
            }

            Item {
                anchors { fill: parent; bottomMargin: 6 }

                // left: launcher, workspace tabs, window title
                RowLayout {
                    id: leftRow
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                    spacing: 6

                    // launcher: cyan grid icon
                    Item {
                        implicitWidth: 30
                        implicitHeight: 30
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Qt.alpha(root.white, launchArea.containsMouse ? 0.16 : 0)
                        }
                        Icon {
                            anchors.centerIn: parent
                            text: "apps"
                            font.pixelSize: 21
                            color: launchArea.containsMouse ? root.white : root.cyan
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

                    Row {
                    spacing: 2
                    Repeater {
                        model: 5

                        // bold number; the active one is dark on a solid cyan tab that runs
                        // down into the glowing edge
                        Item {
                            id: ws
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)

                            implicitWidth: 30
                            implicitHeight: 30

                            Rectangle {
                                // from just under the top of the bar down to its bottom edge
                                x: 0
                                y: -3
                                width: parent.width
                                height: 44
                                color: root.cyan
                                opacity: ws.active ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                            Label {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                text: ws.wsId
                                font.pixelSize: 17
                                font.weight: Font.Black
                                color: ws.active ? root.deep : root.white
                                opacity: ws.active || wsArea.containsMouse ? 1 : ws.occupied ? 0.9 : 0.4
                                Behavior on opacity { NumberAnimation { duration: 120 } }
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

                    Text {
                        id: titleText
                        readonly property real room: rightRow.x - leftRow.x - x - 24
                        visible: text !== "" && room > 60
                        Layout.leftMargin: 10
                        Layout.maximumWidth: Math.max(0, room)
                        elide: Text.ElideRight
                        text: Hyprland.activeToplevel?.title ?? ""
                        font.family: root.face
                        font.weight: Font.Bold
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
                        labelColor: root.gold
                        icon: charging ? "bolt" : pct > 15 ? "battery_full" : "battery_alert"
                        text: `${pct}%`
                    }

                    // power: red icon (opens the p3 power menu)
                    Item {
                        id: powerBtn
                        implicitWidth: 30
                        implicitHeight: 28
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Qt.alpha(root.red, powerArea.containsMouse ? 0.22 : 0)
                        }
                        Icon {
                            anchors.centerIn: parent
                            text: "power_settings_new"
                            font.pixelSize: 18
                            color: powerArea.containsMouse ? "#ff8090" : "#ff4d63"
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
