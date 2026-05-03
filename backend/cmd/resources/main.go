// Command resources fetches the uv binary + python-build-standalone tarball
// for the current platform into FORGIFY_DEV_RESOURCES (default
// ~/.forgify-dev-resources), named so internal/infra/sandbox.Bootstrap can
// find them:
//
//	uv-<platform>             ← bundled uv binary (no .tar.gz wrapper)
//	python-<platform>.tar.gz  ← python-build-standalone install_only tarball
//
// Pin versions via env vars (defaults match devbox.lock's uv@0.11 +
// matching cpython-3.12 PBS release; bump in lockstep):
//
//	UV_VERSION       e.g. 0.11.8
//	PBS_TAG          e.g. 20260414
//	PYTHON_VERSION   e.g. 3.12   (matched as prefix against PBS assets)
//	FORGIFY_DEV_RESOURCES
//
// Command resources 下载当前平台的 uv 二进制 + python-build-standalone
// tarball 到 FORGIFY_DEV_RESOURCES（默认 ~/.forgify-dev-resources），按
// internal/infra/sandbox.Bootstrap 期望的文件名命名。版本默认与 devbox.lock
// 的 uv@0.11 + 对应 cpython-3.12 PBS release 对齐，升级时同步改。
package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

const (
	defaultUVVersion     = "0.11.8"
	defaultPBSTag        = "20260414"
	defaultPythonVersion = "3.12"
)

// platformMap entry: maps Go's (GOOS, GOARCH) to the upstream Rust-style
// triplet used by uv + python-build-standalone release assets, and the
// sandbox.platformKey() form ("<goos>-<goarch>") used as filename suffix.
//
// platformMap 把 Go 的 (GOOS, GOARCH) 映射到 uv + PBS release 用的 Rust 风格
// triplet，和 sandbox.platformKey() 的 "<goos>-<goarch>" 文件名后缀。
type platform struct {
	key      string // <goos>-<goarch>, used as filename suffix
	upstream string // Rust-style triplet for upstream releases
}

var platforms = map[string]platform{
	"darwin/arm64": {"darwin-arm64", "aarch64-apple-darwin"},
	"darwin/amd64": {"darwin-amd64", "x86_64-apple-darwin"},
	"linux/amd64":  {"linux-amd64", "x86_64-unknown-linux-gnu"},
	"linux/arm64":  {"linux-arm64", "aarch64-unknown-linux-gnu"},
}

func main() {
	plat, ok := platforms[runtime.GOOS+"/"+runtime.GOARCH]
	if !ok {
		log.Fatalf("unsupported platform: %s/%s", runtime.GOOS, runtime.GOARCH)
	}

	uvVersion := envOr("UV_VERSION", defaultUVVersion)
	pbsTag := envOr("PBS_TAG", defaultPBSTag)
	pyVersion := envOr("PYTHON_VERSION", defaultPythonVersion)
	resourcesDir := envOr("FORGIFY_DEV_RESOURCES", filepath.Join(mustHome(), ".forgify-dev-resources"))

	if uvVersion == "" {
		fmt.Println("→ resolving latest uv version ...")
		uvVersion = mustLatestTag("astral-sh/uv")
	}
	if pbsTag == "" {
		fmt.Println("→ resolving latest python-build-standalone release ...")
		pbsTag = mustLatestTag("astral-sh/python-build-standalone")
	}

	uvOut := filepath.Join(resourcesDir, "uv-"+plat.key)
	pyOut := filepath.Join(resourcesDir, "python-"+plat.key+".tar.gz")

	// Idempotent skip: both files already present → nothing to do.
	// Force re-download by `rm -rf $FORGIFY_DEV_RESOURCES/` first.
	// 幂等跳过：两个文件都在则什么都不做。强制重下先 rm。
	if fileExists(uvOut) && fileExists(pyOut) {
		fmt.Printf("✓ sandbox resources present at %s (%s)\n", resourcesDir, plat.key)
		return
	}
	fmt.Printf("→ sandbox resources missing for %s, downloading...\n", plat.key)

	if err := os.MkdirAll(resourcesDir, 0o755); err != nil {
		log.Fatalf("mkdir %s: %v", resourcesDir, err)
	}

	fmt.Printf("→ uv %s (%s) → %s\n", uvVersion, plat.upstream, uvOut)
	if err := fetchUV(uvVersion, plat.upstream, uvOut); err != nil {
		log.Fatalf("uv: %v", err)
	}

	fmt.Printf("→ python-build-standalone %s (cpython-%s-%s)\n", pbsTag, pyVersion, plat.upstream)
	if err := fetchPBS(pbsTag, pyVersion, plat.upstream, pyOut); err != nil {
		log.Fatalf("python: %v", err)
	}

	fmt.Printf("\n✓ resources ready: %s\n", resourcesDir)
	fmt.Printf("  uv:     %s\n", uvOut)
	fmt.Printf("  python: %s\n\n", pyOut)
	fmt.Printf("  Add to your shell:  export FORGIFY_DEV_RESOURCES=%s\n", resourcesDir)
}

