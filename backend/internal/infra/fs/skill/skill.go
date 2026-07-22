// Package skill is the file-backed store for the skill domain — one directory per skill
// (~/.anselm/workspaces/<wsID>/skills/<name>/SKILL.md plus any bundled files). Pure on-demand:
// every List rescans the directory, no cache / no fingerprint / no watcher goroutine. The
// DIRECTORY IS THE TRUTH (WRK-076): reads never write back, the structured Save patches the
// raw YAML node tree (unknown keys and key order survive), SaveRaw lands bytes verbatim, and
// bundled files are reached only through an os.Root handle (traversal/symlink/TOCTOU guarded).
//
// Package skill 是 skill domain 的文件式 store——每 skill 一个目录
// （~/.anselm/workspaces/<wsID>/skills/<name>/SKILL.md + 任意捆绑文件）。纯按需：每次 List
// 现扫目录，无缓存 / 无 fingerprint / 无 watcher goroutine。**目录即真相**（WRK-076）：读永不
// 写回；结构化 Save 对原文 YAML 节点树做手术（未知键与键序不丢）；SaveRaw 字节忠实落盘；
// 捆绑文件一律经 os.Root 句柄触达（穿越/symlink/TOCTOU 由内核挡）。
package skill

import (
	"context"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Store reads/writes SKILL.md under a base root; base is ~/.anselm (boot-injected, temp in tests).
//
// Store 在 base 根下读写 SKILL.md；base 是 ~/.anselm（boot 注入，测试用 temp）。
type Store struct {
	base string
}

func New(base string) *Store { return &Store{base: base} }

var _ skilldomain.Repository = (*Store)(nil)

const (
	skillFileName      = "SKILL.md"
	skillFileNameLower = "skill.md" // 读取回退（对齐参考实现）；平台写入恒大写
)

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

// resolveSkillFile returns the existing manifest path inside dir — SKILL.md preferred,
// lowercase skill.md accepted as a fallback (reference-parser behavior). Missing both →
// fs.ErrNotExist for the caller to classify.
//
// resolveSkillFile 返回 dir 内实际存在的清单路径——SKILL.md 优先、小写 skill.md 回退
// （参考实现行为）。两者皆缺 → fs.ErrNotExist 交调用方判别。
func resolveSkillFile(dir string) (string, error) {
	p := filepath.Join(dir, skillFileName)
	if _, err := os.Stat(p); err == nil {
		return p, nil
	}
	lp := filepath.Join(dir, skillFileNameLower)
	if _, err := os.Stat(lp); err == nil {
		return lp, nil
	}
	return "", fs.ErrNotExist
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
		p, rerr := resolveSkillFile(filepath.Join(dir, name))
		if rerr != nil {
			continue // 无清单的目录跳过
		}
		sk, rerr := s.readSkill(p, name, false)
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
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return nil, err
	}
	p, rerr := resolveSkillFile(dir)
	if rerr != nil {
		return nil, skilldomain.ErrNotFound
	}
	sk, rerr := s.readSkill(p, name, true)
	if os.IsNotExist(rerr) {
		return nil, skilldomain.ErrNotFound
	}
	if rerr != nil {
		return nil, rerr // 已是 domain 错误（ErrInvalidFrontmatter/ErrBodyTooLarge）或原始 os 错误
	}
	// Get（单读）附带完整 provenance；List 只有 sidecar 存在性投影的 source（保持轻量）。
	// Get（单读）附完整 provenance；List 只有 sidecar 存在性投影出的 source（保持轻量）。
	if sk.Source == skilldomain.SourceInstalled {
		if prov, pErr := s.ReadProvenance(ctx, name); pErr == nil {
			sk.Provenance = prov
		}
	}
	return sk, nil
}

