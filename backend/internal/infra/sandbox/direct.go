package sandbox

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"fmt"
	"hash"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"sort"
	"strings"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

// directInstaller is a RuntimeInstaller that fetches a runtime straight from its upstream
// distribution channel — no mise, no embedded tool. Each runtime is a pinned tarball/zip with a
// published checksum; we stream-download, verify, and extract the tree under
// <sandboxRoot>/runtimes/<kind>/<version>/.
//
// directInstaller 是直接从上游分发渠道拉运行时的 RuntimeInstaller——无 mise、无内嵌工具。每个运行时
// 是钉死版本的 tarball/zip + 公布的校验和；流式下载、校验、解压树到 <sandboxRoot>/runtimes/<kind>/
// <version>/。
type directInstaller struct{ r runtimeRecipe }

var _ sandboxdomain.RuntimeInstaller = (*directInstaller)(nil)

// DirectInstallers returns the four runtime installers (python / node / uv / dotnet), registered by
// the bootstrap composition root.
//
// DirectInstallers 返回四个运行时 installer（python / node / uv / dotnet），由 bootstrap 装配根注册。
func DirectInstallers() []sandboxdomain.RuntimeInstaller {
	recipes := []runtimeRecipe{pythonRecipe(), nodeRecipe(), uvRecipe(), dotnetRecipe()}
	out := make([]sandboxdomain.RuntimeInstaller, len(recipes))
	for i := range recipes {
		out[i] = &directInstaller{r: recipes[i]}
	}
	return out
}

func (d *directInstaller) Kind() string                                   { return d.r.kind }
func (d *directInstaller) ResolveDefault(context.Context) (string, error) { return d.r.defVersion, nil }
func (d *directInstaller) NormalizeVersion(v string) string               { return d.r.normalize(v) }

// AvailableVersions returns the pinned installable version set (nil = the version templates
// freely, so any value installs). UserFacing reports whether this is a user-installable
// language runtime — the settings "runtimes" page lists only those, never engine artifacts
// (llamasrv/embedmodel) which the search embedder auto-manages.
//
// AvailableVersions 返回钉死的可装版本集（nil = 版本自由套模板、任意值可装）。UserFacing 报告这是否
// 是用户可装的语言运行时——设置「运行时」页只列这些,绝不列引擎产物（llamasrv/embedmodel,由搜索
// embedder 自管）。
func (d *directInstaller) AvailableVersions() []string { return d.r.versions }
func (d *directInstaller) UserFacing() bool            { return d.r.userFacing }

// runtimeRoot is the install dir for a (kind, version): <sandboxRoot>/runtimes/<kind>/<normalized>.
// Consumers join their own subpaths onto it (node → bin/npm, dotnet → dnx), so it must hold the
// runtime tree with the wrapper dir stripped.
//
// runtimeRoot 是某 (kind, version) 的安装目录。消费方在其上拼自己的子路径（node→bin/npm，dotnet→dnx），
// 故它必须是剥掉 wrapper 的运行时树。
func (d *directInstaller) runtimeRoot(sandboxRoot, version string) string {
	return filepath.Join(sandboxRoot, "runtimes", d.r.kind, d.r.normalize(version))
}

// Locate returns the primary binary's absolute path; no network (the dir layout is known).
//
// Locate 返回主 binary 绝对路径；不联网（目录布局已知）。
func (d *directInstaller) Locate(version, sandboxRoot string) (string, error) {
	root := d.runtimeRoot(sandboxRoot, version)
	bin := filepath.Join(root, d.r.binRel(runtime.GOOS, runtime.GOARCH))
	if st, err := os.Stat(bin); err != nil || st.IsDir() {
		return "", fmt.Errorf("sandbox.directInstaller.Locate %s@%s: binary not at %s: %w",
			d.r.kind, version, bin, sandboxdomain.ErrRuntimeInstallFailed)
	}
	return bin, nil
}

