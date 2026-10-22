// Vivaldi's "Operating System" theme schedule reads this pref, which its Linux
// build never sets; the UI's media query still follows the portal.
const dark = matchMedia("(prefers-color-scheme: dark)");
let applied;

function sync() {
    const scheme = dark.matches ? "dark" : "light";
    if (scheme === applied)
        return;
    applied = scheme;
    vivaldi.prefs.set({ path: "vivaldi.system.desktop_theme_color", value: scheme });
}

sync();
dark.addEventListener("change", sync);
// Hyprland sends a hidden window no frames, and without frames no change event.
setInterval(sync, 1000);