// readSkill parses one SKILL.md into the typed view (the raw node tree is parse-and-drop here —
// reads never write back, so nothing to preserve). dirName is the fallback name when
// frontmatter omits one.
//
// readSkill 把单个 SKILL.md 解析成类型化视图（原文节点树在此即解即弃——读永不写回，无需保留）。
// dirName 是 frontmatter 缺 name 时的兜底。
func (s *Store) readSkill(path, dirName string, withBody bool) (*skilldomain.Skill, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err // 含 NotExist，交上层判别
	}
	if len(raw) > skilldomain.MaxBodyBytes {
		return nil, skilldomain.ErrBodyTooLarge
	}
	fm, body, _, perr := parseFrontmatter(raw)
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
	// source=installed is DERIVED from the provenance sidecar — never written into the
	// frontmatter, so upstream files stay pristine (WRK-076 B4).
	// source=installed 由来源 sidecar 推导——绝不写进 frontmatter，上游文件保持原样（WRK-076 B4）。
	if _, sErr := os.Stat(filepath.Join(filepath.Dir(path), skilldomain.InstallSidecarName)); sErr == nil {
		sk.Source = skilldomain.SourceInstalled
	}
	if withBody {
		sk.Body = strings.TrimSpace(body)
	}
	if info, serr := os.Stat(path); serr == nil {
		sk.UpdatedAt = info.ModTime().UTC()
	}
	return sk, nil
}

// Save is the STRUCTURED write: when a manifest already exists and parses, its raw node tree
// is patched in place (only the structured surface's own keys — unknown keys, key order and
// comments survive, WRK-076 D1); otherwise the frontmatter is rendered from scratch. The body
// is trimmed (structured surface convention; SaveRaw is the verbatim path).
//
// Save 是结构化写：既有清单存在且可解析时对其原文节点树做手术（只碰结构化面自己的键——未知键、
// 键序与注释不丢，WRK-076 D1）；否则从零渲染 frontmatter。body 走 TrimSpace（结构化面约定；
// 逐字节路径是 SaveRaw）。
func (s *Store) Save(ctx context.Context, name string, fm skilldomain.Frontmatter, body string) error {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return err
	}
	header := ""
	if p, rerr := resolveSkillFile(dir); rerr == nil {
		if raw, readErr := os.ReadFile(p); readErr == nil && len(raw) <= skilldomain.MaxBodyBytes {
			if _, _, doc, perr := parseFrontmatter(raw); perr == nil {
				structuredPatch(doc.Content[0], fm)
				if h, encErr := encodeFrontmatter(doc); encErr == nil {
					header = h
				}
			}
		}
	}
	if header == "" {
		// 新建，或既有件坏/超限 → 修复性覆盖（结构化面语义 = 我给你完整新值）。
		header = renderFrontmatter(fm)
	}
	content := header + strings.TrimSpace(body) + "\n"
	return s.writeManifest(dir, []byte(content))
}

// SaveRaw is the VERBATIM write (the file-is-truth surface): bytes land exactly as given — no
// TrimSpace, no re-render. Minimal manifest validation lives HERE (the parser lives here):
// size cap, parsable fence, and frontmatter name == directory name when present (spec law);
// description is deliberately NOT required — imported skills may omit it (catalog falls back).
//
// SaveRaw 是逐字节原文写（文件即真相面）：字节原样落盘——不 TrimSpace、不重渲染。清单最小
// 校验就在**这里**（解析器在此层）：尺寸、围栏可解析、frontmatter 带 name 时必须==目录名
// （规范铁律）；刻意不要求 description——导入的 skill 可缺省（catalog 有兜底）。
func (s *Store) SaveRaw(ctx context.Context, name string, raw []byte) error {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return err
	}
	if len(raw) > skilldomain.MaxBodyBytes {
		return skilldomain.ErrBodyTooLarge
	}
	fm, _, _, perr := parseFrontmatter(raw)
	if perr != nil {
		return skilldomain.ErrInvalidFrontmatter.WithCause(perr)
	}
	if fmName := strings.TrimSpace(fm.Name); fmName != "" && fmName != name {
		return skilldomain.ErrInvalidFrontmatter.WithDetails(map[string]any{
			"reason": "frontmatter name must equal the skill directory name (Agent Skills spec)",
			"name":   fmName, "directory": name,
		})
	}
	return s.writeManifest(dir, raw)
}

