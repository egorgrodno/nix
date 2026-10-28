# Quickshell

The bar and everything drawn with it: panels, notifications, OSD, launcher, lock screen, and the greeter in `greeter/`. `shell.qml` is the root. This file covers what no single file shows.

**Build.** Every `*.qml` here is linked into `~/.config/quickshell`. `default.nix` also generates `Theme.qml`, `Host.qml`, `Programs.qml` and `symbols.json`. The `quickshell` user unit has no useful PATH, so every program the bar runs **must** come from `Programs.qml`.

**Running programs.** A program the bar opens **must** start through `Launcher.run`, which gives it a scope of its own. A plain child dies when the bar restarts.

**State.** The bar's own state lives under `Quickshell.statePath`. State shared with scripts (the color scheme, the night light) sits in `$XDG_STATE_HOME`. The bosun panel's state (`BosunKept.qml`) is the exception: it must survive a restart of the bar but not a logout, which `Quickshell.statePath` outlasts. It sits in `$XDG_RUNTIME_DIR`, in a file named after `HYPRLAND_INSTANCE_SIGNATURE`, so it starts fresh on each login even with lingering on.

**IPC.** Hyprland's binds and scripts reach the bar through `quickshell ipc call <target> <function>`, each target an `IpcHandler`. Renaming a target or function breaks its callers: the binds in `modules/desktop/default.nix`, and `lockCommand` and the desktop entries in `default.nix`. Scripts drive the bosun panel through its target, never by keystrokes: see `BOSUN-IPC.md`. That target **must not** gain a call that sends, interrupts, answers, kills or pauses, or that completes a two-press action.

**Layers.** Hyprland's `layer_rule`s in `modules/desktop/default.nix` match the bar's surfaces by `WlrLayershell.namespace`. Renaming a namespace drops its rules.

**Panels.** A panel builds on `Panel.qml`. Its focus grab, layer and fixed-size surface each work around Hyprland, and its comments say how.

**Components.** Before building a control, use one of these. If none fits, extend it rather than copy it. A `component` declared inside a file serves only that file: when a second file needs it, move it to its own file first and use it from both.

| Component | For |
|---|---|
| `BarText` | Every piece of text: the bar's face, hinting and curve rendering, plain text |
| `Caption` | Muted, smaller `BarText` |
| `Figure` | A changing number in mono, in a slot as wide as `widest` so it never moves its neighbours |
| `TextButton` | A small labelled button, lit while `lit` is set |
| `ChoiceButton` | A `TextButton` of a row of choices, blue while it is the one picked |
| `Toggle` | A switch, blue while on |
| `Chevron` | A ‹ or › that steps what it sits beside |
| `Meter`, `Spark` | A 0 to 1 level, and a history scaled to its own peak |
| `Pill`, `Segment` | A right-hand module with an optional tooltip, and a group of modules on a bar |
| `Tooltip` | The hover tip under or over a module, or with `beside` to its right |
| `OverlayScrollBar` | The scroll bar of every view that scrolls, attached as `ScrollBar.vertical` or `ScrollBar.horizontal` |
| `BosunDropdown` | A button showing the current value that opens a menu of the others, inside the panel's window |
| `BosunComposer` | Every text field of the panel: grows to a few lines and sends on Ctrl+Enter; `oneLine` makes it a line that Return submits; `sends: false` makes a submit emit `accepted` and keep the text |
| `BosunMarkdown` | An assistant's text as Markdown, selectable a block at a time |
| `SelectableText` | `BarText`'s look in a read-only `TextEdit` the mouse selects, for `MouseSelection` to copy |
| `SelectableMarkdown` | Todoist-style Markdown the mouse selects, built on `SelectableText` |
| `BosunLine` | A line that opens at a click: chevron, glyph, label and an aside, with `open` and `toggled` for the caller to wire |
| `BosunRow` | A row that selects: fill while current, a lighter one on hover, a 2 px edge blue while the keyboard is in the list; `inert` for an entry with nothing behind it, which takes no hover or click |
| `BosunLink` | Blue text that opens what it names, strong on hover, with `clicked` |
| `BosunBanner` | A glyph and wrapped text on a tint of its colour, a note in a pane or with `strip` a band across the panel |
| `BosunCodeBox` | Selectable text in a box on a tint: a tool's input and result and a message's fenced code, which break at a space where they can and anywhere else |
| `BosunWhyNote` | Why the master passed a decision on to the user, on a blue card |
| `BosunYouSaid` | The user's words a decision was answered on, as “You said: …” |
| `BosunCard` | A conversation's card: a tinted box with an optional header of a caption and the age, blue with `mine` for the user's own message, `outlined` for one not yet taken, what it holds declared inside it |
| `BosunFact` | A glyph and its words in a header |
| `BosunSpinner` | A running state's spinner |
| `BosunJumpButton` | A round button over a scrolling view's corner that jumps to its newest entry |
| `BosunHints` | Keycaps, each run beside what it does |
| `BosunIconButton` | A square button of one glyph, with a tooltip |
| `BosunBadge` | How many decisions wait, on a yellow pill that grows in, swells as one arrives and shrinks away at 0 |
| `BosunReveal` | A list delegate whose row opens and fades in as it arrives in the model, and closes as it leaves |
| `BosunStateGlyph` | A session state's glyph in its colour, the spinner for working |
| `BosunCount` | A state's glyph, a number and a word, as the titlebar counts the fleet |
| `BosunActivityLine` | What a session does: its tool's glyph and the call in mono, or its last words |
| `BosunDashed` | A dashed yellow outline behind what has yet to be dealt with |

**Harness.** `harness/run.sh` runs the bosun panel offscreen: timed scenarios on fake conversations, and scripts that call IPC on a real panel. A change to the panel's QML is measured there on its worktree, and a new entry kind or desk card **must** join `harness/HarnessData.qml`, or the harness cannot catch what it breaks. `harness/README.md` covers adding a scenario.

**Look.** Meters, sparks and sliders fill in blue, and colour marks state:

| Colour | State |
|---|---|
| Blue | Focus, or something on: a connected Bluetooth device, a VPN up |
| Faint grey | A muted or dimmed meter |
| Yellow, red | Warnings |
| Red | A muted speaker or microphone |
| Green | Charging |

**Greeter.** The greeter's config holds `greeter/` and the files `greeterConfig` copies, nothing else. A bar file the greeter comes to use, directly or through another file, **must** join that list. `ColorScheme.qml` is the exception: `greeter/` has its own, which a copy of the bar's would replace. The build does not catch a missing one, and a rebuild never restarts greetd, so the breakage shows only at the next boot.

**Debugging.** `Monitors.qml`, `Curtain.qml` and `Lock.qml` log to `journalctl --user -u quickshell`, and the greeter to `journalctl -u greetd`.