// Install stream-downloads the pinned asset, verifies its checksum, and extracts the tree; idempotent
// (a present binary short-circuits). Returns the relPath stored in Runtime.Path.
//
// Install 流式下载钉死的 asset、校验、解压树；幂等（binary 在则短路）。返回存进 Runtime.Path 的 relPath。
func (d *directInstaller) Install(ctx context.Context, version, sandboxRoot string, stream sandboxdomain.ProgressFunc) (string, error) {
	norm := d.r.normalize(version)
	spec, err := d.r.resolve(norm, runtime.GOOS, runtime.GOARCH)
	if err != nil {
		return "", fmt.Errorf("sandbox.directInstaller.Install %s@%s: %w", d.r.kind, version, err)
	}

	root := d.runtimeRoot(sandboxRoot, version)
	rel, relErr := filepath.Rel(sandboxRoot, root)
	if relErr != nil {
		return "", fmt.Errorf("sandbox.directInstaller.Install %s: rel path: %w", d.r.kind, relErr)
	}
	binAbs := filepath.Join(root, d.r.binRel(runtime.GOOS, runtime.GOARCH))
	if st, statErr := os.Stat(binAbs); statErr == nil && !st.IsDir() {
		return rel, nil // already installed
	}

	progress(stream, "↓ 下载 %s %s（%s）", d.r.kind, norm, spec.asset)
	tmp, gotHash, err := streamDownload(ctx, spec.url, spec.sumAlgo)
	for _, alt := range spec.altURLs {
		if err == nil {
			break
		}
		progress(stream, "↓ 主源失败，改用镜像 %s", alt)
		tmp, gotHash, err = streamDownload(ctx, alt, spec.sumAlgo)
	}
	if err != nil {
		return "", fmt.Errorf("sandbox.directInstaller.Install %s: %w: %w", d.r.kind, err, sandboxdomain.ErrRuntimeInstallFailed)
	}
	defer os.Remove(tmp)

	wantHash, err := fetchChecksum(ctx, spec)
	if err != nil {
		return "", fmt.Errorf("sandbox.directInstaller.Install %s: checksum: %w: %w", d.r.kind, err, sandboxdomain.ErrRuntimeInstallFailed)
	}
	if !strings.EqualFold(gotHash, wantHash) {
		return "", fmt.Errorf("sandbox.directInstaller.Install %s: %s mismatch: want %s got %s: %w",
			d.r.kind, spec.sumAlgo, wantHash, gotHash, sandboxdomain.ErrRuntimeInstallFailed)
	}

	staging := root + ".staging"
	_ = os.RemoveAll(staging)
	if spec.raw {
		// Single-file asset: verified bytes land as <staging>/<asset>, the same
		// atomic-rename discipline as an extracted tree.
		// 单文件 asset：校验后的字节落 <staging>/<asset>，与解压树同一套原子换纪律。
		if err := os.MkdirAll(staging, 0o755); err == nil {
			err = copyFile(tmp, filepath.Join(staging, spec.asset))
		} else {
			err = fmt.Errorf("mkdir staging: %w", err)
		}
		if err != nil {
			_ = os.RemoveAll(staging)
			return "", fmt.Errorf("sandbox.directInstaller.Install %s: place: %w: %w", d.r.kind, err, sandboxdomain.ErrRuntimeInstallFailed)
		}
	} else {
		progress(stream, "⤓ 解压 %s", d.r.kind)
		if spec.isZip() {
			err = extractZipTree(tmp, staging, spec.strip)
		} else {
			err = extractTarGzTree(tmp, staging, spec.strip)
		}
		if err != nil {
			_ = os.RemoveAll(staging)
			return "", fmt.Errorf("sandbox.directInstaller.Install %s: extract: %w: %w", d.r.kind, err, sandboxdomain.ErrRuntimeInstallFailed)
		}
	}

	// Atomic swap: a half-extracted tree never occupies the canonical dir.
	// 原子换：半解压的树永不占据正式目录。
	if err := os.MkdirAll(filepath.Dir(root), 0o755); err != nil {
		_ = os.RemoveAll(staging)
		return "", fmt.Errorf("sandbox.directInstaller.Install %s: mkdir parent: %w", d.r.kind, err)
	}
	_ = os.RemoveAll(root)
	if err := os.Rename(staging, root); err != nil {
		_ = os.RemoveAll(staging)
		return "", fmt.Errorf("sandbox.directInstaller.Install %s: rename: %w", d.r.kind, err)
	}

	macPrepRuntime(ctx, root)

	if st, statErr := os.Stat(binAbs); statErr != nil || st.IsDir() {
		return "", fmt.Errorf("sandbox.directInstaller.Install %s: binary missing after extract at %s: %w",
			d.r.kind, binAbs, sandboxdomain.ErrRuntimeInstallFailed)
	}
	return rel, nil
}

// --- recipes ---------------------------------------------------------------

