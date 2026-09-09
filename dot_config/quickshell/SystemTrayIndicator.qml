import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects

// StatusNotifierItem host. Instantiating anything from
// Quickshell.Services.SystemTray is what makes quickshell claim
// org.kde.StatusNotifierWatcher on the session bus, so tray-capable apps only
// start publishing once this widget exists — apps launched before it will not
// show up until they re-register.
//
// Menus are deliberately *not* drawn here: see the UseQApplication pragma in
// shell.qml. Right-click hands the item's DBusMenu handle to QsMenuAnchor,
// which renders it as a genuine Qt QMenu with working submenus, checkboxes,
// icons, keyboard navigation and pointer grab.
Item {
    id: tray


    // Sized to the ink height of the Nerd Font glyphs beside it rather than to
    // the font's full line box, so the icons read as the same size as the rest
    // of the bar and don't force the panel taller than the text needs.
    readonly property int iconSize: Math.round(Theme.fontSize * 0.85)
    // Tray icons read as one group, so they sit tighter than the gap between
    // status items. They're bitmaps with no side bearing, unlike the Nerd Font
    // glyphs elsewhere on the bar, so this value lands on screen as-is.
    readonly property int spacing: Math.round(Theme.fontSize * 0.45)

    // Passive items are the SNI way of saying "nothing to show right now".
    readonly property var items: SystemTray.items.values.filter(
        i => i.status !== Status.Passive)

    visible: items.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: iconSize

    QsMenuAnchor {
        id: menuAnchor

        // Open below the icon that was clicked, left edges aligned. The anchor
        // item is re-pointed per click rather than one anchor per delegate,
        // because only one menu can be up at a time anyway.
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom | Edges.Right
    }

    function openMenu(item, anchorItem) {
        if (!item.hasMenu)
            return;
        menuAnchor.anchor.item = anchorItem;
        menuAnchor.menu = item.menu;
        menuAnchor.open();
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: tray.spacing

        Repeater {
            model: tray.items

            Item {
                id: delegate
                required property var modelData

                width: tray.iconSize
                height: tray.iconSize

                // Symbolic icons ship a baked-in near-white fill that the host
                // is expected to recolour; anything else is a full-colour app
                // icon and must be left alone.
                readonly property bool symbolic:
                    String(modelData.icon || "").split("?")[0].endsWith("-symbolic")

                Image {
                    id: icon
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: delegate.modelData.icon
                    // Decode at device pixels, otherwise PNG tray icons are
                    // upscaled from the logical size and look blurry on HiDPI.
                    sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                    sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                    // Kept as an offscreen layer so MultiEffect can sample it.
                    visible: !delegate.symbolic
                    layer.enabled: delegate.symbolic
                }

                MultiEffect {
                    anchors.fill: icon
                    source: icon
                    visible: delegate.symbolic
                    colorization: 1.0
                    colorizationColor: Theme.colFg
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    // Right-press, not right-click: native menus grab the
                    // pointer, so the release never arrives here.
                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            tray.openMenu(delegate.modelData, delegate);
                            mouse.accepted = true;
                        }
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            delegate.modelData.secondaryActivate();
                        } else if (mouse.button === Qt.LeftButton) {
                            // onlyMenu items expose no activate action at all;
                            // a plain click on them is meant to raise the menu.
                            if (delegate.modelData.onlyMenu)
                                tray.openMenu(delegate.modelData, delegate);
                            else
                                delegate.modelData.activate();
                        }
                    }

                    onWheel: wheel => {
                        if (wheel.angleDelta.y !== 0)
                            delegate.modelData.scroll(wheel.angleDelta.y, false);
                        if (wheel.angleDelta.x !== 0)
                            delegate.modelData.scroll(wheel.angleDelta.x, true);
                    }
                }
            }
        }
    }
}
