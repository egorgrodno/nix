package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"
)

// The test binary is the fake server when FAKE_SERVER names a file to mark
// its start in.
func TestMain(m *testing.M) {
	if mark := os.Getenv("FAKE_SERVER"); mark != "" {
		os.WriteFile(mark, nil, 0o644)
		fakeServer(os.Args[1:], os.Getenv("FAKE_STATELESS") != "")
		os.Exit(0)
	}
	os.Exit(m.Run())
}

// fakeServer answers like a craft CLI: tools in two pages, resources without
// templates, and its arguments in its instructions. Stateless, it answers
// server/discover and refuses a request without _meta; otherwise it refuses
// server/discover, a request before initialize, and a tool call before
// initialized.
func fakeServer(args []string, stateless bool) {
	in := bufio.NewReader(os.Stdin)
	out := json.NewEncoder(os.Stdout)
	state := "new"
	capabilities := map[string]any{"tools": map[string]any{}, "resources": map[string]any{}}
	instructions := "Run as " + strings.Join(args, " ") + "."
	for {
		line, err := in.ReadBytes('\n')
		if err != nil {
			return
		}
		var m message
		json.Unmarshal(line, &m)
		var p struct {
			Cursor    string
			Name      string
			Arguments json.RawMessage
			Meta      map[string]json.RawMessage `json:"_meta"`
		}
		json.Unmarshal(m.Params, &p)
		result := any(nil)
		failure := ""
		switch {
		case m.Method == "notifications/initialized":
			state = "ready"
			continue
		case m.ID == nil:
			continue
		case m.Method == "ping":
			result = map[string]any{}
		case m.Method == "server/discover" && !stateless:
			failure = "method not found"
		case m.Method == "server/discover":
			result = map[string]any{"supportedVersions": []string{"2026-07-28"}, "capabilities": capabilities, "instructions": instructions}
		case stateless && p.Meta["io.modelcontextprotocol/protocolVersion"] == nil:
			failure = "request _meta is missing"
		case !stateless && state == "new" && m.Method != "initialize":
			fmt.Fprintf(os.Stderr, "%s before initialize\n", m.Method)
			os.Exit(3)
		case m.Method == "initialize":
			state = "initialized"
			result = map[string]any{
				"protocolVersion": "2025-06-18",
				"capabilities":    capabilities,
				"serverInfo":      map[string]any{"name": "fake", "version": "1"},
				"instructions":    instructions,
			}
		case m.Method == "tools/list" && p.Cursor == "":
			result = map[string]any{"tools": []any{map[string]any{"name": "echo"}}, "nextCursor": "2"}
		case m.Method == "tools/list" && p.Cursor == "2":
			result = map[string]any{"tools": []any{map[string]any{"name": "pid"}}}
		case m.Method == "resources/list":
			result = map[string]any{"resources": []any{}}
		case m.Method == "tools/call" && !stateless && state != "ready":
			fmt.Fprintf(os.Stderr, "tools/call before initialized\n")
			os.Exit(3)
		case m.Method == "tools/call" && p.Name == "echo":
			result = map[string]any{"content": []any{map[string]any{"type": "text", "text": string(p.Arguments)}}}
		default:
			failure = "method not found"
		}
		resp := map[string]any{"jsonrpc": "2.0", "id": m.ID}
		if failure != "" {
			resp["error"] = map[string]any{"code": -32601, "message": failure}
		} else {
			resp["result"] = result
		}
		out.Encode(resp)
	}
}

type fixture struct {
	t     *testing.T
	mark  string
	cache string
}

// newFixture records the fake server's cache, with args, into a cache
// directory, and forgets that the recording started it.
func newFixture(t *testing.T, stateless bool, args ...string) *fixture {
	dir := t.TempDir()
	f := &fixture{t, filepath.Join(dir, "started"), filepath.Join(dir, "cache")}
	t.Setenv("FAKE_SERVER", f.mark)
	t.Setenv("FAKE_STATELESS", map[bool]string{true: "1"}[stateless])
	if err := os.Mkdir(f.cache, 0o755); err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	if err := record(append([]string{os.Args[0]}, args...), &out); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(f.cache, filepath.Base(os.Args[0])+".json"), out.Bytes(), 0o644); err != nil {
		t.Fatal(err)
	}
	os.Remove(f.mark)
	return f
}

