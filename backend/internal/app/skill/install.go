package skill

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
	skillfs "github.com/sunweilin/anselm/backend/internal/infra/fs/skill"
	skillfetch "github.com/sunweilin/anselm/backend/internal/infra/skillfetch"
)

// fetchFunc is the download seam (unit tests inject a fake; production uses skillfetch.Fetch).
//
// fetchFunc 是下载接缝（单测注假；生产用 skillfetch.Fetch）。
type fetchFunc func(ctx context.Context, src skillfetch.Source) ([]skillfetch.Candidate, error)

// SetFetcher overrides the tarball fetcher (tests).
//
// SetFetcher 覆写 tarball 取物器（测试用）。
func (s *Service) SetFetcher(f fetchFunc) { s.fetch = f }

func (s *Service) fetcher() fetchFunc {
	if s.fetch != nil {
		return s.fetch
	}
	return skillfetch.Fetch
}

// InstallPreview is one candidate the source offers — the F2 install dialog renders this list
// with the allowed-tools SHOWN UP FRONT (the trust gate starts at the picking step).
//
// InstallPreview 是来源提供的一个候选——F2 安装对话框渲染此列表，allowed-tools **前置亮相**
// （信任门从挑选那一步就开始）。
type InstallPreview struct {
	Name          string   `json:"name"`
	Description   string   `json:"description"`
	AllowedTools  []string `json:"allowedTools,omitempty"`
	FileCount     int      `json:"fileCount"`
	TotalBytes    int64    `json:"totalBytes"`
	Installable   bool     `json:"installable"`
	Reason        string   `json:"reason,omitempty"` // 不可装原因（人话）
	AlreadyExists bool     `json:"alreadyExists"`    // 同名已存在（装 = 覆盖，需 force）
}

// InstallResult reports what one Install call actually did, per name.
//
// InstallResult 逐名报告一次 Install 实际做了什么。
type InstallResult struct {
	Installed []string          `json:"installed"`
	Skipped   map[string]string `json:"skipped,omitempty"` // name → 原因
}

// InspectSource fetches the source and previews every candidate WITHOUT touching disk.
//
// InspectSource 拉取来源并预览全部候选，不落盘。
func (s *Service) InspectSource(ctx context.Context, source string) ([]InstallPreview, error) {
	src, err := skillfetch.ParseSource(source)
	if err != nil {
		return nil, err
	}
	cands, err := s.fetcher()(ctx, src)
	if err != nil {
		return nil, err
	}
	if len(cands) == 0 {
		return nil, skilldomain.ErrInstallNoSkills
	}
	out := make([]InstallPreview, 0, len(cands))
	for _, c := range cands {
		out = append(out, s.previewOf(ctx, c))
	}
	return out, nil
}

func (s *Service) previewOf(ctx context.Context, c skillfetch.Candidate) InstallPreview {
	p := InstallPreview{Name: c.Name, FileCount: len(c.Files)}
	for _, d := range c.Files {
		p.TotalBytes += int64(len(d))
	}
	manifest, ok := candidateManifest(c)
	switch {
	case !ok:
		p.Reason = "no SKILL.md manifest"
	case len(manifest) > skilldomain.MaxBodyBytes:
		p.Reason = "manifest exceeds the 32KB cap"
	case !skilldomain.IsValidName(c.Name):
		p.Reason = "directory name is not a valid skill slug"
	default:
		fm, _, perr := skillfs.ParseManifest(manifest)
		if perr != nil {
			p.Reason = "manifest frontmatter does not parse"
		} else {
			p.Installable = true
			p.Description = fm.Description
			p.AllowedTools = fm.AllowedTools
		}
	}
	if exists, err := s.repo.Exists(ctx, c.Name); err == nil && exists {
		p.AlreadyExists = true
	}
	return p
}

// candidateManifest returns the candidate's manifest bytes (uppercase preferred).
//
// candidateManifest 返回候选的清单字节（大写优先）。
func candidateManifest(c skillfetch.Candidate) ([]byte, bool) {
	if m, ok := c.Files["SKILL.md"]; ok {
		return m, true
	}
	m, ok := c.Files["skill.md"]
	return m, ok
}

