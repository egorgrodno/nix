//@ pragma UseQApplication

import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Once for the shell, not per screen.
    PowerSaverDim {}
}
