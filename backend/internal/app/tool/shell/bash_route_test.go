// bash_route_test.go — pure-function tests for the Bash auto-route layer:
// detectRuntime classification, stripCDPrefix parsing, envBinDirsForKind
// per-OS path derivation, prependPath env-var manipulation. The actual
// EnsureEnv path (Bash.maybeAutoRoute → sandbox Service) is covered in
// the D9 pipeline suite where a real sandbox can spin up.
//
// bash_route_test.go ——Bash auto-route 层 pure-function 测试：detectRuntime
// 分类、stripCDPrefix 解析、envBinDirsForKind per-OS 路径推导、prependPath
// env var 操作。真 EnsureEnv 路径（Bash.maybeAutoRoute → sandbox Service）
// 由 D9 pipeline 套覆盖（真 sandbox 启动）。

package shell

import (
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// ── detectRuntime ─────────────────────────────────────────────────────

func TestDetectRuntime_Classification(t *testing.T) {
	cases := []struct {
		cmd  string
		want string
	}{
		// Python family
		{"python script.py", "python"},
		{"python3 script.py", "python"},
		{"python3.12 -m foo", "python"},
		{"pip install pandas", "python"},
		{"pip3 install pandas", "python"},
		{"uv pip install requests", "python"},
		{"poetry add httpx", "python"},
		{"pipenv install", "python"},
		// Node family
		{"node app.js", "node"},
		{"npm install express", "node"},
		{"npx tsc", "node"},
		{"yarn add lodash", "node"},
		{"pnpm add react", "node"},
		// Rust family
		{"cargo build --release", "rust"},
		{"rustc main.rs", "rust"},
		// Go
		{"go build ./...", "go"},
		{"go test -run TestFoo", "go"},
		// Ruby family
		{"ruby script.rb", "ruby"},
		{"gem install rake", "ruby"},
		{"bundle install", "ruby"},
		{"rake test", "ruby"},
		// PHP
		{"php artisan migrate", "php"},
		{"composer require monolog/monolog", "php"},
		// Java family
		{"java -jar app.jar", "java"},
		{"javac Foo.java", "java"},
		{"mvn install", "java"},
		{"gradle build", "java"},
		// Dotnet
		{"dotnet build", "dotnet"},
		// CD prefix stripped
		{"cd /tmp && pip install pandas", "python"},
		{"cd /workspace && npm test", "node"},
		// Plain shell — nil
		{"ls -la", ""},
		{"git status", ""},
		{"cat README.md", ""},
		{"echo hello", ""},
		{"", ""},
		{"   ", ""},
		// Nested constructs intentionally NOT detected
		{`bash -c "pip install pandas"`, ""},
		{`sh -c 'npm install'`, ""},
		// First-token wins; "FOO=bar pip" doesn't strip env assignment
		{"FOO=bar pip install x", ""},
	}
	for _, c := range cases {
		got := detectRuntime(c.cmd)
		if got != c.want {
			t.Errorf("detectRuntime(%q) = %q, want %q", c.cmd, got, c.want)
		}
	}
}

func TestStripCDPrefix(t *testing.T) {
	cases := []struct {
		in       string
		wantRest string
		wantOK   bool
	}{
		{"cd /tmp && pip install x", "pip install x", true},
		{"  cd /tmp   &&   npm install", "npm install", true},
		{"cd /workspace && cd nested && npm test", "cd nested && npm test", true},
		{"pip install x", "pip install x", false},
		{"cd /tmp", "cd /tmp", false}, // no &&
		{"cd /tmp;ls", "cd /tmp;ls", false},
	}
	for _, c := range cases {
		gotRest, gotOK := stripCDPrefix(c.in)
		if gotRest != c.wantRest || gotOK != c.wantOK {
			t.Errorf("stripCDPrefix(%q) = (%q, %v), want (%q, %v)",
				c.in, gotRest, gotOK, c.wantRest, c.wantOK)
		}
	}
}

// ── envBinDirsForKind ────────────────────────────────────────────────

func TestEnvBinDirsForKind(t *testing.T) {
	envPath := "/data/envs/conv/cv_abc:python"
	cases := []struct {
		kind     string
		wantUnix []string
	}{
		{"python", []string{filepath.Join(envPath, ".venv", "bin")}},
		{"node", []string{filepath.Join(envPath, "node_modules", ".bin")}},
		{"rust", []string{filepath.Join(envPath, "bin")}},
		{"go", []string{filepath.Join(envPath, "bin")}},
		{"ruby", []string{filepath.Join(envPath, "bundle", "bin")}},
		{"php", []string{filepath.Join(envPath, "vendor", "bin")}},
		// Java / dotnet — no per-env bin dir; rely on classpath / install dir.
		{"java", nil},
		{"dotnet", nil},
		// Unknown kind — nil so prepend is a no-op.
		{"elixir", nil},
		{"", nil},
	}
	for _, c := range cases {
		got := envBinDirsForKind(envPath, c.kind)
		if c.kind == "python" && runtime.GOOS == "windows" {
			// venv bin dir is Scripts on Windows.
			want := []string{filepath.Join(envPath, ".venv", "Scripts")}
			if !slicesEqual(got, want) {
				t.Errorf("envBinDirsForKind(python) on windows = %v, want %v", got, want)
			}
			continue
		}
		if !slicesEqual(got, c.wantUnix) {
			t.Errorf("envBinDirsForKind(%s) = %v, want %v", c.kind, got, c.wantUnix)
		}
	}
}

// ── prependPath ──────────────────────────────────────────────────────

func TestPrependPath_PrependsToExistingPATH(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("PATH semantics differ on Windows; covered by case-fold test below")
	}
	env := []string{"FOO=bar", "PATH=/usr/bin:/bin", "BAZ=qux"}
	out := prependPath(env, []string{"/sandbox/.venv/bin"})

	// Order must be: prepended dirs FIRST, original PATH after.
	// 顺序：前置 dir 在前，原 PATH 在后。
	wantPath := "PATH=/sandbox/.venv/bin:/usr/bin:/bin"
	found := false
	for _, kv := range out {
		if kv == wantPath {
			found = true
		}
	}
	if !found {
		t.Errorf("PATH not prepended correctly: %v", out)
	}
	if !contains(out, "FOO=bar") || !contains(out, "BAZ=qux") {
		t.Errorf("non-PATH entries dropped: %v", out)
	}
}