// writeManifest atomically writes SKILL.md (.tmp + rename) and retires a lowercase skill.md
// leftover — platform writes are always uppercase, and keeping both would shadow the edit on
// the next read (uppercase wins the fallback).
//
// writeManifest 用 .tmp + rename 原子写 SKILL.md，并清退小写 skill.md 残件——平台写入恒大写，
// 两者并存会让下次读取（大写优先）把这次编辑遮蔽掉。
func (s *Store) writeManifest(dir string, content []byte) error {
	if mkErr := os.MkdirAll(dir, 0o755); mkErr != nil {
		return fmt.Errorf("skillfs.Save mkdir: %w", mkErr)
	}
	target := filepath.Join(dir, skillFileName)
	tmp := target + ".tmp"
	if wErr := os.WriteFile(tmp, content, 0o644); wErr != nil {
		return fmt.Errorf("skillfs.Save write: %w", wErr)
	}
	if rErr := os.Rename(tmp, target); rErr != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("skillfs.Save rename: %w", rErr)
	}
	// Retire a lowercase leftover ONLY when it is a distinct file — on case-insensitive
	// filesystems (macOS APFS default) skill.md and SKILL.md are the SAME file, and a blind
	// remove would delete what we just wrote.
	// 仅当小写残件是**独立文件**时清退——大小写不敏感文件系统（macOS APFS 默认）上
	// skill.md 与 SKILL.md 是同一个文件，盲删会删掉刚写入的内容。
	lower := filepath.Join(dir, skillFileNameLower)
	if li, lErr := os.Lstat(lower); lErr == nil {
		if ti, tErr := os.Lstat(target); tErr == nil && !os.SameFile(li, ti) {
			_ = os.Remove(lower)
		}
	}
	return nil
}

// Delete removes the entire skill directory (bundled files included). Missing → ErrNotFound.
//
// Delete 删除整个 skill 目录（含捆绑文件）。缺失 → ErrNotFound。
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

// Dir returns the skill directory's absolute path — the ${CLAUDE_SKILL_DIR} substitution value
// (activation) and the anchor the LLM's filesystem tools use to reach bundled files. Missing
// skill → ErrNotFound (a path to nowhere would render a lying preamble).
//
// Dir 返回 skill 目录绝对路径——${CLAUDE_SKILL_DIR} 的替换值（激活时）、也是 LLM filesystem
// 工具触达捆绑文件的锚点。skill 缺失 → ErrNotFound（指向虚无的路径会渲出说谎的前导）。
func (s *Store) Dir(ctx context.Context, name string) (string, error) {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return "", err
	}
	if _, rerr := resolveSkillFile(dir); rerr != nil {
		return "", skilldomain.ErrNotFound
	}
	return dir, nil
}

// IsInSkillsTree reports whether abs points INSIDE some skill's directory under base — the
// pathguard allow predicate that punches the skills subtree out of the ~/.anselm deny rule
// (progressive disclosure layer 3: the LLM's Read reaches bundled files). Symlinks are resolved
// first so a malicious installed skill cannot smuggle a link that lexically sits in the tree
// but physically points at ~/.ssh — the RESOLVED path must still be in the tree.
//
// IsInSkillsTree 报告 abs 是否指向 base 下某 skill 目录**内部**——pathguard 的放行谓词，把
// skills 子树从 ~/.anselm 黑名单里精确豁免（渐进披露第 3 层：LLM 的 Read 触达捆绑文件）。先解
// symlink 再判定：恶意安装的 skill 无法用「词法在树内、物理指向 ~/.ssh」的链接走私——**解析后**
// 的路径仍须在树内。
func IsInSkillsTree(base, abs string) bool {
	if base == "" || !filepath.IsAbs(abs) {
		return false
	}
	resolved := resolveBestEffort(abs)
	wsRoot, err := filepath.EvalSymlinks(filepath.Join(base, "workspaces"))
	if err != nil {
		wsRoot = filepath.Join(base, "workspaces")
	}
	rel, err := filepath.Rel(wsRoot, resolved)
	if err != nil || rel == "." || strings.HasPrefix(rel, "..") {
		return false
	}
	// 形状必须是 <ws>/skills/<name>/...（skill 目录内部的文件，不含 skills 桶与 skill 根本身）。
	parts := strings.Split(filepath.ToSlash(rel), "/")
	return len(parts) >= 4 && parts[1] == "skills"
}