// runtimeRecipe is the per-kind download identity: how a normalized version maps to a platform asset
// URL + checksum + extract shape. Versions are PINNED (reproducible builds); bumping = edit one line
// here. python additionally pins the python-build-standalone release tag (its assets carry a +<date>
// suffix).
//
// runtimeRecipe 是按 kind 的下载身份：normalized 版本如何映射到平台 asset URL + 校验和 + 解压形状。
// 版本钉死（可复现）；升级 = 改这里一行。python 额外钉死 python-build-standalone 的 release tag
// （其 asset 带 +<日期> 后缀）。
type runtimeRecipe struct {
	kind       string
	defVersion string
	versions   []string // pinned installable set surfaced to the UI; nil = open (any version templates)
	userFacing bool     // true = user-installable language runtime (settings lists it); false = engine artifact
	normalize  func(string) string
	resolve    func(version, goos, goarch string) (downloadSpec, error)
	binRel     func(goos, goarch string) string
}

// sortedKeys returns a map's keys in sorted order — a recipe's pinned-version slice is derived
// from the very map resolve() looks up, so the advertised versions can never drift from the
// installable ones.
//
// sortedKeys 返回 map 的有序 key——recipe 的可装版本切片由 resolve() 查的同一张 map 派生,故对外
// 公布的版本绝不会与真正可装的漂开。
func sortedKeys(m map[string]string) []string {
	ks := make([]string, 0, len(m))
	for k := range m {
		ks = append(ks, k)
	}
	sort.Strings(ks)
	return ks
}

// downloadSpec is one platform's resolved asset.
//
// downloadSpec 是某平台解析出的 asset。
type downloadSpec struct {
	url     string
	asset   string // archive filename (zip/tgz detect + SHASUMS lookup) / 归档文件名
	sumURL  string
	sumAlgo string // "sha256" | "sha512"
	sumList bool   // sumURL is a SHASUMS file (lookup by filename); else sidecar (hash-first) / 是 SHASUMS 清单（按文件名查）否则 sidecar（取首个 hash）
	strip   int    // leading path components to drop (wrapper dir) / 剥掉的前导路径段（wrapper）

	// sumFixed pins the digest in the recipe itself — for upstreams that publish
	// no checksum file (llama.cpp releases); pinning the version pins the hash.
	// sumFixed 把摘要钉死在 recipe 里——上游不发 checksum 文件时用（llama.cpp release）；
	// 钉版本即钉 hash。
	sumFixed string
	// raw marks a single-file asset (a GGUF model): save verified bytes as
	// <root>/<asset> instead of extracting an archive tree.
	// raw 标记单文件 asset（GGUF 模型）：校验后直接落 <root>/<asset>，不解压。
	raw bool
	// altURLs are fallback mirrors tried in order when url fails — the HF →
	// hf-mirror chain for networks where huggingface.co is unreachable.
	// altURLs 是 url 失败后按序尝试的镜像——HF → hf-mirror 链，应对 huggingface.co
	// 不可达的网络。
	altURLs []string
}

func (s downloadSpec) isZip() bool { return strings.HasSuffix(s.asset, ".zip") }

// python: astral python-build-standalone install_only tarballs (relocatable). PINNED release tag +
// per-minor patch; minors beyond the map error out cleanly.
//
// python: astral python-build-standalone 的 install_only tarball（可重定位）。钉死 release tag +
// 各 minor 的 patch；表外 minor 干净报错。
func pythonRecipe() runtimeRecipe {
	const tag = "20260610"
	patch := map[string]string{"3.11": "3.11.15", "3.12": "3.12.13", "3.13": "3.13.14"}
	triple := map[string]string{
		"darwin/arm64":  "aarch64-apple-darwin",
		"darwin/amd64":  "x86_64-apple-darwin",
		"linux/amd64":   "x86_64-unknown-linux-gnu",
		"linux/arm64":   "aarch64-unknown-linux-gnu",
		"windows/amd64": "x86_64-pc-windows-msvc",
	}
	return runtimeRecipe{
		kind: "python", defVersion: "3.12", versions: sortedKeys(patch), userFacing: true,
		normalize: func(v string) string { return majorMinor(stripRange(v)) },
		resolve: func(version, goos, goarch string) (downloadSpec, error) {
			p, ok := patch[version]
			if !ok {
				return downloadSpec{}, fmt.Errorf("python %s unsupported (pinned: 3.11/3.12/3.13): %w", version, sandboxdomain.ErrRuntimeNotSupported)
			}
			tr, ok := triple[goos+"/"+goarch]
			if !ok {
				return downloadSpec{}, fmt.Errorf("python: no build for %s/%s: %w", goos, goarch, sandboxdomain.ErrRuntimeNotSupported)
			}
			asset := fmt.Sprintf("cpython-%s+%s-%s-install_only.tar.gz", p, tag, tr)
			base := "https://github.com/astral-sh/python-build-standalone/releases/download/" + tag
			// pbs publishes one SHA256SUMS manifest per release (hash<space>filename), not per-asset sidecars.
			// pbs 每个 release 发一个 SHA256SUMS 清单（hash<空格>文件名），而非每 asset 的 sidecar。
			return downloadSpec{url: base + "/" + asset, asset: asset, sumURL: base + "/SHA256SUMS", sumAlgo: "sha256", sumList: true, strip: 1}, nil
		},
		binRel: func(goos, _ string) string {
			if goos == "windows" {
				return "python.exe"
			}
			return filepath.Join("bin", "python3")
		},
	}
}