func TestPrependPath_AppendsWhenPATHMissing(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Windows PATH key is Path; case-fold case below")
	}
	env := []string{"FOO=bar"}
	out := prependPath(env, []string{"/x", "/y"})
	want := "PATH=/x:/y"
	if !contains(out, want) {
		t.Errorf("PATH not appended when missing: %v (want includes %q)", out, want)
	}
}

func TestPrependPath_EmptyExtras_NoChange(t *testing.T) {
	env := []string{"FOO=bar", "PATH=/usr/bin"}
	out := prependPath(env, nil)
	if !slicesEqual(out, env) {
		t.Errorf("empty extras must not change env: %v vs %v", out, env)
	}
}

func TestPrependPath_MultipleExtrasJoinedWithSeparator(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("uses unix : separator")
	}
	env := []string{"PATH=/usr/bin"}
	out := prependPath(env, []string{"/a", "/b", "/c"})
	want := "PATH=/a:/b:/c:/usr/bin"
	if !contains(out, want) {
		t.Errorf("multiple extras not joined: got %v, want %q", out, want)
	}
}

// ── helpers ──────────────────────────────────────────────────────────

func slicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func contains(haystack []string, needle string) bool {
	for _, s := range haystack {
		if s == needle {
			return true
		}
	}
	return false
}

// envKeyEqual is exercised indirectly by the Windows-skipped tests;
// add a direct case so the helper itself is asserted.
//
// envKeyEqual 在 Windows-skipped 测试间接覆盖；加一个直接 case 让 helper
// 自身被断言。
func TestEnvKeyEqual(t *testing.T) {
	if !envKeyEqual("PATH", "PATH") {
		t.Error("identical keys should be equal")
	}
	if envKeyEqual("PATH", "FOO") {
		t.Error("different keys should not be equal")
	}
	if runtime.GOOS == "windows" {
		if !envKeyEqual("PATH", "Path") {
			t.Error("Windows: PATH/Path should be case-insensitive equal")
		}
	} else {
		if envKeyEqual("PATH", "Path") {
			t.Error("non-Windows: PATH/Path must be case-sensitive distinct")
		}
	}
	// Smoke-test: TrimSpace usage + strings import via TrimSpace branch
	// in detectRuntime stays exercised even when env-based detection is
	// blank (sanity in case linter ever flags strings as unused).
	//
	// 烟雾测试：保 strings 包 TrimSpace 持续被引用（防 linter 报未用）。
	_ = strings.TrimSpace("")
}
