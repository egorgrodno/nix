package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
)

// File is a path's content and git mode; a nil *File is an absent path.
type File struct {
	Mode string
	Data []byte
}

func sameFile(a, b *File) bool {
	if a == nil || b == nil {
		return a == b
	}
	return a.Mode == b.Mode && bytes.Equal(a.Data, b.Data)
}

// Item is a hunk, or a change taken in one piece.
type Item struct {
	Change *Change
	// "hunk", or for a whole change "added", "deleted", "replaced" or "mode".
	Kind string
	// A hunk's Old lines, from index Start of the base, give way to New.
	Start    int
	Old, New [][]byte
	// Old and New interleaved, each new line after the old line it most
	// resembles: the order `carve show` numbers and a partial take keeps.
	Lines []Line
	// The hunk's line in the working tree, for display.
	Line int
	// The commit taking each changed line, or the whole change; one past the
	// last commit leaves it.
	Owners    []int
	Overrides []Override
	Digest    string
	ID        string
}

// Line is a changed line: '-' of the base, '+' of the working tree.
type Line struct {
	Sign byte
	Text []byte
}

// Override gives a hunk interim lines from Commit until a commit takes it.
type Override struct {
	Commit int
	Lines  [][]byte
}

func newHunk(c *Change, start int, old, new [][]byte, line int) *Item {
	return &Item{
		Change: c, Kind: "hunk", Start: start, Line: line,
		Old: old, New: new, Lines: interleave(old, new),
	}
}

// interleave orders a hunk's lines so each new line follows the old line it
// replaces, by the pairing that shares the most prefix and suffix.
func interleave(old, new [][]byte) []Line {
	n, m := len(old), len(new)
	var lines []Line
	if n*m > 1<<20 {
		// Too many pairs to weigh: pair them by position.
		for i := range max(n, m) {
			if i < n {
				lines = append(lines, Line{'-', old[i]})
			}
			if i < m {
				lines = append(lines, Line{'+', new[i]})
			}
		}
		return lines
	}
	// best[i][j] is the most similarity old[i:] and new[j:] pair up to.
	best := make([][]int, n+1)
	for i := range best {
		best[i] = make([]int, m+1)
	}
	for i := n - 1; i >= 0; i-- {
		for j := m - 1; j >= 0; j-- {
			best[i][j] = max(best[i+1][j], best[i][j+1], similarity(old[i], new[j])+best[i+1][j+1])
		}
	}
	for i, j := 0, 0; i < n || j < m; {
		s := 0
		if i < n && j < m {
			s = similarity(old[i], new[j])
		}
		switch {
		case s > 0 && best[i][j] == s+best[i+1][j+1]:
			lines = append(lines, Line{'-', old[i]}, Line{'+', new[j]})
			i, j = i+1, j+1
		case i < n && (j == m || best[i][j] == best[i+1][j]):
			lines = append(lines, Line{'-', old[i]})
			i++
		default:
			lines = append(lines, Line{'+', new[j]})
			j++
		}
	}
	return lines
}

// similarity is how many bytes two lines share at their start and end.
func similarity(a, b []byte) int {
	a, b = bytes.TrimSpace(a), bytes.TrimSpace(b)
	p := 0
	for p < len(a) && p < len(b) && a[p] == b[p] {
		p++
	}
	s := 0
	for s < len(a)-p && s < len(b)-p && a[len(a)-1-s] == b[len(b)-1-s] {
		s++
	}
	return p + s
}

func (it *Item) Size() int {
	if it.Kind == "hunk" {
		return len(it.Lines)
	}
	return 1
}

// region is the hunk with the lines in taken applied: the old lines it does
// not take and the new lines it does, or the override in their place.
func (it *Item) region(taken []bool, override [][]byte) [][]byte {
	if override != nil {
		return override
	}
	var lines [][]byte
	for i, line := range it.Lines {
		if line.Sign == '-' && !taken[i] || line.Sign == '+' && taken[i] {
			lines = append(lines, line.Text)
		}
	}
	return lines
}

// at is which lines the hunk has taken after commit k, and its override
// while it has taken none.
func (it *Item) at(k int) ([]bool, [][]byte) {
	taken := make([]bool, it.Size())
	for i, owner := range it.Owners {
		taken[i] = owner <= k
	}
	if slices.Contains(taken, true) {
		return taken, nil
	}
	var override [][]byte
	for _, o := range it.Overrides {
		if o.Commit <= k {
			override = o.Lines
		}
	}
	return taken, override
}

// Change is one path's difference between HEAD and the working tree.
type Change struct {
	Path        string
	Base, Final *File
	Hunks       []*Item
	Whole, Mode *Item
}

