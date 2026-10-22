pragma Singleton

import Quickshell

// Stands in for the bar's ColorScheme: the last user's scheme, as
// SharedLayouts loads it. Dark until then.
Singleton {
    property bool light: false
}
