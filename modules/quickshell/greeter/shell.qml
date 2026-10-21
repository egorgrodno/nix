import QtQuick
import Quickshell

// greetd's greeter, inside a Hyprland of its own that ends once Quickshell
// does, as it does on launching the session: on every screen the time, the
// login card and the keys, over the theme's background.
ShellRoot {
    Greeter {
        id: login
    }

    Variants {
        model: Quickshell.screens

        GreeterSurface {
            greeter: login
        }
    }
}