func (c *Change) Items() []*Item {
	items := slices.Clone(c.Hunks)
	for _, it := range []*Item{c.Whole, c.Mode} {
		if it != nil {
			items = append(items, it)
		}
	}
	return items
}

func (c *Change) rebuild(regions [][][]byte) []byte {
	var base, lines [][]byte
	if c.Base != nil {
		base = split(c.Base.Data)
	}
	pos := 0
	for i, h := range c.Hunks {
		lines = append(lines, base[pos:h.Start]...)
		lines = append(lines, regions[i]...)
		pos = h.Start + len(h.Old)
	}
	return join(append(lines, base[pos:]...))
}

// at is the path after commit k, nil where it is absent; k = -1 is HEAD.
func (c *Change) at(k int) *File {
	if c.Whole != nil {
		if c.Whole.Owners[0] <= k {
			return c.Final
		}
		return c.Base
	}
	regions := make([][][]byte, len(c.Hunks))
	touched := false
	for i, h := range c.Hunks {
		taken, override := h.at(k)
		touched = touched || override != nil || slices.Contains(taken, true)
		regions[i] = h.region(taken, override)
	}
	if c.Base == nil && !touched {
		return nil
	}
	mode := c.Final.Mode
	if c.Base != nil && (c.Mode == nil || c.Mode.Owners[0] > k) {
		mode = c.Base.Mode
	}
	return &File{mode, c.rebuild(regions)}
}

// rebuilds checks that taking every hunk gives the working tree's file and
// taking none gives HEAD's.
func (c *Change) rebuilds() bool {
	all := make([][][]byte, len(c.Hunks))
	none := make([][][]byte, len(c.Hunks))
	for i, h := range c.Hunks {
		taken := make([]bool, h.Size())
		none[i] = h.region(taken, nil)
		for j := range taken {
			taken[j] = true
		}
		all[i] = h.region(taken, nil)
	}
	return bytes.Equal(c.rebuild(all), c.Final.Data) &&
		(c.Base == nil || bytes.Equal(c.rebuild(none), c.Base.Data))
}

func split(data []byte) [][]byte {
	var lines [][]byte
	for len(data) > 0 {
		i := bytes.IndexByte(data, '\n')
		if i < 0 {
			return append(lines, data)
		}
		lines, data = append(lines, data[:i+1]), data[i+1:]
	}
	return lines
}

// join concatenates lines; a last line without a newline takes one once a
// later line follows it.
func join(lines [][]byte) []byte {
	var buf bytes.Buffer
	for i, line := range lines {
		buf.Write(line)
		if i < len(lines)-1 && !bytes.HasSuffix(line, []byte("\n")) {
			buf.WriteByte('\n')
		}
	}
	return buf.Bytes()
}

func binary(f *File) bool {
	return f != nil && bytes.IndexByte(f.Data[:min(len(f.Data), 8000)], 0) >= 0
}

func link(f *File) bool {
	return f != nil && f.Mode == "120000"
}

func current(root, path string) (*File, error) {
	full := filepath.Join(root, path)
	st, err := os.Lstat(full)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	switch {
	case st.Mode()&fs.ModeSymlink != 0:
		target, err := os.Readlink(full)
		return &File{"120000", []byte(target)}, err
	case st.Mode().IsRegular():
		data, err := os.ReadFile(full)
		mode := "100644"
		if st.Mode()&0o100 != 0 {
			mode = "100755"
		}
		return &File{mode, data}, err
	}
	return nil, fmt.Errorf("%s: neither a file nor a symlink", path)
}

var hunkHeader = regexp.MustCompile(`^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@`)

func (r *repo) collect() ([]*Change, error) {
	unmerged, err := r.git(r.root, nil, "ls-files", "--unmerged")
	if err != nil {
		return nil, err
	}
	if len(unmerged) > 0 {
		return nil, errors.New("the index has unmerged paths")
	}
	type entry struct{ path, mode, finalMode, sha string }
	var entries []entry
	raw, err := r.git(r.root, nil, "diff", "--raw", "-z", "--no-abbrev", "--no-renames", "HEAD")
	if err != nil {
		return nil, err
	}
	fields := strings.Split(string(raw), "\x00")
	for i := 0; i+1 < len(fields); i += 2 {
		meta := strings.Fields(strings.TrimPrefix(fields[i], ":"))
		if len(meta) < 5 {
			return nil, fmt.Errorf("git diff --raw: cannot read %q", fields[i])
		}
		entries = append(entries, entry{fields[i+1], meta[0], meta[1], meta[2]})
	}
	untracked, err := r.git(r.root, nil, "ls-files", "-z", "--others", "--exclude-standard")
	if err != nil {
		return nil, err
	}
	for _, path := range strings.Split(string(untracked), "\x00") {
		if path != "" {
			entries = append(entries, entry{path, "000000", "", ""})
		}
	}
	slices.SortFunc(entries, func(a, b entry) int { return strings.Compare(a.path, b.path) })
	var changes []*Change
	for _, e := range entries {
		if e.mode == "160000" || e.finalMode == "160000" || strings.HasSuffix(e.path, "/") {
			return nil, fmt.Errorf("%s: carve does not split submodules or nested repositories", e.path)
		}
		c, err := r.load(e.path, e.mode, e.sha)
		if err != nil {
			return nil, err
		}
		changes = append(changes, c)
	}
	return changes, nil
}

