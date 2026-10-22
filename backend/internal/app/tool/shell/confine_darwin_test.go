//go:build darwin

package shell

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func runBash(t *testing.T, ctx context.Context, cmd string) string {
	t.Helper()
	args, _ := json.Marshal(map[string]any{"command": cmd})
	out, err := (&Bash{}).Execute(ctx, string(args))
	if err != nil {
		t.Fatalf("Bash.Execute(%q): %v", cmd, err)
	}
	return out
}

// homeVictim makes a file under $HOME, NOT under a temp directory: temp is deliberately writable, so a
// victim there would test nothing. The directory is removed with the test.
//
// homeVictim 在 $HOME 下建一个文件、**不**在临时目录下：临时目录是刻意可写的，victim 放那里什么也测不到。
// 目录随测试清除。
func homeVictim(t *testing.T) (dir, file string) {
	t.Helper()
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skip("no home dir")
	}
	dir, err = os.MkdirTemp(home, ".anselm-confine-test-")
	if err != nil {
		t.Skipf("cannot create a victim under $HOME: %v", err)
	}
	t.Cleanup(func() { os.RemoveAll(dir) })
	file = filepath.Join(dir, "ledger.txt")
	if err := os.WriteFile(file, []byte("books\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir, file
}

func intact(t *testing.T, file string) bool {
	t.Helper()
	b, err := os.ReadFile(file)
	return err == nil && string(b) == "books\n"
}

// TestConfinement_OSRefusesWhateverTriesTheWrite is the point of the sandbox: the five spellings below
// are the ones the static floor was MEASURED not to read (awk, python open(...,'w')) plus the obvious
// ones. None of them is recognised by name — the kernel refuses all of them.
//
// TestConfinement_OSRefusesWhateverTriesTheWrite 是沙箱的意义所在：下面五种写法里有静态下限被**实测**读不到
// 的（awk、python open(...,'w')）与显而易见的几种。没有一种靠名字被认出——内核把它们全拒了。
func TestConfinement_OSRefusesWhateverTriesTheWrite(t *testing.T) {
	root := t.TempDir()
	_, victim := homeVictim(t)
	ctx := reqctxpkg.SetWorkDir(context.Background(), root)

	attacks := map[string]string{
		"redirect": `echo hacked > '` + victim + `'`,
		"python":   `python3 -c "open('` + victim + `','w').write('x')"`,
		"awk":      `awk 'BEGIN{printf "" > "` + victim + `"}'`,
		"perl":     `perl -e 'unlink("` + victim + `") or die "perl: $!"'`,
		"rm":       `rm -f '` + victim + `'`,
		"tee":      `echo x | tee '` + victim + `'`,
		"sed -i":   `sed -i '' 's/books/x/' '` + victim + `'`,
		"mv":       `mv '` + victim + `' '` + victim + `.gone'`,
	}
	for name, cmd := range attacks {
		out := runBash(t, ctx, cmd)
		if !intact(t, victim) {
			t.Errorf("%s: the victim changed; out=%q", name, out)
			if err := os.WriteFile(victim, []byte("books\n"), 0o644); err != nil {
				t.Fatal(err)
			}
		}
		if !strings.Contains(out, "[sandbox]") {
			t.Errorf("%s: the refusal must explain itself to the model, out=%q", name, out)
		}
	}
}

func TestConfinement_AllowsWhatBuildsNeed(t *testing.T) {
	root := t.TempDir()
	ctx := reqctxpkg.SetWorkDir(context.Background(), root)
	tmp := filepath.Join(os.TempDir(), "anselm-confine-ok-"+filepath.Base(root))
	t.Cleanup(func() { os.Remove(tmp) })

	out := runBash(t, ctx, `echo a > in.txt && mkdir sub && echo b > sub/x && echo c > /dev/null && echo d > '`+tmp+`' && cat in.txt sub/x`)
	if strings.Contains(out, "[sandbox]") || strings.Contains(out, "not permitted") || !strings.Contains(out, "a\nb") {
		t.Fatalf("writes inside the residency, /dev/null and temp must work: %q", out)
	}
	if b, err := os.ReadFile(tmp); err != nil || string(b) != "d\n" {
		t.Fatalf("temp write did not land: %v %q", err, b)
	}
	// Reads are never restricted: the residency is a zoom, not a cage.
	// 读从不受限：驻地是 zoom、不是笼子。
	if out := runBash(t, ctx, `cat /etc/hosts | head -1`); strings.Contains(out, "not permitted") || strings.TrimSpace(strings.SplitN(out, "\n[", 2)[0]) == "" {
		t.Fatalf("reads outside the residency must work: %q", out)
	}
}

// TestConfinement_HumanApprovalIsHonoured: the user said yes to this exact command, so the OS must not
// contradict them. Without the waiver the same command is refused.
//
// TestConfinement_HumanApprovalIsHonoured：用户对这条命令说了行，OS 就不能反驳他。没有豁免时同一命令被拒。
func TestConfinement_HumanApprovalIsHonoured(t *testing.T) {
	root := t.TempDir()
	_, victim := homeVictim(t)
	base := reqctxpkg.SetWorkDir(context.Background(), root)
	cmd := `echo approved > '` + victim + `'`

	runBash(t, base, cmd)
	if !intact(t, victim) {
		t.Fatal("unapproved outside write must be refused")
	}
	runBash(t, reqctxpkg.WaiveConfinement(base), cmd)
	if b, _ := os.ReadFile(victim); string(b) != "approved\n" {
		t.Fatalf("a human-approved write must go through, file=%q", b)
	}
}

// TestConfinement_NoResidencyNoConfinement: unmounted keeps today's whole-machine behaviour.
// TestConfinement_NoResidencyNoConfinement：未挂驻地保持今天整台机器的行为。
func TestConfinement_NoResidencyNoConfinement(t *testing.T) {
	_, victim := homeVictim(t)
	runBash(t, context.Background(), `echo free > '`+victim+`'`)
	if b, _ := os.ReadFile(victim); string(b) != "free\n" {
		t.Fatalf("unmounted Bash must stay unconfined, file=%q", b)
	}
}

// TestConfinement_ProfileUsesRealPaths pins the macOS /var → /private/var trap: a symlinked spelling in
// the profile denies writes even inside the residency.
// TestConfinement_ProfileUsesRealPaths 钉住 macOS 的 /var → /private/var 陷阱：profile 里写符号链接拼法会让
// 驻地之内的写入也被拒。
func TestConfinement_ProfileUsesRealPaths(t *testing.T) {
	root := t.TempDir() // /var/folders/… on macOS. macOS 上是 /var/folders/…
	real, _ := filepath.EvalSymlinks(root)
	p := writeProfile(real, os.TempDir(), os.Getenv("HOME"), "")
	if strings.Contains(p, `"/var/`) {
		t.Fatalf("profile names a symlinked /var path: %s", p)
	}
	if !strings.Contains(p, quote(real)) {
		t.Fatalf("profile does not allow the real residency path %q: %s", real, p)
	}
}

// TestConfinement_SelfPortIsClosed: the sidecar's own local API is the same authority as the entity
// tools without their human gate, so a confined shell may not reach it — by any client — while every other
// port stays reachable, and a human-approved call may.
//
// TestConfinement_SelfPortIsClosed：sidecar 自己的本地 API 与实体工具是同一份权限、只是没有它们的人闸，故受
// 约束的 shell 不得触达它——无论用哪种客户端——而其他端口照常可达，人工批准的调用则可以。
func TestConfinement_SelfPortIsClosed(t *testing.T) {
	hit := func(name string, hits *int) *httptest.Server {
		return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { *hits++ }))
	}
	var selfHits, otherHits int
	self, other := hit("self", &selfHits), hit("other", &otherHits)
	defer self.Close()
	defer other.Close()
	selfPort := strings.TrimPrefix(self.URL[strings.LastIndex(self.URL, ":"):], ":")

	root := t.TempDir()
	ctx := reqctxpkg.SetWorkDir(context.Background(), root)
	args := func(cmd string) string { b, _ := json.Marshal(map[string]any{"command": cmd}); return string(b) }
	b := &Bash{selfPort: selfPort}
	run := func(ctx context.Context, cmd string) string {
		out, err := b.Execute(ctx, args(cmd))
		if err != nil {
			t.Fatal(err)
		}
		return out
	}

	for name, cmd := range map[string]string{
		"curl":   `curl -s -X DELETE ` + self.URL + `/api/v1/functions/x`,
		"python": `python3 -c "import urllib.request as u; u.urlopen(u.Request('` + self.URL + `/x', method='DELETE'))"`,
	} {
		out := run(ctx, cmd)
		if selfHits != 0 || !strings.Contains(out, "[sandbox]") {
			t.Fatalf("%s reached the sidecar's own port (hits=%d) or went unexplained: %q", name, selfHits, out)
		}
	}
	run(ctx, `curl -s `+other.URL+`/ok`)
	if otherHits != 1 {
		t.Fatalf("another port must stay reachable, hits=%d", otherHits)
	}
	run(reqctxpkg.WaiveConfinement(ctx), `curl -s `+self.URL+`/approved`)
	if selfHits != 1 {
		t.Fatalf("a human-approved call may reach it, hits=%d", selfHits)
	}
}
