package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"path"
	"regexp"
	"slices"
	"strconv"
	"strings"
)

type Plan struct {
	Commits []Commit `json:"commits"`
	Leave   []string `json:"leave"`
}

type Commit struct {
	Message  string              `json:"message"`
	Take     []string            `json:"take"`
	Override map[string][]string `json:"override"`
}

func parsePlan(data []byte) (*Plan, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	var p Plan
	if err := dec.Decode(&p); err != nil {
		return nil, fmt.Errorf("plan: %w; see carve apply -h", err)
	}
	if len(p.Commits) == 0 {
		return nil, errors.New("plan: no commits; see carve apply -h")
	}
	for k, c := range p.Commits {
		if strings.TrimSpace(c.Message) == "" {
			return nil, fmt.Errorf("plan: commit %d has no message", k+1)
		}
	}
	return &p, nil
}

var idSpec = regexp.MustCompile(`^([0-9a-f]{4,40})(?::(.+))?$`)

// picked is an item a spec names, with the lines it names, nil for all.
type picked struct {
	item  *Item
	byID  bool
	lines []bool
}

func lookup(items []*Item, prefix string) []*Item {
	var found []*Item
	for _, it := range items {
		if strings.HasPrefix(it.Digest, prefix) {
			found = append(found, it)
		}
	}
	return found
}

func covers(spec, file string) bool {
	if strings.ContainsAny(spec, "*?[") {
		if !strings.Contains(spec, "/") {
			file = path.Base(file)
		}
		ok, _ := path.Match(spec, file)
		return ok
	}
	spec = strings.TrimRight(spec, "/")
	return spec == "" || spec == "." || file == spec || strings.HasPrefix(file, spec+"/")
}

func match(spec string, items []*Item) ([]picked, error) {
	if m := idSpec.FindStringSubmatch(spec); m != nil {
		found := lookup(items, m[1])
		if len(found) > 1 {
			return nil, fmt.Errorf("%s: ambiguous, %d IDs share the prefix", spec, len(found))
		}
		if len(found) == 1 {
			p := picked{item: found[0], byID: true}
			if m[2] != "" {
				lines, err := selection(found[0], spec, m[2])
				if err != nil {
					return nil, err
				}
				p.lines = lines
			}
			return []picked{p}, nil
		}
	}
	var found []picked
	for _, it := range items {
		if covers(spec, it.Change.Path) {
			found = append(found, picked{item: it})
		}
	}
	if len(found) > 0 {
		return found, nil
	}
	if i := strings.LastIndex(spec, ":"); i >= 0 {
		for _, it := range items {
			if covers(spec[:i], it.Change.Path) {
				return nil, fmt.Errorf("%s: lines go with a hunk ID, not a path", spec)
			}
		}
	}
	return nil, fmt.Errorf("%s: matches no hunk or path; rerun carve map", spec)
}

func selection(it *Item, spec, sel string) ([]bool, error) {
	if it.Kind != "hunk" {
		return nil, fmt.Errorf("%s: a %s change is taken whole", spec, it.Kind)
	}
	taken := make([]bool, it.Size())
	for _, part := range strings.Split(sel, ",") {
		lo, hi, isRange := strings.Cut(part, "-")
		a, err := strconv.Atoi(lo)
		b := a
		if err == nil && isRange {
			b, err = strconv.Atoi(hi)
		}
		if err != nil {
			return nil, fmt.Errorf("%s: lines are N, N-M or a list of them", spec)
		}
		if a < 1 || b > it.Size() || a > b {
			return nil, fmt.Errorf("%s: its lines run 1-%d", spec, it.Size())
		}
		for n := a; n <= b; n++ {
			taken[n-1] = true
		}
	}
	return taken, nil
}

