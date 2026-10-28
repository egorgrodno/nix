import QtQuick

// The fleet and the conversations the harness feeds the bosun panel, in the
// shapes `bosun watch` and `bosun follow` send. Every entry kind the panel
// draws is here, the desk's cards included: a harness without one has missed
// the freeze that kind caused (egor/nix#143).
QtObject {
    id: data

    // Each entry's time: `n - i` minutes before now.
    function at(i, n) {
        return new Date(Date.now() - (n - i) * 60000).toISOString();
    }

    function reply(i) {
        const para = `Paragraph ${i}: the quick brown fox jumps over the lazy dog, then reads \`inline code\` and a [link](http://example.com) while the **bold** and *italic* runs carry on across the wrapped line so that it wraps at least twice in a narrow panel.`;
        const code = Array.from({
            length: 24
        }, (_, k) => `    const value${k} = compute(${k}, "argument ${k}", { flag: ${k % 2 === 0} });`).join("\n");
        const table = "| Name | Kind | Size | Note |\n|---|---|---|---|\n" + Array.from({
            length: 8
        }, (_, k) => `| item-${k} | kind ${k % 3} | ${k * 12} KiB | a note that is long enough to wrap in its cell ${k} |`).join("\n");
        const bullets = Array.from({
            length: 6
        }, (_, k) => `- bullet ${k} with \`code\` and some words`).join("\n");
        return [para, para, "```js\n" + code + "\n```", para, bullets, table, para, para].join("\n\n");
    }

    function diffLines(count) {
        const out = [];
        for (let k = 0; k < count; k++)
            out.push((k % 7 === 3 ? "-" : k % 5 === 1 ? "+" : " ") + `    line ${k}: let result_${k} = transform(input_${k}, options) // a comment that runs long enough to wrap in the panel sometimes`);
        return out;
    }

    function lines(count) {
        return Array.from({
            length: count
        }, (_, k) => `-rw-r--r-- 1 user user ${k * 100} Oct 27 12:00 file_${k}.txt`).join("\n");
    }

    // A session's entries, `n` of them, cycling through every kind a
    // session's conversation holds.
    function session(n) {
        const out = [];
        for (let i = 0; i < n; i++) {
            const base = {
                id: `e${i}`,
                at: at(i, n)
            };
            const merge = o => out.push(Object.assign(base, o));
            switch (i % 15) {
            case 0:
                merge({
                    kind: "prompt",
                    from: "user",
                    text: `Please look at item ${i} and tell me what you find, including details.`
                });
                break;
            case 1:
            case 4:
            case 10:
                merge({
                    kind: "text",
                    text: reply(i)
                });
                break;
            case 2:
                merge({
                    kind: "tool",
                    name: "Edit",
                    input: {
                        file_path: "/x/y.ts"
                    },
                    result: {
                        text: "ok",
                        diff: [
                            {
                                lines: diffLines(120)
                            },
                            {
                                lines: diffLines(80)
                            }
                        ]
                    }
                });
                break;
            case 3:
                merge({
                    kind: "tool",
                    name: "Bash",
                    input: {
                        command: "ls -la"
                    },
                    result: {
                        text: lines(40)
                    }
                });
                break;
            case 5:
                merge({
                    kind: "thinking"
                });
                break;
            case 6:
                merge({
                    kind: "prompt",
                    from: "master",
                    midTurn: true,
                    text: "Also check the **second** host before you report."
                });
                break;
            case 7:
                merge({
                    kind: "tool",
                    name: "Read",
                    input: {
                        file_path: "/x/missing.ts"
                    },
                    result: {
                        error: true,
                        text: "File does not exist.\nTried /x/missing.ts"
                    }
                });
                break;
            case 8:
                merge({
                    kind: "task",
                    status: i % 2 ? "completed" : "failed",
                    summary: `Background task ${i}`,
                    text: "Output of the task.\nSecond line."
                });
                break;
            case 9:
                merge({
                    kind: "compact",
                    summary: "The conversation so far: " + "a long summary sentence. ".repeat(20)
                });
                break;
            case 11:
                merge({
                    kind: "command",
                    name: "/model",
                    args: "opus",
                    output: "Set model to opus."
                });
                break;
            case 12:
                merge({
                    kind: "cleared"
                });
                break;
            case 13:
                merge({
                    kind: "meta",
                    recordType: "attachment/hook_success",
                    raw: {
                        attachment: {
                            hookEvent: "Stop"
                        }
                    }
                });
                break;
            default:
                // A kind the panel does not know, which shows as raw.
                merge({
                    kind: "future-kind",
                    raw: {
                        any: "thing",
                        n: i
                    }
                });
            }
        }
        // A call with no result yet, and a message waiting for its turn.
        out.push({
            id: "running",
            kind: "tool",
            name: "Bash",
            input: {
                command: "sleep 60"
            },
            at: new Date().toISOString()
        });
        out.push({
            id: "queued",
            kind: "queued",
            text: "A message queued for the turn.",
            at: new Date().toISOString()
        });
        return out;
    }

    readonly property string userHead: "bosun: the user sent this through bosun tell, so they may not be watching this session:\n"
    readonly property string masterHead: "bosun: the master answers:\n"

    // The front desk's entries, `n` of them, as the daemon sends them: the
    // panel's BosunDesk.shape turns them into the desk-* kinds.
    function desk(n) {
        const out = [];
        for (let i = 0; i < n; i++) {
            const base = {
                id: `d${i}`,
                at: at(i, n)
            };
            const merge = o => out.push(Object.assign(base, o));
            switch (i % 9) {
            case 0:
                merge({
                    kind: "prompt",
                    from: "user",
                    text: `What is ${i % 7 === 0 ? "select-lag" : "panel-ipc"} doing, and does decision 7 wait on me?`
                });
                break;
            case 1:
                merge({
                    kind: "text",
                    text: `select-lag is measuring the scroll. **Decision 7** waits on you.\n\n${reply(i)}`
                });
                break;
            case 2:
                merge({
                    kind: "tool",
                    name: "mcp__bosun__tell_master",
                    input: {
                        text: `Instruction ${i}: spawn panel-ipc for egor/nix#88.`
                    },
                    result: {
                        text: "queued"
                    }
                });
                break;
            case 3:
                merge({
                    kind: "tool",
                    name: "mcp__bosun__tell_master",
                    input: {
                        text: `Instruction ${i}: merge select-lag.`
                    },
                    result: {
                        error: true,
                        text: "the master is not running"
                    }
                });
                break;
            case 4:
                merge({
                    kind: "prompt",
                    from: "bosun",
                    text: `${userHead}Use the lighter model.\n\n${masterHead}The master spawned panel-ipc.`
                });
                break;
            case 5:
                merge({
                    kind: "tool",
                    name: "mcp__bosun__answer",
                    input: {
                        id: "7",
                        allow: true,
                        words: "yes, go ahead"
                    },
                    result: {
                        text: "answered"
                    }
                });
                break;
            case 6:
                merge({
                    kind: "tool",
                    name: "ToolSearch",
                    input: {
                        query: "select:Bash"
                    },
                    result: {
                        text: "ok"
                    }
                });
                break;
            case 7:
                merge({
                    kind: "tool",
                    name: "Bash",
                    input: {
                        command: "ls -la"
                    },
                    result: {
                        text: lines(30)
                    }
                });
                break;
            default:
                merge({
                    kind: "thinking"
                });
            }
        }
        return out;
    }

    // `bosun status`'s sessions.
    readonly property var sessions: [
        {
            node: "master",
            status: "idle"
        },
        {
            node: "desk",
            status: "idle"
        },
        {
            node: "select-lag",
            id: "abc",
            status: "busy",
            parent: "master"
        },
        {
            node: "panel-ipc",
            status: "waiting",
            parent: "master"
        }
    ]

    // Decision 7 carries the master's note and what reserved it, and a command
    // long enough to wrap, with a path that cannot break at a space.
    readonly property var decisions: [
        {
            id: "7",
            holder: "user",
            node: "select-lag",
            kind: "permission",
            tool: "Bash",
            note: "It runs the suite the worker already ran once. Nothing in it writes outside the worktree, so approve it unless you want the run held back.",
            reserved: "a command that runs the project's own test suite",
            refused: "make test, as it also runs the slow integration tests",
            input: {
                command: "make test ARGS='--race --count=1 --timeout=10m ./modules/quickshell/harness/scenarios/very/long/path/that/does/not/break/anywhere/at/all/file.go' && echo done"
            }
        }
    ]

    readonly property var answered: [
        {
            decision: decisions[0],
            behavior: "allow",
            words: "yes, go ahead"
        }
    ]

    // What the desk's instruction cards read their outcomes from: each tell
    // to the master, then what the master did before the desk's next one.
    // The tells' texts must equal the ones in `desk`.
    function log(n) {
        const out = [];
        let seq = 1;
        const put = (kind, by, node, extra) => out.push(Object.assign({
                seq: seq++,
                at: new Date().toISOString(),
                kind,
                by,
                node
            }, extra));
        // The two instructions of each round overlap: the second is told before
        // the master acts on the first, and its act lands first. Each entry
        // carries its instruction's number, which links it to its tell.
        let number = 1;
        for (let i = 2; i < n; i += 9, number += 2) {
            put("tell", "desk", "master", {
                text: `Instruction ${i}: spawn panel-ipc for egor/nix#88.`,
                instruction: number
            });
            put("tell", "desk", "master", {
                text: `Instruction ${i + 1}: merge select-lag.`,
                instruction: number + 1
            });
            put("merged", "master", "select-lag", {
                instruction: number + 1
            });
            put("spawned", "master", "panel-ipc", {
                instruction: number
            });
            put("tell", "master", "desk", {
                text: "Spawned panel-ipc.",
                instruction: number
            });
        }
        // A decision's life, as the Log keeps it, with the routing fields the
        // daemon logs.
        const routing = {
            rule: "unboxed.write",
            match: "./modules/quickshell/harness",
            route: "escalated"
        };
        put("decision", "worker", "select-lag", Object.assign({
            decision: decisions[0]
        }, routing));
        put("escalated", "master", "select-lag", Object.assign({
            decision: decisions[0],
            text: decisions[0].note
        }, routing));
        put("settled", "desk", "select-lag", Object.assign({
            decision: decisions[0],
            behavior: "allow",
            words: "yes, go ahead",
            waited: 252.4
        }, routing));
        put("allowed", "bosun", "select-lag", {
            decision: decisions[0],
            behavior: "allow"
        });
        // The rest of the kinds the daemon logs, one of each.
        const grant = {
            id: "g3",
            class: "git-write",
            since: new Date().toISOString(),
            until: new Date(Date.now() + 2 * 3600000).toISOString(),
            by: "user"
        };
        put("parked", "bosun", "select-lag", {
            from: "master",
            decision: decisions[0],
            text: "the master escalated it: " + decisions[0].note
        });
        put("stalled", "bosun", "select-lag", {
            text: "select-lag's decision 7 has waited on the user for 12m. It waits for permission to run make test."
        });
        put("away", "user", "", {
            text: "I am at lunch until two"
        });
        put("back", "user", "", {
            text: "Away mode is off. bosun parked 1 decision while you were away: 7, select-lag's Bash."
        });
        put("granted", "user", "", {
            grant,
            text: "yes, let it push to its own branches for two hours"
        });
        put("revoked", "user", "", {
            grant,
            text: "that is enough"
        });
        put("expired", "bosun", "", {
            grant
        });
        put("sleeplock", "bosun", "", {
            text: "took the sleep lock: 2 sessions work"
        });
        put("sleeplock", "bosun", "", {
            text: "could not hold the sleep lock",
            error: "the inhibit call was refused"
        });
        put("message", "session", "panel-ipc", {
            from: "select-lag",
            text: "The harness is ready for you to test."
        });
        put("resumed", "master", "panel-ipc", {
            text: "Continue with the Log page."
        });
        put("killed", "user", "panel-ipc");
        put("paused", "user", "");
        put("unpaused", "user", "", {
            text: "select-lag resumed"
        });
        put("model", "user", "master", {
            model: "opus",
            effort: "high"
        });
        put("turn_end", "worker", "select-lag", {
            text: "Done: the table scrolls."
        });
        put("exit", "worker", "panel-ipc", {
            text: "the session ended in its turn"
        });
        put("say", "user", "select-lag", {
            text: "also run the linter",
            via: "supervisor"
        });
        put("interrupt", "user", "select-lag", {
            via: "supervisor"
        });
        put("compact", "user", "master", {
            via: "supervisor"
        });
        put("clear", "user", "desk", {
            via: "resume"
        });
        put("prompt", "user", "select-lag", {
            behavior: "deny",
            text: "use the Makefile instead"
        });
        // A tell the desk has not taken, which shows as pending.
        put("tell", "user", "desk", {
            text: "A message the desk has not read yet."
        });
        return out.slice(-200);
    }
}