// fetchUV downloads the uv release tarball, extracts the inner `uv` binary,
// writes it to dst, and chmods 0755.
//
// fetchUV 下载 uv release tarball，解出内部的 `uv` 二进制写到 dst 并 chmod 0755。
func fetchUV(version, upstream, dst string) error {
	url := fmt.Sprintf("https://github.com/astral-sh/uv/releases/download/%s/uv-%s.tar.gz", version, upstream)
	resp, err := httpGet(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	gz, err := gzip.NewReader(resp.Body)
	if err != nil {
		return fmt.Errorf("gunzip: %w", err)
	}
	defer gz.Close()

	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			return fmt.Errorf("uv binary not found in tarball")
		}
		if err != nil {
			return fmt.Errorf("tar next: %w", err)
		}
		if hdr.Typeflag != tar.TypeReg || filepath.Base(hdr.Name) != "uv" {
			continue
		}
		out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
		if err != nil {
			return fmt.Errorf("open %s: %w", dst, err)
		}
		if _, err := io.Copy(out, tr); err != nil {
			out.Close()
			return fmt.Errorf("write %s: %w", dst, err)
		}
		return out.Close()
	}
}

// fetchPBS hits the GitHub Releases API for the given PBS tag, locates the
// install_only asset matching cpython-<pyVersion>.* + upstream triplet, then
// streams the tarball to dst.
//
// fetchPBS 调 PBS release API 找到匹配 cpython-<pyVersion>.* + upstream triplet
// 的 install_only asset，流式下载到 dst。
func fetchPBS(tag, pyVersion, upstream, dst string) error {
	apiURL := fmt.Sprintf("https://api.github.com/repos/astral-sh/python-build-standalone/releases/tags/%s", tag)
	resp, err := httpGet(apiURL)
	if err != nil {
		return err
	}
	body, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		return fmt.Errorf("read release JSON: %w", err)
	}

	// Match the install_only asset URL — escape pyVersion's "." since it's
	// regex-significant. Pattern mirrors the bash grep in the original script.
	// 匹配 install_only asset URL——pyVersion 里的 "." 要转义。
	pat := fmt.Sprintf(`https://[^"]*cpython-%s\.[^"]*-%s-install_only\.tar\.gz`,
		regexp.QuoteMeta(pyVersion), regexp.QuoteMeta(upstream))
	m := regexp.MustCompile(pat).Find(body)
	if m == nil {
		return fmt.Errorf("no asset matching cpython-%s.* + %s in release %s\n  browse https://github.com/astral-sh/python-build-standalone/releases/tag/%s",
			pyVersion, upstream, tag, tag)
	}

	dl, err := httpGet(string(m))
	if err != nil {
		return err
	}
	defer dl.Body.Close()
	out, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("create %s: %w", dst, err)
	}
	if _, err := io.Copy(out, dl.Body); err != nil {
		out.Close()
		return fmt.Errorf("write %s: %w", dst, err)
	}
	return out.Close()
}

// httpGet GETs url and returns the response only on 2xx; caller closes Body.
//
// httpGet 发 GET，仅 2xx 返回 response；调用方负责关 Body。
func httpGet(url string) (*http.Response, error) {
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("get %s: %w", url, err)
	}
	if resp.StatusCode/100 != 2 {
		resp.Body.Close()
		return nil, fmt.Errorf("get %s: status %s", url, resp.Status)
	}
	return resp, nil
}

// mustLatestTag returns the latest release tag for owner/repo or dies.
//
// mustLatestTag 返 owner/repo 最新 release tag，失败 fatal。
func mustLatestTag(repo string) string {
	resp, err := httpGet("https://api.github.com/repos/" + repo + "/releases/latest")
	if err != nil {
		log.Fatalf("latest tag for %s: %v", repo, err)
	}
	defer resp.Body.Close()
	var v struct {
		TagName string `json:"tag_name"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&v); err != nil {
		log.Fatalf("decode latest tag for %s: %v", repo, err)
	}
	if v.TagName == "" {
		log.Fatalf("empty tag_name from %s latest release", repo)
	}
	return v.TagName
}

func envOr(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	// Special case: env var explicitly set to empty string means "resolve latest".
	// Mirror the bash script's behavior.
	// 特例：env var 显式设为空串表示"取 latest"——对齐 bash 脚本行为。
	if v, ok := os.LookupEnv(key); ok && v == "" {
		return ""
	}
	return fallback
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func mustHome() string {
	h, err := os.UserHomeDir()
	if err != nil {
		log.Fatalf("home dir: %v", err)
	}
	if strings.TrimSpace(h) == "" {
		log.Fatalf("home dir empty")
	}
	return h
}
