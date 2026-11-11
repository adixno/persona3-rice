// Persona 3 style SDDM login (local theme), title-screen layout: moonlit room backdrop,
// outlined clock wordmark top right, short right-aligned menu bottom right where the
// selected row sits on a blue band running off the screen edge. All drawn in code.
import QtQuick
import QtQuick.Shapes

Rectangle {
    id: root

    width: 1280
    height: 720
    color: deep

    readonly property color deep: config.deep || "#030a26"
    readonly property color blue: config.blue || "#1238d6"
    readonly property color cyan: config.cyan || "#3fd8ff"
    readonly property color ice: config.ice || "#aaf2ff"
    readonly property color white: config.white || "#f2fbff"
    readonly property color red: config.red || "#ff1f3a"
    readonly property real u: height / 720
    readonly property string face: "Montserrat"
    readonly property string cond: "Antonio"

    property int userIdx: 0
    property int sessIdx: 0
    property string userName: ""
    property string sessName: ""
    property bool busy: false
    property bool failed: false
    property int sel: 1
    property date now: new Date()

    readonly property var items: [
        { text: root.userName.toUpperCase(), tag: "USER" },
        { text: root.failed ? "TRY AGAIN" : pw.text.length ? "•".repeat(Math.min(pw.text.length, 12)) : "PASSWORD", tag: "KEY" },
        { text: root.sessName.replace(/\s*\(.*\)/, "").toUpperCase(), tag: "SESSION" },
        { text: root.busy ? "· · ·" : "START", tag: "" }
    ]

    function refresh() {
        const ui = userRep.itemAt(userIdx);
        const si = sessRep.itemAt(sessIdx);
        userName = ui ? ui.uname : "";
        sessName = si ? si.sname : "";
    }
    function nextUser() {
        if (userRep.count > 1) {
            userIdx = (userIdx + 1) % userRep.count;
            refresh();
        }
    }
    function nextSession() {
        if (sessRep.count > 1) {
            sessIdx = (sessIdx + 1) % sessRep.count;
            refresh();
        }
    }
    function login() {
        if (busy || userName === "")
            return;
        busy = true;
        failed = false;
        sddm.login(userName, pw.text, sessIdx);
    }
    function activate(i) {
        if (i === 0)
            nextUser();
        else if (i === 2)
            nextSession();
        else
            login();
        pw.forceActiveFocus();
    }

    Component.onCompleted: {
        sessIdx = Math.max(0, sessionModel.lastIndex);
        refresh();
        pw.forceActiveFocus();
    }

    Repeater {
        id: userRep
        model: userModel
        delegate: Item {
            required property int index
            required property string name
            readonly property string uname: name
            Component.onCompleted: {
                if (uname === userModel.lastUser)
                    root.userIdx = index;
                root.refresh();
            }
        }
    }
    Repeater {
        id: sessRep
        model: sessionModel
        delegate: Item {
            required property int index
            required property string name
            readonly property string sname: name
            Component.onCompleted: root.refresh()
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.failed = true;
            root.sel = 1;
            pw.text = "";
            shake.restart();
            pw.forceActiveFocus();
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // hidden input: typing always lands here; arrows/enter drive the menu
    TextInput {
        id: pw
        opacity: 0
        width: 1
        height: 1
        echoMode: TextInput.Password
        enabled: !root.busy
        focus: true
        onTextChanged: if (text.length) { root.failed = false; root.sel = 1; }
        Keys.onUpPressed: root.sel = (root.sel + 3) % 4
        Keys.onDownPressed: root.sel = (root.sel + 1) % 4
        Keys.onTabPressed: root.sel = (root.sel + 1) % 4
        Keys.onLeftPressed: if (root.sel === 0) root.nextUser(); else if (root.sel === 2) root.nextSession()
        Keys.onRightPressed: if (root.sel === 0) root.nextUser(); else if (root.sel === 2) root.nextSession()
        Keys.onEscapePressed: { pw.text = ""; root.failed = false; }
        Keys.onReturnPressed: root.activate(root.sel)
        Keys.onEnterPressed: root.activate(root.sel)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F1 && sddm.canSuspend) sddm.suspend();
            else if (event.key === Qt.Key_F2 && sddm.canReboot) sddm.reboot();
            else if (event.key === Qt.Key_F3 && sddm.canPowerOff) sddm.powerOff();
        }
    }

    // ── backdrop with a slow push-in ─────────────────────────────────────────
    // Plays background.gif / background.webp (animated) if present in the theme folder,
    // otherwise shows the still `background` from theme.conf.
    Item {
        id: bg
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.05; duration: 24000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.05; to: 1.0; duration: 24000; easing.type: Easing.InOutSine }
        }

        AnimatedImage {
            id: anim
            anchors.fill: parent
            source: "background.gif"
            fillMode: Image.PreserveAspectCrop
            playing: status === AnimatedImage.Ready
            cache: false
            onStatusChanged: if (status === AnimatedImage.Error && source.toString().endsWith(".gif")) source = "background.webp"
        }
        Image {
            anchors.fill: parent
            visible: anim.status !== AnimatedImage.Ready
            source: visible ? (config.background || "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    // blue wash over the picture, then navy shade that deepens toward the
    // bottom-right corner so the white menu and clock stay readable
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.blue, 0.16)
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.55; color: Qt.alpha(root.deep, 0.12) }
            GradientStop { position: 1.0; color: Qt.alpha(root.deep, 0.62) }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(root.deep, 0.25) }
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(root.deep, 0.72) }
        }
    }

    // optional cut-out image (theme.conf: character=), only shown if the file exists
    Image {
        anchors.bottom: parent.bottom
        x: root.width * 0.08
        height: root.height * 0.9
        width: root.width * 0.5
        source: config.character || ""
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignBottom
        asynchronous: true
        visible: status === Image.Ready
    }

    Item {
        id: ui
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: fadeIn.start()
        NumberAnimation { id: fadeIn; target: ui; property: "opacity"; to: 1; duration: 900; easing.type: Easing.OutCubic }

        // ── wordmark: outlined clock + date + host band ──────────────────────
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 120 * root.u
            y: 46 * root.u
            spacing: 0

            Text {
                anchors.right: parent.right
                text: Qt.formatDateTime(root.now, "hh:mm")
                font.family: root.face
                font.weight: Font.Black
                font.pixelSize: 118 * root.u
                font.letterSpacing: -2 * root.u
                color: Qt.alpha(root.blue, 0.28)
                style: Text.Outline
                styleColor: root.white
            }
            Row {
                anchors.right: parent.right
                spacing: 0
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 12 * root.u
                    text: Qt.formatDateTime(root.now, "dddd").toUpperCase()
                    font.family: root.face
                    font.weight: Font.ExtraBold
                    font.pixelSize: 22 * root.u
                    font.letterSpacing: 3 * root.u
                    color: root.white
                }
                Rectangle {
                    width: dateTxt.implicitWidth + 28 * root.u
                    height: 34 * root.u
                    color: root.white
                    Text {
                        id: dateTxt
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(root.now, "dd MMM").toUpperCase()
                        font.family: root.face
                        font.weight: Font.Black
                        font.italic: true
                        font.pixelSize: 22 * root.u
                        color: root.blue
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: -120 * root.u
                visible: hostTxt.text !== ""
                width: hostTxt.implicitWidth + 160 * root.u
                height: 30 * root.u
                color: Qt.alpha(root.blue, 0.85)
                Text {
                    id: hostTxt
                    x: 20 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    text: (sddm.hostName || "").toUpperCase()
                    font.family: root.face
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pixelSize: 16 * root.u
                    font.letterSpacing: 4 * root.u
                    color: root.white
                }
            }
        }

        // ── menu, bottom right ───────────────────────────────────────────────
        Column {
            id: menu
            anchors.right: parent.right
            anchors.rightMargin: 90 * root.u - shakeX
            anchors.bottom: hints.top
            anchors.bottomMargin: 20 * root.u
            spacing: -4 * root.u
            property real shakeX: 0

            SequentialAnimation {
                id: shake
                NumberAnimation { target: menu; property: "shakeX"; to: -18 * root.u; duration: 50 }
                NumberAnimation { target: menu; property: "shakeX"; to: 14 * root.u; duration: 70 }
                NumberAnimation { target: menu; property: "shakeX"; to: -6 * root.u; duration: 60 }
                NumberAnimation { target: menu; property: "shakeX"; to: 0; duration: 60 }
            }

            Repeater {
                model: root.items.length

                Item {
                    id: row
                    required property int index
                    readonly property bool on: root.sel === index
                    property real reveal: on ? 1 : 0
                    Behavior on reveal { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    anchors.right: parent.right
                    width: label.implicitWidth
                    height: 62 * root.u

                    // band: slanted left edge, runs past the screen edge
                    Shape {
                        id: band
                        visible: row.reveal > 0.01
                        readonly property real full: label.implicitWidth + 80 * root.u + menu.anchors.rightMargin + 40 * root.u
                        readonly property real w: full * row.reveal
                        readonly property real x0: label.implicitWidth + menu.anchors.rightMargin + 40 * root.u - w
                        readonly property real h: row.height - 6 * root.u
                        y: 4 * root.u
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: root.failed && row.index === 1 ? Qt.alpha(root.red, 0.9) : Qt.alpha(root.blue, 0.92)
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(band.x0 + 18 * root.u, 0), Qt.point(band.x0 + band.w, 0), Qt.point(band.x0 + band.w, band.h), Qt.point(band.x0, band.h), Qt.point(band.x0 + 18 * root.u, 0)] }
                        }
                        ShapePath {
                            fillColor: root.cyan
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(band.x0 + 18 * root.u, 0), Qt.point(band.x0 + 24 * root.u, 0), Qt.point(band.x0 + 6 * root.u, band.h), Qt.point(band.x0, band.h), Qt.point(band.x0 + 18 * root.u, 0)] }
                        }
                    }

                    Text {
                        visible: root.items[row.index].tag !== ""
                        anchors.right: label.left
                        anchors.rightMargin: 14 * root.u
                        anchors.verticalCenter: label.verticalCenter
                        anchors.verticalCenterOffset: 4 * root.u
                        text: root.items[row.index].tag
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 12 * root.u
                        font.letterSpacing: 2 * root.u
                        color: row.on ? root.ice : Qt.alpha(root.white, 0.45)
                    }
                    Text {
                        id: label
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.items[row.index].text
                        font.family: root.cond
                        font.weight: Font.Bold
                        font.pixelSize: 54 * root.u
                        font.letterSpacing: 1 * root.u
                        color: root.white
                        opacity: row.on ? 1 : 0.88
                        style: Text.Raised
                        styleColor: Qt.alpha(root.deep, 0.6)
                    }

                    MouseArea {
                        anchors.fill: label
                        anchors.leftMargin: -40 * root.u
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = row.index
                        onClicked: root.activate(row.index)
                    }
                }
            }
        }

        // ── hint line ────────────────────────────────────────────────────────
        Row {
            id: hints
            anchors.right: parent.right
            anchors.rightMargin: 64 * root.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26 * root.u
            spacing: 22 * root.u

            Repeater {
                model: [["↵", "Confirm", true], ["F1", "Sleep", sddm.canSuspend], ["F2", "Reboot", sddm.canReboot], ["F3", "Shut down", sddm.canPowerOff]]
                Row {
                    required property var modelData
                    visible: modelData[2]
                    spacing: 6 * root.u
                    Rectangle {
                        width: Math.max(22 * root.u, k.implicitWidth + 10 * root.u)
                        height: 22 * root.u
                        radius: height / 2
                        color: "transparent"
                        border.color: root.white
                        border.width: 1.5 * root.u
                        Text {
                            id: k
                            anchors.centerIn: parent
                            text: modelData[0]
                            font.family: root.face
                            font.weight: Font.Bold
                            font.pixelSize: 10 * root.u
                            color: root.white
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        font.family: root.face
                        font.weight: Font.Bold
                        font.pixelSize: 14 * root.u
                        color: root.white
                    }
                }
            }
        }
    }
}
