#!/usr/bin/env python3
"""Punk-style edits to the user copy of Caelestia, applied by sync-caelestia.sh.

Each edit must match exactly once; if Caelestia changes upstream the script
stops with the file and anchor that failed instead of half-patching.
"""
import sys
from pathlib import Path

root = Path(sys.argv[1])

PATCHES = {
    "modules/notifications/Notification.qml": [
        (
            "import qs.components.effects\n",
            "import qs.components.effects\nimport qs.components.punk\n",
        ),
        (
            "    color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer\n"
            "    radius: Tokens.rounding.large\n",
            "    color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3primaryContainer : Colours.palette.m3background\n"
            "    radius: Tokens.rounding.large\n"
            "    border.color: Colours.palette.m3onSurface\n"
            "    border.width: 3\n",
        ),
        (
            "    Component.onDestruction: modelData.unlock(this)\n",
            "    Component.onDestruction: modelData.unlock(this)\n"
            "\n"
            "    // punk: red offset edge along the bottom and right (the list clips anything outside the card)\n"
            "    Rectangle {\n"
            "        z: 4\n"
            "        anchors.left: parent.left\n"
            "        anchors.right: parent.right\n"
            "        anchors.bottom: parent.bottom\n"
            "        anchors.leftMargin: 8\n"
            "        height: 6\n"
            "        color: Colours.palette.m3primary\n"
            "    }\n"
            "    Rectangle {\n"
            "        z: 4\n"
            "        anchors.top: parent.top\n"
            "        anchors.right: parent.right\n"
            "        anchors.bottom: parent.bottom\n"
            "        anchors.topMargin: 8\n"
            "        width: 6\n"
            "        color: Colours.palette.m3primary\n"
            "    }\n"
            "\n"
            "    // punk: \"!!\" sticker on urgent notifications\n"
            "    Burst {\n"
            "        visible: root.modelData.urgency === NotificationUrgency.Critical\n"
            "        z: 5\n"
            "        anchors.right: parent.right\n"
            "        anchors.rightMargin: 44\n"
            "        y: 2\n"
            "        width: 48\n"
            "        height: 44\n"
            "        seed: 9\n"
            "        rotation: 12\n"
            "\n"
            "        Ransom {\n"
            "            anchors.centerIn: parent\n"
            "            text: \"!!\"\n"
            "            size: 18\n"
            "            forceStyle: 1\n"
            "        }\n"
            "    }\n",
        ),
        (
            "            StyledText {\n                id: summary\n",
            "            StyledText {\n                id: summary\n\n"
            "                font.family: \"Antonio\"\n"
            "                font.weight: Font.Bold\n"
            "                font.pixelSize: 17\n"
            "                font.capitalization: Font.AllUppercase\n",
        ),
    ],
    "modules/lock/center/PasswordInput.qml": [
        (
            "    color: Colours.tPalette.m3surfaceContainer\n    radius: Tokens.rounding.full\n\n    focus: true\n",
            "    color: Colours.palette.m3background\n"
            "    radius: Tokens.rounding.full\n"
            "    border.color: Colours.palette.m3onSurface\n"
            "    border.width: 3\n"
            "\n"
            "    // punk: red offset shadow\n"
            "    Rectangle {\n"
            "        z: -1\n"
            "        x: 7\n"
            "        y: 7\n"
            "        width: root.width\n"
            "        height: root.height\n"
            "        color: Colours.palette.m3primary\n"
            "    }\n"
            "\n"
            "    focus: true\n",
        ),
    ],
}

# red offset edge along the bottom and right of a card (drawn inside, so clipping can't hide it)
RED_EDGE = """\
    Rectangle {
        z: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        height: 5
        color: Colours.palette.m3primary
    }
    Rectangle {
        z: 4
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        width: 5
        color: Colours.palette.m3primary
    }
"""

CONDENSED = """\
font.family: "Antonio"
{i}font.weight: Font.Bold
{i}font.pixelSize: {size}
{i}font.capitalization: Font.AllUppercase
"""


def condensed(indent: int, size: int) -> str:
    return CONDENSED.format(i=" " * indent, size=size)


ALL = "all"  # third tuple element: anchor may occur more than once, replace every copy

CARD_OLD = "    radius: Tokens.rounding.large\n    color: Colours.tPalette.m3surfaceContainer\n"
CARD_NEW = (
    "    radius: Tokens.rounding.large\n"
    "    color: Colours.palette.m3background\n"
    "    border.color: Colours.palette.m3onSurface\n"
    "    border.width: 3\n"
    "\n"
    + RED_EDGE
)

HALFTONE = """\
            // punk: halftone dots fading down from the top-right corner
            Canvas {
                anchors.fill: parent
                opacity: 0.5
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Colours.palette.m3primaryContainer;
                    const step = 14;
                    for (let y = 4; y < height; y += step)
                        for (let x = (y / step % 2) * step / 2; x < width; x += step) {
                            const t = Math.max(0, 1 - Math.hypot(width - x, y) / (width * 0.9));
                            if (t <= 0)
                                continue;
                            ctx.beginPath();
                            ctx.arc(x, y, 5.5 * t, 0, Math.PI * 2);
                            ctx.fill();
                        }
                }
            }

"""


