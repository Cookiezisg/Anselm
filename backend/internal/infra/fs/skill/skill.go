// Package skill is the file-backed store for the skill domain — one directory per skill
// (~/.forgify/workspaces/<wsID>/skills/<name>/SKILL.md). Pure on-demand: every List rescans
// the directory, no cache / no fingerprint / no watcher goroutine. Mirrors memory's infra/fs
// pattern with a directory (not a flat file) per entry so future references/ assets
// can live alongside SKILL.md.
//
// Package skill 是 skill domain 的文件式 store——每 skill 一个目录
// （~/.forgify/workspaces/<wsID>/skills/<name>/SKILL.md）。纯按需：每次 List 现扫目录，
// 无缓存 / 无 fingerprint / 无 watcher goroutine。复用 memory 的 infra/fs 范式，
// 每条用目录（非扁平文件）以便未来附加 references/ assets。
package skill

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Store reads/writes SKILL.md under a base root; base is ~/.forgify (boot-injected, temp in tests).
//
// Store 在 base 根下读写 SKILL.md；base 是 ~/.forgify（boot 注入，测试用 temp）。
type Store struct {
	base string
}

func New(base string) *Store { return &Store{base: base} }

var _ skilldomain.Repository = (*Store)(nil)

const skillFileName = "SKILL.md"

// dir resolves the current workspace's skills bucket from ctx.
//
// dir 据 ctx 解析当前 workspace 的 skills 桶目录。
func (s *Store) dir(ctx context.Context) (string, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return "", err
	}
	return filepath.Join(s.base, "workspaces", wsID, "skills"), nil
}

// skillDir is one skill's directory; name validated as a slug (= path-traversal guard).
//
// skillDir 是单个 skill 的目录；name 校验为 slug（= 路径穿越守卫）。
func (s *Store) skillDir(ctx context.Context, name string) (string, error) {
	if !skilldomain.IsValidName(name) {
		return "", skilldomain.ErrInvalidName
	}
	dir, err := s.dir(ctx)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, name), nil
}

func (s *Store) skillFile(ctx context.Context, name string) (string, error) {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, skillFileName), nil
}

// List rescans the skills directory each call (pure on-demand). Missing dir → empty list;
// unparseable skills are skipped rather than failing the whole list.
//
// List 每次现扫 skills 目录（纯按需）。缺目录 → 空列表；坏 skill 跳过而非整列失败。
func (s *Store) List(ctx context.Context, filter skilldomain.ListFilter) ([]*skilldomain.Skill, error) {
	dir, err := s.dir(ctx)
	if err != nil {
		return nil, err
	}
	entries, err := os.ReadDir(dir)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("skillfs.List: %w", err)
	}
	var out []*skilldomain.Skill
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		name := e.Name()
		sk, rerr := s.readSkill(filepath.Join(dir, name, skillFileName), name, false)
		if rerr != nil {
			continue // 坏文件跳过
		}
		if filter.Source != "" && sk.Source != filter.Source {
			continue
		}
		out = append(out, sk)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out, nil
}

// Get reads one skill including its body. Missing → ErrNotFound.
//
// Get 读单个 skill（含 body）。缺失 → ErrNotFound。
func (s *Store) Get(ctx context.Context, name string) (*skilldomain.Skill, error) {
	p, err := s.skillFile(ctx, name)
	if err != nil {
		return nil, err
	}
	sk, rerr := s.readSkill(p, name, true)
	if os.IsNotExist(rerr) {
		return nil, skilldomain.ErrNotFound
	}
	if rerr != nil {
		return nil, rerr // 已是 domain 错误（ErrInvalidFrontmatter/ErrBodyTooLarge）或原始 os 错误
	}
	return sk, nil
}

// readSkill parses one SKILL.md. dirName is the fallback name when frontmatter omits one.
//
// readSkill 解析单个 SKILL.md。dirName 是 frontmatter 缺 name 时的兜底。
func (s *Store) readSkill(path, dirName string, withBody bool) (*skilldomain.Skill, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err // 含 NotExist，交上层判别
	}
	if len(raw) > skilldomain.MaxBodyBytes {
		return nil, skilldomain.ErrBodyTooLarge
	}
	fm, body, perr := parseFrontmatter(raw)
	if perr != nil {
		return nil, skilldomain.ErrInvalidFrontmatter.WithCause(perr)
	}
	name := strings.TrimSpace(fm.Name)
	if name == "" {
		name = dirName
	}
	sk := &skilldomain.Skill{
		Name:        name,
		Description: fm.Description,
		Source:      fm.Source,
		Context:     fm.Context,
		Frontmatter: fm,
	}
	if withBody {
		sk.Body = strings.TrimSpace(body)
	}
	if info, serr := os.Stat(path); serr == nil {
		sk.UpdatedAt = info.ModTime().UTC()
	}
	return sk, nil
}

// Save writes SKILL.md atomically (.tmp + rename) under the skill's directory.
//
// Save 用 .tmp + rename 原子写 skill 目录下的 SKILL.md。
func (s *Store) Save(ctx context.Context, name string, fm skilldomain.Frontmatter, body string) error {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return err
	}
	if mkErr := os.MkdirAll(dir, 0o755); mkErr != nil {
		return fmt.Errorf("skillfs.Save mkdir: %w", mkErr)
	}
	content := renderFrontmatter(fm) + strings.TrimSpace(body) + "\n"
	target := filepath.Join(dir, skillFileName)
	tmp := target + ".tmp"
	if wErr := os.WriteFile(tmp, []byte(content), 0o644); wErr != nil {
		return fmt.Errorf("skillfs.Save write: %w", wErr)
	}
	if rErr := os.Rename(tmp, target); rErr != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("skillfs.Save rename: %w", rErr)
	}
	return nil
}

// Delete removes the entire skill directory. Missing → ErrNotFound.
//
// Delete 删除整个 skill 目录。缺失 → ErrNotFound。
func (s *Store) Delete(ctx context.Context, name string) error {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return err
	}
	if _, statErr := os.Stat(dir); os.IsNotExist(statErr) {
		return skilldomain.ErrNotFound
	}
	if rmErr := os.RemoveAll(dir); rmErr != nil {
		return fmt.Errorf("skillfs.Delete: %w", rmErr)
	}
	return nil
}

// Exists reports whether a skill's SKILL.md is present (used by Create's conflict check).
//
// Exists 报告 skill 的 SKILL.md 是否存在（Create 冲突检查用）。
func (s *Store) Exists(ctx context.Context, name string) (bool, error) {
	p, err := s.skillFile(ctx, name)
	if err != nil {
		return false, err
	}
	_, statErr := os.Stat(p)
	if os.IsNotExist(statErr) {
		return false, nil
	}
	if statErr != nil {
		return false, fmt.Errorf("skillfs.Exists: %w", statErr)
	}
	return true, nil
}
