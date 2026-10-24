import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The session lock, through ext-session-lock: while it holds, Hyprland shows
// only its surfaces, one per screen, and gives them every key, and should the
// bar die under it the session stays locked on a plain colour. A flag in the
// runtime directory names the Hyprland instance locked, so a bar started under
// the lock, after a crash or `$mod SHIFT R`, takes it over, as
// `misc:allow_session_lock_restore` lets it; the lock command writes the flag
// too, and starts the bar should it be down. Every screen shows the one
// password typed, which PAM's `quickshell-lock` service checks.
Scope {
    id: root

    readonly property bool locked: session.locked
    readonly property bool checking: pam.active
    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property alias password: buffer
    readonly property alias caps: capsLock
    property string message: ""
    readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
    property real since: 0

    function engage() {
        flag.setText(instance);
        if (session.locked)
            return;
        buffer.text = "";
        message = "";
        since = Date.now();
        capsLock.update();
        session.locked = true;
    }

    function release() {
        session.locked = false;
        flag.setText("");
        buffer.text = "";
        message = "";
    }

    function check() {
        if (buffer.text === "" || pam.active)
            return;
        message = "";
        pam.start();
    }

    Component.onCompleted: {
        if (instance !== "" && flag.text().trim() === instance)
            engage();
    }

    KeyBuffer {
        id: buffer

        readOnly: root.checking
        onSubmitted: root.check()
    }

    CapsLock {
        id: capsLock
    }

    FileView {
        id: flag

        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-lock`
        blockAllReads: true
        blockWrites: true
        printErrors: false
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.engage();
        }
    }

    WlSessionLock {
        id: session

        onSecureChanged: if (secure)
            console.info(`Lock: every screen covered after ${Date.now() - root.since} ms`)

        LockSurface {
            lock: root
        }
    }

    // The password goes with the first prompt, the only one pam_unix sends;
    // its dots stay until the answer, which empties the field.
    PamContext {
        id: pam

        config: "quickshell-lock"
        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(buffer.text);
            } else if (pam.message !== "")
                root.message = pam.message;
        }
        onCompleted: result => {
            buffer.text = "";
            if (result === PamResult.Success)
                root.release();
            else
                root.message = result === PamResult.Failed ? "Wrong password" : result === PamResult.MaxTries ? "Too many attempts" : "Could not check the password";
        }
    }
}
