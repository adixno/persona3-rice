// Punk lock clock: huge ransom-note time over a starburst.
import QtQuick
import qs.components.punk
import qs.services

Item {
    id: root

    required property real centerScale

    implicitWidth: time.implicitWidth + 40 * centerScale
    implicitHeight: time.implicitHeight + 30 * centerScale

    Burst {
        anchors.centerIn: parent
        width: parent.width * 1.05
        height: parent.height * 1.6
        spikes: 15
        seed: 61
        rotation: -4
    }

    Ransom {
        id: time

        anchors.centerIn: parent
        text: Time.hourStr + ":" + Time.minuteStr + (Time.amPmStr ? " " + Time.amPmStr : "")
        size: 84 * root.centerScale
        autoGlitch: true
    }
}