// node: official nodejs.org/dist tarballs (signed, npm bundled). PINNED 22.x LTS; SHASUMS256.txt
// carries the checksum keyed by filename.
//
// node: 官方 nodejs.org/dist tarball（已签名、自带 npm）。钉死 22.x LTS；SHASUMS256.txt 按文件名带校验和。
func nodeRecipe() runtimeRecipe {
	pin := map[string]string{"22": "22.22.3"}
	plat := map[string]string{
		"darwin/arm64":  "darwin-arm64",
		"darwin/amd64":  "darwin-x64",
		"linux/amd64":   "linux-x64",
		"linux/arm64":   "linux-arm64",
		"windows/amd64": "win-x64",
	}
	return runtimeRecipe{
		kind: "node", defVersion: "22", versions: sortedKeys(pin), userFacing: true,
		normalize: func(v string) string { return major(stripRange(v)) },
		resolve: func(version, goos, goarch string) (downloadSpec, error) {
			full, ok := pin[version]
			if !ok {
				return downloadSpec{}, fmt.Errorf("node %s unsupported (pinned: 22): %w", version, sandboxdomain.ErrRuntimeNotSupported)
			}
			pl, ok := plat[goos+"/"+goarch]
			if !ok {
				return downloadSpec{}, fmt.Errorf("node: no build for %s/%s: %w", goos, goarch, sandboxdomain.ErrRuntimeNotSupported)
			}
			ext := ".tar.gz"
			if goos == "windows" {
				ext = ".zip"
			}
			asset := fmt.Sprintf("node-v%s-%s%s", full, pl, ext)
			base := "https://nodejs.org/dist/v" + full
			return downloadSpec{url: base + "/" + asset, asset: asset, sumURL: base + "/SHASUMS256.txt", sumAlgo: "sha256", sumList: true, strip: 1}, nil
		},
		binRel: func(goos, _ string) string {
			if goos == "windows" {
				return "node.exe"
			}
			return filepath.Join("bin", "node")
		},
	}
}

// uv: astral-sh/uv release binaries (uv + uvx beside it). The release tag IS the version, so any
// version templates directly — no pin map needed; .sha256 sidecar.
//
// uv: astral-sh/uv release 二进制（uv + 同目录 uvx）。release tag 即版本，故任意版本直接套模板——无需 pin 表；
// .sha256 sidecar。
func uvRecipe() runtimeRecipe {
	triple := map[string]string{
		"darwin/arm64":  "aarch64-apple-darwin",
		"darwin/amd64":  "x86_64-apple-darwin",
		"linux/amd64":   "x86_64-unknown-linux-gnu",
		"linux/arm64":   "aarch64-unknown-linux-gnu",
		"windows/amd64": "x86_64-pc-windows-msvc",
	}
	return runtimeRecipe{
		kind: "uv", defVersion: "0.11.4", userFacing: true, // open: the release tag is the version
		normalize: func(v string) string { return strings.TrimPrefix(stripRange(v), "v") },
		resolve: func(version, goos, goarch string) (downloadSpec, error) {
			tr, ok := triple[goos+"/"+goarch]
			if !ok {
				return downloadSpec{}, fmt.Errorf("uv: no build for %s/%s: %w", goos, goarch, sandboxdomain.ErrRuntimeNotSupported)
			}
			ext := ".tar.gz"
			if goos == "windows" {
				ext = ".zip"
			}
			asset := "uv-" + tr + ext
			url := "https://github.com/astral-sh/uv/releases/download/" + version + "/" + asset
			return downloadSpec{url: url, asset: asset, sumURL: url + ".sha256", sumAlgo: "sha256", strip: 1}, nil
		},
		binRel: func(goos, _ string) string {
			if goos == "windows" {
				return "uv.exe"
			}
			return "uv"
		},
	}
}

