pragma Singleton

import QtQuick
import Quickshell

// The one SelectableText with a selection, which Ctrl+C copies. A new
// selection clears the one before.
Singleton {
    property SelectableText owner: null

    function take(item) {
        if (owner && owner !== item)
            owner.clearSelection();
        owner = item;
    }

    function drop(item) {
        if (owner === item)
            owner = null;
    }

    // False with nothing selected, so the key goes on to whatever else takes it.
    function copy() {
        const text = owner?.copied() ?? "";
        if (text === "")
            return false;
        Quickshell.clipboardText = text;
        return true;
    }
}