// resolveBestEffort resolves symlinks over the deepest EXISTING ancestor and rejoins the
// not-yet-existing tail — EvalSymlinks fails outright on paths that don't exist yet (a Write
// target), but the jail must hold for creation too, and on macOS even the temp root is a
// symlink (/var → /private/var), so a single-level parent fallback is not enough. Existing
// segments are always fully resolved; non-existent tail segments cannot be symlinks.
//
// resolveBestEffort 对**最深已存在祖先**解 symlink、再拼回尚不存在的尾段——EvalSymlinks 对未
// 存在路径直接失败（如 Write 目标），而围栏对新建也须成立；且 macOS 连临时根都是 symlink
// （/var → /private/var），只回退一层父目录不够。已存在段恒被完整解析；不存在的尾段不可能是 symlink。
func resolveBestEffort(abs string) string {
	suffix := ""
	cur := abs
	for {
		if r, err := filepath.EvalSymlinks(cur); err == nil {
			return filepath.Join(r, suffix)
		}
		parent := filepath.Dir(cur)
		if parent == cur {
			return abs // 到根仍失败（不可达兜底）
		}
		suffix = filepath.Join(filepath.Base(cur), suffix)
		cur = parent
	}
}

// Exists reports whether a skill's manifest is present (used by Create's conflict check).
//
// Exists 报告 skill 的清单是否存在（Create 冲突检查用）。
func (s *Store) Exists(ctx context.Context, name string) (bool, error) {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return false, err
	}
	if _, rerr := resolveSkillFile(dir); rerr != nil {
		return false, nil
	}
	return true, nil
}

// ── bundled files (the second traversal surface — every touch goes through os.Root) ─────────

// openRoot opens the skill directory as an os.Root — the kernel-backed jail for all bundled-
// file I/O (symlink escapes and TOCTOU are stopped below us). Missing skill dir → ErrNotFound.
//
// openRoot 把 skill 目录开成 os.Root——捆绑文件 I/O 的内核级围栏（symlink 逃逸与 TOCTOU 在
// 我们之下被挡）。skill 目录缺失 → ErrNotFound。
func (s *Store) openRoot(ctx context.Context, name string) (*os.Root, error) {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return nil, err
	}
	root, oErr := os.OpenRoot(dir)
	if oErr != nil {
		if os.IsNotExist(oErr) {
			return nil, skilldomain.ErrNotFound
		}
		return nil, fmt.Errorf("skillfs.openRoot: %w", oErr)
	}
	return root, nil
}

// isManifestRel reports whether a CLEANED relative path names the manifest (either case form).
//
// isManifestRel 报告清洗后的相对路径是否指清单（两种大小写形态）。
func isManifestRel(c string) bool {
	return strings.EqualFold(c, skillFileName)
}

