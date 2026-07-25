package fspath

import (
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// residency builds base/{root,outside} with the four escape shapes planted inside root, and returns
// (root, outside). Every Inside case below reads from this one fixture so a shape can't quietly stop
// existing.
//
// residency 建出 base/{root,outside} 并在 root 里种下四种逃逸形状,返回 (root, outside)。下面每个
// Inside 用例都读这唯一夹具,免得某个形状悄悄不存在了。
func residency(t *testing.T) (root, outside string) {
	t.Helper()
	base := t.TempDir()
	root = filepath.Join(base, "root")
	outside = filepath.Join(base, "outside")
	// The sibling whose NAME extends the root's — the case a naive strings.HasPrefix gets wrong.
	// 名字**扩展**了根名的兄弟目录——朴素 strings.HasPrefix 判错的那一格。
	evil := filepath.Join(base, "root-evil")
	for _, d := range []string{root, outside, evil, filepath.Join(root, "sub")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", d, err)
		}
	}
	for _, f := range []string{filepath.Join(root, "in.txt"), filepath.Join(outside, "secret.txt"), filepath.Join(evil, "e.txt")} {
		if err := os.WriteFile(f, []byte("x"), 0o644); err != nil {
			t.Fatalf("write %s: %v", f, err)
		}
	}
	links := map[string]string{
		"abslink": filepath.Join(outside, "secret.txt"), // absolute symlink out
		"rellink": "../outside/secret.txt",              // relative symlink out
		"dirlink": outside,                              // symlinked DIRECTORY out
	}
	for name, target := range links {
		if err := os.Symlink(target, filepath.Join(root, name)); err != nil {
			t.Fatalf("symlink %s: %v", name, err)
		}
	}
	return root, outside
}

// TestInside_NoResidencyIsAlwaysInside: root "" = not mounted, and the whole-machine status quo must
// stay gate-free — an empty root can never manufacture an "outside".
//
// TestInside_NoResidencyIsAlwaysInside:root "" = 未挂,整台机器的现状必须保持无闸——空根绝不能
// 造出一个「外面」。
func TestInside_NoResidencyIsAlwaysInside(t *testing.T) {
	for _, p := range []string{"/etc/passwd", "/", "/tmp/whatever"} {
		if !Inside("", p) {
			t.Fatalf("Inside(%q, %q) = false; an unmounted conversation has no outside", "", p)
		}
	}
}

// TestInside_PlainMembership: the ordinary yes-answers — a file in the root, a file in a subdir, a
// path that does NOT exist yet (the fresh-Write case), and the ROOT ITSELF (membership is inclusive).
//
// TestInside_PlainMembership:普通的「是」——根里的文件、子目录里的文件、**尚不存在**的路径(全新
// Write 那一格),以及**根本身**(归属含自身)。
func TestInside_PlainMembership(t *testing.T) {
	root, _ := residency(t)
	for _, p := range []string{
		filepath.Join(root, "in.txt"),
		filepath.Join(root, "sub"),
		filepath.Join(root, "new.txt"),
		filepath.Join(root, "sub", "deep", "deeper", "new.txt"),
		root,
		root + string(filepath.Separator), // trailing separator is the same directory
	} {
		if !Inside(root, p) {
			t.Errorf("Inside(root, %q) = false, want true", p)
		}
	}
}

// TestInside_DotDotTraversal: a lexical walk out — including one that lands back on a path whose
// prefix still matches the root's string.
//
// TestInside_DotDotTraversal:字面走出去——包括走完后**前缀仍匹配根字符串**的那一种。
func TestInside_DotDotTraversal(t *testing.T) {
	root, outside := residency(t)
	for _, p := range []string{
		filepath.Join(root, "..", "outside", "secret.txt"),
		filepath.Join(root, "sub", "..", "..", "outside", "x.txt"),
		filepath.Join(outside, "secret.txt"),
		filepath.Dir(root), // the residency's parent
	} {
		if Inside(root, p) {
			t.Errorf("Inside(root, %q) = true, want false (walks out of the root)", p)
		}
	}
}

// TestInside_SiblingDirectoryWithSharedNamePrefix: /root-evil vs /root — the bug a string-prefix
// check ships. This case is the whole reason Inside starts from filepath.Rel.
//
// TestInside_SiblingDirectoryWithSharedNamePrefix:/root-evil vs /root——字符串前缀判定会发出去的
// 那个 bug。这一格正是 Inside 从 filepath.Rel 起步的全部理由。
func TestInside_SiblingDirectoryWithSharedNamePrefix(t *testing.T) {
	root, _ := residency(t)
	evil := root + "-evil"
	if !strings.HasPrefix(evil, root) {
		t.Fatalf("fixture is not hard enough: %q must textually start with %q", evil, root)
	}
	for _, p := range []string{evil, filepath.Join(evil, "e.txt"), filepath.Join(evil, "new.txt")} {
		if Inside(root, p) {
			t.Errorf("Inside(root, %q) = true, want false (a sibling, not a child)", p)
		}
	}
}

// TestInside_SymlinkEscape: the three link shapes that are lexically inside and physically outside.
// Write/Edit FOLLOW the final component, so each of these is a real escape — including when the link
// is the last component (which is precisely why Inside stats rather than lstats).
//
// TestInside_SymlinkEscape:字面在内、物理在外的三种链接形状。Write/Edit 会**跟随**末段,故每一种
// 都是真逃逸——包括链接**就是**末段那种(这正是 Inside 用 Stat 而非 Lstat 的原因)。
func TestInside_SymlinkEscape(t *testing.T) {
	root, _ := residency(t)
	for _, name := range []string{"abslink", "rellink", "dirlink"} {
		p := filepath.Join(root, name)
		if Inside(root, p) {
			t.Errorf("Inside(root, %q) = true, want false (symlink points out of the root)", p)
		}
	}
	// Through a symlinked DIRECTORY: both an existing and a not-yet-existing leaf must fail closed.
	// 穿过符号链接**目录**:已存在与尚不存在的叶子都必须 fail-closed。
	for _, p := range []string{
		filepath.Join(root, "dirlink", "secret.txt"),
		filepath.Join(root, "dirlink", "brand-new.txt"),
	} {
		if Inside(root, p) {
			t.Errorf("Inside(root, %q) = true, want false (traverses a symlink out of the root)", p)
		}
	}
}