// dotnet: official builds.dotnet.microsoft.com SDK tarballs (flat layout: dotnet + dnx at top). The
// version templates directly; checksum is a .sha512 sidecar (note: SHA-512, not 256).
//
// dotnet: 官方 builds.dotnet.microsoft.com SDK tarball（扁平布局：dotnet + dnx 在顶层）。版本直接套模板；
// 校验和是 .sha512 sidecar（注意是 SHA-512 非 256）。
func dotnetRecipe() runtimeRecipe {
	rid := map[string]string{
		"darwin/arm64":  "osx-arm64",
		"darwin/amd64":  "osx-x64",
		"linux/amd64":   "linux-x64",
		"linux/arm64":   "linux-arm64",
		"windows/amd64": "win-x64",
	}
	return runtimeRecipe{
		kind: "dotnet", defVersion: "10.0.300", userFacing: true, // open: the version templates directly
		normalize: func(v string) string { return strings.TrimPrefix(stripRange(v), "v") },
		resolve: func(version, goos, goarch string) (downloadSpec, error) {
			r, ok := rid[goos+"/"+goarch]
			if !ok {
				return downloadSpec{}, fmt.Errorf("dotnet: no build for %s/%s: %w", goos, goarch, sandboxdomain.ErrRuntimeNotSupported)
			}
			ext := ".tar.gz"
			if goos == "windows" {
				ext = ".zip"
			}
			asset := fmt.Sprintf("dotnet-sdk-%s-%s%s", version, r, ext)
			url := "https://builds.dotnet.microsoft.com/dotnet/Sdk/" + version + "/" + asset
			return downloadSpec{url: url, asset: asset, sumURL: url + ".sha512", sumAlgo: "sha512", strip: 0}, nil
		},
		binRel: func(goos, _ string) string {
			if goos == "windows" {
				return "dotnet.exe"
			}
			return "dotnet"
		},
	}
}

// --- version helpers -------------------------------------------------------

// stripRange drops a PEP 440 / semver range prefix so ">=3.12" and "3.12" share one row.
//
// stripRange 剥 PEP 440 / semver 范围前缀，使 ">=3.12" 与 "3.12" 共用一行。
func stripRange(v string) string {
	for _, p := range []string{">=", "<=", "~=", "==", ">", "<", "~", "^"} {
		if strings.HasPrefix(v, p) {
			v = v[len(p):]
			break
		}
	}
	return strings.TrimSpace(v)
}

func majorMinor(v string) string {
	if parts := strings.SplitN(v, ".", 3); len(parts) >= 2 {
		return parts[0] + "." + parts[1]
	}
	return v
}

func major(v string) string {
	if i := strings.IndexByte(v, '.'); i > 0 {
		return v[:i]
	}
	return v
}

// --- download + checksum ---------------------------------------------------

const maxRuntimeBytes = 1 << 30 // 1 GiB ceiling per runtime archive (dotnet SDK ~226 MB)

// streamDownload streams url to a temp file while hashing; returns the temp path + hex digest. The
// caller verifies the digest and removes the temp file.
//
// streamDownload 把 url 流式写入临时文件并同时哈希；返回临时路径 + hex 摘要。调用方负责校验与删除临时文件。
func streamDownload(ctx context.Context, url, algo string) (string, string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", "", fmt.Errorf("new request %s: %w", url, err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("get %s: %w", url, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return "", "", fmt.Errorf("get %s: %s", url, resp.Status)
	}

	tmp, err := os.CreateTemp("", "anselm-runtime-*")
	if err != nil {
		return "", "", fmt.Errorf("create temp: %w", err)
	}
	h := newHasher(algo)
	if _, err := io.Copy(io.MultiWriter(tmp, h), io.LimitReader(resp.Body, maxRuntimeBytes)); err != nil {
		tmp.Close()
		_ = os.Remove(tmp.Name())
		return "", "", fmt.Errorf("download body: %w", err)
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(tmp.Name())
		return "", "", fmt.Errorf("close temp: %w", err)
	}
	return tmp.Name(), hex.EncodeToString(h.Sum(nil)), nil
}