// cleanRel is the lexical half of the traversal guard: URL-style relative paths only — no
// backslashes (cross-platform ambiguity), absolute paths / ".." / reserved names rejected by
// filepath.IsLocal. Returns the cleaned slash form; os.Root enforces the physical half.
//
// cleanRel 是穿越守卫的词法半：只收 URL 风格相对路径——拒反斜杠（跨平台歧义）、绝对路径 /
// ".." / 保留名由 filepath.IsLocal 拒。返回清洗后的 slash 形态；物理半由 os.Root 兜底。
func cleanRel(rel string) (string, error) {
	if rel == "" || strings.Contains(rel, `\`) {
		return "", skilldomain.ErrFilePathInvalid
	}
	local := filepath.FromSlash(rel)
	if !filepath.IsLocal(local) {
		return "", skilldomain.ErrFilePathInvalid
	}
	c := filepath.ToSlash(filepath.Clean(local))
	if c == "." || c == ".." || strings.HasPrefix(c, "../") {
		return "", skilldomain.ErrFilePathInvalid
	}
	return c, nil
}

// ListFiles walks the skill directory (manifest included) and returns every regular file as a
// slash-relative FileInfo, path-sorted. Bounded by the skill's own size — scan cost is not a
// function of file count elsewhere.
//
// ListFiles 遍历 skill 目录（含清单），把每个普通文件按 slash 相对路径返回 FileInfo，按路径
// 排序。以该 skill 自身体量为界。
func (s *Store) ListFiles(ctx context.Context, name string) ([]skilldomain.FileInfo, error) {
	root, err := s.openRoot(ctx, name)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	var out []skilldomain.FileInfo
	wErr := fs.WalkDir(root.FS(), ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		// Only regular files: a symlink would be listed but unreadable (os.Root blocks the
		// escape) — an entry the UI can never open is noise, not honesty.
		// 只列普通文件:symlink 列得出读不了(os.Root 挡逃逸)——UI 永远打不开的条目是噪音。
		if !d.Type().IsRegular() {
			return nil
		}
		info, iErr := d.Info()
		if iErr != nil {
			return nil // 竞态消失的文件跳过
		}
		out = append(out, skilldomain.FileInfo{
			Path:      filepath.ToSlash(p),
			Size:      info.Size(),
			UpdatedAt: info.ModTime().UTC(),
		})
		return nil
	})
	if wErr != nil {
		return nil, fmt.Errorf("skillfs.ListFiles: %w", wErr)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	return out, nil
}

// ReadFile returns one bundled file's bytes. The read guard is MaxFileBytes for EVERY file —
// including an oversized SKILL.md (a broken manifest must stay readable so the user can fix
// it through the files surface).
//
// ReadFile 返回单个捆绑文件的字节。读护栏对**一切**文件统一用 MaxFileBytes——包括超限的
// SKILL.md（坏清单必须仍可读，用户才能经 files 面修复它）。
func (s *Store) ReadFile(ctx context.Context, name, rel string) ([]byte, error) {
	c, err := cleanRel(rel)
	if err != nil {
		return nil, err
	}
	root, err := s.openRoot(ctx, name)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	info, sErr := root.Stat(c)
	if sErr != nil {
		if os.IsNotExist(sErr) {
			return nil, skilldomain.ErrFileNotFound
		}
		return nil, fmt.Errorf("skillfs.ReadFile: %w", sErr)
	}
	if info.IsDir() {
		return nil, skilldomain.ErrFileNotFound
	}
	if info.Size() > skilldomain.MaxFileBytes {
		return nil, skilldomain.ErrFileTooLarge
	}
	data, rErr := root.ReadFile(c)
	if rErr != nil {
		if os.IsNotExist(rErr) {
			return nil, skilldomain.ErrFileNotFound
		}
		return nil, fmt.Errorf("skillfs.ReadFile: %w", rErr)
	}
	return data, nil
}

// WriteFile atomically writes one bundled file (.tmp + rename inside the root), creating
// parent directories on demand. Size guard is enforced here as the last line (transport caps
// the request body too).
//
// WriteFile 原子写单个捆绑文件（root 内 .tmp + rename），父目录按需创建。大小护栏在此做
// 最后一道（transport 层对请求体另有封顶）。
func (s *Store) WriteFile(ctx context.Context, name, rel string, data []byte) error {
	c, err := cleanRel(rel)
	if err != nil {
		return err
	}
	if isManifestRel(c) {
		return skilldomain.ErrFilePathInvalid // 清单写走 SaveRaw（app 路由；此为纵深防御）
	}
	if len(data) > skilldomain.MaxFileBytes {
		return skilldomain.ErrFileTooLarge
	}
	root, err := s.openRoot(ctx, name)
	if err != nil {
		return err
	}
	defer root.Close()
	if parent := filepath.Dir(filepath.FromSlash(c)); parent != "." {
		if mkErr := root.MkdirAll(parent, 0o755); mkErr != nil {
			return fmt.Errorf("skillfs.WriteFile mkdir: %w", mkErr)
		}
	}
	local := filepath.FromSlash(c)
	tmp := local + ".tmp"
	if wErr := root.WriteFile(tmp, data, 0o644); wErr != nil {
		return fmt.Errorf("skillfs.WriteFile write: %w", wErr)
	}
	if rErr := root.Rename(tmp, local); rErr != nil {
		_ = root.Remove(tmp)
		return fmt.Errorf("skillfs.WriteFile rename: %w", rErr)
	}
	return nil
}

// DeleteFile removes one bundled file (never the manifest — the app layer rejects that;
// deleting the skill itself is DELETE /skills/{name}). Empty parent dirs are left in place.
//
// DeleteFile 删单个捆绑文件（清单不经此路——app 层拒；删 skill 本体走 DELETE /skills/{name}）。
// 空父目录原地保留。
func (s *Store) DeleteFile(ctx context.Context, name, rel string) error {
	c, err := cleanRel(rel)
	if err != nil {
		return err
	}
	if isManifestRel(c) {
		return skilldomain.ErrFilePathInvalid // 删清单=毁 skill，走 DELETE /skills/{name}
	}
	root, err := s.openRoot(ctx, name)
	if err != nil {
		return err
	}
	defer root.Close()
	if rmErr := root.Remove(filepath.FromSlash(c)); rmErr != nil {
		if os.IsNotExist(rmErr) {
			return skilldomain.ErrFileNotFound
		}
		return fmt.Errorf("skillfs.DeleteFile: %w", rmErr)
	}
	return nil
}

// ── install provenance sidecar（B4：出处档案，目录即真相的簿记文件）────────────────────

// ReadProvenance returns the install sidecar, or (nil, nil) when the skill was not installed
// from a source. Malformed sidecars fail loud (the trust gate must not silently open).
//
// ReadProvenance 返回安装 sidecar；非安装来源 → (nil, nil)。坏 sidecar 大声失败（信任门
// 不得静默洞开）。
func (s *Store) ReadProvenance(ctx context.Context, name string) (*skilldomain.Provenance, error) {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return nil, err
	}
	raw, rErr := os.ReadFile(filepath.Join(dir, skilldomain.InstallSidecarName))
	if os.IsNotExist(rErr) {
		return nil, nil
	}
	if rErr != nil {
		return nil, fmt.Errorf("skillfs.ReadProvenance: %w", rErr)
	}
	var p skilldomain.Provenance
	if jErr := json.Unmarshal(raw, &p); jErr != nil {
		return nil, fmt.Errorf("skillfs.ReadProvenance: %w", jErr)
	}
	return &p, nil
}

// WriteProvenance atomically writes the install sidecar (.tmp + rename).
//
// WriteProvenance 原子写安装 sidecar（.tmp + rename）。
func (s *Store) WriteProvenance(ctx context.Context, name string, p *skilldomain.Provenance) error {
	dir, err := s.skillDir(ctx, name)
	if err != nil {
		return err
	}
	raw, jErr := json.MarshalIndent(p, "", "  ")
	if jErr != nil {
		return fmt.Errorf("skillfs.WriteProvenance: %w", jErr)
	}
	target := filepath.Join(dir, skilldomain.InstallSidecarName)
	tmp := target + ".tmp"
	if wErr := os.WriteFile(tmp, append(raw, '\n'), 0o644); wErr != nil {
		return fmt.Errorf("skillfs.WriteProvenance: %w", wErr)
	}
	if rErr := os.Rename(tmp, target); rErr != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("skillfs.WriteProvenance: %w", rErr)
	}
	return nil
}
