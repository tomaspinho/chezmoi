import Quickshell
import QtQuick

// The rounded, bordered panel that drops out of a bar widget when it's
// clicked. Six widgets grew their own copy of this same PopupWindow: anchored
// under the item, left edges aligned, 6px clear of the bar, transparent
// surface with an opaque rounded Rectangle inside it.
//
// Children are placed in a Column, which is what all six call sites wanted -
// the popup sizes itself to that Column's implicit height plus `contentPadding`.
PopupWindow {
    id: popup

    // The bar widget this hangs from.
    required property Item anchorItem

    // Popups are hand-sized rather than content-sized: their contents are
    // lists and grids that would otherwise make the width jump around as the
    // data changes.
    property int popupWidth: 260

    // Total vertical padding - the frame is the content's height plus this.
    property int contentPadding: 16

    // Margin from the frame's edge to the content Column.
    property int contentMargin: 8

    property int spacing: 2

    default property alias content: column.data

    anchor {
        item: popup.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom | Edges.Left
        margins.top: 6
    }

    color: "transparent"
    implicitWidth: popup.popupWidth
    implicitHeight: frame.implicitHeight

    Rectangle {
        id: frame
        anchors.fill: parent
        implicitHeight: column.implicitHeight + popup.contentPadding
        color: Theme.colBg
        radius: 8
        border { width: 1; color: Theme.colMuted }

        Column {
            id: column
            anchors { fill: parent; margins: popup.contentMargin }
            spacing: popup.spacing
        }
    }
}