func newHasher(algo string) hash.Hash {
	if algo == "sha512" {
		return sha512.New()
	}
	return sha256.New()
}

// fetchChecksum pulls the expected hex digest, either from a SHASUMS file (keyed by filename) or a
// bare sidecar (first whitespace token).
//
// fetchChecksum 取期望的 hex 摘要：SHASUMS 清单（按文件名）或裸 sidecar（首个空白分隔 token）。
func fetchChecksum(ctx context.Context, spec downloadSpec) (string, error) {
	if spec.sumFixed != "" {
		return strings.ToLower(spec.sumFixed), nil
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, spec.sumURL, nil)
	if err != nil {
		return "", fmt.Errorf("new request %s: %w", spec.sumURL, err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("get %s: %w", spec.sumURL, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return "", fmt.Errorf("get %s: %s", spec.sumURL, resp.Status)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return "", fmt.Errorf("read %s: %w", spec.sumURL, err)
	}
	if spec.sumList {
		for line := range strings.SplitSeq(string(body), "\n") {
			f := strings.Fields(line)
			if len(f) >= 2 && strings.TrimPrefix(f[1], "./") == spec.asset {
				return strings.ToLower(f[0]), nil
			}
		}
		return "", fmt.Errorf("no SHASUMS entry for %s", spec.asset)
	}
	f := strings.Fields(string(body))
	if len(f) == 0 {
		return "", fmt.Errorf("empty checksum at %s", spec.sumURL)
	}
	return strings.ToLower(f[0]), nil
}

// progress fires a best-effort stream tick (nil stream = no-op).
//
// progress 发一条 best-effort 流 tick（stream 为 nil 即 no-op）。
func progress(stream sandboxdomain.ProgressFunc, format string, args ...any) {
	if stream != nil {
		stream("running", fmt.Sprintf(format, args...), -1)
	}
}

// macPrepRuntime clears quarantine/provenance xattrs so freshly-extracted binaries run on macOS;
// best-effort, no-op off darwin. Upstream node/uv/dotnet binaries are publisher-signed and pbs
// python is build-signed, so no re-signing is needed — only the xattr wipe.
//
// macPrepRuntime 清掉 quarantine/provenance xattr，使刚解压的二进制在 macOS 可运行；best-effort，
// 非 darwin no-op。上游 node/uv/dotnet 由发布方签名、pbs python 构建期签名，故无需重签——只需抹 xattr。
func macPrepRuntime(ctx context.Context, root string) {
	if runtime.GOOS != "darwin" {
		return
	}
	_ = exec.CommandContext(ctx, "xattr", "-cr", root).Run()
}

// --- tree extraction -------------------------------------------------------

// extractTarGzTree writes a .tar.gz's full tree to dst, dropping `strip` leading path components and
// preserving regular files, dirs, symlinks, and hardlinks.
//
// extractTarGzTree 把 .tar.gz 的整棵树写到 dst，剥掉 strip 个前导路径段，保留普通文件 / 目录 / 符号链接 /
// 硬链接。
func extractTarGzTree(srcPath, dst string, strip int) error {
	f, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("open archive: %w", err)
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return fmt.Errorf("gunzip: %w", err)
	}
	defer gz.Close()

	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return fmt.Errorf("tar next: %w", err)
		}
		rel := stripComponents(hdr.Name, strip)
		if rel == "" {
			continue
		}
		target := filepath.Join(dst, rel)
		if !within(dst, target) {
			return fmt.Errorf("tar entry escapes dst: %q", hdr.Name)
		}
		switch hdr.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0o755); err != nil {
				return fmt.Errorf("mkdir %s: %w", target, err)
			}
		case tar.TypeReg:
			if err := writeStreamFile(tr, target, hdr.FileInfo().Mode().Perm()); err != nil {
				return err
			}
		case tar.TypeSymlink:
			if err := writeSymlink(hdr.Linkname, target); err != nil {
				return err
			}
		case tar.TypeLink:
			source := filepath.Join(dst, stripComponents(hdr.Linkname, strip))
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return fmt.Errorf("mkdir for hardlink %s: %w", target, err)
			}
			_ = os.Remove(target)
			if err := os.Link(source, target); err != nil {
				return fmt.Errorf("hardlink %s -> %s: %w", target, source, err)
			}
		}
	}
}