PATCHES.update({
    # ---- launcher (Super+Space) ----
    "modules/launcher/AppList.qml": [
        (
            "import qs.components\n",
            "import qs.components\nimport qs.components.punk\n",
        ),
        (
            """\
    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08
""",
            """\
    highlight: Slab {
        fill: Colours.palette.m3primary
        skew: 14
""",
        ),
    ],
    "modules/launcher/items/AppItem.qml": [
        (
            "            implicitSize: parent.height * 0.8\n",
            "            implicitSize: parent.height * 0.8\n"
            "            rotation: (root.modelData?.name?.length ?? 0) % 2 ? -7 : 6\n",
        ),
        (
            "                text: root.modelData?.name ?? \"\"\n                font: Tokens.font.body.medium\n",
            "                text: root.modelData?.name ?? \"\"\n                " + condensed(16, 19),
        ),
        (
            "                color: Colours.palette.m3outline\n\n                elide: Text.ElideRight\n",
            "                color: Colours.palette.m3onSurfaceVariant\n\n                elide: Text.ElideRight\n",
        ),
    ],
    "components/controls/SearchBar.qml": [
        (
            "        color: Colours.tPalette.m3surfaceContainer\n        radius: Tokens.rounding.full\n",
            "        color: Colours.palette.m3background\n"
            "        radius: Tokens.rounding.full\n"
            "        border.color: Colours.palette.m3onSurface\n"
            "        border.width: 3\n",
        ),
    ],
    "modules/launcher/Content.qml": [
        (
            "        placeholderText: Tr.tr(\"Type \\\"%1\\\" for commands\").arg(GlobalConfig.launcher.actionPrefix)\n",
            "        placeholderText: `PICK YOUR POISON... (\"${GlobalConfig.launcher.actionPrefix}\" FOR COMMANDS)`\n"
            "        " + condensed(8, 17),
        ),
    ],

    # ---- notifications sidebar (Super+A) ----
    "modules/sidebar/Content.qml": [
        (
            "            radius: Tokens.rounding.large\n            color: Colours.tPalette.m3surfaceContainerLow\n",
            "            radius: Tokens.rounding.large\n            color: Colours.palette.m3background\n",
        ),
        (
            "            NotifDock {\n",
            HALFTONE + "            NotifDock {\n",
        ),
    ],
    "modules/sidebar/NotifDock.qml": [
        (
            "import qs.services\n",
            "import qs.services\nimport qs.components.punk\n",
        ),
        (
            "            text: root.notifCount\n            color: Colours.palette.m3outline\n            font: Tokens.font.label.large\n",
            "            text: root.notifCount\n"
            "            color: Colours.palette.m3primary\n"
            "            font.family: \"Bebas Neue\"\n"
            "            font.pixelSize: 36\n"
            "            font.italic: true\n",
        ),
        (
            "        StyledText {\n            id: titleText\n",
            "        Ransom {\n            id: titleText\n",
        ),
        (
            "            // TRANSLATORS: the count itself is rendered separately, immediately to the left\n"
            "            text: root.notifCount > 0 ? Tr.trCtxN(\"notification\", \"notifications\", root.notifCount, \"notification count label, number shown separately\") : Tr.tr(\"Notifications\")\n"
            "            color: Colours.palette.m3outline\n            font: Tokens.font.label.large\n            elide: Text.ElideRight\n",
            "            text: root.notifCount === 1 ? \"NOTIFICATION\" : root.notifCount > 0 ? \"NOTIFICATIONS\" : \"NOTHING NEW\"\n"
            "            size: 20\n"
            "            seed: 77\n",
        ),
        (
            """\
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("All up to date!")
                    color: Colours.palette.m3outlineVariant
                    font: Tokens.font.headline.builders.small.width(90).build()
                }
""",
            """\
                Ransom {
                    Layout.alignment: Qt.AlignHCenter
                    text: "ALL CLEAR!!"
                    size: 34
                    seed: 1312
                    rotation: -3
                    autoGlitch: true
                }
""",
        ),
    ],
    "modules/sidebar/NotifGroup.qml": [
        (
            "    radius: Tokens.rounding.large\n    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)\n",
            "    radius: Tokens.rounding.large\n"
            "    color: Colours.palette.m3onSurface\n"
            "    border.color: Colours.palette.m3background\n"
            "    border.width: 3\n"
            "\n"
            + RED_EDGE,
        ),
        (
            "                    text: root.modelData\n                    color: Colours.palette.m3onSurfaceVariant\n                    font: Tokens.font.body.small\n",
            "                    text: root.modelData\n                    color: Colours.palette.m3primary\n                    " + condensed(20, 15),
        ),
    ],
    "modules/sidebar/Notif.qml": [
        (
            "        id: summary\n",
            "        id: summary\n\n        " + condensed(8, 16),
        ),
        (
            "        color: root.modelData?.urgency === \"critical\" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface\n",
            "        color: Colours.palette.m3background\n",
            ALL,
        ),
        (
            "        const c = root.modelData?.urgency === \"critical\" ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2);\n",
            "        const c = root.modelData?.urgency === \"critical\" ? Colours.palette.m3primaryFixed : Colours.palette.m3secondaryDim;\n",
        ),
        (
            # opaque paper when collapsed: something dark sits behind the rows and showed through
            "        return expanded ? c : Qt.alpha(c, 0);\n",
            "        return expanded ? c : Colours.palette.m3onSurface;\n",
        ),
    ],

    # ---- utilities cards (bottom half of the sidebar) ----
    "modules/utilities/cards/IdleInhibit.qml": [
        (CARD_OLD, CARD_NEW),
        (
            "                text: Tr.trCtx(\"Keep awake\", \"idle inhibitor\")\n                font: Tokens.font.body.medium\n",
            "                text: Tr.trCtx(\"Keep awake\", \"idle inhibitor\")\n                " + condensed(16, 20),
        ),
    ],
    "modules/utilities/cards/Record.qml": [
        (CARD_OLD, CARD_NEW),
        (
            "                    text: Tr.tr(\"Screen recorder\")\n                    font: Tokens.font.body.medium\n",
            "                    text: Tr.tr(\"Screen recorder\")\n                    " + condensed(20, 20),
        ),
    ],
    "modules/utilities/cards/RecordingList.qml": [
        (
            "                text: Tr.tr(\"Recordings\")\n                font: Tokens.font.body.medium\n",
            "                text: Tr.tr(\"Recordings\")\n                " + condensed(16, 18),
        ),
    ],
    "modules/utilities/cards/Toggles.qml": [
        (CARD_OLD, CARD_NEW),
        (
            "            text: Tr.tr(\"Quick toggles\")\n            font: Tokens.font.body.medium\n",
            "            text: Tr.tr(\"Quick toggles\")\n            " + condensed(12, 20),
        ),
    ],
})

