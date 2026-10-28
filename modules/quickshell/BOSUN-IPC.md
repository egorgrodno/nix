# Driving the bosun panel from a script

A visual check, or any script, drives the panel with `quickshell ipc call bosun <function> [argument]` instead of keystrokes, which land in whatever window has the focus. The `IpcHandler` is at the end of `Bosun.qml`, and `BosunPanel.qml` holds the panel's side, passing the full panel's calls on to `BosunView.qml`.

An IPC function returns one string. A function that acts returns `ok`, or `error: <why>` with the exit status still 0, so a script compares the text. `state` and `geometry` return JSON, or `error: <why>` for `geometry`.

**Out of reach.** Nothing here sends a message, interrupts a session, answers a prompt or decision, kills a worker or pauses the fleet. An action of two presses stops after the first (`arm`), and the second is the user's. Do not add a call that finishes one.

**Needs the panel open.** `select`, `focus`, `mode`, `sidebar`, `arm` and `geometry` answer `error: no panel is open` otherwise. `open` returns before the open animation ends: poll `state` for `"entered":true` before a screenshot. Calls reach the open panel on the focused screen, else the newest.

| Call | Does |
|---|---|
| `toggle`, `open`, `close` | Open or close the panel. `open` and `toggle` act on the focused screen's bar |
| `isOpen` | `true` or `false` |
| `select <row>` | Selects a sidebar row, as a click does. From the overview it opens the full panel on the row |
| `focus <place>` | Moves the keyboard: `pane` as Enter does, `list` as Tab from the pane does. In the overview, `list` takes the rows |
| `mode <name>` | `full` or `overview`, as the `f` key switches |
| `sidebar <how>` | `open`, `closed` or `toggle`, as the `[` key toggles. The overview has none |
| `arm <action>` | The first press of `approve`, `deny`, `pause`, `clear` or `kill` |
| `state` | The selection, mode, keyboard and armed action as JSON |
| `geometry` | The box in the compositor's layout, as JSON |

## Examples

```bash
quickshell ipc call bosun open
until quickshell ipc call bosun state | jq -e .entered >/dev/null; do sleep 0.1; done

quickshell ipc call bosun select desk              # the desk
quickshell ipc call bosun select session:forge     # a session, by node name
quickshell ipc call bosun select decision:12       # a waiting decision, by id
quickshell ipc call bosun select log               # the Log, on the entry last selected
quickshell ipc call bosun select log:431           # a Log entry, by seq

quickshell ipc call bosun mode full
quickshell ipc call bosun sidebar closed           # the rail
quickshell ipc call bosun focus pane

quickshell ipc call bosun arm approve              # Approve, armed: needs a second press to act
quickshell ipc call bosun state | jq -e '.armed == "y"'

quickshell ipc call bosun geometry |
  jq -r '"\(.x),\(.y) \(.width)x\(.height)"' |
  xargs -I{} grim -g {} panel.png

quickshell ipc call bosun close
```

## Rows

`select` takes a key from `state.selected`, so a script restores a selection by passing it back. A key must name a row in the sidebar: `desk`, `session:<node>`, `decision:<id>` for a decision waiting on the user, or one of the latest six Log entries as `log:<seq>`. `log` alone opens the Log, and `log:<seq>` also takes any entry the daemon still holds. The desk needs the daemon connected, as the `t` key does.

## Armed actions

`arm` arms what the key would, with the same conditions: `approve` and `deny` for a live permission, `pause` for the fleet, which `pause` also resumes while paused, `clear` for the desk's or the master's conversation, and `kill` for the selected worker. The overview offers only `pause`. A refused one answers `error: <action> is not on offer here`. An armed action disarms after three seconds, or on the next key or selection, and arming again never completes it.

## State

```json
{
  "open": true,
  "selected": "session:forge",
  "mode": "full",
  "sidebarOpen": true,
  "entered": true,
  "kind": "session",
  "focus": "sidebar",
  "armed": ""
}
```

`mode` is `full` or `overview`, and `sidebarOpen` is whether the full panel shows the sidebar rather than its rail. `kind` is the pane: `decision`, `desk`, `session`, `log` or `spawn`, or `overview`. `focus` is `sidebar`, `rail`, `table`, `pane`, `field` for a field of the pane's, `rows` for the overview's rows, or empty. `armed` is `y`, `d`, `p`, `C`, `kill` or empty. With the panel closed, `state` holds only `open`, `selected`, `mode` and `sidebarOpen`, as the panel last left them, which the next open takes.

## Geometry

`geometry` returns the panel's box where it ends up, whatever the animation has reached, in the layout's logical pixels, which `grim -g` takes. `screen` holds the output's name and its origin, to subtract for a crop of one output.

```json
{ "screen": { "name": "eDP-1", "x": 0, "y": 0 }, "x": 8, "y": 57, "width": 1424, "height": 786 }
```