// Install fetches the source and lands the picked candidates on disk: bundled files through
// the guarded file writer, the manifest last through the validated raw path, then the
// provenance sidecar (trust gate CLOSED — allowed-tools await user approval) and equip-edge
// sync. names empty = every installable candidate. Existing skills are skipped unless force.
//
// Install 拉取来源并把选中候选落盘：附属文件走带守卫的文件写、清单最后走带校验的原文路径、
// 再写来源 sidecar（信任门**关闭**——allowed-tools 等用户授权）+ equip 边同步。names 空 =
// 全部可装候选。同名已存在非 force 则跳过。
func (s *Service) Install(ctx context.Context, source string, names []string, force bool) (*InstallResult, error) {
	src, err := skillfetch.ParseSource(source)
	if err != nil {
		return nil, err
	}
	cands, err := s.fetcher()(ctx, src)
	if err != nil {
		return nil, err
	}
	if len(cands) == 0 {
		return nil, skilldomain.ErrInstallNoSkills
	}

	picked := map[string]bool{}
	for _, n := range names {
		picked[n] = true
	}
	res := &InstallResult{Skipped: map[string]string{}}
	for _, c := range cands {
		if len(picked) > 0 && !picked[c.Name] {
			continue
		}
		if pv := s.previewOf(ctx, c); !pv.Installable {
			res.Skipped[c.Name] = pv.Reason
			continue
		}
		if exists, _ := s.repo.Exists(ctx, c.Name); exists && !force {
			res.Skipped[c.Name] = "already exists (pass force to overwrite)"
			continue
		}
		if err := s.landCandidate(ctx, src, c); err != nil {
			res.Skipped[c.Name] = errorspkgSurface(err)
			continue
		}
		res.Installed = append(res.Installed, c.Name)
	}
	if len(res.Installed) == 0 && len(res.Skipped) > 0 {
		s.log.Warn("skillapp.Install: nothing installed", zap.Any("skipped", res.Skipped))
	}
	return res, nil
}

// landCandidate writes one candidate: wipe-on-force, bundled files, manifest, sidecar, edges.
//
// landCandidate 落一个候选：force 先清、附属文件、清单、sidecar、关系边。
func (s *Service) landCandidate(ctx context.Context, src skillfetch.Source, c skillfetch.Candidate) error {
	if exists, _ := s.repo.Exists(ctx, c.Name); exists {
		if err := s.repo.Delete(ctx, c.Name); err != nil {
			return fmt.Errorf("wipe before reinstall: %w", err)
		}
	}
	manifest, _ := candidateManifest(c)
	// 清单先落（SaveRaw 建目录 + 校验 name==目录名）；附属文件随后（守卫写）。
	if err := s.repo.SaveRaw(ctx, c.Name, manifest); err != nil {
		return err
	}
	hashes := map[string]string{}
	for rel, data := range c.Files {
		if rel == "SKILL.md" || rel == "skill.md" {
			hashes["SKILL.md"] = sha256hex(manifest)
			continue
		}
		if err := s.repo.WriteFile(ctx, c.Name, rel, data); err != nil {
			return fmt.Errorf("write %s: %w", rel, err)
		}
		hashes[rel] = sha256hex(data)
	}
	prov := &skilldomain.Provenance{
		Source:      src.Raw,
		Repo:        src.Repo,
		Ref:         src.Ref,
		Subdir:      src.Subdir,
		InstalledAt: time.Now().UTC(),
		FileHashes:  hashes,
		// ToolsApproved 恒 false 起步：三方 allowed-tools 是请求、不是授权（WRK-076 信任门）。
	}
	if err := s.repo.WriteProvenance(ctx, c.Name, prov); err != nil {
		return err
	}
	s.notify(ctx, "created", c.Name)
	if sk, gErr := s.repo.Get(ctx, c.Name); gErr == nil {
		s.syncEquipEdges(ctx, c.Name, sk.Frontmatter.AllowedTools)
	}
	return nil
}

