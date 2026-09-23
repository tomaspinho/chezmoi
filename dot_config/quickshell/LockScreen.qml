import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import QtQuick

// A real Wayland session lock (ext-session-lock-v1, via WlSessionLock) rather
// than a fullscreen window pretending to be one - the compositor itself
// blanks every output and refuses input to anything else until `locked` goes
// back to false, so this can't be dismissed by closing/killing the surface
// the way a plain PanelWindow lock screen could. Authentication is real PAM
// (PamContext), not a hardcoded/local check.
//
// Lives in the object tree as a plain non-visual Item (like AppLauncher, but
// without AppLauncher's own PanelWindow - WlSessionLock isn't a window
// itself, it hands out one WlSessionLockSurface per output on its own).
// Triggered the same way PowerMenu's "Lock" already was: `loginctl
// lock-session` emits logind's Lock signal, which hypridle's `lock_cmd` turns
// into `qs ipc call lock lock` (see hypridle.conf) instead of launching
// hyprlock. That indirection is kept rather than having PowerMenu call this
// directly, so idle-timeout- and suspend-triggered locks (hypridle's other
// listeners, also just `loginctl lock-session`) keep locking the session the
// same way a manual click does.
Item {
    id: root

    // Single shared auth/status state, read by every per-screen surface
    // below - only one of them actually has keyboard focus at a time, but
    // all of them show the same clock and the same authenticating/error
    // state.
    property bool unlocking: false
    property string errorMessage: ""

    // Fingerprint state, kept apart from `errorMessage` above: the two stacks
    // run at the same time and say unrelated things, so "Incorrect password"
    // and "Place your finger on ..." need to be able to sit on screen
    // together without overwriting each other.
    //
    // `fingerprintMessage` is whatever pam_fprintd last said, verbatim, until
    // we stop restarting it and replace it with a note of our own. Empty
    // means the reader has nothing to report yet and the line stays hidden.
    property string fingerprintMessage: ""
    property bool fingerprintAvailable: true
    property int fingerprintRestarts: 0
    readonly property int maxFingerprintRestarts: 10

    // The PAM conversation is driven from here rather than from
    // WlSessionLock's own `onLockStateChanged` - that signal is documented
    // as the notify for `locked` (see quickshell's qmltypes) but was
    // confirmed live, with a counter, to never actually fire when `locked`
    // is set from this file's own IpcHandler, even though the property
    // change itself does take effect and is visible immediately on
    // read-back. Calling pam.start()/abort() directly at the two places
    // that ever change `locked` sidesteps that rather than chasing it
    // further - verified live that pam.start() itself works fine (responds
    // with a real "Password: " prompt) when called directly.
    function beginLock() {
        root.unlocking = false;
        root.errorMessage = "";
        root.fingerprintMessage = "";
        root.fingerprintAvailable = true;
        root.fingerprintRestarts = 0;
        sessionLock.locked = true;
        pam.start();
        fingerprint.start();
    }

    function endLock() {
        sessionLock.locked = false;
        pam.abort();
        fingerprint.abort();
        fingerprintRetry.stop();
    }

    // Each pam_fprintd run ends after max-tries non-matching touches (see
    // pam/quickshell-fingerprint), so the reader has to be restarted to stay
    // live for the rest of the lock - the same one-run-per-attempt shape the
    // password context already deals with. Capped rather than endless: a
    // reader that fails instantly (device claimed by something else, unplugged
    // mid-lock) would otherwise spin on fprintd for as long as the screen is
    // locked. Past the cap the reader goes quiet and the password field, which
    // none of this touches, is still there.
    function retryFingerprint() {
        if (!sessionLock.locked || !root.fingerprintAvailable) return;

        if (root.fingerprintRestarts >= root.maxFingerprintRestarts) {
            root.fingerprintAvailable = false;
            root.fingerprintMessage = "Too many fingerprint attempts - use your password";
            return;
        }

        root.fingerprintRestarts++;
        fingerprintRetry.restart();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // A sibling of WlSessionLock rather than nested inside it: WlSessionLock's
    // only child slot is its default `surface` property (a single Component),
    // so a second child declared alongside WlSessionLockSurface there doesn't
    // land where a plain reading suggests - `pam` ended up unreachable by id
    // from inside the surface content (`pam is not defined` at runtime).
    // Verified live.
    //
    // Was "hyprlock" (that PAM service, `/etc/pam.d/hyprlock`, was itself
    // just `include login`) - switched after hyprlock's package was removed
    // from the system (no longer needed once this replaced it) took that
    // file with it, which silently broke authentication here: pam.start()
    // failed with no service file to read, so responseRequired never became
    // true and Enter appeared to do nothing. "login" is a base system file
    // with no package dependency of its own to disappear.
    PamContext {
        id: pam
        config: "login"

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.endLock();
                return;
            }

            root.unlocking = false;
            root.errorMessage = result === PamResult.MaxTries
                ? "Too many attempts"
                : "Incorrect password";

            // Each PamContext run is one attempt; start a fresh one so the
            // field is live again for the next try. Deferred rather than
            // called straight from this handler, since it's a reentrant call
            // back into the object whose signal is still being handled.
            if (sessionLock.locked) Qt.callLater(() => pam.start());
        }

        onError: error => {
            root.unlocking = false;
            root.errorMessage = PamError.toString(error);
            if (sessionLock.locked) Qt.callLater(() => pam.start());
        }
    }

    // The second, parallel authentication stack. Two PamContexts rather than
    // one stack containing both modules because PAM is a serialised
    // conversation - pam_fprintd(8) spells this out under LIMITATIONS and says
    // the application is the one that has to run the two separately, which is
    // how gdm does it too. Sharing a stack would mean the password field sat
    // dead until the reader gave up.
    //
    // Whichever stack succeeds first calls endLock(), which aborts the other.
    PamContext {
        id: fingerprint
        config: "quickshell-fingerprint"
        // Not /etc/pam.d - this one ships with the shell, see the header of
        // pam/quickshell-fingerprint for why that's acceptable here and what
        // would change if the IPC unlock ever goes away.
        configDirectory: Quickshell.shellPath("pam")

        // pam_fprintd talks to the user purely through PAM_TEXT_INFO /
        // PAM_ERROR_MSG ("Place your right index finger on ...", "Failed to
        // match fingerprint") and never asks for anything back, so
        // responseRequired never becomes true here and this context has no
        // input widget of its own - the message line below is its entire UI.
        onPamMessage: root.fingerprintMessage = fingerprint.message

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.endLock();
                return;
            }

            root.retryFingerprint();
        }

        onError: error => {
            // StartFailed means the stack never got off the ground (config
            // file missing, pam_fprintd.so not installed) - that is not going
            // to come good on a retry, so don't spend the restart budget on
            // it. Anything else goes through the capped retry path.
            if (error === PamError.StartFailed) {
                root.fingerprintAvailable = false;
                root.fingerprintMessage = "";
                return;
            }

            root.retryFingerprint();
        }
    }

    // Deferred rather than calling fingerprint.start() straight out of the
    // handler above, for the same reentrancy reason the password context uses
    // Qt.callLater - the signal of the object being restarted is still on the
    // stack. The delay does double duty as the floor on how fast a reader that
    // fails immediately can be retried.
    Timer {
        id: fingerprintRetry
        interval: 1000
        repeat: false
        onTriggered: if (sessionLock.locked && root.fingerprintAvailable) fingerprint.start()
    }

    WlSessionLock {
        id: sessionLock

        // Best-effort only: this runs on a clean shutdown (the process
        // receiving SIGTERM, `qs kill`, a graceful exit), not a hard crash
        // (SIGKILL, segfault) - those never run QML cleanup at all. Tested
        // live: a quickshell process that dies while `locked` is true has no
        // software recovery on this Hyprland build - a *new* WlSessionLock
        // client calling lock() while the old one's lock is still considered
        // active does not take over/supersede it, it just dies too, silently
        // and without a trace. The only way out was a reboot. So this is a
        // real mitigation for the common case (a restart/reload of the
        // shell), not a substitute for being careful about what runs while
        // `locked` is true.
        Component.onDestruction: sessionLock.locked = false

        WlSessionLockSurface {
            id: surface

            // Grabbed on creation and again whenever the compositor actually
            // maps this surface - on multi-monitor setups only one of them
            // ends up with real keyboard input, but there's no way to know
            // which in advance, so every surface tries.
            onVisibleChanged: if (visible) passwordField.forceActiveFocus()
            Component.onCompleted: passwordField.forceActiveFocus()

            // Qt's own activeFocus can drop out from under the field on
            // resume from suspend (DPMS/output power-cycling), even though
            // the compositor's session-lock input grab itself stays intact -
            // confirmed live, the surface never re-fires onVisibleChanged for
            // this. Rather than chase the exact cause/signal, just watch for
            // it and take focus back - cheap, and correct regardless of what
            // knocked it out (suspend, a monitor hotplug, whatever else).
            //
            // `running` is a plain `true` rather than bound to
            // `sessionLock.locked`: that binding never re-evaluated in
            // testing (stuck at its initial value, never fired even while
            // genuinely locked) - the same broken `lockStateChanged` notify
            // already worked around in beginLock()/endLock() turns out to
            // break *any* binding on `locked`, not just explicit signal
            // handlers. Reading `sessionLock.locked` directly inside
            // onTriggered instead is unaffected, since that's a plain
            // property read, not a change-notification. Confirmed live
            // (suspend/resume, kernel-log-verified) that this successfully
            // catches and recovers the dropped focus within one tick.
            Timer {
                interval: 500
                running: true
                repeat: true
                onTriggered: if (sessionLock.locked && !passwordField.activeFocus) passwordField.forceActiveFocus()
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.colBg

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.colFg
                        font { family: Theme.fontFamily; pixelSize: 96; bold: true }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                        color: Theme.colMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 2 }
                    }

                    Item { width: 1; height: 24 }

                    Rectangle {
                        id: card
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320
                        height: cardColumn.implicitHeight + 32
                        radius: 8
                        color: Qt.lighter(Theme.colBg, 1.4)
                        border { width: 1; color: Theme.colMuted }

                        Column {
                            id: cardColumn
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                            spacing: 10

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String.fromCodePoint(0xF033E) + " " + Quickshell.env("USER")
                                color: Theme.colBlue
                                font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                            }

                            Rectangle {
                                id: passwordBox
                                width: parent.width
                                height: 36
                                radius: 4
                                color: Theme.colBg
                                border { width: 1; color: root.errorMessage !== "" ? Theme.colRed : Theme.colMuted }

                                // Click-to-reveal rather than press-and-hold:
                                // matches how the rest of this screen already
                                // works (click a toggle, see the state change),
                                // and a lock screen's password box isn't
                                // exposed to anyone but whoever is standing at
                                // the keyboard typing it anyway.
                                property bool revealPassword: false

                                Text {
                                    id: revealIcon
                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    // md-eye / md-eye-off
                                    text: String.fromCodePoint(passwordBox.revealPassword ? 0xF06D1 : 0xF06D0)
                                    color: revealHover.hovered ? Theme.colFg : Theme.colMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 6 }

                                    HoverHandler { id: revealHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: passwordBox.revealPassword = !passwordBox.revealPassword }
                                }

                                Text {
                                    anchors { left: parent.left; leftMargin: 10; right: revealIcon.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    verticalAlignment: Text.AlignVCenter
                                    visible: passwordField.text === ""
                                    text: "Password"
                                    color: Theme.colMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                                }

                                TextInput {
                                    id: passwordField
                                    anchors { left: parent.left; leftMargin: 10; right: revealIcon.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    verticalAlignment: TextInput.AlignVCenter
                                    // TextInput already scrolls horizontally to
                                    // keep the cursor in view once the text is
                                    // wider than the field (autoScroll), but it
                                    // still *paints* the part that scrolled out
                                    // of the anchored width unless it clips -
                                    // which looked like the password spilling
                                    // over the box's borders. With this it
                                    // behaves like an <input> on the web: the
                                    // contents slide under the edges and are cut
                                    // off there.
                                    clip: true
                                    color: Theme.colFg
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                                    // PAM sets responseVisible for prompts that
                                    // aren't the password itself (rare, but
                                    // e.g. a plain "PIN" module) - that and the
                                    // reveal toggle both unmask the field.
                                    echoMode: (passwordBox.revealPassword || pam.responseVisible) ? TextInput.Normal : TextInput.Password
                                    enabled: !root.unlocking
                                    focus: true

                                    function submit() {
                                        if (root.unlocking || !pam.responseRequired) return;
                                        root.unlocking = true;
                                        root.errorMessage = "";
                                        pam.respond(text);
                                        text = "";
                                    }

                                    Keys.onPressed: event => {
                                        switch (event.key) {
                                        case Qt.Key_Return:
                                        case Qt.Key_Enter:
                                            passwordField.submit();
                                            event.accepted = true;
                                            break;
                                        case Qt.Key_Escape:
                                            passwordField.text = "";
                                            root.errorMessage = "";
                                            event.accepted = true;
                                            break;
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                text: root.unlocking ? "Authenticating…" : root.errorMessage
                                color: Theme.colRed
                                font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 3 }
                                visible: text !== ""
                            }

                            // pam_fprintd's own words, prefixed with the
                            // reader icon. Muted while the reader is live,
                            // since "Place your finger on ..." is an
                            // invitation and not a problem; yellow rather than
                            // red once it has given up, to keep red meaning
                            // "the password you typed was wrong".
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                // nf-md-fingerprint
                                text: String.fromCodePoint(0xF0237) + "  " + root.fingerprintMessage
                                color: root.fingerprintAvailable ? Theme.colMuted : Theme.colYellow
                                font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 3 }
                                visible: root.fingerprintMessage !== ""
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.beginLock(); }
        // Not the normal unlock path (a correct password is), but useful for
        // manual recovery/testing: `qs ipc call lock unlock`. No extra
        // exposure over what's already true without it - anything able to
        // reach this shell's IPC socket is already running as this user, the
        // exact same trust boundary loginctl's own unlock-session sits behind.
        function unlock(): void { root.endLock(); }
    }
}
