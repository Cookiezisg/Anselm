// Package skillfetch downloads and unpacks skill sources into in-memory candidates
// (WRK-076 B4). A source is a GitHub shorthand (owner/repo[@ref][#subdir]), a github.com
// URL, or any other http(s) URL served as a gzipped tarball — the GitHub form is rewritten
// to the codeload tarball endpoint, so there is no git dependency and no CGO. Extraction is
// guarded against archive bombs (total size / file count / per-file caps) and tar symlink
// entries are dropped outright.
//
// Package skillfetch 把 skill 来源下载解包成内存候选（WRK-076 B4）。来源可以是 GitHub 简写
// （owner/repo[@ref][#subdir]）、github.com URL、或任意以 gzip tarball 提供的 http(s) URL——
// GitHub 形态改写为 codeload tarball 端点，零 git 依赖零 CGO。解包带炸弹护栏（总量/文件数/
// 单文件上限），tar 的 symlink 条目直接丢弃。
package skillfetch

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"sort"
	"strings"
	"time"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

const (
	maxArchiveBytes  = 100 * 1024 * 1024 // 压缩包下载上限
	maxUnpackedBytes = 200 * 1024 * 1024 // 解压累计上限（炸弹护栏）
	maxFileCount     = 4096              // 条目数上限
	fetchTimeout     = 2 * time.Minute
)

// Source is a parsed install source.
//
// Source 是解析后的安装来源。
type Source struct {
	Raw    string // 规范化显示串（provenance 记录用）
	Repo   string // owner/repo（GitHub 形态时）
	Ref    string // 分支/标签/commit；GitHub 缺省 HEAD
	Subdir string // 仓库内子目录过滤（空 = 全仓）
	URL    string // 实际下载 URL
}

var ghShorthand = regexp.MustCompile(`^([\w.-]+)/([\w.-]+)$`)

// ParseSource accepts `owner/repo[@ref][#subdir]`, a github.com URL (optionally
// /tree/<ref>[/<subdir>]), or any other http(s) URL (used verbatim as a tarball address —
// this is also the seam black-box tests use with a local server).
//
// ParseSource 接受 `owner/repo[@ref][#subdir]`、github.com URL（可含 /tree/<ref>[/<subdir>]）、
// 或任意其它 http(s) URL（原样作为 tarball 地址——也是黑盒测试用本地 server 的接缝）。
func ParseSource(in string) (Source, error) {
	in = strings.TrimSpace(in)
	if in == "" {
		return Source{}, skilldomain.ErrInstallSourceInvalid
	}

	if strings.HasPrefix(in, "http://") || strings.HasPrefix(in, "https://") {
		u, err := url.Parse(in)
		if err != nil {
			return Source{}, skilldomain.ErrInstallSourceInvalid.WithCause(err)
		}
		if u.Host == "github.com" || u.Host == "www.github.com" {
			return parseGitHubURL(u)
		}
		return Source{Raw: in, URL: in}, nil
	}

	// owner/repo[@ref][#subdir] 简写。
	rest, subdir, _ := strings.Cut(in, "#")
	rest, ref, _ := strings.Cut(rest, "@")
	if !ghShorthand.MatchString(rest) {
		return Source{}, skilldomain.ErrInstallSourceInvalid
	}
	return githubSource(rest, ref, subdir), nil
}

func parseGitHubURL(u *url.URL) (Source, error) {
	parts := strings.Split(strings.Trim(u.Path, "/"), "/")
	if len(parts) < 2 {
		return Source{}, skilldomain.ErrInstallSourceInvalid
	}
	repo := parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
	ref, subdir := "", ""
	// github.com/o/r/tree/<ref>[/<subdir...>]
	if len(parts) >= 4 && parts[2] == "tree" {
		ref = parts[3]
		if len(parts) > 4 {
			subdir = strings.Join(parts[4:], "/")
		}
	}
	return githubSource(repo, ref, subdir), nil
}

