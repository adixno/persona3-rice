// p3-links: the app launcher, as the Persona 3 SOCIAL LINK list.
// Your 20 apps, one per Major Arcana (0 Fool … XIX Sun). RANK 1-10 grows with how often you
// launch each app from here (~/.local/state/p3-links.json); the list sorts by it. Moving the
// selection swaps the arcana card in the character's hand (frames in
// ~/.local/share/persona-rice/media/p3/links-bg/NN.png, aligned via offsets.json).
// Type to search (arcana or app name), ↵ launches, Esc clears the search, then closes.
//
// Resident like the other p3 menus; one menu at a time. Toggle: SUPER+Space (global p3links:toggle)
import QtQuick
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

ShellRoot {
    id: shell

    // the Dark Hour grades the art green and swaps cyan accents for green (DarkHour.qml)
    DarkHour { id: dh }

    readonly property string media: Quickshell.env("P3_MEDIA") || (Quickshell.env("HOME") + "/.local/share/persona-rice/media/p3")
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/p3-links.json"
    property bool shown: Quickshell.env("P3_LINKS_OPEN") === "1"

    function toggle(): void {
        if (!shell.shown)
            shell.shown = true;
        else if (content.item)
            content.item.close();
    }

    GlobalShortcut {
        appid: "p3links"
        name: "toggle"
        description: "Toggle the p3 app launcher (SOCIAL LINK)"
        onPressed: shell.toggle()
    }
    GlobalShortcut {
        appid: "p3links"
        name: "hide"
        description: "Hide immediately (another p3 menu is opening)"
        onPressed: {
            if (!shell.shown)
                return;
            if (content.item)
                content.item.hideNow();
            else
                shell.shown = false;
        }
    }

    IpcHandler {
        target: "links"
        function toggle(): void { shell.toggle(); }
        function open(): void { shell.shown = true; }
        function close(): void { if (content.item) content.item.close(); }
        // testing only: move the selection / type into the search (never launches)
        function move(d: int): void { if (content.item) content.item.move(d); }
        function type(s: string): void { if (content.item) content.item.query = s; }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; left: true; bottom: shell.shown; right: shell.shown }
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: shell.shown ? null : noInput
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "p3-links"
        WlrLayershell.keyboardFocus: shell.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Region { id: noInput }

        Loader {
            id: content
            width: win.screen ? win.screen.width : 1280
            height: win.screen ? win.screen.height : 720
            focus: true
            sourceComponent: Component {
        Item {
            id: root

            anchors.fill: parent
            focus: true

            readonly property real u: height / 720
            readonly property color ink: "#06102f"
            readonly property color navy: "#0b1f6e"
            readonly property color cyan: dh.mix("#5ee6ff", dh.green)
            readonly property color white: "#f2fbff"
            readonly property color red: "#ff1f3a"
            readonly property string face: "Montserrat"

            property real fill: 0
            property real listIn: 0
            property bool closing: false
            property bool warming: false
            property int warmFrames: 0

            // ── the links ────────────────────────────────────────────────
            readonly property var links: [
                { n: 0, roman: "0", arcana: "Fool", app: "firefox" },
                { n: 1, roman: "I", arcana: "Magician", app: "code" },
                { n: 2, roman: "II", arcana: "Priestess", app: "org.pwmt.zathura" },
                { n: 3, roman: "III", arcana: "Empress", app: "org.inkscape.Inkscape" },
                { n: 4, roman: "IV", arcana: "Emperor", app: "io.missioncenter.MissionCenter" },
                { n: 5, roman: "V", arcana: "Hierophant", app: "anki" },
                { n: 6, roman: "VI", arcana: "Lovers", app: "spotify-launcher" },
                { n: 7, roman: "VII", arcana: "Chariot", app: "steam" },
                { n: 8, roman: "VIII", arcana: "Justice", app: "org.gnome.Calculator" },
                { n: 9, roman: "IX", arcana: "Hermit", app: "kitty" },
                { n: 10, roman: "X", arcana: "Fortune", app: "org.qbittorrent.qBittorrent" },
                { n: 11, roman: "XI", arcana: "Strength", app: "onlyoffice-desktopeditors" },
                { n: 12, roman: "XII", arcana: "Hanged Man", app: "thunar-bulk-rename" },
                { n: 13, roman: "XIII", arcana: "Death", app: "yazi" },
                { n: 14, roman: "XIV", arcana: "Temperance", app: "org.pulseaudio.pavucontrol" },
                { n: 15, roman: "XV", arcana: "Devil", app: "discord" },
                { n: 16, roman: "XVI", arcana: "Tower", app: "vlc" },
                { n: 17, roman: "XVII", arcana: "Star", app: "com.obsproject.Studio" },
                { n: 18, roman: "XVIII", arcana: "Moon", app: "com.stremio.stremio" },
                { n: 19, roman: "XIX", arcana: "Sun", app: "org.kde.kdeconnect.app" }
            ]
            readonly property var appMap: {
                const m = {};
                for (const e of DesktopEntries.applications.values)
                    m[e.id] = e;
                return m;
            }
            function entry(id) { return appMap[id] ?? DesktopEntries.byId(id); }
            function appName(l) { const e = entry(l.app); return e ? e.name.replace(" (Launcher)", "") : l.app; }

            // launch counts → rank 1..10
            property var counts: ({})
            readonly property var steps: [0, 1, 3, 6, 10, 15, 22, 32, 45, 60]
            function rankOf(c) { let r = 1; for (let i = 0; i < steps.length; i++) if ((c ?? 0) >= steps[i]) r = i + 1; return r; }
            FileView {
                id: store
                path: shell.statePath
                watchChanges: false
                onLoaded: { try { root.counts = JSON.parse(text()) || {}; } catch (e) { root.counts = {}; } }
                onLoadFailed: root.counts = {}
            }

            // filtered + sorted list
            property string query: ""
            readonly property var shownLinks: {
                const q = query.trim().toLowerCase();
                const c = counts;
                return links
                    .filter(l => !q || l.arcana.toLowerCase().includes(q) || appName(l).toLowerCase().includes(q) || l.roman.toLowerCase() === q)
                    .sort((a, b) => ((c[b.app] ?? 0) - (c[a.app] ?? 0)) || (a.n - b.n));
            }
            property int sel: 0
            onQueryChanged: sel = 0
            readonly property var cur: shownLinks.length ? shownLinks[Math.min(sel, shownLinks.length - 1)] : null
            onCurChanged: if (cur) slides.show(cur.n)

            function move(d) {
                if (!shell.shown || closing || !shownLinks.length)
                    return;
                sel = (sel + d + shownLinks.length) % shownLinks.length;
            }

            // ── launch ───────────────────────────────────────────────────
            property string flash: ""
            function launch() {
                if (!cur || !shell.shown || closing)
                    return;
                const e = entry(cur.app);
                if (!e)
                    return;
                const before = rankOf(counts[cur.app]);
                const nc = Object.assign({}, counts);
                nc[cur.app] = (nc[cur.app] ?? 0) + 1;
                counts = nc;
                store.setText(JSON.stringify(nc));
                if (e.runInTerminal)
                    Quickshell.execDetached({ command: ["kitty", "-e", ...e.command], workingDirectory: e.workingDirectory });
                else
                    e.execute();
                if (rankOf(nc[cur.app]) > before) {
                    flash = "RANK UP!  " + cur.arcana + " → " + rankOf(nc[cur.app]);
                    flashAnim.restart();
                    rankTimer.restart();
                } else {
                    close();
                }
            }
            Timer { id: rankTimer; interval: 650; onTriggered: root.close() }

            Keys.onPressed: e => {
                if (e.key === Qt.Key_Up || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier)) || e.key === Qt.Key_Backtab) { move(-1); e.accepted = true; }
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { move(1); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { launch(); e.accepted = true; }
                else if (e.key === Qt.Key_Escape) { if (query) query = ""; else close(); e.accepted = true; }
                else if (e.key === Qt.Key_Backspace) { query = query.slice(0, -1); e.accepted = true; }
                else if (e.text && e.text.length === 1 && e.text >= " " && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { query += e.text; e.accepted = true; }
            }

            // ── open / close ─────────────────────────────────────────────
            function hideNow() {
                closeAnim.stop();
                openAnim.stop();
                rankTimer.stop();
                warming = false;
                closing = false;
                fill = 0; listIn = 0;
                shell.shown = false;
            }
            function hideOthers() {
                Quickshell.execDetached(["sh", "-c", "for m in p3status p3equip p3items p3skills; do hyprctl dispatch \"hl.dsp.global(\\\"$m:hide\\\")\" >/dev/null; done"]);
            }
            function reopen() {
                hideOthers();
                closeAnim.stop();
                openAnim.stop();
                rankTimer.stop();
                closing = false;
                flash = "";
                query = "";
                sel = 0;
                fill = 0;
                listIn = 0;
                store.reload();
                warmFrames = 0;
                warming = true;
            }
            Connections {
                target: shell
                function onShownChanged() { if (shell.shown) root.reopen(); }
            }
            Connections {
                target: root.Window.window
                function onFrameSwapped() {
                    if (!root.warming)
                        return;
                    if (++root.warmFrames >= 2) {
                        root.warming = false;
                        openAnim.restart();
                    } else {
                        root.Window.window.update();
                    }
                }
            }
            Component.onCompleted: if (shell.shown) reopen()
            function close() {
                if (closing)
                    return;
                closing = true;
                closeAnim.start();
            }
            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: root; property: "fill"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 80 }
                    NumberAnimation { target: root; property: "listIn"; from: 0; to: 1; duration: 460 }
                }
            }
            SequentialAnimation {
                id: closeAnim
                NumberAnimation { target: root; property: "listIn"; to: 0; duration: 160 }
                NumberAnimation { target: root; property: "fill"; to: 0; duration: 200; easing.type: Easing.InCubic }
                ScriptAction { script: shell.shown = false }
            }

            property real clock: 0
            // ambient motion follows the shared rule (Motion.qml): full speed until the battery
            // limit, then it eases to a halt
            Motion { id: motion }
            FrameAnimation { running: shell.shown && motion.speed > 0; onTriggered: root.clock += frameTime * motion.speed }

            // ── backdrop: one frame per arcana, crossfading, aligned ─────
            Item {
                id: backdrop
                layer.enabled: dh.t > 0
                layer.effect: ShaderEffect {
                    property real dark: dh.t
                    fragmentShader: Qt.resolvedUrl("grade.frag.qsb")
                }
                anchors.fill: parent
                opacity: root.warming ? 0.004 : root.fill
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#16b4ff" }
                        GradientStop { position: 1.0; color: "#0a1cb8" }
                    }
                }
                FolderListModel {
                    id: frames
                    folder: "file://" + shell.media + "/links-bg"
                    nameFilters: ["*.png", "*.jpg"]
                    showDirs: false
                    sortField: FolderListModel.Name
                }
                FileView {
                    path: shell.media + "/links-bg/offsets.json"
                    onLoaded: { try { slides.offs = JSON.parse(text()).abs || []; } catch (e) {} }
                }
                Item {
                    id: slides
                    anchors.fill: parent
                    property int topIdx: 0
                    property int prevIdx: -1
                    property real fade: 1
                    property var offs: []
                    readonly property real k: width / 1920
                    NumberAnimation { id: fadeAnim; target: slides; property: "fade"; from: 0; to: 1; duration: 170; easing.type: Easing.OutQuad }
                    function show(i) {
                        if (i === topIdx || i >= frames.count)
                            return;
                        prevIdx = fade >= 0.5 ? topIdx : prevIdx;
                        topIdx = i;
                        fadeAnim.restart();
                    }
                    Repeater {
                        model: frames
                        Image {
                            id: fr
                            required property int index
                            required property url fileUrl
                            anchors.fill: parent
                            source: fileUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: index !== 0
                            smooth: true
                            mipmap: true
                            scale: 1.03
                            readonly property bool isTop: index === slides.topIdx
                            readonly property bool isPrev: index === slides.prevIdx
                            z: isTop ? 2 : isPrev ? 1 : 0
                            opacity: isTop ? slides.fade : isPrev ? 1 : 0
                            visible: opacity > 0
                            transform: Translate {
                                x: -(slides.offs[fr.index] ? slides.offs[fr.index][0] : 0) * slides.k
                                y: -(slides.offs[fr.index] ? slides.offs[fr.index][1] : 0) * slides.k
                            }
                        }
                    }
                }
                ShaderEffectSource {
                    id: slidesTex
                    sourceItem: slides
                    // the plain stack is only drawn through `living` (when its mask is there)
                    hideSource: living.visible
                    live: true
                    visible: false
                }
                Image {
                    id: livingMask
                    source: "file://" + shell.media + "/links-bg/mask.png"
                    asynchronous: false
                    visible: false
                    smooth: true
                }
                ShaderEffect {
                    id: living
                    anchors.fill: parent
                    visible: livingMask.status === Image.Ready
                    property variant src: slidesTex
                    property variant mask: livingMask
                    property real time: root.clock
                    property real aspect: width / Math.max(1, height)
                    property real zoom: 1.03
                    fragmentShader: Qt.resolvedUrl("living.frag.qsb")
                }
                // shards
                Repeater {
                    model: [
                        [180, 600, 14, "#ff4fd8", 8, 0.0], [330, 660, 10, "#5fe3ff", 7, 1.3], [760, 560, 12, "#ffffff", 9, 2.6],
                        [880, 640, 15, "#ff4fd8", 6, 0.7], [1100, 520, 9, "#5fe3ff", 10, 3.4], [1210, 620, 13, "#ffffff", 7, 4.1]
                    ]
                    Shape {
                        id: shard
                        required property var modelData
                        readonly property real range: 150
                        readonly property real prog: ((root.clock * modelData[4] / range + modelData[5] / 6.2831853) % 1 + 1) % 1
                        readonly property real sz: modelData[2] * 1.6 * root.u
                        x: (modelData[0] + 12 * Math.sin(root.clock * 0.6 + modelData[5])) * root.u
                        y: (modelData[1] - prog * range) * root.u
                        rotation: modelData[5] * 57 + root.clock * (12 + modelData[4] * 2)
                        opacity: Math.sin(Math.PI * prog) * 0.7
                        width: sz
                        height: sz
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: shard.modelData[3]
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(0, shard.sz * 0.2), Qt.point(shard.sz, 0), Qt.point(shard.sz * 0.65, shard.sz), Qt.point(0, shard.sz * 0.2)] }
                        }
                    }
                }
                // SOCIAL LINK, set along the white band
                Text {
                    x: 930 * root.u
                    y: 640 * root.u
                    rotation: -57
                    transformOrigin: Item.TopLeft
                    text: "SOCIAL LINK"
                    font.family: root.face
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 74 * root.u
                    font.letterSpacing: -1 * root.u
                    color: "#b9c1cf"
                    opacity: root.listIn
                }
            }

            // ── header: LIST + search ────────────────────────────────────
            Item {
                x: 40 * root.u
                y: 52 * root.u
                opacity: root.listIn
                Text {
                    id: listTitle
                    text: "LIST"
                    font.family: root.face
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 48 * root.u
                    color: root.white
                    style: Text.Outline
                    styleColor: root.ink
                }
                Text {
                    x: listTitle.implicitWidth + 18 * root.u
                    anchors.baseline: listTitle.baseline
                    text: root.query ? root.query : "type to search"
                    font.family: root.face
                    font.weight: root.query ? Font.ExtraBold : Font.DemiBold
                    font.italic: true
                    font.pixelSize: (root.query ? 26 : 15) * root.u
                    color: root.query ? root.cyan : Qt.alpha(root.white, 0.6)
                    style: Text.Outline
                    styleColor: root.ink
                    Rectangle {
                        visible: root.query !== ""
                        anchors.left: parent.right
                        anchors.leftMargin: 3 * root.u
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3 * root.u
                        height: parent.height * 0.8
                        color: root.cyan
                        opacity: Math.floor(root.clock * 2) % 2 ? 0.2 : 1
                    }
                }
            }

            // ── the list ─────────────────────────────────────────────────
            ListView {
                id: list
                x: 40 * root.u
                y: 120 * root.u
                width: 520 * root.u
                height: 5 * 84 * root.u
                clip: true
                interactive: false
                model: root.shownLinks
                // keep the selection in view: scroll so it sits at most 3 rows down
                readonly property real pitch: 84 * root.u
                function follow() {
                    const top = Math.round(contentY / pitch);
                    let t = top;
                    if (root.sel < top + 1) t = Math.max(0, root.sel - 1);
                    else if (root.sel > top + 3) t = Math.min(Math.max(0, count - 5), root.sel - 3);
                    if (root.sel === 0) t = 0;
                    if (root.sel === count - 1) t = Math.max(0, count - 5);
                    scroller.to = t * pitch;
                    scroller.restart();
                }
                NumberAnimation { id: scroller; target: list; property: "contentY"; duration: 140; easing.type: Easing.OutCubic }
                Connections {
                    target: root
                    function onSelChanged() { list.follow(); }
                }
                opacity: root.listIn

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: index === root.sel
                    readonly property int count: root.counts[modelData.app] ?? 0
                    readonly property int rank: root.rankOf(count)
                    readonly property var e: root.entry(modelData.app)
                    readonly property real enter: Math.max(0, Math.min(1, root.listIn * 3 - Math.min(index, 5) * 0.3))
                    width: list.width
                    height: 84 * root.u
                    opacity: enter
                    transform: Translate { x: (1 - row.enter) * -80 * root.u }

                    // slab: name band on top, subtitle band below
                    Shape {
                        x: (row.on ? 0 : 14) * root.u
                        preferredRendererType: Shape.CurveRenderer
                        readonly property real w: 470 * root.u
                        readonly property real h: 74 * root.u
                        ShapePath {
                            fillColor: row.on ? root.white : Qt.alpha(root.navy, 0.92)
                            strokeColor: row.on ? root.red : "transparent"
                            strokeWidth: row.on ? 3 * root.u : -1
                            joinStyle: ShapePath.MiterJoin
                            PathPolyline { path: [Qt.point(14 * root.u, 0), Qt.point(470 * root.u, 0), Qt.point(458 * root.u, 74 * root.u), Qt.point(0, 74 * root.u), Qt.point(14 * root.u, 0)] }
                        }
                        // subtitle band
                        ShapePath {
                            fillColor: row.on ? root.ink : Qt.alpha("#d9f3ff", 0.92)
                            strokeWidth: -1
                            PathPolyline { path: [Qt.point(76 * root.u, 46 * root.u), Qt.point(462 * root.u, 46 * root.u), Qt.point(458 * root.u, 70 * root.u), Qt.point(72 * root.u, 70 * root.u), Qt.point(76 * root.u, 46 * root.u)] }
                        }
                        // numeral plate
                        ShapePath {
                            fillColor: root.ink
                            strokeColor: row.on ? root.ink : root.cyan
                            strokeWidth: 1.5 * root.u
                            PathPolyline { path: [Qt.point(22 * root.u, 6 * root.u), Qt.point(68 * root.u, 6 * root.u), Qt.point(60 * root.u, 68 * root.u), Qt.point(14 * root.u, 68 * root.u), Qt.point(22 * root.u, 6 * root.u)] }
                        }
                    }
                    Item {
                        x: (row.on ? 0 : 14) * root.u
                        width: parent.width
                        height: parent.height
                        Text {
                            x: 14 * root.u
                            width: 54 * root.u
                            y: 6 * root.u
                            height: 62 * root.u
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 12
                            text: row.modelData.roman
                            font.family: "Jost"
                            font.weight: Font.Bold
                            font.italic: true
                            font.pixelSize: 30 * root.u
                            color: root.white
                        }
                        Text {
                            x: 84 * root.u
                            y: 4 * root.u
                            text: row.modelData.arcana
                            font.family: root.face
                            font.weight: Font.ExtraBold
                            font.italic: true
                            font.pixelSize: 30 * root.u
                            color: row.on ? root.ink : root.cyan
                            style: row.on ? Text.Normal : Text.Raised
                            styleColor: root.ink
                        }
                        Text {
                            anchors.right: rankNum.left
                            anchors.rightMargin: 8 * root.u
                            anchors.baseline: rankNum.baseline
                            text: "RANK"
                            font.family: root.face
                            font.weight: Font.Black
                            font.italic: true
                            font.pixelSize: 12 * root.u
                            color: row.on ? root.ink : root.white
                        }
                        Text {
                            id: rankNum
                            x: 404 * root.u
                            y: -4 * root.u
                            width: 40 * root.u
                            text: row.rank >= 10 ? "MAX" : String(row.rank)
                            horizontalAlignment: Text.AlignHCenter
                            font.family: "Jost"
                            font.weight: Font.Black
                            font.italic: true
                            font.pixelSize: (row.rank >= 10 ? 24 : 44) * root.u
                            color: row.on ? root.ink : root.white
                            style: Text.Outline
                            styleColor: row.on ? root.white : root.ink
                        }
                        // subtitle: app icon + name
                        Row {
                            x: 100 * root.u
                            y: 47 * root.u
                            height: 22 * root.u
                            spacing: 8 * root.u
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18 * root.u
                                height: width
                                sourceSize: Qt.size(64, 64)
                                source: row.e && row.e.icon ? Quickshell.iconPath(row.e.icon, true) : ""
                                visible: source != ""
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.appName(row.modelData)
                                font.family: root.face
                                font.weight: Font.Bold
                                font.pixelSize: 15 * root.u
                                color: row.on ? root.white : root.ink
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = row.index
                        onClicked: { root.sel = row.index; root.launch(); }
                    }
                }
            }
            // scroll marks: one tick per link, the visible window lit
            Column {
                x: 22 * root.u
                y: list.y + 6 * root.u
                spacing: 3 * root.u
                opacity: root.listIn
                visible: root.shownLinks.length > 5
                Repeater {
                    model: root.shownLinks.length
                    Rectangle {
                        required property int index
                        width: 4 * root.u
                        height: (5 * 84 - 6) / Math.max(1, root.shownLinks.length) * root.u - 3 * root.u
                        color: index === root.sel ? root.red : root.white
                        opacity: index === root.sel ? 1 : 0.5
                    }
                }
            }
            Text {
                visible: root.shownLinks.length === 0
                x: 60 * root.u
                y: 140 * root.u
                text: "No link matches “" + root.query + "”"
                font.family: root.face
                font.weight: Font.Bold
                font.italic: true
                font.pixelSize: 20 * root.u
                color: root.white
                style: Text.Outline
                styleColor: root.ink
            }

            // rank-up flash
            Text {
                id: flashText
                x: 560 * root.u
                y: 300 * root.u
                rotation: -8
                text: root.flash
                font.family: root.face
                font.weight: Font.Black
                font.italic: true
                font.pixelSize: 40 * root.u
                color: root.white
                style: Text.Outline
                styleColor: root.red
                opacity: 0
                SequentialAnimation {
                    id: flashAnim
                    ParallelAnimation {
                        NumberAnimation { target: flashText; property: "opacity"; from: 0; to: 1; duration: 90 }
                        NumberAnimation { target: flashText; property: "scale"; from: 1.3; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }

            // ── guide ────────────────────────────────────────────────────
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 36 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26 * root.u
                spacing: 4 * root.u
                opacity: root.listIn
                Text {
                    anchors.right: parent.right
                    text: "Whose link do you want to call?"
                    font.family: root.face
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pixelSize: 22 * root.u
                    color: root.white
                    style: Text.Outline
                    styleColor: "#0a1cb8"
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 360 * root.u
                    height: 1.5 * root.u
                    color: root.white
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.bottom
                        anchors.topMargin: 1 * root.u
                        text: "Guide"
                        font.family: root.face
                        font.weight: Font.Bold
                        font.italic: true
                        font.pixelSize: 10 * root.u
                        color: root.white
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 14 * root.u
                    topPadding: 16 * root.u
                    Repeater {
                        model: [["↵", "Launch"], ["A-Z", "Search"], ["Esc", "Back"]]
                        Row {
                            required property var modelData
                            spacing: 5 * root.u
                            Rectangle {
                                width: Math.max(22 * root.u, key.implicitWidth + 10 * root.u)
                                height: 22 * root.u
                                radius: height / 2
                                color: root.white
                                Text {
                                    id: key
                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    font.family: root.face
                                    font.weight: Font.Black
                                    font.pixelSize: 11 * root.u
                                    color: "#0a1cb8"
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                font.family: root.face
                                font.weight: Font.ExtraBold
                                font.italic: true
                                font.pixelSize: 18 * root.u
                                color: root.white
                                style: Text.Outline
                                styleColor: "#0a1cb8"
                            }
                        }
                    }
                }
            }
        }
            }
        }
    }
}
