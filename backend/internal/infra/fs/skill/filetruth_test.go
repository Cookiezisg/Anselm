package skill

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

// B1「文件即真相」电池（WRK-076）：保真往返 / 两态 allowed-tools / 逐字节 SaveRaw /
// 小写回退 / files CRUD + 穿越矩阵 + symlink 逃逸 + 护栏。

func TestStore_StructuredSavePreservesUnknownKeysAndOrder(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	raw := `---
license: MIT
name: fancy
x-vendor-thing: keepme
description: old desc
metadata:
  author: someone
  version: "1.0"
---
Body here.
`
	if err := st.SaveRaw(ctx, "fancy", []byte(raw)); err != nil {
		t.Fatalf("seed: %v", err)
	}
	// 结构化面只改 description——license / 未知键 / metadata / 键序必须幸存。
	fm := skilldomain.Frontmatter{Name: "fancy", Description: "new desc", Source: "user"}
	if err := st.Save(ctx, "fancy", fm, "Body here."); err != nil {
		t.Fatalf("structured save: %v", err)
	}
	got, err := os.ReadFile(filepath.Join(st.base, "workspaces", "ws_1", "skills", "fancy", "SKILL.md"))
	if err != nil {
		t.Fatalf("read back: %v", err)
	}
	text := string(got)
	for _, want := range []string{"license: MIT", "x-vendor-thing: keepme", "author: someone", `version: "1.0"`, "description: new desc"} {
		if !strings.Contains(text, want) {
			t.Fatalf("fidelity lost %q in:\n%s", want, text)
		}
	}
	if strings.Contains(text, "old desc") {
		t.Fatalf("stale description survived:\n%s", text)
	}
	// 键序：license 仍在 name 之前（手术不重排）。
	if strings.Index(text, "license:") > strings.Index(text, "name:") {
		t.Fatalf("key order not preserved:\n%s", text)
	}
	// typed 视图也读得到规范核心字段。
	sk, err := st.Get(ctx, "fancy")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if sk.Frontmatter.License != "MIT" || sk.Frontmatter.Metadata["author"] != "someone" {
		t.Fatalf("typed view missing spec-core fields: %+v", sk.Frontmatter)
	}
}

func TestStore_DuplicateKeysAreMalformed(t *testing.T) {
	// yaml v3 在 Unmarshal 即拒重复 mapping key（v3.0.4 实测）——重复键文件 = 坏件：
	// SaveRaw 拒收；手写落盘的经 Get 大声失败、List 跳过。
	base := t.TempDir()
	st := New(base)
	ctx := ctxWS("ws_1")
	raw := "---\nname: dup\ndescription: first\ndescription: second\n---\nb\n"
	if err := st.SaveRaw(ctx, "dup", []byte(raw)); !errors.Is(err, skilldomain.ErrInvalidFrontmatter) {
		t.Fatalf("duplicate-key raw should be InvalidFrontmatter, got %v", err)
	}
	dir := filepath.Join(base, "workspaces", "ws_1", "skills", "dup")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "SKILL.md"), []byte(raw), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	if _, err := st.Get(ctx, "dup"); !errors.Is(err, skilldomain.ErrInvalidFrontmatter) {
		t.Fatalf("hand-written duplicate-key file should fail loud on Get, got %v", err)
	}
	items, err := st.List(ctx, skilldomain.ListFilter{})
	if err != nil || len(items) != 0 {
		t.Fatalf("duplicate-key file must be skipped by List: n=%d err=%v", len(items), err)
	}
}

