pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Emits `resumed` when the machine wakes from suspend/hibernate.
//
// SystemClock schedules its next tick with a QTimer, which counts on the
// monotonic clock - and that clock stops while the machine is asleep. So
// after a resume the pending tick still has whatever was left of the minute
// when it went down, and the clocks keep showing the pre-suspend time for up
// to a minute. Anything holding a SystemClock listens here and forces it to
// resync.
//
// logind broadcasts PrepareForSleep(true) going down and PrepareForSleep(false)
// coming back up, readable by any user on the system bus.
Singleton {
    id: sleep

    signal resumed()

    Process {
        id: monitorProc
        // stdbuf: don't trust gdbus to flush per line when stdout is a pipe.
        command: ["stdbuf", "-oL", "gdbus", "monitor", "--system",
            "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("PrepareForSleep (false")) sleep.resumed();
            }
        }
        // Nothing restarts a dead Process on its own, and without the delay a
        // missing gdbus would spin here.
        onExited: monitorRetry.restart()
    }

    Timer {
        id: monitorRetry
        interval: 2000
        onTriggered: monitorProc.running = true
    }
}
