import QtQuick
import Quickshell
import Quickshell.Io

// Monitors' saved layouts and the color scheme in a file per user under
// Host.sharedLayouts, for the greeter, which cannot reach a state directory in
// the user's home. The greeter loads one user's into its own Monitors and
// ColorScheme before the lid is read, so the first layout it applies is
// theirs. Written in place: the directory is root's, and only the file the
// user's own.
Scope {
    id: root

    property string user: Quickshell.env("USER") ?? ""
    // The bar's; the greeter only reads.
    property bool writes: false

    function load() {
        try {
            const shared = JSON.parse(file.text());
            Monitors.layouts = shared.layouts ?? {};
            ColorScheme.light = shared.light === true;
        } catch (e) {}
    }

    function write() {
        file.setText(JSON.stringify({
            layouts: Monitors.layouts,
            light: ColorScheme.light
        }));
    }

    Component.onCompleted: if (writes)
        write()

    Connections {
        target: root.writes ? Monitors : null

        function onLayoutsChanged() {
            root.write();
        }
    }

    Connections {
        target: root.writes ? ColorScheme : null

        function onLightChanged() {
            root.write();
        }
    }

    FileView {
        id: file

        path: `${Host.sharedLayouts}/${root.user}.json`
        blockAllReads: true
        atomicWrites: false
        printErrors: false
    }
}
