// Persona 3 theme lock screen content, Portable-bar visual language:
// bright blue gradient card with a white rim and soft waves, white rounded tabs and pills,
// the corner-calendar date/moon, avatar in a white ring, big time, white password pill,
// and white cards for media and notifications. Replaces Caelestia's Content.qml via the
// overlay; the lock surface, intro animation and PAM logic are untouched.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import Caelestia.Config
import qs.services

Item {
    id: root

    required property var lock

    readonly property color gTop: "#3f86ff"
    readonly property color gBottom: "#1240d8"
    readonly property color ink: "#1240d8"
    readonly property color navy: "#0a2a9a"
    readonly property color white: "#ffffff"
    readonly property color red: "#ff3a5a"
    readonly property color cyan: "#2ff3ff"
    readonly property color gold: "#ffe600"
    readonly property string face: "Jost"
    readonly property string icons: "Material Symbols Sharp"
    readonly property real s: Math.max(0.7, Math.min(1.2, height / 900))   // layout scale

    readonly property var pam: lock.pam
    readonly property bool failed: pam.state === Pam.Failed || pam.state === Pam.Error || pam.state === Pam.MaxTries

    function dayPart(h: int): string {
        return h < 5 ? "Late Night" : h < 7 ? "Early Morning" : h < 11 ? "Morning" : h < 14 ? "Daytime"
            : h < 18 ? "Afternoon" : h < 21 ? "Evening" : "Night";
    }
    function moonPhase(d: date): real {
        const ref = Date.UTC(2000, 0, 6, 18, 14) / 86400000;
        const p = ((d.getTime() / 86400000 - ref) % 29.530588853) / 29.530588853;
        return p < 0 ? p + 1 : p;
    }

    component Icon: Text {
        font.family: root.icons
        font.pixelSize: 18 * root.s
        color: root.ink
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
    component Pill: Rectangle {
        id: pl
        property string icon
        property string text
        property color fg: root.ink
        implicitWidth: plRow.implicitWidth + 22 * root.s
        implicitHeight: 30 * root.s
        radius: height / 2
        color: root.white
        Row {
            id: plRow
            anchors.centerIn: parent
            spacing: 5 * root.s
            Icon { visible: pl.icon !== ""; text: pl.icon; color: pl.fg; font.pixelSize: 17 * root.s; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pl.text; color: pl.fg; font.family: root.face; font.weight: Font.Bold; font.pixelSize: 15 * root.s; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    // white card with a blue header tab
    component Card: Rectangle {
        id: cd
        property string title
        property string titleIcon
        default property alias body: cdBody.data
        radius: 18 * root.s
        color: root.white
        Rectangle {
            id: cdTab
            x: 14 * root.s
            y: -12 * root.s
            width: cdTabRow.implicitWidth + 22 * root.s
            height: 26 * root.s
            radius: height / 2
            color: root.ink
            border.color: root.white
            border.width: 2
            Row {
                id: cdTabRow
                anchors.centerIn: parent
                spacing: 5 * root.s
                Icon { text: cd.titleIcon; color: root.white; font.pixelSize: 15 * root.s; anchors.verticalCenter: parent.verticalCenter }
                Text { text: cd.title; color: root.white; font.family: root.face; font.weight: Font.Bold; font.pixelSize: 13 * root.s; font.letterSpacing: 1.5; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Item {
            id: cdBody
            anchors.fill: parent
            anchors.margins: 16 * root.s
            anchors.topMargin: 22 * root.s
        }
    }

    // ── card background: blue gradient, white rim, soft waves ─────────────────
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 22 * root.s
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.gTop }
            GradientStop { position: 1.0; color: root.gBottom }
        }
        border.color: root.white
        border.width: 3
        clip: true

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(root.white, 0.16); strokeWidth: 2; fillColor: "transparent"
                PathPolyline { path: { const p = []; for (let x = 0; x <= panel.width; x += 8) p.push(Qt.point(x, panel.height * 0.62 + 7 * Math.sin(x / 70))); return p; } }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.white, 0.11); strokeWidth: 2; fillColor: "transparent"
                PathPolyline { path: { const p = []; for (let x = 0; x <= panel.width; x += 8) p.push(Qt.point(x, panel.height * 0.68 + 6 * Math.sin(x / 55 + 1.4))); return p; } }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.white, 0.08); strokeWidth: 2; fillColor: "transparent"
                PathPolyline { path: { const p = []; for (let x = 0; x <= panel.width; x += 8) p.push(Qt.point(x, panel.height * 0.74 + 5 * Math.sin(x / 45 + 2.6))); return p; } }
            }
        }
        // light from the top
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: parent.height * 0.4
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(root.white, 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // ── top left: LOCKED tab, user, battery ───────────────────────────────────
    Row {
        x: 26 * root.s
        y: 24 * root.s
        spacing: 10 * root.s

        Pill { icon: "lock"; text: "LOCKED" }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Quickshell.env("USER") ?? ""
            font.family: root.face
            font.weight: Font.DemiBold
            font.pixelSize: 17 * root.s
            color: root.white
        }
        Pill {
            readonly property var dev: UPower.displayDevice
            readonly property int pct: Math.round((dev?.percentage ?? 0) * (dev?.percentage > 1 ? 1 : 100))
            readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged
            visible: dev?.isLaptopBattery ?? false
            icon: charging ? "bolt" : pct > 15 ? "battery_full" : "battery_alert"
            text: `${pct}%`
            color: pct <= 15 && !charging ? root.red : root.white
            fg: pct <= 15 && !charging ? root.white : root.ink
        }
    }

    // ── top right: mini calendar (date, weekday triangle, time of day, moon) ──
    Item {
        id: cal
        anchors.right: parent.right
        anchors.rightMargin: 26 * root.s
        y: 16 * root.s
        width: calRow.implicitWidth
        height: 80 * root.s

        Row {
            id: calRow
            spacing: 10 * root.s
            Column {
                spacing: -4 * root.s
                Row {
                    spacing: 2 * root.s
                    Text {
                        id: calDate
                        text: Time.format("M/d")
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 44 * root.s
                        color: root.white
                        style: Text.Outline
                        styleColor: Qt.alpha(root.navy, 0.7)
                    }
                    Item {
                        id: tri
                        width: 40 * root.s
                        height: 30 * root.s
                        y: 9 * root.s
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: root.red; strokeWidth: -1
                                PathPolyline { path: [Qt.point(0, 0), Qt.point(tri.width, 0), Qt.point(tri.width / 2, tri.height), Qt.point(0, 0)] }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -1
                            text: Time.format("ddd")
                            font.family: root.face
                            font.weight: Font.Bold
                            font.pixelSize: 15 * root.s
                            color: root.white
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dayPart(Time.hours)
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 19 * root.s
                    color: root.cyan
                    style: Text.Outline
                    styleColor: Qt.alpha(root.navy, 0.75)
                }
            }
            Canvas {
                id: moon
                readonly property real phase: root.moonPhase(Time.date)
                width: 52 * root.s
                height: width
                anchors.verticalCenter: parent.verticalCenter
                onPhaseChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2, r = width / 2 - 3;
                    ctx.fillStyle = "#24242e";
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
                    const side = phase < 0.5 ? 1 : -1, k = Math.cos(phase * 2 * Math.PI);
                    ctx.fillStyle = "#ffe600";
                    ctx.beginPath();
                    for (let i = 0; i <= 48; i++) { const t = -Math.PI / 2 + Math.PI * i / 48; ctx.lineTo(cx + side * r * Math.cos(t), cy + r * Math.sin(t)); }
                    for (let i = 48; i >= 0; i--) { const t = -Math.PI / 2 + Math.PI * i / 48; ctx.lineTo(cx + side * k * r * Math.cos(t), cy + r * Math.sin(t)); }
                    ctx.closePath(); ctx.fill();
                    ctx.strokeStyle = "#ffe600"; ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                }
            }
        }
    }

    // ── centre: avatar, big time, password pill, message ─────────────────────
    Column {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.13
        spacing: 12 * root.s

        // avatar in a white ring (falls back to an icon)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 108 * root.s
            height: width
            radius: width / 2
            color: root.white
            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 5 * root.s
                radius: width / 2
                color: root.navy
                Image {
                    id: faceImg
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.face"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                Icon {
                    anchors.centerIn: parent
                    visible: faceImg.status !== Image.Ready
                    text: "person"
                    color: root.white
                    font.pixelSize: 52 * root.s
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("hh:mm")
            font.family: root.face
            font.weight: Font.Bold
            font.pixelSize: 108 * root.s
            color: root.white
            style: Text.Raised
            styleColor: Qt.alpha(root.navy, 0.55)
        }

        // password pill: takes keyboard input and hands it to PAM
        Item {
            id: passWrap
            anchors.horizontalCenter: parent.horizontalCenter
            width: 440 * root.s
            height: 54 * root.s
            property real shake: 0

            Rectangle {
                id: pass
                x: passWrap.shake
                width: parent.width
                height: parent.height
                radius: height / 2
                color: root.white
                border.color: root.failed ? root.red : root.white
                border.width: 3

                focus: true
                onActiveFocusChanged: if (!activeFocus) forceActiveFocus()
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    if (root.lock.unlocking)
                        return;
                    root.pam.handleKey(event);
                }

                Rectangle {
                    x: 7 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40 * root.s
                    height: width
                    radius: width / 2
                    color: root.failed ? root.red : root.ink
                    Icon {
                        anchors.centerIn: parent
                        text: root.pam.passwd.active ? "hourglass_top" : "lock"
                        color: root.white
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 58 * root.s
                    width: parent.width - 120 * root.s
                    elide: Text.ElideRight
                    text: root.pam.buffer.length ? "●".repeat(Math.min(root.pam.buffer.length, 24)) : "Enter password"
                    font.family: root.face
                    font.weight: root.pam.buffer.length ? Font.Black : Font.DemiBold
                    font.pixelSize: (root.pam.buffer.length ? 16 : 18) * root.s
                    font.letterSpacing: root.pam.buffer.length ? 3 : 0
                    color: root.pam.buffer.length ? root.ink : Qt.alpha(root.ink, 0.45)
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40 * root.s
                    height: width
                    radius: width / 2
                    color: root.pam.buffer.length ? root.ink : Qt.alpha(root.ink, 0.25)
                    Icon {
                        anchors.centerIn: parent
                        text: "arrow_forward"
                        color: root.white
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: pass.forceActiveFocus()
                }
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: passWrap; property: "shake"; to: -16; duration: 50 }
                NumberAnimation { target: passWrap; property: "shake"; to: 13; duration: 70 }
                NumberAnimation { target: passWrap; property: "shake"; to: -7; duration: 60 }
                NumberAnimation { target: passWrap; property: "shake"; to: 0; duration: 60 }
            }
            Connections {
                target: root.pam
                function onStateChanged() {
                    if (root.failed)
                        shakeAnim.restart();
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 22 * root.s
            text: root.pam.state === Pam.MaxTries ? "Too many tries. Wait a moment."
                : root.pam.state === Pam.Failed ? "Wrong password"
                : root.pam.state === Pam.Error ? "Something went wrong"
                : root.pam.lockMessage
            font.family: root.face
            font.weight: Font.Bold
            font.pixelSize: 16 * root.s
            color: root.failed ? "#ffd0d6" : root.white
        }
    }

    // ── bottom: now playing + notifications ───────────────────────────────────
    RowLayout {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 26 * root.s; bottomMargin: 24 * root.s }
        height: 128 * root.s
        spacing: 20 * root.s

        Card {
            id: mediaCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "NOW PLAYING"
            titleIcon: "music_note"

            readonly property var player: Players.active

            Column {
                anchors { left: parent.left; right: mediaBtns.left; rightMargin: 10 * root.s; verticalCenter: parent.verticalCenter }
                spacing: 2
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: mediaCard.player?.trackTitle || "Nothing playing"
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 18 * root.s
                    color: root.ink
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: mediaCard.player?.trackArtist || "Play something to see it here"
                    font.family: root.face
                    font.weight: Font.Medium
                    font.pixelSize: 14 * root.s
                    color: Qt.alpha(root.ink, 0.6)
                }
            }
            Row {
                id: mediaBtns
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * root.s
                Repeater {
                    model: [["skip_previous", "previous"], ["", "toggle"], ["skip_next", "next"]]
                    Rectangle {
                        required property var modelData
                        readonly property var player: Players.active
                        width: (modelData[1] === "toggle" ? 42 : 34) * root.s
                        height: width
                        radius: width / 2
                        color: btnArea.containsMouse ? root.navy : root.ink
                        opacity: player ? 1 : 0.35
                        Icon {
                            anchors.centerIn: parent
                            color: root.white
                            text: parent.modelData[0] || (parent.player?.isPlaying ? "pause" : "play_arrow")
                        }
                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !!parent.player
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const p = parent.player;
                                if (parent.modelData[1] === "previous") p.previous();
                                else if (parent.modelData[1] === "next") p.next();
                                else p.togglePlaying();
                            }
                        }
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: Notifs.notClosed.length ? `NOTIFICATIONS · ${Notifs.notClosed.length}` : "NOTIFICATIONS"
            titleIcon: "notifications"

            Column {
                anchors.fill: parent
                spacing: 4 * root.s
                Text {
                    visible: Notifs.notClosed.length === 0
                    text: "All clear"
                    font.family: root.face
                    font.weight: Font.Bold
                    font.pixelSize: 18 * root.s
                    color: root.ink
                }
                Repeater {
                    model: Notifs.notClosed.slice(-3).reverse()
                    Row {
                        required property var modelData
                        width: parent.width
                        spacing: 8 * root.s
                        Text {
                            id: app
                            text: modelData.appName || "App"
                            font.family: root.face
                            font.weight: Font.Bold
                            font.pixelSize: 14 * root.s
                            color: root.ink
                        }
                        Text {
                            width: parent.width - app.implicitWidth - 8 * root.s
                            elide: Text.ElideRight
                            text: modelData.summary || ""
                            font.family: root.face
                            font.weight: Font.Medium
                            font.pixelSize: 14 * root.s
                            color: Qt.alpha(root.ink, 0.65)
                        }
                    }
                }
            }
        }
    }
}
