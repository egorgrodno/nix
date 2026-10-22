import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// The greeter's state, which every screen shows: the user and session picked,
// the password typed, and greetd's conversation. The password goes with
// greetd's first prompt; a later one, as for a new password, waits for the
// next Enter. The last user, and each user's last session, persist in the
// state directory, under the greeter user's home; a user without one gets
// the system's default session. The screens take the layouts the last user
// saved, clamshell included, and their color scheme, which SharedLayouts
// loads. Reboot and shut down take their key twice.
Scope {
    id: root

    readonly property var logins: JSON.parse(loginsFile.text())
    readonly property var users: logins.users
    readonly property var sessions: logins.sessions
    property int userIndex: 0
    property int sessionIndex: 0
    readonly property var user: users[userIndex] ?? null
    readonly property var session: sessions[sessionIndex] ?? null
    readonly property alias password: buffer
    readonly property alias caps: capsLock
    property string message: ""
    property bool messageError: false
    // From Enter until greetd's first prompt takes the password.
    property bool sending: false
    // greetd asked again, as for a new password.
    property bool asked: false
    // From a failed login to greetd's next word: Quickshell then cancels the
    // session greetd has already ended, and greetd refuses with an error that
    // says nothing about the login.
    property bool failed: false
    readonly property bool busy: Greetd.state !== GreetdState.Inactive && !asked
    // The screens' layout has applied, or never will. The login screen shows
    // only then, so the scale jump happens under the plain background.
    property bool ready: false
    readonly property bool settled: Monitors.settled
    // "reboot" or "poweroff", until its key comes again or the timer ends.
    property string armed: ""
    property var remembered: ({
            user: "",
            sessions: {}
        })

    onSettledChanged: if (settled)
        hold.start()

    function pick(index) {
        if (users.length === 0)
            return;
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        sending = false;
        asked = false;
        buffer.text = "";
        message = "";
        userIndex = (index + users.length) % users.length;
        const slug = remembered.sessions[user.name] ?? logins.defaultSession;
        sessionIndex = Math.max(0, sessions.findIndex(s => s.slug === slug));
    }

    function stepUser(by) {
        if (users.length > 1)
            pick(userIndex + by);
    }

    function stepSession(by) {
        if (sessions.length > 1)
            sessionIndex = (sessionIndex + by + sessions.length) % sessions.length;
    }

    function submit() {
        if (!user || !session)
            return;
        if (asked) {
            asked = false;
            Greetd.respond(buffer.text);
        } else if (Greetd.state === GreetdState.Inactive && buffer.text !== "") {
            message = "";
            sending = true;
            Greetd.createSession(user.name);
        }
    }

    function fail(text) {
        sending = false;
        asked = false;
        buffer.text = "";
        message = text;
        messageError = true;
    }

    function power(verb) {
        if (armed === verb) {
            armed = "";
            Quickshell.execDetached([Programs.systemctl, verb]);
        } else {
            armed = verb;
            disarm.restart();
        }
    }

    // Written before the launch, after which greetd wants the greeter gone.
    function launch() {
        remembered = {
            user: user.name,
            sessions: Object.assign({}, remembered.sessions, {
                [user.name]: session.slug
            })
        };
        stateFile.setText(JSON.stringify(remembered));
        Greetd.launch([session.exec], ["XDG_SESSION_TYPE=wayland", `XDG_SESSION_DESKTOP=${session.slug}`, `DESKTOP_SESSION=${session.slug}`, ...(session.desktops !== "" ? [`XDG_CURRENT_DESKTOP=${session.desktops}`] : [])]);
    }

    Component.onCompleted: {
        try {
            remembered = Object.assign(remembered, JSON.parse(stateFile.text()));
        } catch (e) {}
        pick(Math.max(0, users.findIndex(u => u.name === remembered.user)));
        // The screens as the user picked lays them out, before Monitors reads
        // the lid and applies a layout.
        shared.user = user?.name ?? "";
        shared.load();
        capsLock.update();
    }

    KeyBuffer {
        id: buffer

        onSubmitted: root.submit()
    }

    CapsLock {
        id: capsLock
    }

    SharedLayouts {
        id: shared
    }

    Timer {
        id: hold

        interval: 300
        onTriggered: root.ready = true
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: root.ready = true
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            root.failed = false;
            if (responseRequired && root.sending) {
                root.sending = false;
                Greetd.respond(buffer.text);
            } else if (responseRequired) {
                buffer.text = "";
                root.asked = true;
                root.message = message;
                root.messageError = false;
            } else {
                root.message = message;
                root.messageError = error;
            }
        }

        function onAuthFailure(message) {
            root.fail("Wrong password");
            root.failed = true;
        }

        function onError(error) {
            if (root.failed) {
                root.failed = false;
                console.info(`Greeter: ignored greetd's "${error}" after the failed login`);
            } else
                root.fail(error);
        }

        function onReadyToLaunch() {
            root.launch();
        }
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    // The sessions and users, which the module writes at build time.
    FileView {
        id: loginsFile

        path: Quickshell.shellPath("logins.json")
        blockAllReads: true
    }

    FileView {
        id: stateFile

        path: Quickshell.statePath("greeter.json")
        blockAllReads: true
        blockWrites: true
        printErrors: false
    }
}