// resolve sets every item's owners from the plan, or reports every way the
// plan fails at once.
func resolve(p *Plan, items []*Item) error {
	n := len(p.Commits)
	label := func(owner int) string {
		if owner == n {
			return "leave"
		}
		return fmt.Sprintf("commit %d", owner+1)
	}
	var errs []string
	type claim struct {
		owner int
		picked
	}
	claims := map[*Item][]claim{}
	add := func(owner int, specs []string) {
		for _, spec := range specs {
			found, err := match(spec, items)
			if err != nil {
				errs = append(errs, err.Error())
			}
			for _, f := range found {
				claims[f.item] = append(claims[f.item], claim{owner, f})
			}
		}
	}
	for k, c := range p.Commits {
		add(k, c.Take)
	}
	add(n, p.Leave)

	for _, it := range items {
		found := claims[it]
		if byID := slices.DeleteFunc(slices.Clone(found), func(c claim) bool { return !c.byID }); len(byID) > 0 {
			found = byID
		}
		size := it.Size()
		owners := make([][]int, size)
		for _, c := range found {
			for i := range size {
				if (c.lines == nil || c.lines[i]) && !slices.Contains(owners[i], c.owner) {
					owners[i] = append(owners[i], c.owner)
				}
			}
		}
		where := fmt.Sprintf("%s (%s)", it.ID, it.Change.Path)
		var loose []int
		for i, o := range owners {
			if len(o) == 0 {
				loose = append(loose, i+1)
			}
		}
		if len(loose) > 0 {
			part := ""
			if len(loose) < size {
				part = " lines " + ranges(loose)
			}
			errs = append(errs, fmt.Sprintf("%s%s: in no commit and not left", where, part))
		}
		for i, o := range owners {
			if len(o) > 1 {
				slices.Sort(o)
				names := make([]string, len(o))
				for j, owner := range o {
					names[j] = label(owner)
				}
				part := ""
				if size > 1 {
					part = fmt.Sprintf(" line %d", i+1)
				}
				errs = append(errs, fmt.Sprintf("%s%s: claimed by %s", where, part, strings.Join(names, " and ")))
				break
			}
		}
		it.Owners = make([]int, size)
		for i, o := range owners {
			it.Owners[i] = n
			if len(o) > 0 {
				it.Owners[i] = slices.Min(o)
			}
		}
	}

	for k, c := range p.Commits {
		for _, spec := range slices.Sorted(maps.Keys(c.Override)) {
			m := idSpec.FindStringSubmatch(spec)
			var found []*Item
			if m != nil && m[2] == "" {
				found = lookup(items, spec)
			}
			if len(found) != 1 || found[0].Kind != "hunk" {
				errs = append(errs, fmt.Sprintf("override %s: names no single hunk", spec))
				continue
			}
			h := found[0]
			switch {
			case slices.Min(h.Owners) != slices.Max(h.Owners):
				errs = append(errs, fmt.Sprintf("override %s: an overridden hunk is taken whole", spec))
			case h.Owners[0] <= k:
				errs = append(errs, fmt.Sprintf("override %s: comes in commit %d, not before %s, which takes it", spec, k+1, label(h.Owners[0])))
			}
			lines := make([][]byte, 0, len(c.Override[spec]))
			for _, line := range c.Override[spec] {
				lines = append(lines, []byte(line+"\n"))
			}
			h.Overrides = append(h.Overrides, Override{k, lines})
		}
	}
	if len(errs) > 0 {
		return errors.New(strings.Join(append([]string{"the plan does not hold:"}, errs...), "\n"))
	}
	return nil
}

func ranges(numbers []int) string {
	var parts []string
	for i := 0; i < len(numbers); {
		j := i
		for j+1 < len(numbers) && numbers[j+1] == numbers[j]+1 {
			j++
		}
		if i == j {
			parts = append(parts, strconv.Itoa(numbers[i]))
		} else {
			parts = append(parts, fmt.Sprintf("%d-%d", numbers[i], numbers[j]))
		}
		i = j + 1
	}
	return strings.Join(parts, ",")
}

type row struct{ path, what string }

// summary is what commit k takes of each path; k past the last is leave.
func summary(changes []*Change, k int) []row {
	var rows []row
	for _, c := range changes {
		old, new := 0, 0
		var parts []string
		for _, it := range c.Items() {
			if it.Kind != "hunk" {
				if it.Owners[0] == k {
					parts = append(parts, describe(it))
				}
				continue
			}
			for i, owner := range it.Owners {
				if owner == k && it.Lines[i].Sign == '-' {
					old++
				} else if owner == k {
					new++
				}
			}
			if slices.ContainsFunc(it.Overrides, func(o Override) bool { return o.Commit == k }) {
				parts = append(parts, "interim "+it.ID)
			}
		}
		if what := joinSome(", ", append([]string{counts(old, new)}, parts...)...); what != "" {
			rows = append(rows, row{c.Path, what})
		}
	}
	return rows
}
