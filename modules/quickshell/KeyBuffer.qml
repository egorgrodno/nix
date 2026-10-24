import QtQml

// A password typed with no field behind it, so every screen can show the one
// buffer and whichever has the keyboard edits it. Enter submits, Backspace
// takes the last character, Ctrl Backspace and Escape clear it. While
// read-only it takes no keys.
QtObject {
    id: buffer

    property string text: ""
    property bool readOnly: false

    signal submitted

    // True for a key it took.
    function key(event) {
        if (readOnly)
            return false;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            submitted();
            return true;
        case Qt.Key_Backspace:
            text = ctrl ? "" : text.slice(0, -1);
            return true;
        case Qt.Key_Escape:
            text = "";
            return true;
        }
        // A printable character, not a shortcut: Alt and Super combinations
        // type nothing in a password either.
        const code = event.text.length > 0 ? event.text.charCodeAt(0) : 0;
        if (code < 0x20 || code === 0x7f || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0)
            return false;
        text += event.text;
        return true;
    }
}
