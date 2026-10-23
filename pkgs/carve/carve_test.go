package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"testing"
)

func TestMain(m *testing.M) {
	home, err := os.MkdirTemp("", "carve-home-")
	if err != nil {
		panic(err)
	}
	// No user or system git config, and a fixed identity and clock.
	for k, v := range map[string]string{
		"HOME":                home,
		"XDG_CONFIG_HOME":     home,
		"GIT_CONFIG_NOSYSTEM": "1",
		"GIT_AUTHOR_NAME":     "t",
		"GIT_AUTHOR_EMAIL":    "t@t",
		"GIT_COMMITTER_NAME":  "t",
		"GIT_COMMITTER_EMAIL": "t@t",
		"GIT_AUTHOR_DATE":     "2026-01-01T00:00:00Z",
		"GIT_COMMITTER_DATE":  "2026-01-01T00:00:00Z",
	} {
		os.Setenv(k, v)
	}
	code := m.Run()
	os.RemoveAll(home)
	os.Exit(code)
}

type fixture struct {
	t   *testing.T
	dir string
}

// newRepo makes a repository whose first commit holds files.
func newRepo(t *testing.T, files map[string]string) *fixture {
	f := &fixture{t, t.TempDir()}
	f.git("init", "-q", "-b", "main")
	for path, content := range files {
		f.write(path, content)
	}
	f.git("add", "-A")
	f.git("commit", "-qm", "base")
	return f
}

func (f *fixture) git(args ...string) string {
	f.t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = f.dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		f.t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
	}
	return string(out)
}

func (f *fixture) write(path, content string) {
	f.t.Helper()
	full := filepath.Join(f.dir, path)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		f.t.Fatal(err)
	}
	if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fixture) hook(script string) {
	f.t.Helper()
	f.write(".git/hooks/pre-commit", "#!/bin/sh\n"+script+"\n")
	if err := os.Chmod(filepath.Join(f.dir, ".git/hooks/pre-commit"), 0o755); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fixture) carve(stdin string, args ...string) (string, error) {
	var out bytes.Buffer
	err := run(args, f.dir, strings.NewReader(stdin), &out)
	return out.String(), err
}

func (f *fixture) mustCarve(stdin string, args ...string) string {
	f.t.Helper()
	out, err := f.carve(stdin, args...)
	if err != nil {
		f.t.Fatalf("carve %s: %v\n%s", strings.Join(args, " "), err, out)
	}
	return out
}

// failCarve runs a carve that must fail, and checks it left HEAD alone.
func (f *fixture) failCarve(stdin string, args ...string) string {
	f.t.Helper()
	head := f.head()
	out, err := f.carve(stdin, args...)
	if err == nil {
		f.t.Fatalf("carve %s succeeded:\n%s", strings.Join(args, " "), out)
	}
	if f.head() != head {
		f.t.Errorf("a failed carve moved HEAD")
	}
	if worktrees := f.git("worktree", "list"); strings.Count(worktrees, "\n") != 1 {
		f.t.Errorf("a failed carve left a worktree:\n%s", worktrees)
	}
	return err.Error()
}

// id is the ID of the item in path whose lines hold text, or whose kind is text.
func (f *fixture) id(path, text string) string {
	f.t.Helper()
	r, err := open(f.dir)
	if err != nil {
		f.t.Fatal(err)
	}
	changes, err := r.collect()
	if err != nil {
		f.t.Fatal(err)
	}
	name(changes)
	for _, c := range changes {
		for _, it := range c.Items() {
			lines := bytes.Join(slices.Concat(it.Old, it.New), nil)
			if c.Path == path && (it.Kind == text || bytes.Contains(lines, []byte(text))) {
				return it.ID
			}
		}
	}
	f.t.Fatalf("no item in %s holds %q", path, text)
	return ""
}

func (f *fixture) head() string {
	return strings.TrimSpace(f.git("rev-parse", "HEAD"))
}

func (f *fixture) show(rev, path string) string {
	return f.git("show", rev+":"+path)
}

func plan(leave []string, commits ...Commit) string {
	data, err := json.Marshal(Plan{commits, leave})
	if err != nil {
		panic(err)
	}
	return string(data)
}

func contains(t *testing.T, got string, wants ...string) {
	t.Helper()
	for _, want := range wants {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in:\n%s", want, got)
		}
	}
}

