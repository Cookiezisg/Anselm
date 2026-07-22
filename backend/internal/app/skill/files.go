package skill

import (
	"context"
	"fmt"
	"path"
	"strings"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

// manifestFileName is the skill manifest; the files surface routes it specially (write =
// verbatim manifest replace with validation, delete = refused).
//
// manifestFileName 是 skill 清单；files 面对它特殊路由（写 = 带校验的原文整替，删 = 拒）。
const manifestFileName = "SKILL.md"

// isManifestPath reports whether rel names the manifest (either case, any ./ prefix form).
// Backslash forms need no handling here — the store's cleanRel rejects them outright.
//
// isManifestPath 报告 rel 是否指清单（两种大小写、任意 ./ 前缀形态）。反斜杠形态无需在此
// 处理——store 的 cleanRel 直接拒。
func isManifestPath(rel string) bool {
	return strings.EqualFold(path.Clean(rel), manifestFileName)
}

// ReplaceRaw overwrites SKILL.md verbatim (the file-is-truth edit surface). The skill must
// already exist — creation goes through the structured POST (or, later, install). The store
// validates size / fence / name==dir; allowed-tools may have changed, so equip edges resync.
//
// ReplaceRaw 逐字节整替 SKILL.md（文件即真相的编辑面）。skill 必须已存在——创建走结构化
// POST（或日后的安装）。尺寸 / 围栏 / name==目录名由 store 校验；allowed-tools 可能已变，
// 故重同步 equip 边。
func (s *Service) ReplaceRaw(ctx context.Context, name string, raw []byte) (*skilldomain.Skill, error) {
	if !skilldomain.IsValidName(name) {
		return nil, skilldomain.ErrInvalidName
	}
	exists, err := s.repo.Exists(ctx, name)
	if err != nil {
		return nil, fmt.Errorf("skillapp.ReplaceRaw: %w", err)
	}
	if !exists {
		return nil, skilldomain.ErrNotFound
	}
	if err := s.repo.SaveRaw(ctx, name, raw); err != nil {
		return nil, fmt.Errorf("skillapp.ReplaceRaw: %w", err)
	}
	s.notifyFile(ctx, name, manifestFileName)
	sk, gErr := s.repo.Get(ctx, name)
	if gErr != nil {
		return nil, fmt.Errorf("skillapp.ReplaceRaw readback: %w", gErr)
	}
	s.syncEquipEdges(ctx, name, sk.Frontmatter.AllowedTools)
	return sk, nil
}

// Dir returns the skill directory's absolute path (the ${CLAUDE_SKILL_DIR} value — script
// execution anchors its cwd here).
//
// Dir 返回 skill 目录绝对路径（${CLAUDE_SKILL_DIR} 取值——脚本执行以此为 cwd 锚点）。
func (s *Service) Dir(ctx context.Context, name string) (string, error) {
	dir, err := s.repo.Dir(ctx, name)
	if err != nil {
		return "", fmt.Errorf("skillapp.Dir: %w", err)
	}
	return dir, nil
}

// ListFiles returns every bundled file (manifest included) as path-sorted metadata.
//
// ListFiles 返回全部捆绑文件（含清单）的按路径排序元数据。
func (s *Service) ListFiles(ctx context.Context, name string) ([]skilldomain.FileInfo, error) {
	files, err := s.repo.ListFiles(ctx, name)
	if err != nil {
		return nil, fmt.Errorf("skillapp.ListFiles: %w", err)
	}
	return files, nil
}

// ReadFile returns one bundled file's bytes (manifest readable too — the fix-a-broken-file
// channel).
//
// ReadFile 返回单个捆绑文件的字节（清单同样可读——修坏件的通道）。
func (s *Service) ReadFile(ctx context.Context, name, rel string) ([]byte, error) {
	data, err := s.repo.ReadFile(ctx, name, rel)
	if err != nil {
		return nil, fmt.Errorf("skillapp.ReadFile: %w", err)
	}
	return data, nil
}

// WriteFile writes one bundled file; a manifest path routes to ReplaceRaw (validated verbatim
// replace) so there is exactly one manifest-write door.
//
// WriteFile 写单个捆绑文件；清单路径路由到 ReplaceRaw（带校验的原文整替），清单写入只有
// 一扇门。
func (s *Service) WriteFile(ctx context.Context, name, rel string, data []byte) error {
	if isManifestPath(rel) {
		_, err := s.ReplaceRaw(ctx, name, data)
		return err
	}
	if err := s.repo.WriteFile(ctx, name, rel, data); err != nil {
		return fmt.Errorf("skillapp.WriteFile: %w", err)
	}
	s.notifyFile(ctx, name, path.Clean(rel))
	return nil
}

// DeleteFile removes one bundled file; deleting the manifest is refused with a pointer to the
// real door (DELETE /skills/{name}).
//
// DeleteFile 删单个捆绑文件；删清单被拒并指向正门（DELETE /skills/{name}）。
func (s *Service) DeleteFile(ctx context.Context, name, rel string) error {
	if isManifestPath(rel) {
		return skilldomain.ErrFilePathInvalid.WithDetails(map[string]any{
			"reason": "the manifest cannot be deleted; delete the skill itself via DELETE /skills/{name}",
		})
	}
	if err := s.repo.DeleteFile(ctx, name, rel); err != nil {
		return fmt.Errorf("skillapp.DeleteFile: %w", err)
	}
	s.notifyFile(ctx, name, path.Clean(rel))
	return nil
}
