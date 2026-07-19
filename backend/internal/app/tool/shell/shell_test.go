package shell

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestShellTools_NamesAndCount(t *testing.T) {
	st := NewShellTools("")
	if len(st.Tools) != 3 {
		t.Fatalf("want 3 tools, got %d", len(st.Tools))
	}
	names := map[string]bool{}
	for _, tl := range st.Tools {
		names[tl.Name()] = true
	}
	for _, w := range []string{"Bash", "BashOutput", "KillShell"} {
		if !names[w] {
			t.Fatalf("missing tool %s", w)
		}
	}
}

// TestCheckDangerous exercises the hard-block matcher as a PURE FUNCTION — the
// catastrophic commands are never handed to a shell, so a regex gap can't wipe a disk.
//
// TestCheckDangerous 把硬拦截匹配器当纯函数测——灾难命令绝不交给 shell，正则漏洞也不会抹盘。
func TestCheckDangerous(t *testing.T) {
	blocked := []string{
		"rm -rf /", "rm -fr /", "rm -rf /*", "rm -rf ~", "rm -rf $HOME",
		"sudo rm x", "doas reboot",
		"mkfs.ext4 /dev/sda1", "mkfs /dev/sdb",
		"dd if=/dev/zero of=/dev/sda",
		"echo x > /dev/sda",
		":(){ :|:& };:",
	}
	for _, c := range blocked {
		if _, b := checkDangerous(c); !b {
			t.Errorf("should block: %q", c)
		}
	}
	safe := []string{
		"echo hi", "ls /", "cat /etc/hosts",
		"rm -rf /tmp/build", "rm -rf ./node_modules", "rm file.txt",
		"rm -rf ~/project/dist", // a home subdir, not the whole home
		"python train.py", "git status", "dd if=a of=b",
	}
	for _, c := range safe {
		if r, b := checkDangerous(c); b {
			t.Errorf("should NOT block: %q (reason %q)", c, r)
		}
	}
}

func TestBash_Foreground(t *testing.T) {
	b := &Bash{mgr: NewProcessManager("")}
	out, err := b.Execute(context.Background(), `{"command":"echo hello-fg"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "hello-fg") || !strings.Contains(out, "[exit code: 0]") {
		t.Fatalf("got %q", out)
	}
}

func TestBash_NonZeroExit(t *testing.T) {
	b := &Bash{mgr: NewProcessManager("")}
	out, _ := b.Execute(context.Background(), `{"command":"exit 3"}`)
	if !strings.Contains(out, "[exit code: 3]") {
		t.Fatalf("got %q", out)
	}
}

func TestBash_Timeout(t *testing.T) {
	b := &Bash{mgr: NewProcessManager("")}
	out, _ := b.Execute(context.Background(), `{"command":"sleep 5","timeout":100}`)
	if !strings.Contains(out, "timed out") {
		t.Fatalf("got %q", out)
	}
}

// TestBash_DangerBlocked goes through Execute with a harmless-if-it-ran command (whoami)
// behind a blocked prefix (sudo), so the test is safe even if the block ever regressed.
//
// TestBash_DangerBlocked 经 Execute 测，用一个被拦前缀（sudo）+ 即便执行也无害的命令（whoami），
// 故即使拦截回退测试也安全。
func TestBash_DangerBlocked(t *testing.T) {
	b := &Bash{mgr: NewProcessManager("")}
	out, _ := b.Execute(context.Background(), `{"command":"sudo whoami"}`)
	if !strings.Contains(out, "blocked") {
		t.Fatalf("expected danger block, got %q", out)
	}
}

// TestBash_Timeout_GrandchildHoldingPipe: a timed-out command whose CHILD still holds the
// stdout pipe (sh -c pipeline / spawned daemon) must return promptly — group kill takes the
// grandchildren out and WaitDelay bounds any leftover pipe-holder. Without the fix this test
// blocks until the inner sleep ends (~30s).
//
// TestBash_Timeout_GrandchildHoldingPipe：超时命令的**子进程**仍攥着 stdout 管道（sh -c 管道 /
// 拉起的 daemon）也必须及时返回——组杀连孙进程一起带走、WaitDelay 兜住残余管道持有者。无此修复
// 本测试会阻塞到内层 sleep 结束（~30s）。
func TestBash_Timeout_GrandchildHoldingPipe(t *testing.T) {
	if testing.Short() {
		t.Skip("spawns real processes")
	}
	b := &Bash{mgr: NewProcessManager("")}
	start := time.Now()
	out, err := b.Execute(context.Background(), `{"command":"sleep 30 | sleep 30","timeout":200}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "timed out") {
		t.Fatalf("expected timeout note, got %q", out)
	}
	if took := time.Since(start); took > 8*time.Second {
		t.Fatalf("Execute took %s — group kill / WaitDelay not effective", took)
	}
}

