package sandbox

import (
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestDirectInstallers_Kinds(t *testing.T) {
	insts := DirectInstallers()
	if len(insts) != 4 {
		t.Fatalf("want 4 installers, got %d", len(insts))
	}
	got := map[string]bool{}
	for _, in := range insts {
		got[in.Kind()] = true
	}
	for _, want := range []string{"python", "node", "uv", "dotnet"} {
		if !got[want] {
			t.Errorf("missing installer kind %q", want)
		}
	}
}

// TestRecipe_AvailableVersionsAndUserFacing pins G5b: the four user runtimes expose their
// pinned version set + UserFacing()=true (so AvailableRuntimes lists them), while engine
// artifacts (llamasrv/embedmodel) are UserFacing()=false (kept off the settings runtimes UI).
//
// TestRecipe_AvailableVersionsAndUserFacing 锁 G5b:四个用户运行时暴露钉死版本集 + UserFacing()=true
// （故 AvailableRuntimes 列它们）,引擎产物（llamasrv/embedmodel）UserFacing()=false（不上设置运行时面）。
func TestRecipe_AvailableVersionsAndUserFacing(t *testing.T) {
	type cataloger interface {
		AvailableVersions() []string
		UserFacing() bool
	}
	want := map[string][]string{ // nil = open (any version templates directly)
		"python": {"3.11", "3.12", "3.13"},
		"node":   {"22"},
		"uv":     nil,
		"dotnet": nil,
	}
	for _, inst := range DirectInstallers() {
		c, ok := inst.(cataloger)
		if !ok {
			t.Fatalf("%s does not expose AvailableVersions/UserFacing", inst.Kind())
		}
		if !c.UserFacing() {
			t.Errorf("%s: UserFacing = false, want true", inst.Kind())
		}
		w, known := want[inst.Kind()]
		if !known {
			t.Fatalf("unexpected direct installer kind %q", inst.Kind())
		}
		if !slices.Equal(c.AvailableVersions(), w) {
			t.Errorf("%s: AvailableVersions = %v, want %v", inst.Kind(), c.AvailableVersions(), w)
		}
	}
	for _, inst := range EngineInstallers() {
		c, ok := inst.(cataloger)
		if !ok {
			t.Fatalf("%s does not expose UserFacing", inst.Kind())
		}
		if c.UserFacing() {
			t.Errorf("engine installer %s must not be user-facing", inst.Kind())
		}
	}
}

func TestRecipe_Normalize(t *testing.T) {
	cases := []struct {
		recipe   runtimeRecipe
		in, want string
	}{
		{pythonRecipe(), "3.12.5", "3.12"},
		{pythonRecipe(), ">=3.12", "3.12"},
		{pythonRecipe(), "3.12", "3.12"},
		{nodeRecipe(), "22.11.0", "22"},
		{nodeRecipe(), "22", "22"},
		{uvRecipe(), "v0.11.4", "0.11.4"},
		{uvRecipe(), "0.11.4", "0.11.4"},
		{dotnetRecipe(), "10.0.300", "10.0.300"},
	}
	for _, c := range cases {
		if got := c.recipe.normalize(c.in); got != c.want {
			t.Errorf("%s normalize(%q) = %q, want %q", c.recipe.kind, c.in, got, c.want)
		}
	}
}

// TestRecipe_ResolveDarwinArm64 pins the exact asset/URL/checksum shape per runtime on the dev host
// platform, so a typo in a template or a stale version pin fails fast (offline — no download).
//
// TestRecipe_ResolveDarwinArm64 钉死开发主机平台上每个运行时的 asset/URL/校验和形状，模板笔误或版本
// 失配会即时失败（离线，不下载）。
func TestRecipe_ResolveDarwinArm64(t *testing.T) {
	cases := []struct {
		recipe          runtimeRecipe
		version         string
		wantURLContains string
		wantSumSuffix   string
		wantAlgo        string
		wantStrip       int
		wantSumList     bool
	}{
		{pythonRecipe(), "3.12", "cpython-3.12.13+20260610-aarch64-apple-darwin-install_only.tar.gz", "SHA256SUMS", "sha256", 1, true},
		{nodeRecipe(), "22", "node-v22.22.3-darwin-arm64.tar.gz", "SHASUMS256.txt", "sha256", 1, true},
		{uvRecipe(), "0.11.4", "uv-aarch64-apple-darwin.tar.gz", ".sha256", "sha256", 1, false},
		{dotnetRecipe(), "10.0.300", "dotnet-sdk-10.0.300-osx-arm64.tar.gz", ".sha512", "sha512", 0, false},
	}
	for _, c := range cases {
		spec, err := c.recipe.resolve(c.version, "darwin", "arm64")
		if err != nil {
			t.Fatalf("%s resolve: %v", c.recipe.kind, err)
		}
		if !strings.Contains(spec.url, c.wantURLContains) {
			t.Errorf("%s url = %q, want contains %q", c.recipe.kind, spec.url, c.wantURLContains)
		}
		if !strings.HasPrefix(spec.url, "https://") {
			t.Errorf("%s url not https: %q", c.recipe.kind, spec.url)
		}
		if !strings.HasSuffix(spec.sumURL, c.wantSumSuffix) {
			t.Errorf("%s sumURL = %q, want suffix %q", c.recipe.kind, spec.sumURL, c.wantSumSuffix)
		}
		if spec.sumAlgo != c.wantAlgo {
			t.Errorf("%s algo = %q, want %q", c.recipe.kind, spec.sumAlgo, c.wantAlgo)
		}
		if spec.strip != c.wantStrip {
			t.Errorf("%s strip = %d, want %d", c.recipe.kind, spec.strip, c.wantStrip)
		}
		if spec.sumList != c.wantSumList {
			t.Errorf("%s sumList = %v, want %v", c.recipe.kind, spec.sumList, c.wantSumList)
		}
		if spec.isZip() {
			t.Errorf("%s darwin asset should be tar.gz, got %q", c.recipe.kind, spec.asset)
		}
	}
}

func TestRecipe_ResolveWindowsZip(t *testing.T) {
	for _, r := range []runtimeRecipe{nodeRecipe(), uvRecipe(), dotnetRecipe(), pythonRecipe()} {
		spec, err := r.resolve(r.normalize(r.defVersion), "windows", "amd64")
		if err != nil {
			t.Fatalf("%s resolve windows: %v", r.kind, err)
		}
		// python ships install_only as .tar.gz on every platform; the others switch to .zip on windows.
		// python 各平台 install_only 都是 .tar.gz；其余在 windows 切 .zip。
		if r.kind == "python" {
			if spec.isZip() {
				t.Errorf("python windows should stay tar.gz, got %q", spec.asset)
			}
			continue
		}
		if !spec.isZip() {
			t.Errorf("%s windows asset should be .zip, got %q", r.kind, spec.asset)
		}
	}
}

func TestRecipe_UnsupportedErrors(t *testing.T) {
	if _, err := pythonRecipe().resolve("3.9", "darwin", "arm64"); err == nil {
		t.Error("python 3.9 (unpinned minor) should error")
	}
	if _, err := nodeRecipe().resolve("20", "darwin", "arm64"); err == nil {
		t.Error("node 20 (unpinned major) should error")
	}
	if _, err := pythonRecipe().resolve("3.12", "plan9", "mips"); err == nil {
		t.Error("unknown platform should error")
	}
}

func TestRecipe_BinRel(t *testing.T) {
	if got := pythonRecipe().binRel("darwin", "arm64"); got != filepath.Join("bin", "python3") {
		t.Errorf("python binRel unix = %q", got)
	}
	if got := nodeRecipe().binRel("linux", "amd64"); got != filepath.Join("bin", "node") {
		t.Errorf("node binRel unix = %q", got)
	}
	if got := uvRecipe().binRel("darwin", "arm64"); got != "uv" {
		t.Errorf("uv binRel = %q", got)
	}
	if got := dotnetRecipe().binRel("linux", "arm64"); got != "dotnet" {
		t.Errorf("dotnet binRel = %q", got)
	}
	if got := nodeRecipe().binRel("windows", "amd64"); got != "node.exe" {
		t.Errorf("node binRel windows = %q", got)
	}
}

func TestStripComponents(t *testing.T) {
	cases := []struct {
		name string
		n    int
		want string
	}{
		{"node-v22/bin/node", 1, filepath.Join("bin", "node")},
		{"node-v22/bin/node", 0, filepath.Join("node-v22", "bin", "node")},
		{"python/", 1, ""},
		{"python", 1, ""},
		{"dotnet", 0, "dotnet"},
		{"./a/b/c", 1, filepath.Join("b", "c")},
	}
	for _, c := range cases {
		if got := stripComponents(c.name, c.n); got != c.want {
			t.Errorf("stripComponents(%q, %d) = %q, want %q", c.name, c.n, got, c.want)
		}
	}
}

func TestWithin(t *testing.T) {
	if !within("/a/b", "/a/b/c/d") {
		t.Error("nested path should be within")
	}
	if within("/a/b", "/a/b/../c") {
		t.Error("escaping path should not be within")
	}
	if within("/a/b", "/a") {
		t.Error("parent path should not be within")
	}
}

func TestVersionHelpers(t *testing.T) {
	if got := stripRange(">=3.12"); got != "3.12" {
		t.Errorf("stripRange(>=3.12) = %q", got)
	}
	if got := stripRange("^1.2.3"); got != "1.2.3" {
		t.Errorf("stripRange(^1.2.3) = %q", got)
	}
	if got := majorMinor("3.12.13"); got != "3.12" {
		t.Errorf("majorMinor = %q", got)
	}
	if got := major("22.11.0"); got != "22" {
		t.Errorf("major = %q", got)
	}
}

func TestDirectInstaller_LocateMissing(t *testing.T) {
	d := &directInstaller{r: nodeRecipe()}
	if _, err := d.Locate("22", t.TempDir()); err == nil {
		t.Error("Locate should error when the binary is absent")
	}
}