func TestSplitJoin(t *testing.T) {
	for _, s := range []string{"", "a", "a\n", "a\nb", "a\n\nb\n", "\n"} {
		if got := string(join(split([]byte(s)))); got != s {
			t.Errorf("join(split(%q)) = %q", s, got)
		}
	}
	if got := string(join([][]byte{[]byte("x"), []byte("y\n")})); got != "x\ny\n" {
		t.Errorf("a last line followed by another should take a newline, got %q", got)
	}
}

func TestInterleave(t *testing.T) {
	lines := func(s ...string) [][]byte {
		var out [][]byte
		for _, x := range s {
			out = append(out, []byte(x+"\n"))
		}
		return out
	}
	for _, c := range []struct {
		old, new []string
		want     string
	}{
		{[]string{"a = 1;", "b = 2;"}, []string{"a = 10;", "b = 20;"}, "-a = 1;+a = 10;-b = 2;+b = 20;"},
		{[]string{"a = 1;", "b = 2;"}, []string{"c = 0;", "a = 10;", "b = 20;"}, "+c = 0;-a = 1;+a = 10;-b = 2;+b = 20;"},
		{[]string{"x"}, []string{"y"}, "-x+y"},
		{nil, []string{"new"}, "+new"},
	} {
		var got strings.Builder
		for _, l := range interleave(lines(c.old...), lines(c.new...)) {
			got.WriteByte(l.Sign)
			got.Write(bytes.TrimSuffix(l.Text, []byte("\n")))
		}
		if got.String() != c.want {
			t.Errorf("interleave(%q, %q) = %q, want %q", c.old, c.new, got.String(), c.want)
		}
	}
}

func TestCovers(t *testing.T) {
	for _, c := range []struct {
		spec, path string
		want       bool
	}{
		{"a.nix", "a.nix", true},
		{"modules/", "modules/git/hm.nix", true},
		{"modules", "modules/git/hm.nix", true},
		{"mod", "modules/git/hm.nix", false},
		{"*.nix", "modules/git/hm.nix", true},
		{"modules/*.nix", "modules/git/hm.nix", false},
		{"modules/*/hm.nix", "modules/git/hm.nix", true},
		{".", "anything", true},
	} {
		if got := covers(c.spec, c.path); got != c.want {
			t.Errorf("covers(%q, %q) = %v", c.spec, c.path, got)
		}
	}
}

func TestRanges(t *testing.T) {
	if got := ranges([]int{1, 2, 3, 5, 7, 8}); got != "1-3,5,7-8" {
		t.Errorf("ranges = %q", got)
	}
}

func TestMapAndShow(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "one\ntwo\nthree\n"})
	f.write("a.txt", "one\nTWO\nthree\nfour\n")
	f.write("new.txt", "fresh\n")
	want := []string{
		`^a\.txt  -1 \+2$`,
		`^  [0-9a-f]{6}      2  -1 \+1     TWO$`,
		`^  [0-9a-f]{6}      4  \+1        four$`,
		`^new\.txt  new  \+1$`,
		`^  [0-9a-f]{6}      1  \+1        fresh$`,
	}
	out := f.mustCarve("", "map")
	lines := strings.Split(strings.TrimSuffix(out, "\n"), "\n")
	if len(lines) != len(want) {
		t.Fatalf("map:\n%s", out)
	}
	for i, w := range want {
		if !regexp.MustCompile(w).MatchString(lines[i]) {
			t.Errorf("map line %d = %q, want %s", i+1, lines[i], w)
		}
	}
	if got := f.mustCarve("", "map", "--files", "a.txt"); got != "a.txt  -1 +2\n" {
		t.Errorf("map --files a.txt = %q", got)
	}

	two, four := f.id("a.txt", "TWO"), f.id("a.txt", "four")
	wantShow := two + "  a.txt:2\n   1 - two\n   2 + TWO\n\n" + four + "  a.txt:4\n   1 + four\n"
	if got := f.mustCarve("", "show", "a.txt"); got != wantShow {
		t.Errorf("show a.txt = %q, want %q", got, wantShow)
	}
}

func TestIDsSurviveEditsElsewhere(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "1\n2\n3\n4\n5\n6\n7\n8\n9\n"})
	f.write("a.txt", "1\nTWO\n3\n4\n5\n6\n7\n8\n9\n")
	before := f.id("a.txt", "TWO")
	f.write("a.txt", "1\nTWO\n3\n4\n5\n6\n7\n8\nNINE\n")
	if after := f.id("a.txt", "TWO"); after != before {
		t.Errorf("an edit elsewhere changed the ID from %s to %s", before, after)
	}
}

