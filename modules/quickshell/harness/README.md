# Quickshell harness

Measures and drives the bosun panel offscreen, with no display and no daemon. It is not deployed: `default.nix` links only `*.qml` files directly in `modules/quickshell/`.

```bash
modules/quickshell/harness/run.sh                 # every scenario, both panes
modules/quickshell/harness/run.sh idle scroll     # some of them
modules/quickshell/harness/run.sh -v HEAD~3 scroll   # the QML of a revision instead of the worktree's
```

Run it from a worktree: it takes that worktree's QML and resolves weston, labwc, Quickshell and the generated `Theme.qml`, `Programs.qml`, `Host.qml` and `symbols.json` through its flake. `-w DIR` names another worktree; `run.sh -h` lists the other options. The generated files come from the worktree even for another revision's QML.

It prints one line per scenario and pane, in milliseconds per step:

```text
session scroll           frames=150 mean=114.5 med=118.0 p95=163.0 max=188.0 ms items=6210 texts=302
```

`items` and `texts` count the live Qt Quick items and the selectable texts, which shows a leak. A warning in the run's log prints as a count and its first line, and the scratch directory, with every log, is kept. Only the processes `run.sh` started are signalled, by PID, and they run in a runtime directory of their own, so the live bar is never reached.

## How it measures

Quickshell runs under `weston --backend=headless --renderer=pixman` with `QT_QPA_PLATFORM=wayland LIBGL_ALWAYS_SOFTWARE=1`. `QT_QPA_PLATFORM=offscreen` falls back to the software scene graph, which draws no CurveRendering text. Offscreen frames cap at 60 Hz, so each step ends in a synchronous `grabToImage`, whose callback comes after polish, sync and render. Times are relative to each other: compare a variant with `WORK` on one machine, not with the live bar.

`HarnessData.qml` feeds the panel through `Bosun.receive` and the feed's `receive`, as the daemon's streams would. The session pane holds every entry kind a conversation has, and the desk pane every card `BosunDesk.shape` makes, with the fleet log, a decision and a waiting message behind them. A kind the data lacks is a kind the harness cannot test: add it there when the panel gains one.

## Adding a scenario

A scenario is a file `scenarios/<name>.qml`, run with `run.sh <name>`. It is a `QtObject` with optional `frames`, `setup(h)`, `step(h, f)` and `finish(h)`:

```qml
import QtQuick

// One line saying what it does.
QtObject {
    property int frames: 60

    function setup(h) {
        h.show(0);
    }

    function step(h, f) {
        // Return false when there is nothing to act on, which prints "skipped".
        h.list.contentY += 10;
    }
}
```

`h` is `shell.qml`'s window: `conv` and `list` for the conversation and its `ListView`, `show(i)` to scroll to a row, `rowIndex(pred)` to find one, `find(pred)` and `inView(item)` for items, `note(text)` and `snap(name)` for a line or a PNG (`-o DIR`). `scenarios/select-reply.qml` shows a mouse drag through `press` and `drag`; `snap.qml` writes PNGs, which compare looks without the live screen. The shell runs a scenario once per pane, and one that fits a single pane returns false from `step` on the other.

## Driving a live panel

A script `ipc/<name>.sh` runs against a real bar module: `panel.qml` opens the Agents pill in a `PanelWindow` on labwc, with the same fake daemon data, and the script calls `quickshell ipc`. `run.sh` sets `QS` and `QS_CONFIG`; `ipc/toggle.sh` shows the calls. The script prints what it found and exits non-zero to fail. With no Hyprland there is no focused monitor, so the scratch copy of `Agents.qml` has its screen test replaced by `true`.
