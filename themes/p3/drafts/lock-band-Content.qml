// Persona 3 theme lock screen, "calendar takeover": the corner calendar blown
// up into a slanted full-width band (sky haze fading into blue, flowing wave bands, huge
// dark WEEKDAY/WEEKEND), giant outlined date, weekday in a red triangle, cyan time of day,
// yellow time, today's real moon phase; a slim dark password pill below; a quiet info line
// at the bottom. Full-screen: LockSurface.qml (overlay) places this over the blurred desktop
// (or over the lock-bg.mp4 video when present) and calls enter()/leave(). PAM logic is Caelestia's.
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
    readonly property real s: height / 720      // layout unit, 1 at 720p
    readonly property real sw: width
    readonly property real sh: height

    readonly property var pam: lock.pam
    readonly property bool failed: pam.state === Pam.Failed || pam.state === Pam.Error || pam.state === Pam.MaxTries
    readonly property bool weekend: Time.date.getDay() === 0 || Time.date.getDay() === 6

    // 0 → 1 as the band slides in; back to 0 when unlocking
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

    // band corners (slanted): top edge rises to the right, bottom edge drops
    readonly property real bandTopL: sh * 0.21
    readonly property real bandTopR: sh * 0.15
    readonly property real bandBotL: sh * 0.58
    readonly property real bandBotR: sh * 0.65
    function bandBot(x: real): real { return bandBotL + (bandBotR - bandBotL) * x / sw; }

    // dim the blurred desktop a little
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.deep, 0.4)
    }

    // ── the band: everything on it slides in together ─────────────────────────
    Item {
        id: band
        width: root.sw
        height: root.sh
        x: (1 - root.shown) * root.sw * 0.35
        opacity: root.shown

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: root.sw; y2: 0
                    GradientStop { position: 0.0; color: Qt.alpha("#dfe9ff", 0.0) }
                    GradientStop { position: 0.12; color: Qt.alpha("#8fb0ff", 0.8) }
                    GradientStop { position: 0.3; color: "#1830f0" }
                    GradientStop { position: 1.0; color: "#0a1ee0" }
                }
                PathPolyline { path: [Qt.point(0, root.bandTopL), Qt.point(root.sw, root.bandTopR), Qt.point(root.sw, root.bandBotR), Qt.point(0, root.bandBotL), Qt.point(0, root.bandTopL)] }
            }
        }

        // ghost word, kept inside the band's height
        Item {
            y: root.bandTopR
            width: root.sw
            height: root.bandBotL - root.bandTopR
            clip: true
            Text {
                x: root.sw * 0.13
                y: -root.sh * 0.03
                text: root.weekend ? "WEEKEND" : "WEEKDAY"
                font.family: root.face
                font.weight: Font.Black
                font.pixelSize: 236 * root.s
                font.letterSpacing: -3 * root.s
                color: Qt.alpha("#06128f", 0.55)
            }
        }

        // wave bands flowing across the middle
        Shape {
            id: waves
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            property real ph: 0
            NumberAnimation on ph { from: 0; to: Math.PI * 2; duration: 9000; loops: Animation.Infinite }
            function wave(y0: real, thick: real, amp: real, len: real, off: real): var {
                const t = [], b = [];
                for (let x = root.sw * 0.12; x <= root.sw; x += 8) {
                    const w = amp * Math.sin(x / len + off + ph);
                    const lo = root.bandBot(x) - 2;
                    t.push(Qt.point(x, Math.min(y0 + w, lo)));
                    b.push(Qt.point(x, Math.min(y0 + w + thick + amp * 0.5 * Math.sin(x / (len * 0.66) + off), lo)));
                }
                return t.concat(b.reverse(), [t[0]]);
            }
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.alpha("#3a8dff", 0.45)
                PathPolyline { path: waves.wave(root.sh * 0.37, 26 * root.s, 14 * root.s, 120 * root.s, 0.4) }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.alpha("#5fb4ff", 0.28)
                PathPolyline { path: waves.wave(root.sh * 0.47, 16 * root.s, 10 * root.s, 95 * root.s, 2.0) }
            }
        }

        // date + weekday triangle + time of day
        Text {
            id: bigDate
            x: root.sw * 0.22
            y: root.sh * 0.235
            text: Time.format("M/d")
            font.family: root.face
            font.weight: Font.Bold
            font.pixelSize: 150 * root.s
            font.letterSpacing: -2 * root.s
            color: root.white
            style: Text.Outline
            styleColor: Qt.alpha(root.deep, 0.7)
        }
        Item {
            id: tri
            anchors.left: bigDate.right
            anchors.leftMargin: 6 * root.s
            y: bigDate.y + 30 * root.s
            width: 112 * root.s
            height: 86 * root.s
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
                y: -2 * root.s
                text: Time.format("ddd")
                font.family: root.face
                font.weight: Font.Bold
                font.pixelSize: 40 * root.s
                color: root.white
                style: Text.Outline
                styleColor: Qt.alpha("#7a0010", 0.6)
            }
        }
        Text {
            anchors.horizontalCenter: bigDate.horizontalCenter
            anchors.horizontalCenterOffset: 40 * root.s
            anchors.top: bigDate.bottom
            anchors.topMargin: -14 * root.s
            text: root.dayPart(Time.hours)
            font.family: root.face
            font.weight: Font.Bold
            font.pixelSize: 54 * root.s
            color: root.cyan
            style: Text.Outline
            styleColor: Qt.alpha(root.deep, 0.75)
        }

        // time + moon on the right
        Column {
            x: root.sw * 0.66
            y: root.sh * 0.27
            spacing: -8 * root.s
            Text {
                text: "T I M E"
                font.family: root.face
                font.weight: Font.Bold
                font.pixelSize: 22 * root.s
                color: "#fff6c0"
            }
            Text {
                text: Time.format("hh:mm")
                font.family: root.face
                font.weight: Font.Bold
                font.pixelSize: 88 * root.s
                color: root.gold
                style: Text.Outline
                styleColor: Qt.alpha(root.deep, 0.55)
            }
        }
        Canvas {
            id: moon
            readonly property real phase: root.moonPhase(Time.date)
            x: root.sw * 0.865
            y: root.sh * 0.28
            width: 132 * root.s
            height: width
            onPhaseChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2, cy = height / 2, r = width / 2 - 5;
                const g = ctx.createLinearGradient(0, 0, width, 0);
                g.addColorStop(0, "#1c1c26");
                g.addColorStop(1, "#3a3a48");
                ctx.fillStyle = g;
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
                const side = phase < 0.5 ? 1 : -1, k = Math.cos(phase * 2 * Math.PI);
                ctx.fillStyle = "#ffe600";
                ctx.beginPath();
                for (let i = 0; i <= 64; i++) { const t = -Math.PI / 2 + Math.PI * i / 64; ctx.lineTo(cx + side * r * Math.cos(t), cy + r * Math.sin(t)); }
                for (let i = 64; i >= 0; i--) { const t = -Math.PI / 2 + Math.PI * i / 64; ctx.lineTo(cx + side * k * r * Math.cos(t), cy + r * Math.sin(t)); }
                ctx.closePath(); ctx.fill();
                ctx.strokeStyle = "#ffe600"; ctx.lineWidth = 7 * root.s;
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
            }
        }
    }

    // ── password pill, below the band ─────────────────────────────────────────
    Item {
        id: passWrap
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.sh * 0.74 + (1 - root.shown) * 40 * root.s
        opacity: root.shown
        width: 460 * root.s
        height: 56 * root.s
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
                anchors.leftMargin: 20 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.pam.passwd.active ? "hourglass_top" : "lock"
                font.family: root.icons
                font.pixelSize: 22 * root.s
                color: root.failed ? root.red : "#3fd8ff"
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 120 * root.s
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.pam.buffer.length ? "●".repeat(Math.min(root.pam.buffer.length, 20)) : "Enter password"
                font.family: root.face
                font.weight: root.pam.buffer.length ? Font.Black : Font.DemiBold
                font.pixelSize: (root.pam.buffer.length ? 18 : 19) * root.s
                font.letterSpacing: root.pam.buffer.length ? 5 * root.s : 1
                color: root.pam.buffer.length ? root.white : Qt.alpha(root.white, 0.45)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 20 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "keyboard_return"
                font.family: root.icons
                font.pixelSize: 22 * root.s
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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: passWrap.bottom
        anchors.topMargin: 12 * root.s
        opacity: root.shown
        text: root.pam.state === Pam.MaxTries ? "Too many tries. Wait a moment."
            : root.pam.state === Pam.Failed ? "Wrong password"
            : root.pam.state === Pam.Error ? "Something went wrong"
            : root.pam.lockMessage
        font.family: root.face
        font.weight: Font.Bold
        font.pixelSize: 17 * root.s
        color: root.failed ? "#ffb3bd" : root.white
        style: Text.Outline
        styleColor: Qt.alpha(root.deep, 0.6)
    }

    // ── quiet info line at the bottom: battery · now playing · notifications ─
    component Info: Row {
        id: inf
        property string icon
        property string label
        spacing: 6 * root.s
        Text { text: inf.icon; font.family: root.icons; font.pixelSize: 18 * root.s; color: "#3fd8ff"; anchors.verticalCenter: parent.verticalCenter }
        Text { text: inf.label; font.family: root.face; font.weight: Font.DemiBold; font.pixelSize: 16 * root.s; color: root.white; anchors.verticalCenter: parent.verticalCenter }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26 * root.s
        spacing: 26 * root.s
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