// extractZipTree writes a .zip's full tree to dst (windows runtimes), same strip + symlink handling.
//
// extractZipTree 把 .zip 的整棵树写到 dst（windows 运行时），strip + 符号链接处理同上。
func extractZipTree(srcPath, dst string, strip int) error {
	zr, err := zip.OpenReader(srcPath)
	if err != nil {
		return fmt.Errorf("open zip: %w", err)
	}
	defer zr.Close()

	for _, zf := range zr.File {
		rel := stripComponents(zf.Name, strip)
		if rel == "" {
			continue
		}
		target := filepath.Join(dst, rel)
		if !within(dst, target) {
			return fmt.Errorf("zip entry escapes dst: %q", zf.Name)
		}
		info := zf.FileInfo()
		if info.IsDir() {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return fmt.Errorf("mkdir %s: %w", target, err)
			}
			continue
		}
		rc, err := zf.Open()
		if err != nil {
			return fmt.Errorf("open zip entry %s: %w", zf.Name, err)
		}
		if info.Mode()&os.ModeSymlink != 0 {
			linkTarget, readErr := io.ReadAll(io.LimitReader(rc, 4<<10))
			rc.Close()
			if readErr != nil {
				return fmt.Errorf("read zip symlink %s: %w", zf.Name, readErr)
			}
			if err := writeSymlink(string(linkTarget), target); err != nil {
				return err
			}
			continue
		}
		err = writeStreamFile(rc, target, info.Mode().Perm())
		rc.Close()
		if err != nil {
			return err
		}
	}
	return nil
}

// writeStreamFile creates target (perm, min 0644) and streams r into it.
//
// writeStreamFile 按 perm（至少 0644）建 target 并流式写入 r。
func writeStreamFile(r io.Reader, target string, perm os.FileMode) error {
	if perm == 0 {
		perm = 0o644
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return fmt.Errorf("mkdir for %s: %w", target, err)
	}
	out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, perm)
	if err != nil {
		return fmt.Errorf("create %s: %w", target, err)
	}
	if _, err := io.Copy(out, r); err != nil {
		out.Close()
		return fmt.Errorf("write %s: %w", target, err)
	}
	if err := out.Close(); err != nil {
		return fmt.Errorf("close %s: %w", target, err)
	}
	return nil
}

func writeSymlink(linkname, target string) error {
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return fmt.Errorf("mkdir for symlink %s: %w", target, err)
	}
	_ = os.Remove(target)
	if err := os.Symlink(linkname, target); err != nil {
		return fmt.Errorf("symlink %s -> %s: %w", target, linkname, err)
	}
	return nil
}

// stripComponents drops n leading path components from a (forward-slash) archive entry name.
//
// stripComponents 从（正斜杠）归档条目名剥掉 n 个前导路径段。
func stripComponents(name string, n int) string {
	clean := path.Clean("/" + name)[1:]
	if clean == "" || clean == "." {
		return ""
	}
	parts := strings.Split(clean, "/")
	if len(parts) <= n {
		return ""
	}
	return filepath.Join(parts[n:]...)
}

