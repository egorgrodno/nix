// Command mcp-lazy stands in for a stdio MCP server until a client needs it.
// It answers the requests Claude Code opens a session with from a cache
// recorded from the server, and starts the server on the first request the
// cache cannot answer, such as a tool call, relaying both ways from then on.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"syscall"
)

const usage = `usage:
  mcp-lazy -cache DIR COMMAND [ARG...]   stand in for COMMAND
  mcp-lazy -record COMMAND [ARG...]      print COMMAND's cache

An ARG of ${CLAUDE_PROJECT_DIR} stands for the session's directory: the cache
then fits any existing directory there and puts it in the answers.
`

const projectDir = "${CLAUDE_PROJECT_DIR}"

// Claude Code 2.1.310's opening. A server of the 2026-07-28 protocol answers
// server/discover and takes meta on every request after it; any other gets a
// session from initialize. A client asking for other protocol versions starts
// the server.
const (
	meta        = `{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientInfo":{"name":"claude-code","title":"Claude Code","version":"2.1.310"},"io.modelcontextprotocol/clientCapabilities":{"roots":{"listChanged":true},"elicitation":{"form":{},"url":{}},"extensions":{"io.modelcontextprotocol/tasks":{}}}}`
	discover    = `{"jsonrpc":"2.0","id":"mcp-lazy","method":"server/discover","params":{"_meta":` + meta + `}}` + "\n"
	initialize  = `{"jsonrpc":"2.0","id":"mcp-lazy","method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{"roots":{"listChanged":true},"elicitation":{"form":{},"url":{}},"extensions":{"io.modelcontextprotocol/tasks":{}}},"clientInfo":{"name":"claude-code","title":"Claude Code","version":"2.1.310"}}}` + "\n"
	initialized = `{"jsonrpc":"2.0","method":"notifications/initialized"}` + "\n"
)

// ownID is the id of every request mcp-lazy sends a server itself.
const ownID = `"mcp-lazy"`

// lists names the requests each capability brings at startup.
var lists = map[string][]string{
	"tools":     {"tools/list"},
	"prompts":   {"prompts/list"},
	"resources": {"resources/list", "resources/templates/list"},
}

type cache struct {
	// Command is the server's absolute path, and Args its arguments as given
	// to -record.
	Command string   `json:"command"`
	Args    []string `json:"args"`
	// Dir took the place of ${CLAUDE_PROJECT_DIR} while recording.
	Dir string `json:"dir"`
	// Responses holds the server's answers, without their ids, under key.
	Responses map[string]json.RawMessage `json:"responses"`
}

type message struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

func main() {
	cacheDir := flag.String("cache", "", "the directory holding a cache per command")
	rec := flag.Bool("record", false, "print COMMAND's cache")
	flag.Usage = func() { fmt.Fprint(os.Stderr, usage) }
	flag.Parse()
	args := flag.Args()
	if len(args) == 0 {
		flag.Usage()
		os.Exit(2)
	}
	var err error
	if *rec {
		err = record(args, os.Stdout)
	} else {
		err = stand(*cacheDir, args)
	}
	var exit *exec.ExitError
	if errors.As(err, &exit) {
		os.Exit(exit.ExitCode())
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "mcp-lazy: %v\n", err)
		os.Exit(1)
	}
}

// stand serves the cache for args[0] while it can, or runs args outright when
// no cache fits them.
func stand(cacheDir string, args []string) error {
	c, dir, err := load(cacheDir, args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mcp-lazy: %v; starting %s now\n", err, args[0])
		path, err := exec.LookPath(args[0])
		if err != nil {
			return err
		}
		return syscall.Exec(path, args, os.Environ())
	}
	return serve(c, dir, args[1:], bufio.NewReader(os.Stdin), os.Stdout)
}

