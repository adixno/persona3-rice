// Persona 3 style SDDM login (local theme). Pause-menu layout: a tilted stack of heavy italic
// words, the selected one cut by a white blade with a red label; white side panel with giant
// rotated weekday, big grey day numeral, time box. All drawn in code.
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
    readonly property color pink: config.pink || "#ff5fae"
    readonly property real u: height / 720
    readonly property string face: "Montserrat"

    property int userIdx: 0
    property int sessIdx: 0
    property string userName: ""
    property string sessName: ""
    property bool busy: false
    property bool failed: false
    property int sel: 1
    property date now: new Date()

    readonly property var items: [
        { label: root.userName.toUpperCase(), tag: "user", size: 70, dx: 40, hint: "Choose who logs in", ok: true },
        { label: root.failed ? "WRONG" : pw.text.length ? "•".repeat(Math.min(pw.text.length, 10)) : "PASSWORD", tag: "password", size: 64, dx: 0, hint: "Type your password", ok: true },
        { label: root.sessName.replace(/\s*\(.*\)/, "").toUpperCase(), tag: "session", size: 56, dx: 70, hint: "Pick what to start", ok: true },
        { label: root.busy ? "· · ·" : "LOG IN", tag: "", size: 76, dx: 20, hint: "Begin the session", ok: true },
        { label: "SLEEP", tag: "", size: 40, dx: 120, hint: "Suspend", ok: sddm.canSuspend },
        { label: "REBOOT", tag: "", size: 40, dx: 90, hint: "Restart the machine", ok: sddm.canReboot },
        { label: "SHUT DOWN", tag: "", size: 40, dx: 140, hint: "Power off", ok: sddm.canPowerOff }
    ]
    readonly property var shades: ["#aaf2ff", "#3fd8ff", "#2fb8ff", "#5fe6ff", "#2f8fff", "#2a74ff", "#2a5cff"]

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
        if (!items[i].ok)
            return;
        switch (i) {
        case 0: nextUser(); break;
        case 1: case 3: login(); break;
        case 2: nextSession(); break;
        case 4: sddm.suspend(); break;
        case 5: sddm.reboot(); break;
        case 6: sddm.powerOff(); break;
        }
        pw.forceActiveFocus();
    }
    function move(d) {
        let i = sel;
        do {
            i = (i + d + items.length) % items.length;
        } while (!items[i].ok && i !== sel);
        sel = i;
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
        onTextChanged: {
            if (text.length) {
                root.failed = false;
                root.sel = 1;
            }
        }
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onLeftPressed: if (root.sel === 0) root.nextUser(); else if (root.sel === 2) root.nextSession()
        Keys.onRightPressed: if (root.sel === 0) root.nextUser(); else if (root.sel === 2) root.nextSession()
        Keys.onTabPressed: root.move(1)
        Keys.onEscapePressed: { pw.text = ""; root.failed = false; }
        Keys.onReturnPressed: root.activate(root.sel === 1 ? 1 : root.sel)
        Keys.onEnterPressed: root.activate(root.sel === 1 ? 1 : root.sel)
    }

    // ── backdrop ────────────────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(root.blue, 0.25) }
            GradientStop { position: 1.0; color: Qt.alpha(root.deep, 0.8) }
        }
    }

    // drifting light shafts
    Repeater {
        model: 5
        Rectangle {
            required property int index
            width: (40 + index * 22) * root.u
            height: root.height * 1.6
            y: -root.height * 0.3
            x: root.width * (0.38 + index * 0.13) + drift
            rotation: 18 + index * 3
            opacity: 0.07 + 0.02 * (index % 2)
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.ice }
                GradientStop { position: 0.8; color: "transparent" }
            }
            property real drift: 0
            SequentialAnimation on drift {
                loops: Animation.Infinite
                NumberAnimation { to: 40 * root.u; duration: 7000 + index * 1300; easing.type: Easing.InOutSine }
                NumberAnimation { to: -40 * root.u; duration: 7000 + index * 1300; easing.type: Easing.InOutSine }
            }
        }
    }

    // big grey day numeral
    Text {
        x: root.width * 0.47
        y: -root.height * 0.06
        rotation: -6
        text: Qt.formatDateTime(root.now, "d")
        font.family: root.face
        font.weight: Font.Black
        font.italic: true
        font.pixelSize: 520 * root.u
        color: "#8a93b0"
        opacity: 0.42
    }

    // ── left white panel with giant weekday ─────────────────────────────────
    Item {
        id: panel
        width: 400 * root.u
        height: root.height

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.white
                strokeWidth: -1
                PathPolyline { path: [Qt.point(0, 0), Qt.point(400 * root.u, 0), Qt.point(250 * root.u, root.height), Qt.point(0, root.height), Qt.point(0, 0)] }
            }
            ShapePath {
                fillColor: root.cyan
                strokeWidth: -1
                PathPolyline { path: [Qt.point(400 * root.u, 0), Qt.point(414 * root.u, 0), Qt.point(264 * root.u, root.height), Qt.point(250 * root.u, root.height), Qt.point(400 * root.u, 0)] }
            }
        }

        Text {
            // rotated so it reads bottom-to-top along the left edge
            x: -width / 2 + 120 * root.u
            y: root.height / 2 - height / 2
            rotation: -90
            text: Qt.formatDateTime(root.now, "dddd").toUpperCase()
            font.family: root.face
            font.weight: Font.Black
            font.italic: true
            font.pixelSize: 210 * root.u
            font.letterSpacing: -6 * root.u
            color: root.deep
        }

        // optional cut-out image (theme.conf: character=), only if the file exists
        Image {
            id: character
            anchors.bottom: parent.bottom
            x: 40 * root.u
            height: root.height * 0.92
            width: 560 * root.u
            source: config.character || ""
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    // time box
    Rectangle {
        x: 300 * root.u
        y: 40 * root.u
        width: 230 * root.u
        height: 78 * root.u
        color: root.white
        border.color: root.deep
        border.width: 2 * root.u
        Text {
            x: 16 * root.u
            y: 2 * root.u
            text: Qt.formatDateTime(root.now, "hh:mm")
            font.family: root.face
            font.weight: Font.Black
            font.italic: true
            font.pixelSize: 44 * root.u
            color: root.deep
        }
        Text {
            x: 18 * root.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8 * root.u
            text: Qt.formatDateTime(root.now, "MMM d").toUpperCase() + "  ·  current time"
            font.family: root.face
            font.weight: Font.Bold
            font.italic: true
            font.pixelSize: 13 * root.u
            color: root.deep
        }
    }

    // ── menu stack ──────────────────────────────────────────────────────────
    Item {
        id: stack
        x: 600 * root.u + shakeX
        y: 150 * root.u
        rotation: -11
        transformOrigin: Item.TopLeft
        property real shakeX: 0

        SequentialAnimation {
            id: shake
            NumberAnimation { target: stack; property: "shakeX"; to: -20 * root.u; duration: 50 }
            NumberAnimation { target: stack; property: "shakeX"; to: 16 * root.u; duration: 70 }
            NumberAnimation { target: stack; property: "shakeX"; to: -8 * root.u; duration: 60 }
            NumberAnimation { target: stack; property: "shakeX"; to: 0; duration: 60 }
        }

        Repeater {
            model: root.items.length

            Item {
                id: it
                required property int index
                readonly property var d: root.items[index]
                readonly property bool on: root.sel === index
                readonly property real fs: d.size * root.u
                property real reveal: on ? 1 : 0
                Behavior on reveal { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                x: d.dx * root.u
                y: {
                    let yy = 0;
                    for (let k = 0; k < index; k++)
                        yy += root.items[k].size * root.u * (root.items[k].size < 50 ? 1.05 : 0.92);
                    return yy;
                }
                width: label.implicitWidth
                height: fs
                opacity: d.ok ? 1 : 0.35
                z: on ? 10 : 0

                // white blade with a pink edge, slicing up through the word
                Shape {
                    id: blade
                    visible: it.reveal > 0.01
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real w: (label.implicitWidth + 90 * root.u) * it.reveal
                    readonly property real h: it.fs
                    // tapered wedge: needle tip on the left, word-height at the right end
                    ShapePath {
                        fillColor: root.pink
                        strokeWidth: -1
                        PathPolyline {
                            path: [Qt.point(-100 * root.u, blade.h * 1.02), Qt.point(-40 * root.u + blade.w, -blade.h * 0.34),
                                   Qt.point(-26 * root.u + blade.w, blade.h * 0.86), Qt.point(-100 * root.u, blade.h * 1.02)]
                        }
                    }
                    ShapePath {
                        fillColor: root.white
                        strokeWidth: -1
                        PathPolyline {
                            path: [Qt.point(-96 * root.u, blade.h * 0.98), Qt.point(-48 * root.u + blade.w, -blade.h * 0.26),
                                   Qt.point(-36 * root.u + blade.w, blade.h * 0.8), Qt.point(-96 * root.u, blade.h * 0.98)]
                        }
                    }
                }

                // hard black shadow when selected
                Text {
                    visible: it.on
                    x: 4 * root.u
                    y: 4 * root.u
                    text: label.text
                    font: label.font
                    color: "#000000"
                }
                Text {
                    id: label
                    text: it.d.label
                    font.family: root.face
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: it.fs
                    font.letterSpacing: -it.fs * 0.03
                    color: it.on ? root.red : root.shades[it.index]
                    style: it.on ? Text.Normal : Text.Raised
                    styleColor: Qt.alpha(root.deep, 0.5)
                }
                Text {
                    visible: it.d.tag !== ""
                    anchors.left: label.right
                    anchors.leftMargin: 14 * root.u
                    anchors.baseline: label.baseline
                    text: it.d.tag
                    font.family: root.face
                    font.weight: Font.Bold
                    font.italic: true
                    font.pixelSize: 15 * root.u
                    color: it.on ? root.white : Qt.alpha(root.white, 0.6)
                }

                MouseArea {
                    anchors.fill: label
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (it.d.ok) root.sel = it.index
                    onClicked: root.activate(it.index)
                }
            }
        }
    }

    // ── bottom-right hint ───────────────────────────────────────────────────
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 56 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40 * root.u
        spacing: 6 * root.u

        Text {
            anchors.right: parent.right
            text: root.items[root.sel].hint
            font.family: root.face
            font.weight: Font.ExtraBold
            font.italic: true
            font.pixelSize: 30 * root.u
            color: root.white
        }
        Rectangle {
            anchors.right: parent.right
            width: 300 * root.u
            height: 2 * root.u
            color: root.white
            Text {
                anchors.left: parent.left
                anchors.top: parent.bottom
                anchors.topMargin: 2 * root.u
                text: "Login"
                font.family: root.face
                font.weight: Font.Bold
                font.italic: true
                font.pixelSize: 13 * root.u
                color: root.white
            }
        }
        Row {
            anchors.right: parent.right
            spacing: 18 * root.u
            topPadding: 22 * root.u
            Repeater {
                model: [["↵", "Confirm"], ["↑↓", "Move"], ["Esc", "Clear"]]
                Row {
                    required property var modelData
                    spacing: 6 * root.u
                    Rectangle {
                        width: Math.max(28 * root.u, key.implicitWidth + 12 * root.u)
                        height: 28 * root.u
                        radius: height / 2
                        color: "transparent"
                        border.color: root.white
                        border.width: 2 * root.u
                        Text {
                            id: key
                            anchors.centerIn: parent
                            text: modelData[0]
                            font.family: root.face
                            font.weight: Font.Black
                            font.pixelSize: 13 * root.u
                            color: root.white
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        font.family: root.face
                        font.weight: Font.ExtraBold
                        font.italic: true
                        font.pixelSize: 22 * root.u
                        color: root.white
                    }
                }
            }
        }
    }
}
