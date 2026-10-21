package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type repo struct{ root string }

func open(dir string) (*repo, error) {
	r := &repo{}
	root, err := r.out(dir, "rev-parse", "--show-toplevel")
	if err != nil {
		return nil, err
	}
	r.root = root
	return r, nil
}

func (r *repo) git(dir string, stdin []byte, args ...string) ([]byte, error) {
	cmd := exec.Command("git", append([]string{"--literal-pathspecs"}, args...)...)
	cmd.Dir = dir
	if stdin != nil {
		cmd.Stdin = bytes.NewReader(stdin)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = err.Error()
		}
		return stdout.Bytes(), fmt.Errorf("git %s: %s", args[0], msg)
	}
	return stdout.Bytes(), nil
}

func (r *repo) out(dir string, args ...string) (string, error) {
	out, err := r.git(dir, nil, args...)
	return strings.TrimSpace(string(out)), err
}

// idle refuses a repository in the middle of a merge, rebase or the like.
func (r *repo) idle() error {
	for _, s := range []struct{ file, what string }{
		{"MERGE_HEAD", "merge"},
		{"CHERRY_PICK_HEAD", "cherry-pick"},
		{"REVERT_HEAD", "revert"},
		{"rebase-merge", "rebase"},
		{"rebase-apply", "rebase"},
	} {
		p, err := r.out(r.root, "rev-parse", "--git-path", s.file)
		if err != nil {
			return err
		}
		if !filepath.IsAbs(p) {
			p = filepath.Join(r.root, p)
		}
		if _, err := os.Stat(p); err == nil {
			return fmt.Errorf("a %s is in progress", s.what)
		}
	}
	return nil
}

// unmoved checks that the working tree still holds what carve read from it.
func (r *repo) unmoved(changes []*Change) error {
	var moved []string
	for _, c := range changes {
		now, err := current(r.root, c.Path)
		if err != nil || !sameFile(now, c.Final) {
			moved = append(moved, c.Path)
		}
	}
	if len(moved) > 0 {
		return fmt.Errorf("the working tree changed while carving: %s", strings.Join(moved, ", "))
	}
	return nil
}

// cache holds commits that passed, keyed by parent, tree, message and check.
type cache struct {
	path    string
	entries map[string]string
}

func (r *repo) cache() (*cache, error) {
	common, err := r.out(r.root, "rev-parse", "--path-format=absolute", "--git-common-dir")
	if err != nil {
		return nil, err
	}
	c := &cache{filepath.Join(common, "carve-cache"), map[string]string{}}
	data, err := os.ReadFile(c.path)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	for _, line := range strings.Split(string(data), "\n") {
		if key, sha, ok := strings.Cut(line, " "); ok {
			c.entries[key] = sha
		}
	}
	return c, nil
}

func (c *cache) get(r *repo, key string) string {
	sha := c.entries[key]
	if sha == "" {
		return ""
	}
	if _, err := r.git(r.root, nil, "cat-file", "-e", sha+"^{commit}"); err != nil {
		return ""
	}
	return sha
}

func (c *cache) put(key, sha string) error {
	f, err := os.OpenFile(c.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(f, "%s %s\n", key, sha)
	return errors.Join(err, f.Close())
}

func put(root, path string, f *File) error {
	target := filepath.Join(root, path)
	if err := os.Remove(target); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	if f == nil {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	if f.Mode == "120000" {
		return os.Symlink(string(f.Data), target)
	}
	perm := fs.FileMode(0o644)
	if f.Mode == "100755" {
		perm = 0o755
	}
	if err := os.WriteFile(target, f.Data, perm); err != nil {
		return err
	}
	return os.Chmod(target, perm)
}

// runTail runs a command, and on failure reports the tail of its output.
func runTail(what, dir string, stdin []byte, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	if stdin != nil {
		cmd.Stdin = bytes.NewReader(stdin)
	}
	output, err := cmd.CombinedOutput()
	if err == nil {
		return nil
	}
	text := strings.TrimSpace(strings.ToValidUTF8(string(output), "�"))
	if text == "" {
		text = err.Error()
	}
	lines := strings.Split(text, "\n")
	return fmt.Errorf("%s failed:\n%s", what, strings.Join(lines[max(0, len(lines)-40):], "\n"))
}

// build makes the commits on top of head in a scratch worktree and returns
// the last; the branch is left to the caller.
func (r *repo) build(changes []*Change, commits []Commit, steps [][]*File, head, verify string, stdout io.Writer) (string, error) {
	cache, err := r.cache()
	if err != nil {
		return "", err
	}
	scratch, err := os.MkdirTemp("", "carve-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(scratch)
	if _, err := r.git(r.root, nil, "worktree", "add", "--detach", "-q", scratch, head); err != nil {
		return "", err
	}
	defer r.git(r.root, nil, "worktree", "remove", "--force", scratch)

	parent := head
	for k, commit := range commits {
		what := fmt.Sprintf("commit %d", k+1)
		var touched []string
		for i, c := range changes {
			if !sameFile(steps[k+1][i], steps[k][i]) {
				if err := put(scratch, c.Path, steps[k+1][i]); err != nil {
					return "", err
				}
				touched = append(touched, c.Path)
			}
		}
		paths := []byte(strings.Join(touched, "\x00"))
		if _, err := r.git(scratch, paths, "add", "-A", "--pathspec-from-file=-", "--pathspec-file-nul"); err != nil {
			return "", err
		}
		tree, err := r.out(scratch, "write-tree")
		if err != nil {
			return "", err
		}
		message := strings.TrimSpace(commit.Message) + "\n"
		sum := sha256.Sum256([]byte(strings.Join([]string{parent, tree, message, verify}, "\x00")))
		key := hex.EncodeToString(sum[:])
		sha := cache.get(r, key)
		cached := sha != ""
		if cached {
			if _, err := r.git(scratch, nil, "reset", "-q", "--soft", sha); err != nil {
				return "", err
			}
		} else {
			if err := runTail(what+": git commit", scratch, []byte(message), "git", "commit", "-q", "-F", "-"); err != nil {
				return "", err
			}
			dirty, err := r.git(scratch, nil, "status", "--porcelain", "--untracked-files=no")
			if err != nil {
				return "", err
			}
			if got, _ := r.out(scratch, "rev-parse", "HEAD^{tree}"); len(dirty) > 0 || got != tree {
				return "", fmt.Errorf("%s: a hook changed its files", what)
			}
			if verify != "" {
				if err := runTail(what+": "+verify, scratch, nil, "sh", "-c", verify); err != nil {
					return "", err
				}
			}
			if sha, err = r.out(scratch, "rev-parse", "HEAD"); err != nil {
				return "", err
			}
			if err := cache.put(key, sha); err != nil {
				return "", err
			}
		}
		tag := ""
		if cached {
			tag = "  (cached)"
		}
		fmt.Fprintf(stdout, "%d/%d  %s  %s%s\n", k+1, len(commits), sha[:7], subject(message), tag)
		parent = sha
	}
	return parent, nil
}
