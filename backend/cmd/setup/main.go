// Command setup prepares the dev environment. Today that means fetching the jdx/mise binary into
// internal/infra/sandbox/mise/<goos>-<goarch>/ so go:embed bakes it into the server (the sandbox
// runtime manager). The binaries are gitignored — every dev / release build runs this to populate
// the embed layout. Run from backend/: `go run ./cmd/setup` (current platform) or `--all` (5 targets).
//
// Command setup 准备开发环境。目前 = 下载 jdx/mise 二进制到 internal/infra/sandbox/mise/<goos>-<goarch>/，
// 供 go:embed 烤进 server（沙箱 runtime 管理器）。二进制 gitignored——每次 dev/release 构建跑本工具填充
// embed 布局。从 backend/ 跑：`go run ./cmd/setup`（当前平台）或 `--all`（5 平台）。
package main

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

func main() {
	all := flag.Bool("all", false, "fetch all 5 supported platforms (release build); default = current host only")
	force := flag.Bool("force", false, "redownload even if the embed binary already exists")
	flag.Parse()

	if err := setup(*all, *force); err != nil {
		log.Fatalf("setup: %v", err)
	}
}

// setup runs every dev-environment step. Currently one: populate the mise embed layout.
//
// setup 跑所有 dev 环境步骤。目前一项：填充 mise embed 布局。
func setup(all, force bool) error {
	return fetchMise(all, force)
}

// --- mise embed ------------------------------------------------------------

// platform pairs a Go GOOS/GOARCH with mise's upstream asset naming + archive format.
//
// platform 把 Go GOOS/GOARCH 配上 mise 上游 asset 命名 + 归档格式。
type platform struct {
	goos, goarch    string
	miseOS, miseArc string
	archExt, binNam string
}

func (p platform) key() string { return p.goos + "-" + p.goarch }
func (p platform) outDir() string {
	return filepath.Join("internal", "infra", "sandbox", "mise", p.key())
}
func (p platform) outBin() string { return filepath.Join(p.outDir(), p.binNam) }

var supported = []platform{
	{"darwin", "arm64", "macos", "arm64", ".tar.gz", "mise"},
	{"darwin", "amd64", "macos", "x64", ".tar.gz", "mise"},
	{"linux", "amd64", "linux", "x64", ".tar.gz", "mise"},
	{"linux", "arm64", "linux", "arm64", ".tar.gz", "mise"},
	{"windows", "amd64", "windows", "x64", ".zip", "mise.exe"},
}

// fetchMise downloads + verifies + extracts mise for the host (or all 5 with all=true). Pin the
// version with MISE_VERSION (recommended for reproducible builds); empty → resolve the latest tag.
//
// fetchMise 下载 + 校验 + 解压 mise（host，或 all=true 时 5 平台）。用 MISE_VERSION 钉版本（推荐、可复现
// 构建）；空 → 解析最新 tag。
func fetchMise(all, force bool) error {
	targets := []platform{host()}
	if all {
		targets = supported
	}

	// Filter to what's actually missing first, so a fully-populated tree needs NO network at all
	// (offline-safe: an already-set-up clone re-runs setup without reaching GitHub).
	// 先筛出真正缺的，故已填充的树完全不联网（离线安全：已 setup 的 clone 重跑无需访问 GitHub）。
	var todo []platform
	for _, p := range targets {
		if !force && fileExists(p.outBin()) {
			fmt.Printf("✓ %s already present\n", p.key())
			continue
		}
		todo = append(todo, p)
	}
	if len(todo) == 0 {
		fmt.Println("✓ mise embed already complete (no download needed)")
		return nil
	}

	version := os.Getenv("MISE_VERSION")
	if version == "" {
		fmt.Println("→ resolving latest mise release…")
		v, err := latestTag("jdx/mise")
		if err != nil {
			return err
		}
		version = v
	}
	if !strings.HasPrefix(version, "v") {
		version = "v" + version
	}

	for _, p := range todo {
		fmt.Printf("\n=== %s (mise %s %s/%s) ===\n", p.key(), version, p.miseOS, p.miseArc)
		if err := os.MkdirAll(p.outDir(), 0o755); err != nil {
			return fmt.Errorf("mkdir %s: %w", p.outDir(), err)
		}
		if err := fetchOne(version, p); err != nil {
			return fmt.Errorf("%s: %w", p.key(), err)
		}
		fmt.Printf("✓ wrote %s\n", p.outBin())
	}
	fmt.Println("\n✓ mise embed ready under internal/infra/sandbox/mise/")
	if !all {
		fmt.Println("  (host only; pass --all for the 5-platform release set)")
	}
	return nil
}