// UpdateInstalled re-fetches an installed skill from its recorded source. Local edits (hash
// drift vs the install baseline) refuse without force; a changed allowed-tools set RESETS the
// trust gate (the user approved the OLD grant, not whatever upstream now asks).
//
// UpdateInstalled 按记录的来源重拉一个已安装 skill。本地改动（对安装基线的 hash 漂移）非
// force 拒；allowed-tools 变更**重置**信任门（用户授权的是旧让渡，不是上游现在要的）。
func (s *Service) UpdateInstalled(ctx context.Context, name string, force bool) (*skilldomain.Skill, error) {
	prov, err := s.repo.ReadProvenance(ctx, name)
	if err != nil {
		return nil, fmt.Errorf("skillapp.UpdateInstalled: %w", err)
	}
	if prov == nil {
		return nil, skilldomain.ErrNotInstalled
	}

	if !force {
		if drifted, files := s.localDrift(ctx, name, prov); drifted {
			return nil, skilldomain.ErrLocallyModified.WithDetails(map[string]any{"files": files})
		}
	}

	oldTools := []string(nil)
	if sk, gErr := s.repo.Get(ctx, name); gErr == nil {
		oldTools = sk.Frontmatter.AllowedTools
	}

	src, err := skillfetch.ParseSource(prov.Source)
	if err != nil {
		return nil, err
	}
	cands, err := s.fetcher()(ctx, src)
	if err != nil {
		return nil, err
	}
	for _, c := range cands {
		if c.Name != name {
			continue
		}
		if err := s.landCandidate(ctx, src, c); err != nil {
			return nil, fmt.Errorf("skillapp.UpdateInstalled: %w", err)
		}
		sk, gErr := s.repo.Get(ctx, name)
		if gErr != nil {
			return nil, fmt.Errorf("skillapp.UpdateInstalled readback: %w", gErr)
		}
		// allowed-tools 未变才延续旧授权；变了 = 新的让渡请求，信任门重走。
		if prov.ToolsApproved && equalTools(oldTools, sk.Frontmatter.AllowedTools) {
			if np, rErr := s.repo.ReadProvenance(ctx, name); rErr == nil && np != nil {
				np.ToolsApproved = true
				_ = s.repo.WriteProvenance(ctx, name, np)
			}
		}
		s.notify(ctx, "updated", name)
		return s.repo.Get(ctx, name)
	}
	return nil, skilldomain.ErrInstallNoSkills.WithDetails(map[string]any{
		"reason": "the source no longer offers a skill named " + name,
	})
}

// ApproveTools opens the trust gate: the user has seen and accepted this installed skill's
// allowed-tools pre-authorization.
//
// ApproveTools 打开信任门：用户已看过并接受该安装 skill 的 allowed-tools 预授权。
func (s *Service) ApproveTools(ctx context.Context, name string) (*skilldomain.Skill, error) {
	prov, err := s.repo.ReadProvenance(ctx, name)
	if err != nil {
		return nil, fmt.Errorf("skillapp.ApproveTools: %w", err)
	}
	if prov == nil {
		return nil, skilldomain.ErrNotInstalled
	}
	prov.ToolsApproved = true
	if err := s.repo.WriteProvenance(ctx, name, prov); err != nil {
		return nil, fmt.Errorf("skillapp.ApproveTools: %w", err)
	}
	s.notify(ctx, "updated", name)
	return s.repo.Get(ctx, name)
}

// localDrift compares on-disk files against the install baseline hashes.
//
// localDrift 把盘上文件与安装基线 hash 对比。
func (s *Service) localDrift(ctx context.Context, name string, prov *skilldomain.Provenance) (bool, []string) {
	if len(prov.FileHashes) == 0 {
		return false, nil
	}
	var drifted []string
	files, err := s.repo.ListFiles(ctx, name)
	if err != nil {
		return false, nil // 读不出来交给后续路径大声失败
	}
	onDisk := map[string]bool{}
	for _, f := range files {
		if f.Path == skilldomain.InstallSidecarName {
			continue
		}
		onDisk[f.Path] = true
		want, tracked := prov.FileHashes[f.Path]
		if !tracked {
			drifted = append(drifted, f.Path+" (added)")
			continue
		}
		data, rErr := s.repo.ReadFile(ctx, name, f.Path)
		if rErr != nil || sha256hex(data) != want {
			drifted = append(drifted, f.Path)
		}
	}
	for p := range prov.FileHashes {
		if !onDisk[p] {
			drifted = append(drifted, p+" (deleted)")
		}
	}
	return len(drifted) > 0, drifted
}

func sha256hex(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func equalTools(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	seen := map[string]int{}
	for _, t := range a {
		seen[t]++
	}
	for _, t := range b {
		if seen[t] == 0 {
			return false
		}
		seen[t]--
	}
	return true
}

// errorspkgSurface renders an install-step error as a short human reason for the skip map.
//
// errorspkgSurface 把安装步骤错误渲成 skip 表里的简短人话。
func errorspkgSurface(err error) string {
	msg := err.Error()
	if i := strings.LastIndex(msg, ": "); i >= 0 && i+2 < len(msg) {
		return msg[i+2:]
	}
	return msg
}