func TestApply(t *testing.T) {
	f := newRepo(t, map[string]string{
		"a.txt":     "line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7\nline 8\nline 9\nline 10\n",
		"noeol.txt": "x",
		"bin.dat":   "bin\x00ary",
		"exec.sh":   "echo hi\n",
		"gone.txt":  "gone\n",
		"b.nix":     "{\n  col = \"rgba(61afefee) rgba(c678ddee) 45deg\";\n}\n",
	})
	if err := os.Symlink("a.txt", filepath.Join(f.dir, "link")); err != nil {
		t.Fatal(err)
	}
	f.git("add", "link")
	f.git("commit", "-qm", "link")

	f.write("a.txt", "line 1\nline TWO\nline 3\nline 4\nline 5\nline 5.5\nline 6\nline 7\nline 8\nline 10\n")
	f.write("noeol.txt", "x\ny\n")
	f.write("bin.dat", "bin\x00ARY")
	f.write("exec.sh", "echo hello\n")
	os.Chmod(filepath.Join(f.dir, "exec.sh"), 0o755)
	os.Remove(filepath.Join(f.dir, "gone.txt"))
	os.Remove(filepath.Join(f.dir, "link"))
	os.Symlink("noeol.txt", filepath.Join(f.dir, "link"))
	f.write("new.txt", "new one\nnew two\n")
	f.write("empty.txt", "")
	f.write("TODO.md", "todo\n")
	finalNix := "{\n  col = \"rgb(${theme.blue})\";\n}\n"
	f.write("b.nix", finalNix)

	col := f.id("b.nix", "col")
	newTxt := f.id("new.txt", "new one")
	noeol := f.id("noeol.txt", "y")
	out := f.mustCarve(plan([]string{"TODO.md", f.id("a.txt", "line 9")},
		Commit{
			Message:  "solid border\n\n- body",
			Take:     []string{"b.nix", "a.txt", "exec.sh"},
			Override: map[string][]string{col: {`  col = "rgb(61afef)";`}},
		},
		Commit{
			Message: "theme colour",
			Take:    []string{col, "bin.dat", "link", "gone.txt", "empty.txt", newTxt + ":1", noeol + ":2-3"},
		},
		Commit{
			Message: "rest",
			Take:    []string{newTxt + ":2", noeol + ":1", f.id("exec.sh", "mode")},
		},
	), "apply")
	contains(t, out, "1/3 ", "  solid border\n", "  theme colour\n", "  rest\n", "left: TODO.md, a.txt\n")

	for _, c := range []struct{ rev, path, want string }{
		{"main~2", "b.nix", "{\n  col = \"rgb(61afef)\";\n}\n"},
		{"main~2", "a.txt", "line 1\nline TWO\nline 3\nline 4\nline 5\nline 5.5\nline 6\nline 7\nline 8\nline 9\nline 10\n"},
		{"main~2", "exec.sh", "echo hello\n"},
		{"main~1", "b.nix", finalNix},
		{"main~1", "noeol.txt", "x\nx\ny\n"},
		{"main~1", "new.txt", "new one\n"},
		{"main~1", "empty.txt", ""},
		{"main~1", "link", "noeol.txt"},
		{"main~1", "bin.dat", "bin\x00ARY"},
		{"main", "noeol.txt", "x\ny\n"},
		{"main", "new.txt", "new one\nnew two\n"},
	} {
		if got := f.show(c.rev, c.path); got != c.want {
			t.Errorf("%s:%s = %q, want %q", c.rev, c.path, got, c.want)
		}
	}
	for _, c := range []struct{ rev, path, want string }{
		{"main~3", "gone.txt", "100644"},
		{"main~2", "gone.txt", "100644"},
		{"main~1", "gone.txt", ""},
		{"main~1", "exec.sh", "100644"},
		{"main", "exec.sh", "100755"},
		{"main~1", "link", "120000"},
	} {
		got, _, _ := strings.Cut(f.git("ls-tree", c.rev, c.path), " ")
		if got != c.want {
			t.Errorf("mode of %s:%s = %q, want %q", c.rev, c.path, got, c.want)
		}
	}
	if got := f.git("status", "--porcelain"); got != " M a.txt\n?? TODO.md\n" {
		t.Errorf("status = %q", got)
	}
	if got := f.git("diff", "--numstat"); got != "0\t1\ta.txt\n" {
		t.Errorf("left in the working tree: %q", got)
	}
	if got, _ := os.ReadFile(filepath.Join(f.dir, "b.nix")); string(got) != finalNix {
		t.Errorf("the working tree changed: b.nix = %q", got)
	}
	f.git("diff", "--cached", "--quiet")
}