// load reads the cache for args[0] from dir and checks args[1:] against the
// recorded ones. It returns the session's directory, resolved as the server
// would, where ${CLAUDE_PROJECT_DIR} stood.
func load(dir string, args []string) (*cache, string, error) {
	if dir == "" {
		return nil, "", errors.New("no -cache")
	}
	b, err := os.ReadFile(filepath.Join(dir, filepath.Base(args[0])+".json"))
	if err != nil {
		return nil, "", err
	}
	var c cache
	if err := json.Unmarshal(b, &c); err != nil {
		return nil, "", err
	}
	other := errors.New("the cache holds other arguments")
	if len(args)-1 != len(c.Args) {
		return nil, "", other
	}
	project := ""
	for i, a := range c.Args {
		arg := args[i+1]
		if a != projectDir {
			if arg != a {
				return nil, "", other
			}
			continue
		}
		d, err := filepath.Abs(arg)
		if err == nil {
			d, err = filepath.EvalSymlinks(d)
		}
		if err != nil {
			return nil, "", err
		}
		if project != "" && d != project {
			return nil, "", other
		}
		project = d
	}
	return &c, project, nil
}

// serve answers the client from c until a message needs the server, then
// hands over to relay.
func serve(c *cache, project string, args []string, in *bufio.Reader, out io.Writer) error {
	var init []byte
	sawInitialized := false
	for {
		line, err := in.ReadBytes('\n')
		if len(line) == 0 && err == io.EOF {
			return nil
		}
		if err != nil && err != io.EOF {
			return err
		}
		var m message
		if json.Unmarshal(line, &m) != nil || m.Method == "" {
			return relay(c, args, init, sawInitialized, line, in, out)
		}
		if m.ID == nil {
			// Dropped, as the server starts from the client's state as it is
			// then; initialized is replayed.
			sawInitialized = sawInitialized || m.Method == "notifications/initialized"
			continue
		}
		resp, ok := c.Responses[key(m.Method, m.Params)]
		if m.Method == "ping" {
			resp, ok = json.RawMessage(`{"jsonrpc":"2.0","result":{}}`), true
		}
		if !ok {
			return relay(c, args, init, sawInitialized, line, in, out)
		}
		if m.Method == "initialize" {
			init = line
		}
		if project != "" {
			resp = bytes.ReplaceAll(resp, jsonString(c.Dir), jsonString(project))
		}
		if _, err := fmt.Fprintf(out, "{\"id\":%s,%s\n", m.ID, resp[1:]); err != nil {
			return err
		}
	}
}

// relay starts the server, replays the client's initialize to it, and from
// first on copies the client's input to it and its output to the client.
func relay(c *cache, args []string, init []byte, sawInitialized bool, first []byte, in io.Reader, out io.Writer) error {
	fmt.Fprintf(os.Stderr, "mcp-lazy: starting %s\n", filepath.Base(c.Command))
	s, err := start(c.Command, args)
	if err != nil {
		return err
	}
	if init != nil {
		// The client had this answer from the cache.
		_, err = s.call(withID(init), out)
		if err == nil && sawInitialized {
			_, err = io.WriteString(s.in, initialized)
		}
		if err != nil {
			return s.finish(err)
		}
	}
	if _, err := s.in.Write(first); err != nil {
		return s.finish(err)
	}
	go func() {
		io.Copy(s.in, in)
		s.in.Close()
	}()
	_, err = io.Copy(out, s.out)
	return s.finish(err)
}

// server is a running server and its pipes.
type server struct {
	cmd *exec.Cmd
	in  io.WriteCloser
	out *bufio.Reader
}

func start(path string, args []string) (*server, error) {
	cmd := exec.Command(path, args...)
	cmd.Stderr = os.Stderr
	in, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	return &server{cmd, in, bufio.NewReader(out)}, cmd.Start()
}

// call sends req, a line, and returns the response with ownID, passing
// whatever else the server says to other.
func (s *server) call(req []byte, other io.Writer) (map[string]json.RawMessage, error) {
	if _, err := s.in.Write(req); err != nil {
		return nil, err
	}
	for {
		line, err := s.out.ReadBytes('\n')
		if err != nil {
			return nil, fmt.Errorf("the server left before answering %s", req)
		}
		var m map[string]json.RawMessage
		if json.Unmarshal(line, &m) == nil && string(m["id"]) == ownID && m["method"] == nil {
			return m, nil
		}
		if _, err := other.Write(line); err != nil {
			return nil, err
		}
	}
}

