pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    color: "transparent"

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ScriptAction {
            script: content.leave()
        }
        // p3: correct password -> Yuki drops with a gradient on his body (lock-sink.mp4 at 2.4x,
        // crossfaded over the float loop); as he leaves, the screen fades into a still of the
        // desktop captured at lock time, then the lock is released onto the same picture.
        // (Hyprland draws black behind a fading lock surface, so it never fades to transparent.)
        ScriptAction {
            script: if (root.sinkReady) sinkPlayer.play()
        }
        NumberAnimation {
            target: root
            property: "sinkFade"
            to: 1
            duration: root.sinkReady ? 80 : 0
        }
        PauseAnimation {
            // he is gone ~0.75 s into the sped-up clip; fade in while his last bit leaves
            duration: root.sinkReady ? 450 : 0
        }
        ParallelAnimation {
            Anim {
                target: content
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            NumberAnimation {
                target: root
                property: "desktopFade"
                to: 1
                duration: 300
                easing.type: Easing.InOutSine
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    // p3: no spinning lock card. The surface starts on a still of the desktop (so locking
    // never flashes black) and crossfades into the video while the calendar and password
    // slide in.
    ParallelAnimation {
        id: initAnim

        running: true

        NumberAnimation {
            target: background
            property: "opacity"
            to: 1
            duration: 0
        }
        NumberAnimation {
            target: root
            property: "desktopFade"
            to: 0
            duration: 450
            easing.type: Easing.InOutSine
        }
        Anim {
            type: Anim.DefaultEffects
            target: content
            property: "opacity"
            to: 1
        }
        ScriptAction {
            script: content.enter()
        }
    }

    // p3: video backdrop slots in ~/.local/share/persona-rice/media/p3 (or $P3_MEDIA).
    // lock-float.mp4 loops while locked; on a correct password lock-sink.mp4 (preloaded,
    // paused on its first frame, played at 2.4x) crossfades in, then the desktop still fades in.
    // Without the float video the blurred desktop below is used instead.
    readonly property string media: Quickshell.env("P3_MEDIA") || (Quickshell.env("HOME") + "/.local/share/persona-rice/media/p3")
    readonly property bool videoReady: floatPlayer.hasVideo && floatPlayer.error === MediaPlayer.NoError
    readonly property bool sinkReady: videoReady && sinkPlayer.hasVideo && sinkPlayer.error === MediaPlayer.NoError
    property real sinkFade: 0
    property real desktopFade: 1   // starts on the desktop still, see initAnim

    MediaPlayer {
        id: floatPlayer

        source: "file://" + root.media + "/lock-float.mp4"
        loops: MediaPlayer.Infinite
        videoOutput: floatVideo
        audioOutput: AudioOutput { muted: true }
        // follows Motion (shared p3 rule): slows to a pause, eases back in
        playbackRate: Math.max(0.1, Math.round(lockMotion.speed * 20) / 20)
        Component.onCompleted: { play(); if (lockMotion.speed <= 0.03) pause(); }
    }
    Motion {
        id: lockMotion
        onSpeedChanged: {
            if (speed <= 0.03 && floatPlayer.playbackState === MediaPlayer.PlayingState)
                floatPlayer.pause();
            else if (speed > 0.03 && floatPlayer.playbackState !== MediaPlayer.PlayingState)
                floatPlayer.play();
        }
    }

    MediaPlayer {
        id: sinkPlayer

        source: "file://" + root.media + "/lock-sink.mp4"
        videoOutput: sinkVideo
        playbackRate: 2.4
        audioOutput: AudioOutput { muted: true }
        Component.onCompleted: pause()
    }

    Item {
        id: background

        anchors.fill: parent
        opacity: 0
        visible: !root.videoReady

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: Config.lock.useWallpaper ? wallpaperBackground : screencopyBackground
        }
    }

    // unblurred videos; they share the blurred backdrop's fade in/out
    VideoOutput {
        id: floatVideo

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: background.opacity
        visible: root.videoReady && root.sinkFade < 1   // hidden once the sink clip covers it
    }

    VideoOutput {
        id: sinkVideo

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: background.opacity * root.sinkFade
        visible: root.sinkReady && root.sinkFade > 0
    }

    // the desktop as it looked when locking (captured once): lock-in fades out of it, unlock fades into it
    ScreencopyView {
        id: desktopShot

        anchors.fill: parent
        captureSource: root.screen
        live: false
        opacity: root.desktopFade   // kept "visible" so the capture is taken up front
    }

    Component {
        id: screencopyBackground

        ScreencopyView {
            captureSource: root.screen
        }
    }

    Component {
        id: wallpaperBackground

        CachingImage {
            path: Wallpapers.current
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Tokens.padding.large * 4
        readonly property int radius: size / 4 * Tokens.rounding.scale

        anchors.centerIn: parent
        implicitWidth: size
        implicitHeight: size

        visible: Config.lock.enabled
        rotation: 180
        scale: 0

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Colours.palette.m3surface
            radius: parent.radius
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }

        MaterialIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "lock"
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(4).weight(Font.Bold).build()
            rotation: 180
        }

    }

    // p3: full-screen takeover instead of content inside the card
    Content {
        id: content

        anchors.fill: parent
        lock: root
        opacity: 0
    }
}
