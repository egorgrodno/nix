pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

// The New worker form, which starts one under the master in a repository
// Claude Code trusts. What was typed stays through Cancel, Escape, closing the
// panel and a failed spawn, and clears once the daemon has started the worker.
BosunPane {
    id: pane

    property string repo: ""
    property string model: ""
    property string effort: ""
    property bool waiting: false
    property bool restored: false
    // Each directory Claude Code trusts that holds a repository.
    property var repos: []
    readonly property bool valid: /^[a-z0-9][a-z0-9-]{0,39}$/.test(nameField.text) && repo !== "" && promptField.text.trim() !== ""

    signal cancelled
    signal started

    function start() {
        if (!valid || waiting)
            return;
        waiting = true;
        Bosun.spawn(nameField.text, repo, promptField.text.trim(), model, effort);
    }

    // To the name, or once it is typed, the task.
    function focusIn() {
        if (nameField.text === "")
            nameField.forceActiveFocus();
        else
            promptField.forceActiveFocus();
        return true;
    }

    // Into BosunKept, once the form has taken what it kept.
    function keepForm() {
        if (!restored)
            return;
        // The repository preselected is no draft.
        const empty = nameField.text === "" && promptField.text === "" && [repos[0] ?? "", ""].includes(repo) && model === "" && effort === "";
        BosunKept.keepDraft("spawn", empty ? null : {
            name: nameField.text,
            repo: repo,
            model: model,
            effort: effort,
            prompt: promptField.text
        });
    }

    onRepoChanged: keepForm()
    onModelChanged: keepForm()
    onEffortChanged: keepForm()
    Component.onCompleted: {
        const kept = BosunKept.draft("spawn") || {};
        nameField.text = kept.name ?? "";
        promptField.text = kept.prompt ?? "";
        repo = kept.repo ?? "";
        model = kept.model ?? "";
        effort = kept.effort ?? "";
        restored = true;
    }

    function findRepos() {
        claudeState.reload();
        let trusted = [];
        try {
            const projects = JSON.parse(claudeState.text()).projects ?? {};
            trusted = Object.keys(projects).filter(p => projects[p].hasTrustDialogAccepted === true);
        } catch (e) {}
        repoFinder.command = [Programs.sh, "-c", "for d; do [ -e \"$d/.git\" ] && printf '%s\\n' \"$d\"; done", "sh", ...trusted];
        repoFinder.running = true;
    }

    title: "New worker"
    facts: [
        BosunFact {
            glyph: BosunLook.account
            text: "Under the master"
        },
        BosunFact {
            glyph: BosunLook.branch
            text: "In a worktree of its own, on a new branch"
        }
    ]

    // Claude Code's own state, which records each directory's trust.
    FileView {
        id: claudeState

        path: `${Quickshell.env("HOME")}/.claude.json`
        blockAllReads: true
        printErrors: false
    }

    Process {
        id: repoFinder

        stdout: StdioCollector {
            onStreamFinished: {
                pane.repos = text.split("\n").filter(p => p !== "").sort();
                // The first, unless the draft holds one still trusted.
                if (!pane.repos.includes(pane.repo))
                    pane.repo = pane.repos[0] ?? "";
            }
        }
    }

    Connections {
        target: Bosun

        function onFinished(args, ok) {
            if (args[0] !== "spawn" || !pane.waiting)
                return;
            pane.waiting = false;
            if (!ok)
                return;
            nameField.text = "";
            promptField.text = "";
            pane.repo = pane.repos[0] ?? "";
            pane.model = "";
            pane.effort = "";
            pane.started();
        }
    }

    Field {
        label: "Name"
        hint: "Lowercase letters, digits and hyphens"

        TextField {
            id: nameField

            width: Math.min(parent.width, 420)
            height: 34
            leftPadding: 10
            rightPadding: 10
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.foregroundStrong
            selectionColor: Theme.blue
            selectedTextColor: Theme.backgroundMain
            font.family: Theme.fontUI
            font.pixelSize: 14
            onTextChanged: pane.keepForm()
            onAccepted: promptField.forceActiveFocus()
            Keys.onTabPressed: promptField.forceActiveFocus()
            Keys.onEscapePressed: pane.cancelled()

            background: Rectangle {
                radius: Theme.radius - 4
                color: Theme.tint(0.06)
                border.width: 1
                border.color: nameField.activeFocus ? Theme.blue : Theme.tint(0.12)
            }
        }
    }

    Field {
        label: "Repository"
        hint: pane.repos.length > 0 ? "Every repository Claude Code trusts" : "Claude Code trusts no repository: run claude in one first"

        Choices {
            model: pane.repos
            current: pane.repo
            glyph: BosunLook.folder
            paths: true
            onPicked: value => pane.repo = value
        }
    }

    Field {
        label: "Model"

        Choices {
            model: [""].concat(Bosun.models)
            current: pane.model
            onPicked: value => pane.model = value
        }
    }

    Field {
        label: "Effort"

        Choices {
            model: [""].concat(Bosun.efforts)
            current: pane.effort
            onPicked: value => pane.effort = value
        }
    }

    Field {
        label: "Its task"

        TextArea {
            id: promptField

            width: parent.width
            height: Math.max(200, implicitHeight)
            padding: 12
            wrapMode: TextEdit.Wrap
            color: Theme.foregroundStrong
            selectionColor: Theme.blue
            selectedTextColor: Theme.backgroundMain
            font.family: Theme.fontUI
            font.pixelSize: 14
            onTextChanged: pane.keepForm()
            Keys.onTabPressed: nameField.forceActiveFocus()
            Keys.onEscapePressed: pane.cancelled()
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.modifiers & Qt.ControlModifier) {
                    pane.start();
                    event.accepted = true;
                }
            }

            background: Rectangle {
                radius: Theme.radius - 4
                color: Theme.tint(0.06)
                border.width: 1
                border.color: promptField.activeFocus ? Theme.blue : Theme.tint(0.12)
            }
        }
    }

    foot: [
        Item {
            width: parent.width
            height: startButton.height

            BosunHints {
                anchors.verticalCenter: parent.verticalCenter
                model: [
                    {
                        keys: ["Ctrl", "Enter"],
                        text: "start"
                    },
                    {
                        keys: ["Esc"],
                        text: "cancel, keeping what you typed"
                    }
                ]
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                TextButton {
                    height: 34
                    text: "Cancel"
                    onClicked: pane.cancelled()
                }

                TextButton {
                    id: startButton

                    height: 34
                    enabled: pane.valid && !pane.waiting
                    text: pane.waiting ? `${BosunLook.play}  Starting…` : `${BosunLook.play}  Start`
                    hoverFill: Theme.alpha(Theme.blue, 0.5)
                    onClicked: pane.start()
                }
            }
        }
    ]

    // A label, what goes under it, and a hint below.
    component Field: Column {
        id: field

        property string label
        property string hint
        default property alias content: slot.data

        width: parent?.width ?? 0
        spacing: 6

        Caption {
            text: field.label
        }

        Item {
            id: slot

            width: parent.width
            height: childrenRect.height
        }

        Caption {
            visible: field.hint !== ""
            text: field.hint
            font.pixelSize: 12
        }
    }

    // One button per value, the current one lit; "" is the default.
    component Choices: Flow {
        id: choices

        property var model: []
        property string current
        property string glyph
        // Values are paths, shown from ~.
        property bool paths: false

        signal picked(string value)

        width: parent?.width ?? 0
        spacing: 6

        Repeater {
            model: choices.model

            TextButton {
                required property string modelData

                height: 30
                text: {
                    const words = modelData === "" ? "Default" : choices.paths ? BosunLook.tilde(modelData) : modelData;
                    return choices.glyph ? `${choices.glyph}  ${words}` : words;
                }
                lit: modelData === choices.current
                hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                onClicked: choices.picked(modelData)
            }
        }
    }
}
