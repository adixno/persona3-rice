// Persona 3 theme lock screen. The corner calendar from p3-hud at the same size
// and spot (440x118, top-right: blue panel with a diagonal bottom edge, ghost WEEKDAY/WEEKEND,
// wave bands, outlined date, weekday in a red triangle, cyan time of day, yellow time, today's
// real moon phase); the password pill on the right half, since the lock video's character sits
// on the left; a quiet info line under it. Full-screen: LockSurface.qml (overlay) places this
// over the lock-bg.mp4 video (or the blurred desktop without it) and calls enter()/leave().
// PAM logic is Caelestia's. Previous full-width band version: themes/p3/drafts/lock-band-Content.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import qs.services

Item {
    id: root

    required property var lock

    readonly property color deep: "#030a26"
    readonly property color white: "#ffffff"
    readonly property color cyan: "#2ff3ff"
    readonly property color red: "#ff2a3a"
    readonly property color gold: "#ffe600"
    readonly property string face: "Jost"
    readonly property string icons: "Material Symbols Sharp"

    readonly property var pam: lock.pam
    readonly property bool failed: pam.state === Pam.Failed || pam.state === Pam.Error || pam.state === Pam.MaxTries
    readonly property bool weekend: Time.date.getDay() === 0 || Time.date.getDay() === 6

    // 0 → 1 as things slide in; back to 0 when unlocking
    property real shown: 0
    function enter(): void { leaveAnim.stop(); enterAnim.restart(); }
    function leave(): void { enterAnim.stop(); leaveAnim.restart(); }
    NumberAnimation { id: enterAnim; target: root; property: "shown"; to: 1; duration: 650; easing.type: Easing.OutCubic }
    NumberAnimation { id: leaveAnim; target: root; property: "shown"; to: 0; duration: 260; easing.type: Easing.InCubic }

    function dayPart(h: int): string {
        return h < 5 ? "Late Night" : h < 7 ? "Early Morning" : h < 11 ? "Morning" : h < 14 ? "Daytime"
            : h < 18 ? "Afternoon" : h < 21 ? "Evening" : "Night";
    }
    function moonPhase(d: date): real {
        const ref = Date.UTC(2000, 0, 6, 18, 14) / 86400000;
        const p = ((d.getTime() / 86400000 - ref) % 29.530588853) / 29.530588853;
        return p < 0 ? p + 1 : p;
    }

    // dim the backdrop a little
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.deep, 0.4)
    }

    // ── corner calendar: same size and place as p3-hud ───────────────────────
    Item {
        id: cal
        width: 440
        height: 118
        x: root.width - width + (1 - root.shown) * 120
        y: 0
        opacity: root.shown

        readonly property real pw: width
        readonly property real ph: height
        readonly property real leftY: ph * 0.5
        function bottomAt(x: real): real { return leftY + (ph - leftY) * x / pw; }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: cal.pw; y2: 0
                    GradientStop { position: 0.0; color: Qt.alpha("#dfe9ff", 0.0) }
                    GradientStop { position: 0.12; color: Qt.alpha("#8fb0ff", 0.55) }
                    GradientStop { position: 0.3; color: "#1830f0" }
                    GradientStop { position: 1.0; color: "#0a1ee0" }
                }
                PathPolyline { path: [Qt.point(0, 0), Qt.point(cal.pw, 0), Qt.point(cal.pw, cal.ph), Qt.point(0, cal.leftY), Qt.point(0, 0)] }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            y: -14
            text: root.weekend ? "WEEKEND" : "WEEKDAY"
            font.family: root.face
            font.weight: Font.Black
            font.pixelSize: 78
            font.letterSpacing: -1
            color: Qt.alpha("#06128f", 0.55)
        }

        // wave bands across the whole panel: same GPU shader as p3-hud, animated on AC only
        ShaderEffect {
            anchors.fill: parent
            property real phase: 0
            property real leftY: cal.leftY
            property size size: Qt.size(width, height)
            fragmentShader: Qt.resolvedUrl("waves.frag.qsb")

            Timer {
                interval: 33
                repeat: true
                running: root.shown > 0 && motion.speed > 0
                onTriggered: parent.phase = (parent.phase + Math.PI * 2 * interval / 9000 * motion.speed) % (Math.PI * 2)
            }
            Motion { id: motion }
        }

        Text {
            id: dateText
            x: 104
            // fits between its x and the time block (minus the weekday triangle); shrinks only if needed
            width: timeCol.x - 10 - dayTri.width - 2 - x
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 34
            y: 12
            text: Time.format("M/d")
            font.family: root.face
            font.weight: Font.Bold
            font.pixelSize: 50
            font.letterSpacing: -1
            color: root.white
            style: Text.Outline
            styleColor: Qt.alpha(root.deep, 0.7)
        }

        Item {
            id: dayTri
            x: dateText.x + dateText.contentWidth + 2
            y: 22
            width: 44
            height: 34
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.red
                    strokeWidth: -1
                    PathPolyline { path: [Qt.point(0, 0), Qt.point(dayTri.width, 0), Qt.point(dayTri.width / 2, dayTri.height), Qt.point(0, 0)] }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -1
                text: Time.format("ddd")
                font.family: root.face
                font.weight: Font.Bold
                font.pixelSize: 17
                color: root.white
                style: Text.Outline
                styleColor: Qt.alpha("#7a0010", 0.6)
            }
        }

        Text {
            x: dateText.x + dateText.contentWidth / 2 + 18 - width / 2
            y: 66
            text: root.dayPart(Time.hours)
            font.family: root.face
            font.weight: Font.Bold
            font.pixelSize: 22
            color: root.cyan
            style: Text.Outline
            styleColor: Qt.alpha(root.deep, 0.75)
        }

        Column {
            id: timeCol
            // pinned left of the moon so wide dates (11/10, 12/28) never push it under it
            anchors.right: moon.left
            anchors.rightMargin: 10
            y: 20
            spacing: -4
            Text {
                text: "T I M E"
                font.family: root.face
                font.weight: Font.Bold
                font.pixelSize: 11
                color: "#fff6c0"
            }
            Text {
                text: Time.format("hh:mm")
                font.family: root.face
                font.weight: Font.Bold
                font.pixelSize: 30
                color: root.gold
                style: Text.Outline
                styleColor: Qt.alpha(root.deep, 0.55)
            }
        }

        Canvas {
            id: moon
            readonly property real phase: root.moonPhase(Time.date)
            x: cal.pw - 64
            y: 14
            width: 56
            height: 56
            onPhaseChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2, cy = height / 2, r = width / 2 - 3;
                const g = ctx.createLinearGradient(0, 0, width, 0);
                g.addColorStop(0, "#1c1c26");
                g.addColorStop(1, "#3a3a48");
                ctx.fillStyle = g;
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

    // ── right side: password pill, message, info line ────────────────────────
    Column {
        id: side
        // centred in the right half of the screen
        x: root.width * 0.75 - width / 2 + (1 - root.shown) * 60
        anchors.verticalCenter: parent.verticalCenter
        width: 400
        spacing: 12
        opacity: root.shown

        Item {
            id: passWrap
            width: parent.width
            height: 56
            property real shake: 0

            Rectangle {
                id: pass
                x: passWrap.shake
                width: parent.width
                height: parent.height
                radius: height / 2
                color: Qt.alpha(root.deep, 0.88)
                border.color: root.failed ? root.red : "#3fd8ff"
                border.width: 2

                focus: true
                onActiveFocusChanged: if (!activeFocus) forceActiveFocus()
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    if (root.lock.unlocking)
                        return;
                    root.pam.handleKey(event);
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pam.passwd.active ? "hourglass_top" : "lock"
                    font.family: root.icons
                    font.pixelSize: 22
                    color: root.failed ? root.red : "#3fd8ff"
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 120
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.pam.buffer.length ? "●".repeat(Math.min(root.pam.buffer.length, 20)) : "Enter password"
                    font.family: root.face
                    font.weight: root.pam.buffer.length ? Font.Black : Font.DemiBold
                    font.pixelSize: root.pam.buffer.length ? 18 : 19
                    font.letterSpacing: root.pam.buffer.length ? 5 : 1
                    color: root.pam.buffer.length ? root.white : Qt.alpha(root.white, 0.45)
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "keyboard_return"
                    font.family: root.icons
                    font.pixelSize: 22
                    color: root.pam.buffer.length ? "#3fd8ff" : Qt.alpha("#3fd8ff", 0.35)
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

        // message under the pill
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.pam.state === Pam.MaxTries ? "Too many tries. Wait a moment."
                : root.pam.state === Pam.Failed ? "Wrong password"
                : root.pam.state === Pam.Error ? "Something went wrong"
                : root.pam.lockMessage
            visible: text.length > 0
            font.family: root.face
            font.weight: Font.Bold
            font.pixelSize: 17
            color: root.failed ? "#ffb3bd" : root.white
            style: Text.Outline
            styleColor: Qt.alpha(root.deep, 0.6)
        }
    }

    // ── quiet info line, bottom of the right half: battery · now playing · notifications
    component Info: Row {
        id: inf
        property string icon
        property string label
        spacing: 6
        Text { text: inf.icon; font.family: root.icons; font.pixelSize: 18; color: "#3fd8ff"; anchors.verticalCenter: parent.verticalCenter }
        Text { text: inf.label; font.family: root.face; font.weight: Font.DemiBold; font.pixelSize: 16; color: root.white; anchors.verticalCenter: parent.verticalCenter }
    }
    Row {
        x: root.width * 0.75 - width / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        spacing: 26
        opacity: root.shown * 0.9

        Info {
            readonly property var dev: UPower.displayDevice
            readonly property int pct: Math.round((dev?.percentage ?? 0) * (dev?.percentage > 1 ? 1 : 100))
            readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged
            visible: dev?.isLaptopBattery ?? false
            icon: charging ? "bolt" : pct > 15 ? "battery_full" : "battery_alert"
            label: `${pct}%`
        }
        Info {
            visible: !!Players.active?.trackTitle
            icon: Players.active?.isPlaying ? "music_note" : "pause"
            label: {
                const p = Players.active;
                const t = p?.trackTitle ?? "";
                const a = p?.trackArtist ?? "";
                const txt = a ? `${t} — ${a}` : t;
                return txt.length > 48 ? txt.slice(0, 47) + "…" : txt;
            }
        }
        Info {
            visible: Notifs.notClosed.length > 0
            icon: "notifications"
            label: `${Notifs.notClosed.length} notification${Notifs.notClosed.length === 1 ? "" : "s"}`
        }
    }
}
