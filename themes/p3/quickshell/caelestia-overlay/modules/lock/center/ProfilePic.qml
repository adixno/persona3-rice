// Avatar as a tilted, bordered sticker slapped on a starburst.
import QtQuick
import qs.components
import qs.components.punk
import qs.services
import qs.utils

Item {
    id: root

    required property int centerWidth
    readonly property int side: Math.round(centerWidth * 0.3)

    implicitWidth: Math.round(centerWidth * 0.7)
    implicitHeight: Math.round(side * 1.4)

    Burst {
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.implicitHeight
        spikes: 13
        seed: 17
        rotation: 8
    }

    Item {
        anchors.centerIn: parent
        width: root.side
        height: root.side
        rotation: -7

        // red offset shadow, then the white-bordered photo
        Rectangle {
            x: 9; y: 9
            width: parent.width; height: parent.height
            color: Colours.palette.m3background
        }
        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3onSurface
            antialiasing: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 7
                color: Colours.palette.m3background

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "person"
                    color: Colours.palette.m3onSurface
                    visible: pfp.status !== Image.Ready
                }

                Image {
                    id: pfp

                    anchors.fill: parent
                    source: `file://${Paths.home}/.face`
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                }
            }
        }
    }
}
