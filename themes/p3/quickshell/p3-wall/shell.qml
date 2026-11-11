// p3-wall: video wallpaper for the Persona 3 theme.
// Loops the slot file ~/.local/share/persona-rice/media/p3/wall.mp4 (override the folder with
// $P3_MEDIA) on the Background layer of every screen, muted, but ONLY on AC power: on battery
// the video pauses on its current frame (no decoding, no redraws), and starting up on battery
// shows wall-still.png (the video's first frame) until the charger is plugged in. It also
// pauses while a fullscreen window covers the screen.
// Caelestia's own wallpaper is turned off for this theme (background.wallpaperEnabled: false
// in themes/p3/caelestia/shell.json), so its desktop layer is transparent over this.
//
// Liquid glass: the top bar reserves its strip, so the only thing ever behind it is this
// wallpaper. p3-wall draws the bar's glass itself from its own picture (glass.frag): the image
// lenses toward the strip's bottom edge, with a colour fringe, a sheen, a rim and a soft
// shadow below. The bar (persona-bar) only draws text on top. glassH must match the bar's
// barHeight (persona-bar/shell.qml).
//
// Launch: qs -c p3-wall -n -d   (persona-theme autostarts it while p3 is active)
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

ShellRoot {
    id: shell

    DarkHour { id: dh }

    Motion {
        id: motion
        // tell the user once when the battery limit stops everything
        onLiveChanged: {
            if (!live && mode === "auto" && known)
                Quickshell.execDetached(["notify-send", "-a", "Persona", "-i", "battery-caution",
                    "Animations paused", "Battery at " + Math.round(percent) + "%. Everything eases to a stop until you plug in."]);
        }
    }

    readonly property string media: Quickshell.env("P3_MEDIA") || (Quickshell.env("HOME") + "/.local/share/persona-rice/media/p3")

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "p3-wall"
            color: "#030a26"

            readonly property bool covered: Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false
            // UPower reports onBattery=false until its display device is ready, so wait for it
            readonly property bool powerKnown: UPower.displayDevice?.ready ?? false
            // plays while Motion allows it (slowing down as it stops) and nothing fullscreen covers it
            readonly property bool shouldPlay: powerKnown && motion.speed > 0.03 && !covered
            // true once the video has shown a frame, so pausing keeps it instead of the still
            property bool started: false

            function sync(): void {
                if (shouldPlay) {
                    player.play();
                    started = true;
                } else if (started) {
                    player.pause();
                }
            }
            onShouldPlayChanged: sync()

            MediaPlayer {
                id: player
                source: "file://" + shell.media + "/wall.mp4"
                loops: MediaPlayer.Infinite
                videoOutput: vid
                audioOutput: AudioOutput { muted: true }
                // slows down with Motion instead of stopping dead
                playbackRate: Math.max(0.1, Math.round(motion.speed * 20) / 20)
                Component.onCompleted: win.sync()
            }

            // the picture: the still until the video has shown a frame, then the video. During
            // the Dark Hour it's drawn through grade.frag (green), so the bar's glass, which is
            // made from this picture, turns green with it
            Item {
                id: wallPic
                anchors.fill: parent

            Item {
                id: rawPic
                anchors.fill: parent
            Image {
                anchors.fill: parent
                source: "file://" + shell.media + "/wall-still.png"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: !win.started || !player.hasVideo
            }

            VideoOutput {
                id: vid
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                visible: win.started && player.hasVideo
            }
            }
            ShaderEffectSource {
                id: rawTex
                sourceItem: rawPic
                hideSource: dh.t > 0
                live: true
                visible: false
            }
            ShaderEffect {
                anchors.fill: parent
                visible: dh.t > 0
                property variant source: rawTex
                property real dark: dh.t
                fragmentShader: Qt.resolvedUrl("grade.frag.qsb")
            }
            }

            // liquid glass under the top bar, made from the strip of picture it covers
            readonly property int glassH: 44     // = persona-bar barHeight
            readonly property int shadowH: 14    // soft shadow cast below the glass
            ShaderEffectSource {
                id: strip
                sourceItem: wallPic
                sourceRect: Qt.rect(0, 0, win.width, win.glassH + win.shadowH)
                live: true
                hideSource: false
                visible: false
            }
            ShaderEffect {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: win.glassH + win.shadowH
                property variant source: strip
                property size size: Qt.size(width, height)
                property real glassH: win.glassH
                fragmentShader: Qt.resolvedUrl("glass.frag.qsb")
            }
        }
    }
}