func TestPlanErrors(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "1\n2\n3\n", "bin.dat": "b\x00a"})
	f.write("a.txt", "1\nTWO\n3\nfour\n")
	f.write("bin.dat", "b\x00A")
	f.write("new.txt", "fresh\n")
	two, four, bin, fresh := f.id("a.txt", "TWO"), f.id("a.txt", "four"), f.id("bin.dat", "replaced"), f.id("new.txt", "fresh")
	err := f.failCarve(plan([]string{two},
		Commit{Message: "one", Take: []string{"a.txt", two, "deadbeef", bin + ":1"}},
		Commit{Message: "two", Take: []string{"a.txt", "new.txt:1"}, Override: map[string][]string{four: {"x"}}},
	), "apply")
	contains(t, err,
		"the plan does not hold:",
		"deadbeef: matches no hunk or path",
		bin+":1: a replaced change is taken whole",
		"new.txt:1: lines go with a hunk ID, not a path",
		two+" (a.txt) line 1: claimed by commit 1 and leave",
		four+" (a.txt): claimed by commit 1 and commit 2",
		bin+" (bin.dat): in no commit and not left",
		fresh+" (new.txt): in no commit and not left",
		"override "+four+": comes in commit 2, not before commit 1, which takes it",
	)
}

func TestPlanShape(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "1\n"})
	f.write("a.txt", "2\n")
	for stdin, want := range map[string]string{
		`{"commits": [{"message": "x", "takes": ["a.txt"]}]}`: `unknown field "takes"`,
		`{"commits": []}`:                 "no commits",
		`{"commits": [{"message": " "}]}`: "commit 1 has no message",
		`{"commits": [{"message": "x"}`:   "plan:",
	} {
		contains(t, f.failCarve(stdin, "apply"), want)
	}
}

func TestEmptyCommitRefused(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "1\n"})
	f.write("a.txt", "2\n")
	err := f.failCarve(plan(nil,
		Commit{Message: "one", Take: []string{"a.txt"}},
		Commit{Message: "two", Take: []string{f.id("a.txt", "2")}},
	), "apply")
	contains(t, err, "commit 1 changes nothing")
}

func TestNothingToCarve(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "1\n"})
	if got := f.mustCarve("", "map"); got != "nothing to carve\n" {
		t.Errorf("map = %q", got)
	}
	contains(t, f.failCarve(plan(nil, Commit{Message: "x", Take: []string{"a.txt"}}), "apply"), "nothing to carve")
}

func TestDryRun(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "1\n2\n"})
	f.hook("exit 1")
	f.write("a.txt", "1\nTWO\n")
	f.write("TODO.md", "todo\n")
	file := filepath.Join(t.TempDir(), "plan.json")
	p := plan([]string{"TODO.md"}, Commit{Message: "two\n\n- body", Take: []string{"a.txt"}})
	if err := os.WriteFile(file, []byte(p), 0o644); err != nil {
		t.Fatal(err)
	}
	head := f.head()
	out := f.mustCarve("", "apply", file, "--dry-run")
	if want := "1  two\n    a.txt  -1 +1\nleft\n    TODO.md  +1\n"; out != want {
		t.Errorf("dry run = %q, want %q", out, want)
	}
	if f.head() != head {
		t.Errorf("a dry run moved HEAD")
	}
}

func TestHookJudgesTheCommitNotTheWorkingFile(t *testing.T) {
	f := newRepo(t, map[string]string{"a.nix": "{\n  a = 1;\n  b = 2;\n}\n"})
	f.hook("! git grep -q --cached UNFORMATTED")
	f.write("a.nix", "{\n  a = 10;\n  b = 2; UNFORMATTED\n}\n")
	id := f.id("a.nix", "a = 10")
	f.mustCarve(plan([]string{id + ":3-4"}, Commit{Message: "ten", Take: []string{id + ":1-2"}}), "apply")
	if got := f.show("main", "a.nix"); got != "{\n  a = 10;\n  b = 2;\n}\n" {
		t.Errorf("committed a.nix = %q", got)
	}
	err := f.failCarve(plan(nil, Commit{Message: "rest", Take: []string{"a.nix"}}), "apply")
	contains(t, err, "commit 1: git commit failed", "main unchanged")
}