// run sends the client's lines to a stand-in started with args and returns
// its answers by id.
func (f *fixture) run(args []string, lines ...string) map[string]string {
	f.t.Helper()
	c, project, err := load(f.cache, append([]string{os.Args[0]}, args...))
	if err != nil {
		f.t.Fatal(err)
	}
	var out bytes.Buffer
	in := bufio.NewReader(strings.NewReader(strings.Join(lines, "\n") + "\n"))
	if err := serve(c, project, args, in, &out); err != nil {
		f.t.Fatal(err)
	}
	return answers(f.t, out.Bytes())
}

// direct sends the client's lines to the fake server itself.
func (f *fixture) direct(args []string, lines ...string) map[string]string {
	f.t.Helper()
	c := &cache{Command: os.Args[0]}
	var out bytes.Buffer
	in := bufio.NewReader(strings.NewReader(strings.Join(lines, "\n") + "\n"))
	if err := relay(c, args, nil, false, nil, in, &out); err != nil {
		f.t.Fatal(err)
	}
	return answers(f.t, out.Bytes())
}

func (f *fixture) started() bool {
	_, err := os.Stat(f.mark)
	return err == nil
}

// answers parses a stream of responses, keyed by id and compacted.
func answers(t *testing.T, out []byte) map[string]string {
	t.Helper()
	got := map[string]string{}
	for line := range strings.Lines(string(out)) {
		var m map[string]json.RawMessage
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("%v: %q", err, line)
		}
		id := string(m["id"])
		if _, ok := got[id]; ok {
			t.Fatalf("two answers to %s", id)
		}
		delete(m, "id")
		b, _ := json.Marshal(m)
		got[id] = string(b)
	}
	return got
}

// request is a request line as Claude Code numbers and dresses it.
func request(stateless bool, id int, method, params string) string {
	if stateless {
		params = strings.TrimPrefix(params+`,"_meta":`+meta, ",")
	}
	if params == "" {
		return fmt.Sprintf(`{"jsonrpc":"2.0","id":%d,"method":%q}`, id, method)
	}
	return fmt.Sprintf(`{"jsonrpc":"2.0","id":%d,"method":%q,"params":{%s}}`, id, method, params)
}

// opening is what Claude Code opens with, and some more it may send before a
// tool call.
func opening(stateless bool) []string {
	lines := []string{strings.Replace(strings.TrimSuffix(discover, "\n"), `"mcp-lazy"`, `"server-discover-probe-1"`, 1)}
	if !stateless {
		lines = append(lines,
			strings.Replace(strings.TrimSuffix(initialize, "\n"), `"mcp-lazy"`, `0`, 1),
			strings.TrimSuffix(initialized, "\n"),
		)
	}
	return append(lines,
		request(stateless, 1, "tools/list", ""),
		request(stateless, 2, "tools/list", `"cursor":"2"`),
		request(stateless, 3, "resources/list", ""),
		request(stateless, 4, "resources/templates/list", ""),
		request(false, 5, "ping", ""),
		`{"jsonrpc":"2.0","method":"notifications/roots/list_changed"}`,
	)
}

func both(t *testing.T, test func(t *testing.T, stateless bool)) {
	t.Run("session", func(t *testing.T) { test(t, false) })
	t.Run("stateless", func(t *testing.T) { test(t, true) })
}

func TestOpeningFromCache(t *testing.T) {
	both(t, func(t *testing.T, stateless bool) {
		f := newFixture(t, stateless, "--flag")
		args := []string{"--flag"}
		got := f.run(args, opening(stateless)...)
		if f.started() {
			t.Fatal("the opening started the server")
		}
		if want := f.direct(args, opening(stateless)...); !reflect.DeepEqual(got, want) {
			t.Fatalf("got  %v\nwant %v", got, want)
		}
	})
}