func TestStore_AllowedToolsScalarFormAccepted(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	raw := "---\nname: spacey\ndescription: d\nallowed-tools: Read Bash fn_x\n---\nb\n"
	if err := st.SaveRaw(ctx, "spacey", []byte(raw)); err != nil {
		t.Fatalf("seed: %v", err)
	}
	sk, err := st.Get(ctx, "spacey")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	want := []string{"Read", "Bash", "fn_x"}
	if len(sk.Frontmatter.AllowedTools) != len(want) {
		t.Fatalf("scalar allowed-tools not split: %+v", sk.Frontmatter.AllowedTools)
	}
	for i, w := range want {
		if sk.Frontmatter.AllowedTools[i] != w {
			t.Fatalf("scalar allowed-tools mismatch at %d: %+v", i, sk.Frontmatter.AllowedTools)
		}
	}
	// D4 写回归一：结构化 Save 编辑该键 → 原文变 YAML 块列表（不再是空格标量）。
	sk.Frontmatter.AllowedTools = append(sk.Frontmatter.AllowedTools, "hd_y")
	if err := st.Save(ctx, "spacey", sk.Frontmatter, sk.Body); err != nil {
		t.Fatalf("structured save: %v", err)
	}
	got, _ := os.ReadFile(filepath.Join(st.base, "workspaces", "ws_1", "skills", "spacey", "SKILL.md"))
	if !strings.Contains(string(got), "- hd_y") || strings.Contains(string(got), "allowed-tools: Read Bash") {
		t.Fatalf("edited allowed-tools must normalize to a block list:\n%s", got)
	}
}

func TestStore_SaveRawVerbatimBytes(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	raw := []byte("---\nname: verbatim\ndescription: d\n---\n\n  leading and trailing kept  \n\n\n")
	if err := st.SaveRaw(ctx, "verbatim", raw); err != nil {
		t.Fatalf("save raw: %v", err)
	}
	got, err := os.ReadFile(filepath.Join(st.base, "workspaces", "ws_1", "skills", "verbatim", "SKILL.md"))
	if err != nil {
		t.Fatalf("read back: %v", err)
	}
	if !bytes.Equal(got, raw) {
		t.Fatalf("SaveRaw must be byte-verbatim:\n got %q\nwant %q", got, raw)
	}
}

func TestStore_LowercaseManifestFallback(t *testing.T) {
	base := t.TempDir()
	st := New(base)
	ctx := ctxWS("ws_1")
	dir := filepath.Join(base, "workspaces", "ws_1", "skills", "lower")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "skill.md"), []byte("---\nname: lower\ndescription: d\n---\nb\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	if ok, _ := st.Exists(ctx, "lower"); !ok {
		t.Fatal("lowercase skill.md must count as existing")
	}
	sk, err := st.Get(ctx, "lower")
	if err != nil || sk.Description != "d" {
		t.Fatalf("lowercase manifest must be readable: %+v err=%v", sk, err)
	}
}

func TestStore_Files_CRUD(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	if err := st.Save(ctx, "pdf", skilldomain.Frontmatter{Name: "pdf", Description: "d"}, "b"); err != nil {
		t.Fatalf("seed: %v", err)
	}
	if err := st.WriteFile(ctx, "pdf", "references/deep/notes.md", []byte("# notes")); err != nil {
		t.Fatalf("write file: %v", err)
	}
	files, err := st.ListFiles(ctx, "pdf")
	if err != nil {
		t.Fatalf("list files: %v", err)
	}
	if len(files) != 2 || files[0].Path != "SKILL.md" || files[1].Path != "references/deep/notes.md" {
		t.Fatalf("file list mismatch: %+v", files)
	}
	data, err := st.ReadFile(ctx, "pdf", "references/deep/notes.md")
	if err != nil || string(data) != "# notes" {
		t.Fatalf("read file: %q err=%v", data, err)
	}
	// 清单经 files 面同样可读（用户修坏件的通道）。
	if _, err := st.ReadFile(ctx, "pdf", "SKILL.md"); err != nil {
		t.Fatalf("manifest must be readable via files surface: %v", err)
	}
	if err := st.DeleteFile(ctx, "pdf", "references/deep/notes.md"); err != nil {
		t.Fatalf("delete file: %v", err)
	}
	if _, err := st.ReadFile(ctx, "pdf", "references/deep/notes.md"); !errors.Is(err, skilldomain.ErrFileNotFound) {
		t.Fatalf("deleted file should be FileNotFound, got %v", err)
	}
	if err := st.DeleteFile(ctx, "pdf", "references/deep/notes.md"); !errors.Is(err, skilldomain.ErrFileNotFound) {
		t.Fatalf("double delete should be FileNotFound, got %v", err)
	}
}