// align pads the first word of each line of the staged .txt files to the
// longest, as gofmt aligns a struct's fields: whether a line is formatted
// depends on the others.
const align = `git diff --cached --name-only --diff-filter=ACMR -- '*.txt' | while read -r f; do
  awk '{ k[NR] = $1; v[NR] = $2; if (length($1) > w) w = length($1) }
    END { for (i = 1; i <= NR; i++) printf "%-" w "s %s\n", k[i], v[i] }' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
done`

const aligned = "a          1\nb          2\nc          3\nlongername 4\n"

func TestHookFixToAnInterimVersionStands(t *testing.T) {
	for _, hook := range []struct{ name, script string }{
		{"fixes and fails", align + "\ngit diff --quiet"},
		{"fixes and stages", align + "\ngit add -u"},
	} {
		t.Run(hook.name, func(t *testing.T) {
			f := newRepo(t, map[string]string{"a.txt": "a 1\nb 2\n"})
			f.hook(hook.script)
			f.write("a.txt", aligned)
			id := f.id("a.txt", "c")
			out := f.mustCarve(plan(nil,
				Commit{Message: "add c", Take: []string{id + ":5"}},
				Commit{Message: "add longername", Take: []string{id + ":1-4,6"}},
			), "apply")
			contains(t, out, "  add c  (hook rewrote a.txt)\n", "  add longername\n")
			if got := f.show("main~1", "a.txt"); got != "a 1\nb 2\nc 3\n" {
				t.Errorf("a.txt after add c = %q", got)
			}
			if got := f.show("main", "a.txt"); got != aligned {
				t.Errorf("a.txt at main = %q", got)
			}
			if status := f.git("status", "--porcelain"); status != "" {
				t.Errorf("the working tree differs from main:\n%s", status)
			}
		})
	}
}

func TestHookFixToAFinalVersionRefused(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "a 1\n", "b.txt": "b 1\n"})
	f.hook(align + "\ngit diff --quiet")
	f.write("a.txt", "a 1\nlonger 2\n")
	f.write("b.txt", "b 2\n")
	p := plan(nil,
		Commit{Message: "a", Take: []string{"a.txt"}},
		Commit{Message: "b", Take: []string{"b.txt"}},
	)
	err := f.failCarve(p, "apply")
	contains(t, err, "commit 1: the hook rewrote the final a.txt, so the working tree fails it too")
	m := regexp.MustCompile(`git diff (\S+) (\S+) -- a\.txt shows the fix`).FindStringSubmatch(err)
	if m == nil {
		t.Fatalf("no diff in: %s", err)
	}
	patch := filepath.Join(t.TempDir(), "fix.patch")
	if err := os.WriteFile(patch, []byte(f.git("diff", m[1], m[2], "--", "a.txt")), 0o644); err != nil {
		t.Fatal(err)
	}
	f.git("apply", patch)
	f.mustCarve(p, "apply")
	if got := f.show("main~1", "a.txt"); got != "a      1\nlonger 2\n" {
		t.Errorf("committed a.txt = %q", got)
	}
}

func TestCachedHookFixToAFinalVersionRefused(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "a 1\nb 2\n"})
	f.hook(align + "\ngit diff --quiet && ! git grep -q --cached FORBIDDEN")
	f.write("a.txt", aligned)
	f.write("x.md", "FORBIDDEN\n")
	id := f.id("a.txt", "c")
	c := Commit{Message: "add c", Take: []string{id + ":5"}}
	contains(t, f.failCarve(plan(nil, c, Commit{Message: "rest", Take: []string{id + ":1-4,6", "x.md"}}), "apply"),
		"commit 2: git commit failed")
	// The rest left, the fix commit 1 kept is to a.txt's final version.
	err := f.failCarve(plan([]string{id + ":1-4,6", "x.md"}, c), "apply")
	contains(t, err, "commit 1: the hook rewrote the final a.txt, so the working tree less its left lines fails it too")
}

