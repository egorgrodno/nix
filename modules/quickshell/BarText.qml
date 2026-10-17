import QtQuick

// Full hinting rounds each advance to a whole pixel, as Pango does for GTK, so
// text runs exactly as wide as it did in Waybar. Curve rendering keeps it
// greyscale: native rendering takes subpixel order from the output.
Text {
    color: "#ffffff"
    font.family: Theme.fontUI
    font.pixelSize: 16
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.CurveRendering
    textFormat: Text.PlainText
}