// finish stops the server's input, waits for it to exit and returns its
// failure before err.
func (s *server) finish(err error) error {
	s.in.Close()
	if werr := s.cmd.Wait(); werr != nil {
		return werr
	}
	return err
}

// record runs args, opens a session with it as Claude Code would, asks for
// every list its capabilities bring, and prints the answers as a cache.
func record(args []string, out io.Writer) error {
	dir := filepath.Join(os.TempDir(), "mcp-lazy-project")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	dir, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return err
	}
	path, err := exec.LookPath(args[0])
	if err == nil {
		path, err = filepath.Abs(path)
	}
	if err != nil {
		return err
	}
	argv := slices.Clone(args[1:])
	for i, a := range argv {
		if a == projectDir {
			argv[i] = dir
		}
	}
	s, err := start(path, argv)
	if err != nil {
		return err
	}
	c := cache{Command: path, Args: args[1:], Dir: dir, Responses: map[string]json.RawMessage{}}
	ask := func(req []byte) (map[string]json.RawMessage, error) {
		resp, err := s.call(req, io.Discard)
		if err != nil {
			return nil, err
		}
		var m message
		json.Unmarshal(req, &m)
		delete(resp, "id")
		c.Responses[key(m.Method, m.Params)] = bytes.TrimSuffix(encode(resp), []byte("\n"))
		return resp, nil
	}

	resp, err := ask([]byte(discover))
	if err != nil {
		return s.finish(err)
	}
	base := map[string]any{}
	if resp["error"] == nil {
		base["_meta"] = json.RawMessage(meta)
	} else {
		if resp, err = ask([]byte(initialize)); err != nil {
			return s.finish(err)
		}
		if resp["error"] != nil {
			return s.finish(fmt.Errorf("initialize: %s", resp["error"]))
		}
		if _, err := io.WriteString(s.in, initialized); err != nil {
			return s.finish(err)
		}
	}
	var result struct{ Capabilities map[string]json.RawMessage }
	json.Unmarshal(resp["result"], &result)
	for capability, methods := range lists {
		if result.Capabilities[capability] == nil {
			continue
		}
		for _, method := range methods {
			req := map[string]any{"jsonrpc": "2.0", "id": "mcp-lazy", "method": method}
			params := maps.Clone(base)
			for {
				if len(params) > 0 {
					req["params"] = params
				}
				resp, err := ask(encode(req))
				if err != nil {
					return s.finish(err)
				}
				var page struct{ NextCursor string }
				json.Unmarshal(resp["result"], &page)
				if page.NextCursor == "" {
					break
				}
				params["cursor"] = page.NextCursor
			}
		}
	}
	if err := s.finish(nil); err != nil {
		return err
	}
	_, err = out.Write(encode(c))
	return err
}

// key names a request in the cache by its method, protocol version and other
// parameters. It leaves out the client's name, version and capabilities, from
// _meta or initialize, as the name and version change with every release.
func key(method string, params json.RawMessage) string {
	var p, m map[string]json.RawMessage
	json.Unmarshal(params, &p)
	json.Unmarshal(p["_meta"], &m)
	version := m["io.modelcontextprotocol/protocolVersion"]
	if method == "initialize" {
		version, p = p["protocolVersion"], nil
	}
	delete(p, "_meta")
	k := method
	var v string
	if json.Unmarshal(version, &v) == nil {
		k += " " + v
	}
	if len(p) > 0 {
		k += " " + strings.TrimSpace(string(encode(p)))
	}
	return k
}

// withID gives a request line, one serve parsed, ownID.
func withID(line []byte) []byte {
	var m map[string]json.RawMessage
	json.Unmarshal(line, &m)
	m["id"] = json.RawMessage(ownID)
	return encode(m)
}

// encode is json.Marshal leaving <, > and & as they are, plus a newline.
func encode(v any) []byte {
	var b bytes.Buffer
	e := json.NewEncoder(&b)
	e.SetEscapeHTML(false)
	if err := e.Encode(v); err != nil {
		panic(err)
	}
	return b.Bytes()
}

// jsonString is s as it appears inside a JSON string.
func jsonString(s string) []byte {
	b := encode(s)
	return b[1 : len(b)-2]
}
