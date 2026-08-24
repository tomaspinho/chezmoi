import Quickshell.Hyprland
import QtQuick

// Title of the currently focused Hyprland toplevel.
//
// Unlike the other bar widgets this one takes its colour and font through the
// Text properties it already has rather than through colFg/fontFamily/fontSize
// aliases: the root *is* the Text, so aliasing would leave two writable knobs
// for the same thing and the binding would silently win over whichever the
// caller set.
Text {
    id: title

    // Upper bound on how wide the title may grow before it elides. The widget
    // is centred on the panel, so an unclamped long title would run under the
    // status items on the right. Infinity means "as wide as the text needs",
    // which is what a caller that doesn't care should get.
    property real maxWidth: Infinity

    // Not `implicitWidth` clamped in place: Text only elides when it has been
    // given an explicit width, so the clamp has to be a real width assignment.
    width: Math.min(implicitWidth, maxWidth)
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight

    // Nothing focused (empty workspace) reads as an empty bar centre.
    text: Hyprland.activeToplevel?.title ?? ""
}