// within reports whether target is inside base (path-traversal guard).
//
// within 报告 target 是否在 base 内（防路径穿越）。
func within(base, target string) bool {
	rel, err := filepath.Rel(base, target)
	if err != nil {
		return false
	}
	return rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

// copyFile copies src to dst (0644) — the raw-asset placement step.
//
// copyFile 把 src 拷到 dst（0644）——raw asset 的落位步骤。
func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// llamasrv: the llama.cpp server binary powering the builtin search embedder
// (§domains/search.md). PINNED release tag with per-platform sha256 baked into
// the recipe (llama.cpp publishes no checksum files — pinning the tag pins the
// hash; layouts verified: tar.gz wraps a llama-<tag>/ dir, win zips are flat).
// CPU builds only: a 300M embedding model needs no GPU runtime.
//
// llamasrv：驱动内置搜索 embedder 的 llama.cpp server 二进制（§domains/search.md）。
// 钉死 release tag + 每平台 sha256 直接焙进 recipe（llama.cpp 不发 checksum 文件——
// 钉 tag 即钉 hash；布局已实证：tar.gz 包一层 llama-<tag>/、win zip 平铺）。只用
// CPU 构建：300M 嵌入模型不需要 GPU 运行时。
func llamasrvRecipe() runtimeRecipe {
	const tag = "b9601"
	type asset struct {
		name, sum string
		strip     int
	}
	assets := map[string]asset{
		"darwin/arm64":  {"llama-" + tag + "-bin-macos-arm64.tar.gz", "8e26998a6a47f68142a42006247ecd0a4c6b9a72accc67d88834c851b4703e1f", 1},
		"darwin/amd64":  {"llama-" + tag + "-bin-macos-x64.tar.gz", "ae423e8e959e82496530937b2874e5ab59983b6df25d4b3472131de07fafc079", 1},
		"linux/amd64":   {"llama-" + tag + "-bin-ubuntu-x64.tar.gz", "16d7cd9e190c63d0355a2eb751333fb806f32b9a0ba30f8a52255f0a9de407fd", 1},
		"linux/arm64":   {"llama-" + tag + "-bin-ubuntu-arm64.tar.gz", "676c85757b96c327a7ca4750678fd7ca347c5a743b71d8f8e7ef5084ab5db686", 1},
		"windows/amd64": {"llama-" + tag + "-bin-win-cpu-x64.zip", "33b1888cdc8e0469561a58019174bad8a2705d2717270f35e99757b342c25596", 0},
		"windows/arm64": {"llama-" + tag + "-bin-win-cpu-arm64.zip", "50ce7216f388221d1f16603017d439e8ffeab8878c9ee683be76ac6255540c45", 0},
	}
	return runtimeRecipe{
		kind:       "llamasrv",
		defVersion: tag,
		normalize:  func(v string) string { return v },
		resolve: func(version, goos, goarch string) (downloadSpec, error) {
			a, ok := assets[goos+"/"+goarch]
			if !ok {
				return downloadSpec{}, fmt.Errorf("llamasrv: unsupported platform %s/%s", goos, goarch)
			}
			return downloadSpec{
				url:      "https://github.com/ggml-org/llama.cpp/releases/download/" + version + "/" + a.name,
				asset:    a.name,
				sumAlgo:  "sha256",
				sumFixed: a.sum,
				strip:    a.strip,
			}, nil
		},
		binRel: func(goos, _ string) string {
			if goos == "windows" {
				return "llama-server.exe"
			}
			return "llama-server"
		},
	}
}

// embedmodel: the default embedding model (EmbeddingGemma-300m QAT Q8 GGUF,
// 100+ languages incl. Chinese, <200MB RAM). Single raw file with the HF LFS
// sha256 pinned; hf-mirror.com is the fallback for networks where
// huggingface.co is unreachable.
//
// embedmodel：默认嵌入模型（EmbeddingGemma-300m QAT Q8 GGUF，100+ 语言含中文、
// <200MB RAM）。单 raw 文件、钉 HF LFS sha256；hf-mirror.com 兜底 huggingface.co
// 不可达的网络。
func embedmodelRecipe() runtimeRecipe {
	const (
		repo = "ggml-org/embeddinggemma-300m-qat-q8_0-GGUF"
		file = "embeddinggemma-300m-qat-Q8_0.gguf"
		sum  = "6fa0c02a9c302be6f977521d399b4de3a46310a4f2621ee0063747881b673f67"
	)
	return runtimeRecipe{
		kind:       "embedmodel",
		defVersion: "embeddinggemma-300m-qat-q8_0",
		normalize:  func(v string) string { return v },
		resolve: func(_, _, _ string) (downloadSpec, error) {
			return downloadSpec{
				url:      "https://huggingface.co/" + repo + "/resolve/main/" + file,
				altURLs:  []string{"https://hf-mirror.com/" + repo + "/resolve/main/" + file},
				asset:    file,
				sumAlgo:  "sha256",
				sumFixed: sum,
				raw:      true,
			}, nil
		},
		binRel: func(_, _ string) string { return file },
	}
}

// EngineInstallers returns the search-embedder installers (llama-server binary
// + GGUF model), registered alongside the runtime installers.
//
// EngineInstallers 返回搜索 embedder 的 installer（llama-server 二进制 + GGUF 模型），
// 与运行时 installer 一并注册。
func EngineInstallers() []sandboxdomain.RuntimeInstaller {
	return []sandboxdomain.RuntimeInstaller{
		&directInstaller{r: llamasrvRecipe()},
		&directInstaller{r: embedmodelRecipe()},
	}
}
