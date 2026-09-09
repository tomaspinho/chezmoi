import QtQuick

// The hairline rule between sections inside a popup. Trivial on its own, but
// it appeared five times across four files, so it lives here instead.
//
// Sized to fill its parent Column's width, which is how every one of those
// call sites used it.
Rectangle {
    width: parent ? parent.width : 0
    height: 1
    color: Theme.colMuted
}
