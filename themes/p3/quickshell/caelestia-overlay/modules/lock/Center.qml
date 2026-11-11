import "center"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.punk
import qs.services

ColumnLayout {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: Tokens.spacing.largeIncreased

    Clock {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.padding.large
        centerScale: root.centerScale
    }

    // weekday in cut-out letters, date on a tilted black tag
    Row {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.large
        spacing: 14 * root.centerScale

        Ransom {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("dddd").toUpperCase()
            size: 34 * root.centerScale
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: dateText.implicitWidth + 20 * root.centerScale
            implicitHeight: dateText.implicitHeight
            rotation: -6
            antialiasing: true
            color: Colours.palette.m3background
            border.color: Colours.palette.m3onSurface
            border.width: 3

            Rectangle {
                z: -1
                x: 5; y: 5
                width: parent.width; height: parent.height
                color: Colours.palette.m3primary
            }

            Text {
                id: dateText

                anchors.centerIn: parent
                text: Time.format("d MMM").toUpperCase()
                font.family: "Bebas Neue"
                font.pixelSize: 40 * root.centerScale
                font.italic: true
                color: Colours.palette.m3onSurface
            }
        }
    }

    ProfilePic {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.medium * root.centerScale
        Layout.bottomMargin: Tokens.spacing.large * root.centerScale
        centerWidth: root.centerWidth
    }

    Ransom {
        Layout.alignment: Qt.AlignHCenter
        text: "PROVE IT'S YOU"
        size: 22 * Math.max(0.8, root.centerScale)
        seed: 404
        rotation: -2
    }

    PasswordInput {
        Layout.alignment: Qt.AlignHCenter
        centerScale: Math.max(0.8, root.centerScale)
        centerWidth: root.centerWidth
        lock: root.lock
    }

    StateMessage {
        Layout.fillWidth: true
        pam: root.lock.pam
    }
}
