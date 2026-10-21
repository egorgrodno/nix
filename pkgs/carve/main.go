// Command carve splits the working tree's changes into commits, hunk by hunk.
// The base is HEAD and the target the working tree, untracked files included;
// the index is ignored, and left matching the new HEAD. Each commit is made in
// a scratch worktree, hooks and all, and the branch moves only once every one
// passes.
package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"unicode/utf8"
)

const usage = `usage:
  carve map [--files] [PATH...]   the hunks, under their files
  carve show SPEC...              hunks, their changed lines numbered
  carve apply [--verify CMD] [--dry-run] [PLAN]
                                  make the commits a plan describes
`

const applyHelp = `usage: carve apply [--verify CMD] [--dry-run] [PLAN]

  --verify CMD  run CMD in each new commit's tree; a failure stops the run
  --dry-run     check the plan and print the commits without making them

A plan is JSON, read from PLAN or stdin:

  {"commits": [{"message": "subject\n\n- bullet",
                "take": [SPEC, ...],
                "override": {"ID": ["line", ...]}}],
   "leave": [SPEC, ...]}

A SPEC is a hunk ID or a unique prefix of one, ID:N,N-M for the lines
` + "`carve show`" + ` numbers, or a path, directory or glob for every hunk under it,
relative to the repository root; a glob without a slash matches file names in
any directory. An ID beats a path, so a file can go to one commit and a hunk
of it to another. Every changed line lands in exactly one commit or in
"leave", which stays in the working tree. A partial take keeps the - lines it
does not take and the + lines it does, in the order ` + "`carve show`" + ` prints them.

An override gives a hunk interim lines from its commit until the commit that
takes the hunk whole: the way to split one line serving two commits.

Commits that passed in an earlier run, with the same parent, tree, message and
--verify, are reused rather than made and checked again.
`

func main() {
	if err := run(os.Args[1:], ".", os.Stdin, os.Stdout); err != nil {
		fmt.Fprintf(os.Stderr, "carve: %v\n", err)
		os.Exit(1)
	}
}

func run(args []string, dir string, stdin io.Reader, stdout io.Writer) error {
	if len(args) == 0 {
		return errors.New(strings.TrimSpace(usage))
	}
	switch args[0] {
	case "map":
		return cmdMap(args[1:], dir, stdout)
	case "show":
		return cmdShow(args[1:], dir, stdout)
	case "apply":
		return cmdApply(args[1:], dir, stdin, stdout)
	case "-h", "--help", "help":
		fmt.Fprint(stdout, usage)
		return nil
	}
	return fmt.Errorf("no command %q\n%s", args[0], strings.TrimSpace(usage))
}

// parse lets flags and arguments come in any order.
func parse(fs *flag.FlagSet, help string, stdout io.Writer, args []string) ([]string, error) {
	fs.SetOutput(io.Discard)
	fs.Usage = func() { fmt.Fprint(stdout, help) }
	var rest []string
	for {
		if err := fs.Parse(args); err != nil {
			return nil, err
		}
		if fs.NArg() == 0 {
			return rest, nil
		}
		rest = append(rest, fs.Arg(0))
		args = fs.Args()[1:]
	}
}

func cmdMap(args []string, dir string, stdout io.Writer) error {
	fs := flag.NewFlagSet("map", flag.ContinueOnError)
	files := fs.Bool("files", false, "")
	paths, err := parse(fs, usage, stdout, args)
	if err != nil {
		return helpOK(err)
	}
	r, err := open(dir)
	if err != nil {
		return err
	}
	changes, err := r.collect()
	if err != nil {
		return err
	}
	name(changes)
	shown := 0
	for _, c := range changes {
		if len(paths) > 0 && !slices.ContainsFunc(paths, func(p string) bool { return covers(p, c.Path) }) {
			continue
		}
		shown++
		old, new := 0, 0
		for _, h := range c.Hunks {
			old, new = old+len(h.Old), new+len(h.New)
		}
		tag := ""
		if c.Base == nil {
			tag = "new"
		} else if c.Final == nil {
			tag = "deleted"
		}
		fmt.Fprintln(stdout, joinSome("  ", c.Path, tag, counts(old, new)))
		if *files {
			continue
		}
		for _, it := range c.Items() {
			if it.Kind != "hunk" {
				fmt.Fprintf(stdout, "  %s  %s\n", it.ID, describe(it))
				continue
			}
			size := counts(len(it.Old), len(it.New))
			fmt.Fprintf(stdout, "  %s  %5d  %-9s %s\n", it.ID, it.Line, size, preview(it))
		}
	}
	if shown == 0 {
		fmt.Fprintln(stdout, "nothing to carve")
	}
	return nil
}

