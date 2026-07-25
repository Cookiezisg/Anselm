package gitinfo

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// gitRepo initializes a real repository with one commit, skipping the test when no git binary exists
// (the probe's whole contract is that its absence is not an error, so the TEST must not invent one).
//
// gitRepo 初始化一个真仓库并提交一次;无 git 二进制时 skip(探针的全部契约就是「它不存在不是错误」,
// 故**测试**不该自己造一个错误)。
func gitRepo(t *testing.T) string {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git binary — gitinfo's contract is that this is not an error")
	}
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init", "--initial-branch=main"},
		{"config", "user.email", "t@example.com"},
		{"config", "user.name", "t"},
	} {
		cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("a\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "."}, {"commit", "-m", "init"}} {
		cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	return dir
}

func TestStatus_CleanThenDirty(t *testing.T) {
	dir := gitRepo(t)
	ctx := context.Background()

	branch, dirty, isRepo := Status(ctx, dir)
	if !isRepo || branch != "main" || dirty {
		t.Fatalf("fresh commit: got branch=%q dirty=%v isRepo=%v, want main/false/true", branch, dirty, isRepo)
	}
	if b, ok := Branch(ctx, dir); !ok || b != "main" {
		t.Fatalf("Branch = %q,%v want main,true", b, ok)
	}

	// An UNTRACKED file counts as dirty: the residency dot means "there is work here that isn't
	// committed", and a brand-new file is exactly that.
	// **未跟踪**文件算脏:驻地那个点的意思是「这里有没提交的活」,全新文件正是如此。
	if err := os.WriteFile(filepath.Join(dir, "new.txt"), []byte("n\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, dirty, _ := Status(ctx, dir); !dirty {
		t.Error("an untracked file must read dirty")
	}
	if err := os.Remove(filepath.Join(dir, "new.txt")); err != nil {
		t.Fatal(err)
	}
	// A MODIFIED tracked file too. 已跟踪文件被改亦然。
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("changed\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, dirty, _ := Status(ctx, dir); !dirty {
		t.Error("a modified tracked file must read dirty")
	}
}

// TestStatus_NotARepoAndMissingDir: every flavour of absence answers isRepo=false rather than an
// error — the endpoint and the system prompt both depend on that.
//
// TestStatus_NotARepoAndMissingDir:每种「不存在」都答 isRepo=false 而非报错——端点与 system prompt
// 都靠这一点。
func TestStatus_NotARepoAndMissingDir(t *testing.T) {
	ctx := context.Background()
	plain := t.TempDir()
	for _, dir := range []string{plain, filepath.Join(plain, "gone"), ""} {
		if _, _, isRepo := Status(ctx, dir); isRepo {
			t.Errorf("Status(%q) reported a repo", dir)
		}
		if _, ok := Branch(ctx, dir); ok {
			t.Errorf("Branch(%q) reported a repo", dir)
		}
	}
}

// TestStatus_DetachedHeadNormalized: porcelain=v2 says "(detached)" and rev-parse says "HEAD"; both
// probes must hand the UI the SAME word or the menu shows two different things for one state.
//
// TestStatus_DetachedHeadNormalized:porcelain=v2 说 "(detached)"、rev-parse 说 "HEAD";两个探针必须
// 给 UI **同一个**词,否则同一种状态在菜单里会显示成两样。
func TestStatus_DetachedHeadNormalized(t *testing.T) {
	dir := gitRepo(t)
	ctx := context.Background()
	if out, err := exec.Command("git", "-C", dir, "checkout", "--detach", "HEAD").CombinedOutput(); err != nil {
		t.Fatalf("detach: %v\n%s", err, out)
	}
	branch, _, isRepo := Status(ctx, dir)
	if !isRepo || branch != DetachedBranch {
		t.Fatalf("detached Status branch = %q (isRepo=%v), want %q", branch, isRepo, DetachedBranch)
	}
	b, ok := Branch(ctx, dir)
	if !ok || b != DetachedBranch {
		t.Fatalf("detached Branch = %q,%v want %q,true", b, ok, DetachedBranch)
	}
}