// TestBash_NoCwdPersistence proves cd does NOT carry across calls (no cwd state) but works
// within a single command.
//
// TestBash_NoCwdPersistence 证明 cd 不跨调用（无 cwd 状态）但单条命令内有效。
func TestBash_NoCwdPersistence(t *testing.T) {
	ctx := context.Background()
	b := &Bash{mgr: NewProcessManager("")}
	if _, err := b.Execute(ctx, `{"command":"cd /tmp"}`); err != nil {
		t.Fatalf("cd: %v", err)
	}
	out, err := b.Execute(ctx, `{"command":"pwd"}`)
	if err != nil {
		t.Fatalf("pwd: %v", err)
	}
	first := strings.SplitN(out, "\n", 2)[0]
	if !strings.Contains(first, "shell") {
		t.Errorf("cd leaked across calls — pwd=%q, expected process cwd (…/tool/shell)", first)
	}
	out2, err := b.Execute(ctx, `{"command":"cd /tmp && pwd"}`)
	if err != nil {
		t.Fatalf("cd&&pwd: %v", err)
	}
	if !strings.Contains(out2, "tmp") {
		t.Errorf("cd && pwd should reach /tmp within one command: %q", out2)
	}
}

func TestBash_BackgroundOutputKill(t *testing.T) {
	ctx := context.Background()
	mgr := NewProcessManager("")
	bash := &Bash{mgr: mgr}
	out, err := bash.Execute(ctx, `{"command":"printf 'line1\nline2\n'","run_in_background":true}`)
	if err != nil {
		t.Fatalf("bg start: %v", err)
	}
	id := extractBashID(out)
	if id == "" {
		t.Fatalf("no bash_id in %q", out)
	}
	outTool := &BashOutput{mgr: mgr}
	var acc string
	for i := 0; i < 80; i++ {
		o, _ := outTool.Execute(ctx, `{"bash_id":"`+id+`"}`)
		acc += o
		if strings.Contains(acc, "line2") {
			break
		}
		time.Sleep(25 * time.Millisecond)
	}
	if !strings.Contains(acc, "line1") || !strings.Contains(acc, "line2") {
		t.Fatalf("bg output missing: %q", acc)
	}
	kill := &KillShell{mgr: mgr}
	k1, _ := kill.Execute(ctx, `{"bash_id":"`+id+`"}`)
	if !strings.Contains(k1, id) {
		t.Fatalf("kill: %q", k1)
	}
	k2, _ := kill.Execute(ctx, `{"bash_id":"`+id+`"}`)
	if !strings.Contains(k2, "not found") {
		t.Fatalf("kill again should be not-found: %q", k2)
	}
}

func TestBashOutput_Filter(t *testing.T) {
	ctx := context.Background()
	mgr := NewProcessManager("")
	bash := &Bash{mgr: mgr}
	out, _ := bash.Execute(ctx, `{"command":"printf 'apple\nbanana\ncherry\n'","run_in_background":true}`)
	id := extractBashID(out)
	outTool := &BashOutput{mgr: mgr}
	var acc string
	for i := 0; i < 80; i++ {
		o, _ := outTool.Execute(ctx, `{"bash_id":"`+id+`","filter":"ban"}`)
		acc += o
		if strings.Contains(acc, "banana") {
			break
		}
		time.Sleep(25 * time.Millisecond)
	}
	if !strings.Contains(acc, "banana") || strings.Contains(acc, "apple") {
		t.Fatalf("filter should keep only matching lines: %q", acc)
	}
}

func TestKillShell_UnknownIsHarmless(t *testing.T) {
	kill := &KillShell{mgr: NewProcessManager("")}
	out, _ := kill.Execute(context.Background(), `{"bash_id":"bsh_ghost"}`)
	if !strings.Contains(out, "not found") {
		t.Fatalf("got %q", out)
	}
}

func TestValidateInput(t *testing.T) {
	if err := (&Bash{}).ValidateInput([]byte(`{"command":""}`)); err == nil {
		t.Fatal("empty command should fail")
	}
	if err := (&Bash{}).ValidateInput([]byte(`{"command":"x","timeout":9999999}`)); err == nil {
		t.Fatal("timeout over max should fail")
	}
	if err := (&BashOutput{}).ValidateInput([]byte(`{"bash_id":""}`)); err == nil {
		t.Fatal("empty bash_id should fail")
	}
	if err := (&BashOutput{}).ValidateInput([]byte(`{"bash_id":"x","filter":"["}`)); err == nil {
		t.Fatal("invalid regex should fail")
	}
	if err := (&KillShell{}).ValidateInput([]byte(`{}`)); err == nil {
		t.Fatal("missing bash_id should fail")
	}
}

func extractBashID(s string) string {
	const k = "bash_id="
	i := strings.Index(s, k)
	if i < 0 {
		return ""
	}
	rest := s[i+len(k):]
	j := strings.IndexAny(rest, ")\n ")
	if j < 0 {
		return strings.TrimSpace(rest)
	}
	return rest[:j]
}