func cmdShow(args []string, dir string, stdout io.Writer) error {
	fs := flag.NewFlagSet("show", flag.ContinueOnError)
	specs, err := parse(fs, usage, stdout, args)
	if err != nil {
		return helpOK(err)
	}
	if len(specs) == 0 {
		return errors.New("show takes at least one SPEC")
	}
	r, err := open(dir)
	if err != nil {
		return err
	}
	changes, err := r.collect()
	if err != nil {
		return err
	}
	items := name(changes)
	var shown []*Item
	for _, spec := range specs {
		found, err := match(spec, items)
		if err != nil {
			return err
		}
		for _, p := range found {
			if !slices.Contains(shown, p.item) {
				shown = append(shown, p.item)
			}
		}
	}
	for i, it := range shown {
		if i > 0 {
			fmt.Fprintln(stdout)
		}
		if it.Kind != "hunk" {
			fmt.Fprintf(stdout, "%s  %s  %s\n", it.ID, it.Change.Path, describe(it))
			continue
		}
		fmt.Fprintf(stdout, "%s  %s:%d\n", it.ID, it.Change.Path, it.Line)
		for n, line := range it.Lines {
			text := strings.TrimSuffix(strings.ToValidUTF8(string(line.Text), "�"), "\n")
			fmt.Fprintf(stdout, "%4d %c %s\n", n+1, line.Sign, text)
		}
	}
	return nil
}

func cmdApply(args []string, dir string, stdin io.Reader, stdout io.Writer) error {
	fs := flag.NewFlagSet("apply", flag.ContinueOnError)
	verify := fs.String("verify", "", "")
	dry := fs.Bool("dry-run", false, "")
	rest, err := parse(fs, applyHelp, stdout, args)
	if err != nil {
		return helpOK(err)
	}
	if len(rest) > 1 {
		return errors.New("apply takes one PLAN")
	}
	var data []byte
	if len(rest) == 0 || rest[0] == "-" {
		data, err = io.ReadAll(stdin)
	} else {
		source := rest[0]
		if !filepath.IsAbs(source) {
			source = filepath.Join(dir, source)
		}
		data, err = os.ReadFile(source)
	}
	if err != nil {
		return err
	}
	plan, err := parsePlan(data)
	if err != nil {
		return err
	}
	r, err := open(dir)
	if err != nil {
		return err
	}
	if err := r.idle(); err != nil {
		return err
	}
	head, err := r.out(r.root, "rev-parse", "--verify", "-q", "HEAD")
	if err != nil || head == "" {
		return errors.New("HEAD has no commit to build on")
	}
	branch, _ := r.out(r.root, "symbolic-ref", "-q", "--short", "HEAD")
	if branch == "" {
		branch = "HEAD"
	}
	changes, err := r.collect()
	if err != nil {
		return err
	}
	items := name(changes)
	if len(items) == 0 {
		return errors.New("nothing to carve")
	}
	if err := resolve(plan, items); err != nil {
		return err
	}
	n := len(plan.Commits)
	// steps[k+1] holds each path after commit k; steps[0] is HEAD.
	steps := make([][]*File, n+1)
	for k := -1; k < n; k++ {
		steps[k+1] = make([]*File, len(changes))
		for i, c := range changes {
			steps[k+1][i] = c.at(k)
		}
	}
	var empty []string
	for k := range n {
		if slices.EqualFunc(steps[k+1], steps[k], sameFile) {
			empty = append(empty, strconv.Itoa(k+1))
		}
	}
	if len(empty) > 0 {
		return fmt.Errorf("commit %s changes nothing", strings.Join(empty, ", "))
	}
	left := summary(changes, n)
	if *dry {
		for k, c := range plan.Commits {
			fmt.Fprintf(stdout, "%d  %s\n", k+1, subject(c.Message))
			printRows(stdout, summary(changes, k))
		}
		if len(left) > 0 {
			fmt.Fprintln(stdout, "left")
			printRows(stdout, left)
		}
		return nil
	}
	last, err := r.build(changes, plan.Commits, steps, head, *verify, stdout)
	if err == nil {
		err = r.unmoved(changes)
	}
	if err == nil {
		_, err = r.git(r.root, nil, "update-ref", "-m", fmt.Sprintf("carve: %d commits", n), "HEAD", last, head)
	}
	if err != nil {
		return fmt.Errorf("%w\n%s unchanged; a rerun reuses the commits that passed", err, branch)
	}
	if _, err := r.git(r.root, nil, "reset", "-q"); err != nil {
		return err
	}
	fmt.Fprintf(stdout, "%s  %s..%s\n", branch, head[:7], last[:7])
	if len(left) > 0 {
		var paths []string
		for _, row := range left {
			paths = append(paths, row.path)
		}
		fmt.Fprintf(stdout, "left: %s\n", strings.Join(paths, ", "))
	}
	return nil
}

func helpOK(err error) error {
	if errors.Is(err, flag.ErrHelp) {
		return nil
	}
	return err
}

func printRows(w io.Writer, rows []row) {
	for _, row := range rows {
		fmt.Fprintf(w, "    %s  %s\n", row.path, row.what)
	}
}

func subject(message string) string {
	line, _, _ := strings.Cut(strings.TrimSpace(message), "\n")
	return line
}

func joinSome(sep string, parts ...string) string {
	return strings.Join(slices.DeleteFunc(parts, func(s string) bool { return s == "" }), sep)
}

func counts(old, new int) string {
	var parts []string
	if old > 0 {
		parts = append(parts, fmt.Sprintf("-%d", old))
	}
	if new > 0 {
		parts = append(parts, fmt.Sprintf("+%d", new))
	}
	return strings.Join(parts, " ")
}

func preview(it *Item) string {
	for _, line := range slices.Concat(it.New, it.Old) {
		text := strings.TrimSpace(strings.ToValidUTF8(string(line), "�"))
		if text == "" {
			continue
		}
		if utf8.RuneCountInString(text) > 60 {
			text = string([]rune(text)[:59]) + "…"
		}
		return text
	}
	return ""
}
