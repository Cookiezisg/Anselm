// mutate.go — Service.Create / Replace / Delete / Body. The disk-write
// counterparts to scan.go's read path. All three mutations write to
// ~/.forgify/skills/<name>/SKILL.md, then trigger a Scan + SSE event
// (rescan ensures the in-memory cache reflects what we just wrote
// without waiting for fsnotify; redundant in production but keeps the
// caller's response synchronous).
//
// mutate.go ——Service.Create / Replace / Delete / Body。scan.go 读路径
// 的 disk 写对应。三个变更都写到 ~/.forgify/skills/<name>/SKILL.md 后
// 触发 Scan + SSE（重扫保证内存 cache 反映刚写入，不等 fsnotify；生产里
// 冗余但让调用方响应同步）。
package skill

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"

	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
)

// nameRegexp validates the on-disk skill name (used in directory
// path). Lower-case, digits, hyphens; max 64 chars. Mirrors what
// users could write by hand without surprises.
//
// nameRegexp 校验磁盘 skill 名（目录路径）。小写、数字、连字符；
// 最长 64。和手写习惯一致。
var nameRegexp = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,63}$`)

// Body returns the raw SKILL.md bytes for one skill. Used by the
// GET /skills/{name}/body endpoint (the body editor pulls it on demand
// — the metadata cache deliberately doesn't include body).
//
// Body 返单个 skill 的 SKILL.md 原始字节。供 GET /skills/{name}/body
// 端点（body 编辑器按需拉——元数据 cache 故意不含 body）。
func (s *Service) Body(_ context.Context, name string) ([]byte, error) {
	s.mu.RLock()
	sk, ok := s.skills[name]
	s.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("skillapp.Body: %w: %q", skilldomain.ErrSkillNotFound, name)
	}
	body, err := os.ReadFile(sk.BodyPath)
	if err != nil {
		return nil, fmt.Errorf("skillapp.Body %s: %w", name, err)
	}
	return body, nil
}

// Create writes a brand-new SKILL.md under ~/.forgify/skills/<name>/.
// Validates name format + non-conflict, marshals frontmatter to YAML,
// writes the file, then triggers Scan so the cache reflects it
// immediately. Conflict (existing skill) returns ErrNameConflict so
// the UI can prompt for "replace via PUT".
//
// Create 写全新 SKILL.md 到 ~/.forgify/skills/<name>/。校验 name 格式 +
// 不冲突，marshal frontmatter 为 YAML，写文件，触发 Scan。冲突返
// ErrNameConflict，UI 弹"PUT 替换"。
func (s *Service) Create(ctx context.Context, name string, fm skilldomain.Frontmatter, body string) (*skilldomain.Skill, error) {
	if err := validateName(name); err != nil {
		return nil, err
	}
	// Validate frontmatter content the same way Scan would, so we don't
	// write a file Scan will reject.
	// 同 Scan 校验 frontmatter，避免写入后 Scan 拒。
	if err := validateFrontmatter(fm); err != nil {
		return nil, err
	}
	if err := validateBodySize(body); err != nil {
		return nil, err
	}

	dir := filepath.Join(s.skillsDir, name)
	if _, err := os.Stat(dir); err == nil {
		return nil, fmt.Errorf("skillapp.Create: %w: %q", skilldomain.ErrNameConflict, name)
	} else if !errors.Is(err, fs.ErrNotExist) {
		return nil, fmt.Errorf("skillapp.Create: stat: %w", err)
	}

	if err := writeSkillDir(dir, fm, body); err != nil {
		return nil, fmt.Errorf("skillapp.Create %s: %w", name, err)
	}
	if err := s.Scan(ctx); err != nil {
		return nil, fmt.Errorf("skillapp.Create %s: rescan: %w", name, err)
	}
	return s.Get(ctx, name)
}

// Replace overwrites an existing SKILL.md with new frontmatter + body.
// Returns ErrSkillNotFound if the name doesn't exist (caller should
// POST instead of PUT to create).
//
// Replace 用新 frontmatter + body 覆盖已存在 SKILL.md。name 不存在返
// ErrSkillNotFound（调用方应改 POST 而非 PUT）。
func (s *Service) Replace(ctx context.Context, name string, fm skilldomain.Frontmatter, body string) (*skilldomain.Skill, error) {
	if err := validateName(name); err != nil {
		return nil, err
	}
	if err := validateFrontmatter(fm); err != nil {
		return nil, err
	}
	if err := validateBodySize(body); err != nil {
		return nil, err
	}

	dir := filepath.Join(s.skillsDir, name)
	if _, err := os.Stat(dir); errors.Is(err, fs.ErrNotExist) {
		return nil, fmt.Errorf("skillapp.Replace: %w: %q", skilldomain.ErrSkillNotFound, name)
	} else if err != nil {
		return nil, fmt.Errorf("skillapp.Replace: stat: %w", err)
	}

	if err := writeSkillDir(dir, fm, body); err != nil {
		return nil, fmt.Errorf("skillapp.Replace %s: %w", name, err)
	}
	if err := s.Scan(ctx); err != nil {
		return nil, fmt.Errorf("skillapp.Replace %s: rescan: %w", name, err)
	}
	return s.Get(ctx, name)
}

// Delete removes the entire ~/.forgify/skills/<name>/ directory. ErrSkillNotFound
// when the name isn't loaded. Returns nil on success — caller writes
// 204 No Content.
//
// Delete 移除整个 ~/.forgify/skills/<name>/ 目录。name 未加载返
// ErrSkillNotFound。成功返 nil；调用方写 204。
func (s *Service) Delete(ctx context.Context, name string) error {
	if err := validateName(name); err != nil {
		return err
	}
	s.mu.RLock()
	_, ok := s.skills[name]
	s.mu.RUnlock()
	if !ok {
		return fmt.Errorf("skillapp.Delete: %w: %q", skilldomain.ErrSkillNotFound, name)
	}
	dir := filepath.Join(s.skillsDir, name)
	if err := os.RemoveAll(dir); err != nil {
		return fmt.Errorf("skillapp.Delete %s: %w", name, err)
	}
	if err := s.Scan(ctx); err != nil {
		return fmt.Errorf("skillapp.Delete %s: rescan: %w", name, err)
	}
	return nil
}

// ── helpers ──────────────────────────────────────────────────────────

// validateName enforces the on-disk name regex. Returns ErrInvalidName
// (422) when malformed.
//
// validateName 强制磁盘 name 正则。畸形返 ErrInvalidName (422)。
func validateName(name string) error {
	if !nameRegexp.MatchString(name) {
		return fmt.Errorf("skillapp.validateName: %w: %q (must match %s)",
			skilldomain.ErrInvalidName, name, nameRegexp.String())
	}
	return nil
}

// validateBodySize gates ErrBodyTooLarge before we write — symmetric
// with the Scan-time check so we never write a file Scan will reject.
//
// validateBodySize 写前检 ErrBodyTooLarge——与 Scan-time 对称，避免写
// 入后 Scan 拒。
func validateBodySize(body string) error {
	// Body alone, plus frontmatter + fences, must fit under MaxBodyBytes.
	// Rough headroom: assume frontmatter ≤ 2 KB; warn if body alone
	// already past the cap.
	// body 单独 + frontmatter + 围栏要 ≤ MaxBodyBytes。粗估 frontmatter
	// ≤ 2 KB；body 单独超 cap 直接拒。
	if len(body) > skilldomain.MaxBodyBytes {
		return fmt.Errorf("skillapp.validateBodySize: %w: body %d bytes (cap %d)",
			skilldomain.ErrBodyTooLarge, len(body), skilldomain.MaxBodyBytes)
	}
	return nil
}

// writeSkillDir mkdirs the skill directory and writes SKILL.md atomically
// (write to .tmp, rename). The atomic write means a concurrent Scan
// either sees the old or the new file, never a partially-written one.
//
// writeSkillDir mkdir skill 目录 + 原子写 SKILL.md（写 .tmp + rename）。
// 让并发 Scan 见到的要么是旧版要么新版，不会半截。
func writeSkillDir(dir string, fm skilldomain.Frontmatter, body string) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", dir, err)
	}
	yamlBytes, err := yaml.Marshal(&fm)
	if err != nil {
		return fmt.Errorf("marshal frontmatter: %w", err)
	}
	content := "---\n" + string(yamlBytes) + "---\n" + body
	if !strings.HasSuffix(content, "\n") {
		content += "\n"
	}

	target := filepath.Join(dir, "SKILL.md")
	tmp := target + ".tmp"
	if err := os.WriteFile(tmp, []byte(content), 0o644); err != nil {
		return fmt.Errorf("write tmp: %w", err)
	}
	if err := os.Rename(tmp, target); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("rename: %w", err)
	}
	return nil
}