// host returns the supported entry for runtime.GOOS/GOARCH, or fatals on an unsupported host.
//
// host 返匹配 runtime.GOOS/GOARCH 的项；不支持的 host fatal。
func host() platform {
	for _, p := range supported {
		if p.goos == runtime.GOOS && p.goarch == runtime.GOARCH {
			return p
		}
	}
	log.Fatalf("unsupported host %s/%s; mise embed ships only %d targets", runtime.GOOS, runtime.GOARCH, len(supported))
	return platform{}
}

// fetchOne downloads the asset, verifies its SHA256 against the release SHASUMS, and extracts the
// binary atomically.
//
// fetchOne 下载 asset、对 release SHASUMS 校验 SHA256、原子解压二进制。
func fetchOne(version string, p platform) error {
	asset := fmt.Sprintf("mise-%s-%s-%s%s", version, p.miseOS, p.miseArc, p.archExt)
	base := "https://github.com/jdx/mise/releases/download/" + version

	fmt.Printf("→ %s/%s\n", base, asset)
	body, err := getBytes(base + "/" + asset)
	if err != nil {
		return fmt.Errorf("download: %w", err)
	}
	sums, err := getBytes(base + "/SHASUMS256.txt")
	if err != nil {
		return fmt.Errorf("download SHASUMS256.txt: %w", err)
	}
	want, err := lookupSum(sums, asset)
	if err != nil {
		return err
	}
	got := sha256.Sum256(body)
	if hex.EncodeToString(got[:]) != want {
		return fmt.Errorf("sha256 mismatch: want %s got %x", want, got)
	}
	fmt.Println("✓ sha256 ok")

	if p.archExt == ".zip" {
		return extractZip(body, p.binNam, p.outBin())
	}
	return extractTarGz(body, p.binNam, p.outBin())
}

func extractTarGz(blob []byte, name, dst string) error {
	gz, err := gzip.NewReader(bytes.NewReader(blob))
	if err != nil {
		return fmt.Errorf("gunzip: %w", err)
	}
	defer gz.Close()
	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			return fmt.Errorf("%s not found in tarball", name)
		}
		if err != nil {
			return fmt.Errorf("tar: %w", err)
		}
		if hdr.Typeflag == tar.TypeReg && filepath.Base(hdr.Name) == name {
			return writeBinary(tr, dst)
		}
	}
}

func extractZip(blob []byte, name, dst string) error {
	zr, err := zip.NewReader(bytes.NewReader(blob), int64(len(blob)))
	if err != nil {
		return fmt.Errorf("unzip: %w", err)
	}
	for _, f := range zr.File {
		if filepath.Base(f.Name) != name {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return fmt.Errorf("open zip entry: %w", err)
		}
		defer rc.Close()
		return writeBinary(rc, dst)
	}
	return fmt.Errorf("%s not found in zip", name)
}

// writeBinary streams r to dst (0755) via tmp+rename for atomicity.
//
// writeBinary 用 tmp+rename 原子写 r 到 dst（0755）。
func writeBinary(r io.Reader, dst string) error {
	tmp := dst + ".tmp"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		return fmt.Errorf("open %s: %w", tmp, err)
	}
	if _, err := io.Copy(out, r); err != nil {
		out.Close()
		_ = os.Remove(tmp)
		return fmt.Errorf("write %s: %w", tmp, err)
	}
	if err := out.Close(); err != nil {
		return fmt.Errorf("close %s: %w", tmp, err)
	}
	return os.Rename(tmp, dst)
}

// lookupSum finds asset's hex digest in a SHASUMS256.txt blob.
//
// lookupSum 在 SHASUMS256.txt 里找 asset 的 hex digest。
func lookupSum(sums []byte, asset string) (string, error) {
	for line := range strings.SplitSeq(string(sums), "\n") {
		f := strings.Fields(line)
		if len(f) >= 2 && strings.TrimPrefix(f[1], "./") == asset {
			return f[0], nil
		}
	}
	return "", fmt.Errorf("no SHASUMS entry for %s", asset)
}

// getBytes GETs url and returns the body (capped 100 MB).
//
// getBytes 拉 url 返 body（上限 100 MB）。
func getBytes(url string) ([]byte, error) {
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("get %s: %w", url, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return nil, fmt.Errorf("get %s: %s", url, resp.Status)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 100<<20))
}

// latestTag resolves the newest release tag of owner/repo via the GitHub API.
//
// latestTag 经 GitHub API 解析 owner/repo 最新 release tag。
func latestTag(repo string) (string, error) {
	body, err := getBytes("https://api.github.com/repos/" + repo + "/releases/latest")
	if err != nil {
		return "", fmt.Errorf("latest tag %s: %w", repo, err)
	}
	var v struct {
		TagName string `json:"tag_name"`
	}
	if err := json.Unmarshal(body, &v); err != nil {
		return "", fmt.Errorf("decode latest tag %s: %w", repo, err)
	}
	if v.TagName == "" {
		return "", fmt.Errorf("empty tag_name for %s", repo)
	}
	return v.TagName, nil
}

func fileExists(p string) bool { _, err := os.Stat(p); return err == nil }