func TestStore_Files_TraversalMatrix(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	if err := st.Save(ctx, "guard", skilldomain.Frontmatter{Name: "guard", Description: "d"}, "b"); err != nil {
		t.Fatalf("seed: %v", err)
	}
	bad := []string{"", ".", "..", "../pwn", "/abs", "a/../../pwn", `a\pwn`, "./..", "references/../../pwn"}
	for _, rel := range bad {
		if _, err := st.ReadFile(ctx, "guard", rel); !errors.Is(err, skilldomain.ErrFilePathInvalid) {
			t.Fatalf("ReadFile(%q) must be FilePathInvalid, got %v", rel, err)
		}
		if err := st.WriteFile(ctx, "guard", rel, []byte("x")); !errors.Is(err, skilldomain.ErrFilePathInvalid) {
			t.Fatalf("WriteFile(%q) must be FilePathInvalid, got %v", rel, err)
		}
		if err := st.DeleteFile(ctx, "guard", rel); !errors.Is(err, skilldomain.ErrFilePathInvalid) {
			t.Fatalf("DeleteFile(%q) must be FilePathInvalid, got %v", rel, err)
		}
	}
	// 目录外零产物。
	if _, err := os.Stat(filepath.Join(st.base, "pwn")); !os.IsNotExist(err) {
		t.Fatal("traversal write must leave no artifact outside the skill dir")
	}
}

func TestStore_Files_SymlinkEscapeBlocked(t *testing.T) {
	base := t.TempDir()
	st := New(base)
	ctx := ctxWS("ws_1")
	if err := st.Save(ctx, "sly", skilldomain.Frontmatter{Name: "sly", Description: "d"}, "b"); err != nil {
		t.Fatalf("seed: %v", err)
	}
	secret := filepath.Join(base, "secret.txt")
	if err := os.WriteFile(secret, []byte("top secret"), 0o644); err != nil {
		t.Fatalf("write secret: %v", err)
	}
	link := filepath.Join(base, "workspaces", "ws_1", "skills", "sly", "link.txt")
	if err := os.Symlink(secret, link); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	data, err := st.ReadFile(ctx, "sly", "link.txt")
	if err == nil {
		t.Fatalf("symlink escape must be blocked, read %q", data)
	}
}

func TestStore_Files_SizeGuard(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	if err := st.Save(ctx, "big", skilldomain.Frontmatter{Name: "big", Description: "d"}, "b"); err != nil {
		t.Fatalf("seed: %v", err)
	}
	huge := bytes.Repeat([]byte("a"), skilldomain.MaxFileBytes+1)
	if err := st.WriteFile(ctx, "big", "assets/huge.bin", huge); !errors.Is(err, skilldomain.ErrFileTooLarge) {
		t.Fatalf("oversized write should be FileTooLarge, got %v", err)
	}
}

func TestStore_Files_MissingSkill(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	if _, err := st.ListFiles(ctx, "ghost"); !errors.Is(err, skilldomain.ErrNotFound) {
		t.Fatalf("ListFiles on missing skill should be NotFound, got %v", err)
	}
	if _, err := st.ReadFile(ctx, "ghost", "a.md"); !errors.Is(err, skilldomain.ErrNotFound) {
		t.Fatalf("ReadFile on missing skill should be NotFound, got %v", err)
	}
	if err := st.WriteFile(ctx, "ghost", "a.md", []byte("x")); !errors.Is(err, skilldomain.ErrNotFound) {
		t.Fatalf("WriteFile on missing skill should be NotFound, got %v", err)
	}
	if err := st.DeleteFile(ctx, "ghost", "a.md"); !errors.Is(err, skilldomain.ErrNotFound) {
		t.Fatalf("DeleteFile on missing skill should be NotFound, got %v", err)
	}
}