func (r *repo) load(path, baseMode, baseSHA string) (*Change, error) {
	c := &Change{Path: path}
	if baseMode != "000000" {
		data, err := r.git(r.root, nil, "cat-file", "blob", baseSHA)
		if err != nil {
			return nil, err
		}
		c.Base = &File{baseMode, data}
	}
	final, err := current(r.root, path)
	if err != nil {
		return nil, err
	}
	c.Final = final
	if c.Final == nil || c.Base == nil && len(c.Final.Data) == 0 ||
		binary(c.Base) || binary(c.Final) || link(c.Base) || link(c.Final) ||
		c.Base != nil && bytes.Equal(c.Base.Data, c.Final.Data) {
		c.Whole = &Item{Change: c, Kind: wholeKind(c)}
		return c, nil
	}
	if c.Base == nil {
		c.Hunks = []*Item{newHunk(c, 0, nil, split(c.Final.Data), 1)}
	} else {
		diff, err := r.git(r.root, nil, "diff", "--no-color", "--no-ext-diff", "--no-textconv", "-U0", "HEAD", "--", path)
		if err != nil {
			return nil, err
		}
		before, after := split(c.Base.Data), split(c.Final.Data)
		for _, line := range bytes.Split(diff, []byte("\n")) {
			m := hunkHeader.FindSubmatch(line)
			if m == nil {
				continue
			}
			a, b, n, d := number(m[1]), number(m[2]), number(m[3]), number(m[4])
			start, at := a-1, n-1
			if b == 0 {
				start = a
			}
			if d == 0 {
				at = n
			}
			if start < 0 || at < 0 || start+b > len(before) || at+d > len(after) {
				c.Hunks = nil
				break
			}
			c.Hunks = append(c.Hunks, newHunk(c, start, before[start:start+b], after[at:at+d], n))
		}
		if c.Base.Mode != c.Final.Mode {
			c.Mode = &Item{Change: c, Kind: "mode"}
		}
	}
	if !c.rebuilds() {
		// A filter, or a diff carve misread: the file goes in one piece.
		c.Hunks, c.Mode = nil, nil
		c.Whole = &Item{Change: c, Kind: wholeKind(c)}
	}
	return c, nil
}

func number(b []byte) int {
	if len(b) == 0 {
		return 1
	}
	n, _ := strconv.Atoi(string(b))
	return n
}

func wholeKind(c *Change) string {
	switch {
	case c.Base == nil:
		return "added"
	case c.Final == nil:
		return "deleted"
	case bytes.Equal(c.Base.Data, c.Final.Data):
		return "mode"
	}
	return "replaced"
}

// name gives every item an ID from its content, so an edit elsewhere keeps it.
func name(changes []*Change) []*Item {
	var items []*Item
	seen := map[string]int{}
	for _, c := range changes {
		for _, it := range c.Items() {
			parts := [][]byte{[]byte(c.Path)}
			if it.Kind == "hunk" {
				parts = append(parts, bytes.Join(it.Old, nil), bytes.Join(it.New, nil))
			} else {
				parts = append(parts, []byte(it.Kind))
			}
			key := string(bytes.Join(parts, []byte{0}))
			seen[key]++
			sum := sha1.Sum(fmt.Appendf(nil, "%s\x00%d", key, seen[key]))
			it.Digest = hex.EncodeToString(sum[:])
			items = append(items, it)
		}
	}
	width := 6
	for ; width < 40; width++ {
		ids := map[string]bool{}
		for _, it := range items {
			ids[it.Digest[:width]] = true
		}
		if len(ids) == len(items) {
			break
		}
	}
	for _, it := range items {
		it.ID = it.Digest[:width]
	}
	return items
}

func describe(it *Item) string {
	c := it.Change
	switch it.Kind {
	case "mode":
		return fmt.Sprintf("mode %s -> %s", c.Base.Mode, c.Final.Mode)
	case "deleted":
		return "deleted"
	}
	what := "text, taken whole"
	switch {
	case link(c.Final):
		what = "symlink -> " + string(c.Final.Data)
	case binary(c.Final):
		what = "binary"
	case len(c.Final.Data) == 0:
		what = "empty"
	}
	if it.Kind == "added" {
		return "new " + what
	}
	return what
}
