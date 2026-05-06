// import.go — Service.Import: drag-import flow for the UI. Accepts a
// list of (skillName, rawFileBytes) pairs (one SKILL.md per skill the
// user is dropping). Returns a MergeResult enumerating which were
// imported, which conflicted (existing skill), and which had per-file
// errors (frontmatter invalid, body too large) so the UI can render a
// per-row outcome.
//
// V1 only accepts SKILL.md files directly. ZIP / tar.gz / folder
// uploads (where each subfolder is one skill) are V2 — the front-end
// can unpack on the client side and POST individual SKILL.md files
// in the meantime.
//
// import.go ——Service.Import：UI 拖入流。接 (skillName, rawFileBytes)
// 列表（用户拖入的每个 skill 一个 SKILL.md）。返 MergeResult 列出 imported
// / conflicts / errors per-row 让 UI per-row 渲染。V1 只接 SKILL.md；ZIP /
// tar / folder 留 V2（前端先 client-side 拆完逐个 POST）。
package skill

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"

	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
)

// ImportFile is one skill the caller is dropping. Name comes from the
// user (UI form / multipart filename without extension); RawSkillMD is
// the verbatim SKILL.md bytes the user dropped.
//
// ImportFile 是调用方拖入的一个 skill。Name 用户填（UI 表单 / 不带扩展
// 的 multipart filename）；RawSkillMD 是用户拖入的 SKILL.md 原始字节。
type ImportFile struct {
	Name       string
	RawSkillMD []byte
}

// ImportError pairs one file's name with the reason it couldn't be
// imported (UI shows it as an inline error row).
//
// ImportError 把文件名与不能 import 的原因配对（UI 行内错误展示）。
type ImportError struct {
	Name   string `json:"name"`
	Reason string `json:"reason"`
}

// ImportResult is what the import endpoint returns. Imported lists
// names that are now installed; Conflicts lists names that already
// exist (skipped unless overwrite=true); Errors lists names whose
// SKILL.md was malformed.
//
// ImportResult 是 import 端点返回。Imported 已装；Conflicts 已存在
// （非 overwrite 时跳过）；Errors SKILL.md 畸形。
type ImportResult struct {
	Imported  []string      `json:"imported"`
	Conflicts []string      `json:"conflicts"`
	Errors    []ImportError `json:"errors"`
}

// Import processes a batch of dropped SKILL.md files. For each:
//   - parse + validate frontmatter (per-file errors → result.Errors)
//   - check name conflict; without overwrite → result.Conflicts
//   - write to disk via the same atomic path as Create/Replace
//
// One Scan + one SSE event after the batch completes (more efficient
// than per-file rescan when the user drops a folder of 10 skills).
//
// Import 处理一批拖入的 SKILL.md。每条：解+校 frontmatter（per-file 错
// 入 Errors）；查冲突（无 overwrite 入 Conflicts）；经 atomic 路径写盘。
// 批后单次 Scan + SSE（用户拖一个 10 skill 的文件夹时比 per-file 更划算）。
func (s *Service) Import(ctx context.Context, files []ImportFile, overwrite bool) (ImportResult, error) {
	res := ImportResult{
		Imported:  []string{},
		Conflicts: []string{},
		Errors:    []ImportError{},
	}

	for _, f := range files {
		if err := validateName(f.Name); err != nil {
			res.Errors = append(res.Errors, ImportError{
				Name: f.Name, Reason: err.Error(),
			})
			continue
		}
		if len(f.RawSkillMD) > skilldomain.MaxBodyBytes {
			res.Errors = append(res.Errors, ImportError{
				Name:   f.Name,
				Reason: fmt.Sprintf("body %d bytes exceeds %d cap", len(f.RawSkillMD), skilldomain.MaxBodyBytes),
			})
			continue
		}
		yamlPart, body, err := splitFrontmatter(f.RawSkillMD)
		if err != nil {
			res.Errors = append(res.Errors, ImportError{
				Name: f.Name, Reason: "split frontmatter: " + err.Error(),
			})
			continue
		}
		var fm skilldomain.Frontmatter
		if err := yaml.Unmarshal(yamlPart, &fm); err != nil {
			res.Errors = append(res.Errors, ImportError{
				Name: f.Name, Reason: "yaml parse: " + err.Error(),
			})
			continue
		}
		if err := validateFrontmatter(fm); err != nil {
			res.Errors = append(res.Errors, ImportError{
				Name: f.Name, Reason: err.Error(),
			})
			continue
		}

		dir := filepath.Join(s.skillsDir, f.Name)
		exists := false
		if _, err := os.Stat(dir); err == nil {
			exists = true
		} else if !errors.Is(err, fs.ErrNotExist) {
			res.Errors = append(res.Errors, ImportError{
				Name: f.Name, Reason: "stat: " + err.Error(),
			})
			continue
		}
		if exists && !overwrite {
			res.Conflicts = append(res.Conflicts, f.Name)
			continue
		}

		if err := writeSkillDir(dir, fm, string(body)); err != nil {
			res.Errors = append(res.Errors, ImportError{
				Name: f.Name, Reason: "write: " + err.Error(),
			})
			continue
		}
		res.Imported = append(res.Imported, f.Name)
	}

	if len(res.Imported) > 0 {
		if err := s.Scan(ctx); err != nil {
			return res, fmt.Errorf("skillapp.Import: post-batch rescan: %w", err)
		}
	}
	return res, nil
}