# nexus: `caelestia shell nexus openPage network|bluetooth|...` opens settings on that page
PATCHES.update({
    "modules/Shortcuts.qml": [
        (
            "    IpcHandler {\n        function open(): void {\n            WindowFactory.create();\n        }\n",
            "    IpcHandler {\n        function open(): void {\n            WindowFactory.create();\n        }\n"
            "\n"
            "        function openPage(page: string): void {\n"
            "            const q = page.toLowerCase();\n"
            "            const alias = { bluetooth: \"devices_other\", wifi: \"wifi\", network: \"wifi\" };\n"
            "            const idx = PageRegistry.pages.findIndex(p => p.icon === alias[q] || p.label.toLowerCase().includes(q));\n"
            "            WindowFactory.create(null, { startPage: Math.max(0, idx) });\n"
            "        }\n",
        ),
    ],
    "modules/nexus/WindowFactory.qml": [
        (
            "            id: win\n\n",
            "            id: win\n\n            property int startPage: 0\n\n",
        ),
        (
            "                nState.isWindow: true\n",
            "                nState.isWindow: true\n                nState.currentPageIdx: win.startPage\n",
        ),
    ],
})

# ---- p3: notification popups in the bottom-right corner (the p3-hud calendar covers the
# top-right). They stack upward from just above the utilities panel; the Super+A sidebar
# keeps its place at the top, and its hover zone no longer follows the popups' height. ----
PATCHES.update({
    "modules/drawers/Panels.qml": [
        (
            "        utilitiesPanel: utilities\n"
            "\n"
            "        anchors.top: parent.top\n"
            "        anchors.right: parent.right\n",
            "        utilitiesPanel: utilities\n"
            "\n"
            "        anchors.bottom: utilities.top\n"
            "        anchors.bottomMargin: 10\n"
            "        anchors.right: parent.right\n",
        ),
        (
            "        anchors.top: notifications.bottom\n"
            "        anchors.bottom: utilities.top\n"
            "        anchors.right: parent.right\n"
            "        anchors.topMargin: -notifications.anchors.topMargin\n",
            "        anchors.top: parent.top\n"
            "        anchors.bottom: utilities.top\n"
            "        anchors.right: parent.right\n",
        ),
    ],
    "modules/drawers/Interactions.qml": [
        (
            "panels.notifications.y + panels.notifications.height + borderThickness",
            "0",
            ALL,
        ),
    ],
})

for rel, edits in PATCHES.items():
    path = root / rel
    text = path.read_text()
    for old, new, *mode in edits:
        count = text.count(old)
        if count == 0 or (count != 1 and mode != [ALL]):
            sys.exit(f"patch failed: {rel}: anchor found {count}x:\n{old[:120]}")
        text = text.replace(old, new)
    path.write_text(text)
    print(f"patched {rel}")
