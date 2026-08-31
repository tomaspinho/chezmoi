import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: vol

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

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

    // Snap to the 10% grid, then step.
    function step(direction) {
        if (!ready) return;
        const base = percent;
        setTo(Math.max(0, Math.min(100, base +  direction)));
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
            color: !vol.ready ? vol.colMuted
                : vol.isMuted ? vol.colMuted : vol.colCyan
            font { family: vol.fontFamily; pixelSize: vol.fontSize }
        }

        Text {
            text: vol.ready ? `${vol.percent}%` : "--"
            color: vol.isMuted ? vol.colMuted : vol.colFg
            font { family: vol.fontFamily; pixelSize: vol.fontSize }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => vol.step(wheel.angleDelta.y > 0 ? -1 : 1)
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
    PopupWindow {
        id: fader

        anchor {
            item: vol
            edges: Edges.Bottom
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        color: "transparent"
        visible: vol.expanded
        implicitWidth: 260
        implicitHeight: frame.implicitHeight

        Rectangle {
            id: frame
            anchors.fill: parent
            implicitHeight: column.implicitHeight + 16
            color: vol.colBg
            radius: 8
            border { width: 1; color: vol.colMuted }

            Column {
                id: column
                anchors { fill: parent; margins: 8 }
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
                            color: Qt.lighter(vol.colBg, 1.4)
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
                                color: vol.colMuted
                                font { family: vol.fontFamily; pixelSize: 26 }
                            }
                        }

                        Column {
                            width: parent.width - artFrame.width - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: vol.mprisPlayer?.trackTitle || "Nothing playing"
                                color: vol.colFg
                                font { family: vol.fontFamily; pixelSize: vol.fontSize - 1; bold: true }
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: vol.mprisPlayer?.trackArtist ?? ""
                                color: vol.colMuted
                                font { family: vol.fontFamily; pixelSize: vol.fontSize - 3 }
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
                            color: canUse ? vol.colFg : vol.colMuted
                            font { family: vol.fontFamily; pixelSize: vol.fontSize + 4 }

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
                            color: canUse ? vol.colCyan : vol.colMuted
                            font { family: vol.fontFamily; pixelSize: vol.fontSize + 6 }

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
                            color: canUse ? vol.colFg : vol.colMuted
                            font { family: vol.fontFamily; pixelSize: vol.fontSize + 4 }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.canUse
                                cursorShape: Qt.PointingHandCursor
                                onClicked: vol.mprisPlayer.next()
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: vol.colMuted
                    visible: vol.mprisPlayer !== null
                }

                Item {
                    width: parent.width
                    height: 22

                    Text {
                        id: faderIcon
                        anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                        text: String.fromCodePoint(vol.glyph)
                        color: vol.isMuted ? vol.colMuted : vol.colCyan
                        font { family: vol.fontFamily; pixelSize: vol.fontSize }
                    }

                    Text {
                        id: faderLabel
                        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                        // fixed width so the track doesn't resize as the number grows
                        width: 38
                        horizontalAlignment: Text.AlignRight
                        text: vol.ready ? `${vol.percent}%` : "--"
                        color: vol.colFg
                        font { family: vol.fontFamily; pixelSize: vol.fontSize - 1 }
                    }

                    Item {
                        id: track

                        anchors {
                            left: faderIcon.right; leftMargin: 10
                            right: faderLabel.left; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        height: 20

                        Rectangle {
                            id: groove
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: vol.colMuted

                            Rectangle {
                                width: groove.width * vol.fraction
                                height: parent.height
                                radius: parent.radius
                                color: vol.isMuted ? vol.colMuted : vol.colCyan
                            }
                        }

                        Rectangle {
                            id: handle
                            width: 13
                            height: 13
                            radius: width / 2
                            color: vol.isMuted ? vol.colMuted : vol.colCyan
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(track.width - width,
                                vol.fraction * track.width - width / 2))
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            function apply(x) {
                                vol.setTo(Math.max(0, Math.min(1, x / width)) * 100);
                            }

                            onPressed: mouse => {
                                vol.dragging = true;
                                apply(mouse.x);
                            }
                            onPositionChanged: mouse => {
                                if (pressed) apply(mouse.x);
                            }
                            onReleased: vol.dragging = false
                            onWheel: wheel => vol.step(wheel.angleDelta.y > 0 ? 1 : -1)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 4
                    color: launchHover.hovered ? Qt.lighter(vol.colBg, 1.8) : "transparent"
                    border { width: 1; color: vol.colMuted }

                    Text {
                        anchors.centerIn: parent
                        text: "Audio devices"
                        color: launchHover.hovered ? vol.colCyan : vol.colFg
                        font { family: vol.fontFamily; pixelSize: vol.fontSize - 3 }
                    }

                    HoverHandler {
                        id: launchHover
                        // Not on the TapHandler: a pointer handler's
                        // cursorShape only applies while it is active, which
                        // for a tap is "while held", not "while hovered".
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        // Launched through Hyprland rather than execDetached so
                        // the one-shot [float] rule applies; it would tile
                        // otherwise. Hyprland owns the process, so it also
                        // survives a shell reload.
                        onTapped: {
                            Hyprland.dispatch('hl.dsp.exec_cmd("[float] pavucontrol")');
                            vol.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
