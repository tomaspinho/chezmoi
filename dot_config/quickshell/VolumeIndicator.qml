import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: vol


    property bool expanded: false

    // true while the fader handle is being dragged
    property bool dragging: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property bool ready: audio !== null
    readonly property bool isMuted: audio?.muted ?? false

    // pipewire reports volume as a 0-1 factor and allows over-amplification
    // above 1; the fader stops at 100% to stay out of distortion territory.
    readonly property int percent: audio ? Math.round(audio.volume * 100) : 0
    readonly property real fraction: audio ? Math.max(0, Math.min(1, audio.volume)) : 0

    // speaker glyphs: bare / one wave / two waves / crossed out
    readonly property int volLow: 0xF057F
    readonly property int volMid: 0xF0580
    readonly property int volHigh: 0xF057E
    readonly property int volOff: 0xF0581

    readonly property int glyph: !ready ? volOff
        : isMuted ? volOff
        : percent >= 67 ? volHigh
        : percent >= 34 ? volMid
        : volLow

    // Audio objects have to be tracked for their properties to stay live.
    PwObjectTracker { objects: vol.sink ? [vol.sink] : [] }

    // Setting a level while muted would be a silent no-op to the user, so
    // changing the volume unmutes, as it does on most desktops.
    function setTo(value) {
        if (!audio) return;
        audio.volume = Math.max(0, Math.min(100, Math.round(value))) / 100;
        if (audio.muted) audio.muted = false;
    }

    // One percentage point per wheel notch. Both call sites (the bar icon and
    // the fader track) must pass the same sign for a given scroll direction,
    // or the two surfaces of this one widget move the volume opposite ways.
    function step(direction) {
        if (!ready) return;
        setTo(Math.max(0, Math.min(100, percent + direction)));
    }

    // Whichever player is actually playing wins; with none playing (all
    // paused/stopped, or several paused at once) it falls back to the
    // first one MPRIS knows about, same "just pick one" heuristic as most
    // status-bar media widgets.
    readonly property var mprisPlayer: {
        const players = Mpris.players.values;
        if (players.length === 0) return null;
        return players.find(p => p.isPlaying) ?? players[0];
    }

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: String.fromCodePoint(vol.glyph)
            color: !vol.ready ? Theme.colMuted
                : vol.isMuted ? Theme.colMuted : Theme.colCyan
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
        }

        Text {
            text: vol.ready ? `${vol.percent}%` : "--"
            color: vol.isMuted ? Theme.colMuted : Theme.colFg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Positive delta raises the volume, matching the fader track's own
        // wheel handler below. Whether that reads as "scroll up" depends on
        // the device: hyprland enables natural_scroll for the touchpad only,
        // so libinput hands Qt opposite deltas for the same gesture on the
        // laptop's touchpad and the desktop's mouse.
        onWheel: wheel => vol.step(wheel.angleDelta.y > 0 ? 1 : -1)
        onClicked: vol.expanded = !vol.expanded
    }

    HyprlandFocusGrab {
        active: vol.expanded
        windows: [fader]
        onCleared: vol.expanded = false
    }

    // Volume control menu: fader plus, when something's available over
    // MPRIS, a now-playing section above it. Both live in the one
    // click-triggered popup rather than the media card popping up
    // separately on hover.
    BarPopup {
        id: fader
        anchorItem: vol
        visible: vol.expanded
        popupWidth: 260
        spacing: 8

        // Now-playing section: only takes up space in the column
        // when a player is actually known about.
        Column {
            width: parent.width
            spacing: 10
            visible: vol.mprisPlayer !== null

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    id: artFrame
                    width: 64
                    height: 64
                    radius: 6
                    color: Qt.lighter(Theme.colBg, 1.4)
                    clip: true

                    Image {
                        id: art
                        anchors.fill: parent
                        source: vol.mprisPlayer?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    // Fallback for no art (radio streams, local files
                    // with no embedded cover, art still loading).
                    Text {
                        anchors.centerIn: parent
                        visible: !art.visible
                        text: String.fromCodePoint(0xF075A) // md-music
                        color: Theme.colMuted
                        font { family: Theme.fontFamily; pixelSize: 26 }
                    }
                }

                Column {
                    width: parent.width - artFrame.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: vol.mprisPlayer?.trackTitle || "Nothing playing"
                        color: Theme.colFg
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 1; bold: true }
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: vol.mprisPlayer?.trackArtist ?? ""
                        color: Theme.colMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 3 }
                        elide: Text.ElideRight
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                Text {
                    readonly property bool canUse: vol.mprisPlayer?.canGoPrevious ?? false
                    text: String.fromCodePoint(0xF04AE) // md-skip_previous
                    color: canUse ? Theme.colFg : Theme.colMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 4 }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.canUse
                        cursorShape: Qt.PointingHandCursor
                        onClicked: vol.mprisPlayer.previous()
                    }
                }

                Text {
                    readonly property bool canUse: vol.mprisPlayer?.canTogglePlaying ?? false
                    text: (vol.mprisPlayer?.isPlaying ?? false)
                        ? String.fromCodePoint(0xF03E4)  // md-pause
                        : String.fromCodePoint(0xF040A)  // md-play
                    color: canUse ? Theme.colCyan : Theme.colMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 6 }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.canUse
                        cursorShape: Qt.PointingHandCursor
                        onClicked: vol.mprisPlayer.togglePlaying()
                    }
                }

                Text {
                    readonly property bool canUse: vol.mprisPlayer?.canGoNext ?? false
                    text: String.fromCodePoint(0xF04AD) // md-skip_next
                    color: canUse ? Theme.colFg : Theme.colMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 4 }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.canUse
                        cursorShape: Qt.PointingHandCursor
                        onClicked: vol.mprisPlayer.next()
                    }
                }
            }
        }

        PopupDivider { visible: vol.mprisPlayer !== null }

        BarFader {
            width: parent.width
            glyph: vol.glyph
            accent: vol.isMuted ? Theme.colMuted : Theme.colCyan
            percent: vol.percent
            ready: vol.ready
            fraction: vol.fraction

            onMoved: position => {
                vol.dragging = true;
                vol.setTo(position * 100);
            }
            onStepped: direction => vol.step(direction)
            onReleased: vol.dragging = false
        }

        PopupButton {
            text: "Audio devices"
            // Launched through Hyprland rather than execDetached so
            // the one-shot [float] rule applies; it would tile
            // otherwise. Hyprland owns the process, so it also
            // survives a shell reload.
            onClicked: {
                Hyprland.dispatch('hl.dsp.exec_cmd("[float] pavucontrol")');
                vol.expanded = false;
            }
        }
    }
}