func TestHookThatDoesNotSettleRefused(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "1\n2\n"})
	f.hook("echo more >> a.txt\ngit add -u")
	f.write("a.txt", "one\ntwo\n")
	err := f.failCarve(plan(nil,
		Commit{Message: "one", Take: []string{f.id("a.txt", "one") + ":1-2"}},
		Commit{Message: "two", Take: []string{f.id("a.txt", "one") + ":3-4"}},
	), "apply")
	contains(t, err, "commit 1: the hook rewrote its own fix")
}

func TestCommitAnEarlierHookFixMadeRefused(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "a 1\nb 2\n"})
	f.hook(align + "\ngit diff --quiet")
	f.write("a.txt", "a  1\nb  2\ncc 3\n")
	id := f.id("a.txt", "cc")
	err := f.failCarve(plan(nil,
		Commit{Message: "add cc", Take: []string{id + ":5"}},
		Commit{Message: "realign", Take: []string{id + ":1-4"}},
	), "apply")
	contains(t, err, "commit 2 changes nothing: the hook's fix to a.txt in commit 1 already made it; take its hunks there")
}

func TestCommitItsHookFixUndoesRefused(t *testing.T) {
	f := newRepo(t, map[string]string{"a.txt": "a\n"})
	// Drops x while no line uses it, as deadnix drops an unused binding.
	f.hook("grep -q '^use x$' a.txt || { grep -v '^x$' a.txt > a.tmp; mv a.tmp a.txt; }\ngit diff --quiet")
	f.write("a.txt", "a\nx\nuse x\n")
	id := f.id("a.txt", "use x")
	err := f.failCarve(plan(nil,
		Commit{Message: "add x", Take: []string{id + ":1"}},
		Commit{Message: "use x", Take: []string{id + ":2"}},
	), "apply")
	contains(t, err, "commit 1 changes nothing: the hook's fix to a.txt undoes it; take its hunks in a later commit")
}

func TestRerunReusesPassedCommits(t *testing.T) {
	f := newRepo(t, map[string]string{"base.txt": "base\n"})
	log := filepath.Join(t.TempDir(), "hook.log")
	f.hook("echo ran >> " + log + "\n! git grep -q --cached FORBIDDEN")
	f.write("one.txt", "fine\n")
	f.write("two.txt", "FORBIDDEN\n")
	p := plan(nil,
		Commit{Message: "one", Take: []string{"one.txt"}},
		Commit{Message: "two", Take: []string{"two.txt"}},
	)
	contains(t, f.failCarve(p, "apply"), "commit 2: git commit failed", "main unchanged; a rerun reuses")
	f.write("two.txt", "allowed\n")
	out := f.mustCarve(p, "apply")
	contains(t, out, "  one  (cached)\n", "  two\n")
	if runs, _ := os.ReadFile(log); strings.Count(string(runs), "ran") != 3 {
		t.Errorf("the hook ran %d times, want 3", strings.Count(string(runs), "ran"))
	}
}

func TestVerify(t *testing.T) {
	f := newRepo(t, map[string]string{"base.txt": "base\n"})
	f.write("one.txt", "1\n")
	f.write("two.txt", "2\n")
	p := plan(nil,
		Commit{Message: "one", Take: []string{"one.txt"}},
		Commit{Message: "two", Take: []string{"two.txt"}},
	)
	err := f.failCarve(p, "apply", "--verify", "test -e two.txt || { echo two.txt is missing; exit 3; }")
	contains(t, err, "commit 1: test -e two.txt", "two.txt is missing")

	log := filepath.Join(t.TempDir(), "verify.log")
	f.mustCarve(p, "apply", "--verify", "git log -1 --format=%s >> "+log)
	if got, _ := os.ReadFile(log); string(got) != "one\ntwo\n" {
		t.Errorf("verify ran on %q, want each commit in order", got)
	}
}

func TestWorkingTreeChangedMidRun(t *testing.T) {
	f := newRepo(t, map[string]string{"base.txt": "base\n"})
	f.write("one.txt", "1\n")
	err := f.failCarve(plan(nil, Commit{Message: "one", Take: []string{"one.txt"}}),
		"apply", "--verify", "echo more >> "+filepath.Join(f.dir, "one.txt"))
	contains(t, err, "the working tree changed while carving: one.txt")
}