func TestToolCallStartsServer(t *testing.T) {
	both(t, func(t *testing.T, stateless bool) {
		f := newFixture(t, stateless, "--flag")
		args := []string{"--flag"}
		lines := append(opening(stateless),
			request(stateless, 6, "tools/call", `"name":"echo","arguments":{"text":"hi"}`),
			request(stateless, 7, "tools/list", ""),
		)
		got := f.run(args, lines...)
		if !f.started() {
			t.Fatal("the tool call did not start the server")
		}
		if want := f.direct(args, lines...); !reflect.DeepEqual(got, want) {
			t.Fatalf("got  %v\nwant %v", got, want)
		}
		if !strings.Contains(got["6"], `{\"text\":\"hi\"}`) {
			t.Fatalf("the tool call answered %s", got["6"])
		}
	})
}

func TestOtherProtocolStartsServer(t *testing.T) {
	f := newFixture(t, false)
	init := strings.Replace(opening(false)[1], "2025-11-25", "2025-06-18", 1)
	got := f.run(nil, init, request(false, 1, "tools/list", ""))
	if !f.started() {
		t.Fatal("an unknown protocol version did not start the server")
	}
	if len(got) != 2 || !strings.Contains(got["0"], `"protocolVersion":"2025-06-18"`) {
		t.Fatalf("got %v", got)
	}
}

func TestProjectDir(t *testing.T) {
	f := newFixture(t, false, "--root", projectDir, "--write", projectDir)
	project := t.TempDir()
	link := filepath.Join(t.TempDir(), "link")
	if err := os.Symlink(project, link); err != nil {
		t.Fatal(err)
	}
	real, err := filepath.EvalSymlinks(project)
	if err != nil {
		t.Fatal(err)
	}
	args := []string{"--root", link, "--write", link}
	got := f.run(args, opening(false)[1])
	if f.started() {
		t.Fatal("initialize started the server")
	}
	if want := fmt.Sprintf("Run as --root %s --write %s.", real, real); !strings.Contains(got["0"], want) {
		t.Fatalf("got %s, want %q in it", got["0"], want)
	}
}

func TestLoadRefusesOtherArguments(t *testing.T) {
	f := newFixture(t, false, "--root", projectDir, "--write", projectDir)
	a, b := t.TempDir(), t.TempDir()
	for _, args := range [][]string{
		{"--root", a},
		{"--root", a, "--write", b},
		{"--root", a, "--read", a},
		{"--root", filepath.Join(a, "missing"), "--write", filepath.Join(a, "missing")},
	} {
		if _, _, err := load(f.cache, append([]string{os.Args[0]}, args...)); err == nil {
			t.Errorf("load took %v", args)
		}
	}
	if _, _, err := load(f.cache, []string{"other-cli"}); err == nil {
		t.Error("load took a command without a cache")
	}
}

func TestRecordedKeys(t *testing.T) {
	for stateless, want := range map[bool][]string{
		false: {
			"initialize 2025-11-25",
			"resources/list",
			"resources/templates/list",
			"server/discover 2026-07-28",
			"tools/list",
			`tools/list {"cursor":"2"}`,
		},
		true: {
			"resources/list 2026-07-28",
			"resources/templates/list 2026-07-28",
			"server/discover 2026-07-28",
			"tools/list 2026-07-28",
			`tools/list 2026-07-28 {"cursor":"2"}`,
		},
	} {
		f := newFixture(t, stateless)
		b, err := os.ReadFile(filepath.Join(f.cache, filepath.Base(os.Args[0])+".json"))
		if err != nil {
			t.Fatal(err)
		}
		var c cache
		if err := json.Unmarshal(b, &c); err != nil {
			t.Fatal(err)
		}
		keys := slices.Sorted(maps.Keys(c.Responses))
		if !slices.Equal(keys, want) {
			t.Errorf("stateless %v: got %q, want %q", stateless, keys, want)
		}
	}
}