func githubSource(repo, ref, subdir string) Source {
	dlRef := ref
	if dlRef == "" {
		dlRef = "HEAD" // codeload 认 git 语义的 HEAD = 默认分支
	}
	raw := repo
	if ref != "" {
		raw += "@" + ref
	}
	if subdir != "" {
		raw += "#" + subdir
	}
	return Source{
		Raw:    raw,
		Repo:   repo,
		Ref:    ref,
		Subdir: strings.Trim(subdir, "/"),
		URL:    "https://codeload.github.com/" + repo + "/tar.gz/" + url.PathEscape(dlRef),
	}
}

// Candidate is one unpacked skill found in the source — Files carries every regular file
// under the skill's directory, keyed by slash-relative path (SKILL.md included).
//
// Candidate 是来源里解出的一个 skill——Files 按 slash 相对路径承载 skill 目录下全部普通文件
// （含 SKILL.md）。
type Candidate struct {
	Name  string
	Files map[string][]byte
}

// Fetch downloads the source tarball and extracts every candidate skill: any directory
// holding a SKILL.md (case fallback accepted) is a skill root; a repo whose top level IS a
// single skill uses the repo name. Subdir filters to that subtree.
//
// Fetch 下载来源 tarball 并解出全部候选 skill：任何持有 SKILL.md（接受小写回退）的目录都是
// skill 根；顶层本身就是单 skill 的仓库用 repo 名。Subdir 过滤到该子树。
func Fetch(ctx context.Context, src Source) ([]Candidate, error) {
	ctx, cancel := context.WithTimeout(ctx, fetchTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, src.URL, nil)
	if err != nil {
		return nil, skilldomain.ErrInstallSourceInvalid.WithCause(err)
	}
	req.Header.Set("User-Agent", "anselm-skill-install")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, skilldomain.ErrInstallFetchFailed.WithCause(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, skilldomain.ErrInstallFetchFailed.WithDetails(map[string]any{
			"status": resp.StatusCode, "url": src.URL,
		})
	}
	files, err := untar(io.LimitReader(resp.Body, maxArchiveBytes+1))
	if err != nil {
		return nil, err
	}
	return carve(files, src), nil
}

// untar gunzips + walks the tar, collecting regular files (symlinks/devices dropped) under
// the bomb guards. Paths are cleaned; the archive's single top-level wrapper dir (GitHub's
// `<repo>-<sha>/`) is stripped when uniformly present.
//
// untar 解 gzip + 走 tar，收普通文件（symlink/设备条目丢弃），受炸弹护栏。路径清洗；归档统一
// 的单一顶层包装目录（GitHub 的 `<repo>-<sha>/`）在整体存在时剥除。
func untar(r io.Reader) (map[string][]byte, error) {
	gz, err := gzip.NewReader(r)
	if err != nil {
		return nil, skilldomain.ErrInstallFetchFailed.WithCause(fmt.Errorf("not a gzip tarball: %w", err))
	}
	defer gz.Close()
	tr := tar.NewReader(gz)
	files := make(map[string][]byte)
	var total int64
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, skilldomain.ErrInstallFetchFailed.WithCause(err)
		}
		if hdr.Typeflag != tar.TypeReg {
			continue // symlink / dir / device 一律不落
		}
		name := path.Clean(strings.TrimPrefix(hdr.Name, "./"))
		if name == "." || strings.HasPrefix(name, "..") || path.IsAbs(name) {
			continue // 越界条目丢弃
		}
		if len(files) >= maxFileCount {
			return nil, skilldomain.ErrInstallTooLarge.WithDetails(map[string]any{"limit": "file count", "max": maxFileCount})
		}
		if hdr.Size > skilldomain.MaxFileBytes {
			continue // 超单文件护栏的条目跳过（清单超限会让该候选在 carve 阶段落选）
		}
		data, err := io.ReadAll(io.LimitReader(tr, skilldomain.MaxFileBytes+1))
		if err != nil {
			return nil, skilldomain.ErrInstallFetchFailed.WithCause(err)
		}
		total += int64(len(data))
		if total > maxUnpackedBytes {
			return nil, skilldomain.ErrInstallTooLarge.WithDetails(map[string]any{"limit": "unpacked bytes", "max": maxUnpackedBytes})
		}
		files[name] = data
	}
	return stripWrapper(files), nil
}