// TestInside_UnusableRootFailsClosed: a residency that is gone or is not a directory cannot be
// vouched for, so nothing is "inside" it. The user still gets a confirmation instead of a silent write.
//
// TestInside_UnusableRootFailsClosed:已消失或不是目录的驻地无法为之作保,故没有任何东西「在其内」。
// 用户仍会拿到一次确认、而不是一次静默的写。
func TestInside_UnusableRootFailsClosed(t *testing.T) {
	root, _ := residency(t)
	gone := filepath.Join(root, "does-not-exist")
	if Inside(gone, filepath.Join(gone, "x.txt")) {
		t.Error("a missing residency root must fail closed")
	}
	file := filepath.Join(root, "in.txt")
	if Inside(file, filepath.Join(file, "x.txt")) {
		t.Error("a residency root that is a FILE must fail closed")
	}
}

// TestInside_CaseFoldingOnCaseInsensitiveFS: on macOS/Windows the filesystem folds case, so /Root/x
// and /root/x are the SAME file while filepath.Rel (lexical) says otherwise. The documented verdict
// is the conservative one — gate — and this test pins that it is conservative and never permissive,
// because a permissive answer here would be a silent out-of-root write.
//
// TestInside_CaseFoldingOnCaseInsensitiveFS:macOS/Windows 上文件系统折叠大小写,故 /Root/x 与
// /root/x 是**同一个**文件,而字面的 filepath.Rel 不这么认为。记档的判词是保守那一侧——设闸——本测试
// 钉住它保守、永不宽松:此处一个宽松的答案就是一次静默的越界写。
func TestInside_CaseFoldingOnCaseInsensitiveFS(t *testing.T) {
	root, _ := residency(t)
	swapped := filepath.Join(filepath.Dir(root), "ROOT")
	caseInsensitive := false
	if _, err := os.Stat(swapped); err == nil {
		caseInsensitive = true
	}
	if !caseInsensitive {
		t.Skipf("filesystem is case-sensitive on %s — the folding edge cannot arise here", runtime.GOOS)
	}
	if Inside(root, filepath.Join(swapped, "in.txt")) {
		t.Error("case-folded spelling must fail closed (conservative), not silently pass")
	}
}

// TestExpandIn_RootResolvesRelative: with a residency, a relative path joins onto the root; an
// absolute path is untouched (zoom, not cage); ~ still wins over the residency; and traversal inside
// the argument is Cleaned exactly as Expand does.
//
// TestExpandIn_RootResolvesRelative:挂了驻地时相对路径接到根上;绝对路径原样不动(zoom 非笼子);
// ~ 仍优先于驻地;参数内部的穿越与 Expand 一样被 Clean。
func TestExpandIn_RootResolvesRelative(t *testing.T) {
	root := "/proj"
	cases := map[string]string{
		"src/main.go":   filepath.Join(root, "src/main.go"),
		"./src/x":       filepath.Join(root, "src/x"),
		"a/../b":        filepath.Join(root, "b"),
		"../sibling/x":  filepath.Join(filepath.Dir(root), "sibling/x"), // relative escapes are RESOLVED, not refused — the write gate judges, not the resolver
		"/etc/hosts":    "/etc/hosts",
		"/x/../y":       "/y",
		".":             root,
		"nested/deeper": filepath.Join(root, "nested/deeper"),
	}
	for in, want := range cases {
		got, err := ExpandIn(root, in)
		if err != nil {
			t.Fatalf("ExpandIn(%q, %q) err = %v", root, in, err)
		}
		if got != want {
			t.Errorf("ExpandIn(%q, %q) = %q, want %q", root, in, got, want)
		}
	}
	home, err := os.UserHomeDir()
	if err == nil && home != "" {
		got, err := ExpandIn(root, "~/x")
		if err != nil {
			t.Fatalf("ExpandIn ~ err = %v", err)
		}
		if got != filepath.Join(home, "x") {
			t.Errorf("~ must expand to home even under a residency, got %q", got)
		}
	}
}

// TestExpandIn_EmptyRootIsExpand: root "" must be byte-identical to Expand — that equivalence is what
// lets every call site pass the ctx value through with no branch.
//
// TestExpandIn_EmptyRootIsExpand:root "" 必须与 Expand 逐字等价——正是这个等价让每个调用点都能
// 无分支透传 ctx 里的值。
func TestExpandIn_EmptyRootIsExpand(t *testing.T) {
	for _, in := range []string{"/a/b", "~", "rel/x", "", "  ", "./x", "../y"} {
		gotA, errA := Expand(in)
		gotB, errB := ExpandIn("", in)
		if gotA != gotB || !errors.Is(errB, errA) && !(errA == nil && errB == nil) {
			t.Errorf("ExpandIn(\"\", %q) = (%q,%v), want Expand's (%q,%v)", in, gotB, errB, gotA, errA)
		}
	}
	if _, err := ExpandIn("", "rel/x"); !errors.Is(err, ErrNotAbsolute) {
		t.Fatalf("relative path without a residency must be ErrNotAbsolute, got %v", err)
	}
}