// stripWrapper removes the single shared top-level directory when EVERY path sits under it.
//
// stripWrapper 在**所有**路径共享同一顶层目录时剥掉它。
func stripWrapper(files map[string][]byte) map[string][]byte {
	var wrapper string
	for p := range files {
		seg, _, ok := strings.Cut(p, "/")
		if !ok {
			return files // 顶层就有文件 → 无包装
		}
		if wrapper == "" {
			wrapper = seg
		} else if seg != wrapper {
			return files
		}
	}
	if wrapper == "" {
		return files
	}
	out := make(map[string][]byte, len(files))
	for p, d := range files {
		out[strings.TrimPrefix(p, wrapper+"/")] = d
	}
	return out
}

// carve groups the flat file map into per-skill candidates. A directory containing SKILL.md
// (or skill.md) is a skill root named by its basename; a top-level SKILL.md makes the whole
// archive ONE skill named after the repo. Subdir filters roots to that subtree. Nested skill
// roots are not double-counted — the DEEPEST root owns its files.
//
// carve 把扁平文件表切成按 skill 的候选。含 SKILL.md（或 skill.md）的目录是 skill 根、名取
// basename；顶层 SKILL.md 则整包是**一个** skill、名取 repo。Subdir 把根过滤到该子树。嵌套
// skill 根不重复计——**最深**的根拥有其文件。
func carve(files map[string][]byte, src Source) []Candidate {
	roots := map[string]bool{}
	for p := range files {
		base := path.Base(p)
		if base == "SKILL.md" || base == "skill.md" {
			roots[path.Dir(p)] = true
		}
	}
	if len(roots) == 0 {
		return nil
	}

	// 顶层单 skill：根 "." 时整包一个候选，名取 repo 尾段（无 repo 时取 URL 尾段兜底）。
	if roots["."] {
		name := path.Base(src.Repo)
		if name == "" || name == "." {
			name = strings.TrimSuffix(path.Base(src.URL), path.Ext(src.URL))
		}
		return []Candidate{{Name: strings.ToLower(name), Files: files}}
	}

	rootList := make([]string, 0, len(roots))
	for r := range roots {
		if src.Subdir != "" && r != src.Subdir && !strings.HasPrefix(r, src.Subdir+"/") {
			continue
		}
		rootList = append(rootList, r)
	}
	sort.Strings(rootList)

	out := make([]Candidate, 0, len(rootList))
	for _, root := range rootList {
		c := Candidate{Name: path.Base(root), Files: map[string][]byte{}}
		for p, d := range files {
			if !strings.HasPrefix(p, root+"/") {
				continue
			}
			rel := strings.TrimPrefix(p, root+"/")
			// 最深根拥有文件：rel 内部若还有更深的 skill 根前缀，让给那个候选。
			if deeper := deepestRootUnder(roots, root, rel); deeper {
				continue
			}
			c.Files[rel] = d
		}
		out = append(out, c)
	}
	return out
}

// deepestRootUnder reports whether rel (relative to root) belongs to a DEEPER skill root.
//
// deepestRootUnder 报告 rel（相对 root）是否属于**更深**的 skill 根。
func deepestRootUnder(roots map[string]bool, root, rel string) bool {
	dir := path.Dir(rel)
	for dir != "." {
		if roots[root+"/"+dir] {
			return true
		}
		dir = path.Dir(dir)
	}
	return false
}
