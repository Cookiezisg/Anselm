// Package harness boots the REAL backend binary and gives scenarios a typed black-box
// view of it. testend imports NOTHING from backend/ on purpose: it consumes pure
// HTTP/SSE exactly like the frontend will — every awkwardness a scenario hits here is a
// frontend-developer-experience finding, not a harness bug to paper over.
//
// Package harness 拉起**真实** backend 二进制，给场景一个带类型的黑盒视图。testend 刻意
// 不 import backend/ 任何代码：它像未来前端一样消费纯 HTTP/SSE——场景在这里碰到的每个
// 别扭都是前端开发者体验 finding，不是 harness 该兜的。
package harness

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// HeaderWorkspace is the workspace-identity header (wire fact from api.md, restated here
// because testend does not import backend).
//
// HeaderWorkspace 是 workspace 身份头（api.md 的线缆事实；testend 不 import backend 故复述）。
const HeaderWorkspace = "X-Anselm-Workspace-ID"

const (
	// gracefulStop bounds the SIGTERM → exit wait. The backend's whole ordered drain shares ONE 6s
	// deadline (bootstrap's shutdownGrace — a backend fact, restated per the black-box rule; sized to
	// nest under the app's 8s SIGTERM grace, T8 WRK-070), but a few tail steps honour no ctx
	// (pool/chat wait-groups, the SQLite WAL checkpoint), so the true ceiling is 6s plus a tail. 20s
	// stays as generous test slack — a wedged drain is a defect regardless of the exact budget.
	//
	// gracefulStop 限定 SIGTERM → 退出的等待。backend 整个有序排空共享**一个** 6s 截止（bootstrap 的
	// shutdownGrace，后端事实、按黑盒铁律复述；定为嵌进 app 侧 8s SIGTERM 宽限之内，T8 WRK-070），但
	// 尾部几步不认 ctx（池/chat 的 wait-group、SQLite WAL checkpoint），故真实上界是 6s 加一条尾巴。
	// 20s 保持为宽裕的测试余量——不论精确预算是多少，排空卡死都是缺陷。
	gracefulStop = 20 * time.Second

	// groupReapWait bounds the post-sweep wait for the process group to drain. SIGKILL'd
	// grandchildren reparent to init and are reaped in milliseconds; this is pure slack before we are
	// willing to call something a leak.
	//
	// groupReapWait 限定清扫后等进程组排空的时间。被 SIGKILL 的孙子进程会挂到 init 名下、毫秒级被收尸；
	// 这纯是判定「泄漏」前的余量。
	groupReapWait = 10 * time.Second
)

// Server is one running backend instance on a throwaway data dir.
//
// Server 是一个跑在一次性数据目录上的 backend 实例。
type Server struct {
	BaseURL string
	DataDir string
	cmd     *exec.Cmd
	pgid    int
}

var (
	buildOnce sync.Once
	buildErr  error
	binPath   string
)

// binary builds cmd/server once per test run into a shared temp location.
//
// Nothing here removes that dir on purpose: buildOnce makes the binary shared by every test in the
// package, so a t.Cleanup would delete it out from under the tests still running. Its lifetime is
// the RUN's, and so is its owner — RunTests (TestMain) contains it by pointing TMPDIR at a
// per-run self-cleaning root, which also covers the `-timeout` panic that skips cleanup entirely.
//
// binary 每次测试运行只编译一次 cmd/server，落共享临时位置。
// **此处刻意不删那个目录**：buildOnce 使该二进制被包内每个测试共享，挂 t.Cleanup 会把仍在跑的测试脚下
// 的二进制删掉。它的生命期是**整轮**的，故其所有者也是——RunTests（TestMain）把 TMPDIR 指向每轮自清的
// 根来收容它，顺带覆盖了会跳过一切 cleanup 的 `-timeout` panic。
func binary(t *testing.T) string {
	t.Helper()
	buildOnce.Do(func() {
		dir, err := os.MkdirTemp("", "testend-bin-*")
		if err != nil {
			buildErr = err
			return
		}
		binPath = filepath.Join(dir, "anselm-server")
		cmd := exec.Command("go", "build", "-o", binPath, "./cmd/server")
		cmd.Dir = backendDir()
		out, err := cmd.CombinedOutput()
		if err != nil {
			buildErr = fmt.Errorf("build backend: %v\n%s", err, out)
		}
	})
	if buildErr != nil {
		t.Fatalf("harness: %v", buildErr)
	}
	return binPath
}

// backendDir resolves ../backend relative to this package (testend sits beside backend).
//
// backendDir 解析本包旁的 ../backend（testend 与 backend 平级）。
func backendDir() string {
	wd, _ := os.Getwd()
	for d := wd; d != "/"; d = filepath.Dir(d) {
		cand := filepath.Join(d, "backend", "cmd", "server")
		if _, err := os.Stat(cand); err == nil {
			return filepath.Join(d, "backend")
		}
	}
	return ""
}

// runtimeCache returns the shared sandbox-runtime cache dir: real runs download python/
// node once, then every later Server boot pre-seeds from here instead of re-downloading.
//
// runtimeCache 返回共享 sandbox 运行时缓存目录：真跑首次下载 python/node 后，之后每次
// Server 启动从这里预置、不再重复下载。
func runtimeCache() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".anselm-testend-cache")
}

// cloneMissOnce keeps the fallback notice to one line per run rather than one per test case.
//
// cloneMissOnce 让回落提示每轮只出一行，而非每个用例一行。
var cloneMissOnce sync.Once

// preseedRuntimes gives one test its own private copy of the shared runtime cache.
//
// It CLONES rather than copies because Start runs once per test case and the cache is lazily filled
// (saveRuntimeCache stores each kind the first time a run downloads it), so this cost scales with how
// USEFUL the cache has become: the better the pre-seed works, the slower the suite gets. Measured:
// 221 Start calls against a cache real runs grew to 645MB (embedmodel alone is 313MB) = ~139GB of
// byte-for-byte `cp -R` per suite, ~7.3s of it on every single case. APFS clonefile is copy-on-write,
// so the seed costs ~0.24s and no disk at all, and writes into a clone never reach the source — the
// per-test isolation stays exactly as strong as the copy it replaces.
//
// preseedRuntimes 给单个测试一份共享运行时缓存的私有副本。
// 用 **clone** 而非拷贝：Start 每个用例跑一次，而缓存是懒填充的（`saveRuntimeCache` 在某 kind 首次被下载时
// 才回存），故此代价与缓存**有多好用**成正比——预置越成功，套件越慢。实测：221 次 Start × 真跑养到 645MB 的
// 缓存（光 embedmodel 就 313MB）= 每轮 ~139GB 逐字节 `cp -R`，每个用例摊 ~7.3s。APFS clonefile 是写时复制，
// 故预置只要 ~0.24s、且完全不占盘；往克隆里写永远碰不到源——每测试隔离与它替下的那次拷贝一样强。
func preseedRuntimes(t *testing.T, src, dst string) {
	t.Helper()
	cloneErr := cloneTree(src, dst)
	if cloneErr == nil {
		return
	}
	cloneMissOnce.Do(func() {
		t.Logf("harness: runtime-cache clone unavailable (%v) — falling back to cp -R; expect seconds, not milliseconds, per Start", cloneErr)
	})

	// Fall back rather than fail: the pre-seed is an optimisation, and a scenario that finds no
	// runtime just downloads one. But do NOT swallow the error the way the copy this replaced did —
	// a silent fallback is exactly how a 30m suite quietly turns back into a 30m timeout.
	//
	// 回落而非失败：预置只是优化，找不到运行时的场景自己下一个就是。但**不要**像它替下的那次拷贝那样把错误
	// 吞掉——静默回落正是 30m 套件悄悄变回 30m 超时的方式。
	if out, err := exec.Command("cp", "-R", src, dst).CombinedOutput(); err != nil {
		t.Logf("harness: pre-seed runtimes failed (%v): %s", err, strings.TrimSpace(string(out)))
	}
}

// Start boots a fresh backend on a free port + temp data dir, waits for health, and registers
// containment (graceful stop + process-group sweep + leak self-check) plus runtime cache save-back.
//
// Start 在空闲端口 + 临时数据目录上拉起全新 backend，等 health，注册收容（优雅停 + 进程组清扫 +
// 泄漏自检）与运行时缓存回存。
func Start(t *testing.T) *Server {
	t.Helper()
	bin := binary(t)
	dataDir := t.TempDir()

	// Pre-seed sandbox runtimes from the cache so scenarios that execute code don't
	// re-download per run. 从缓存预置运行时，免得执行类场景每次重新下载。
	if cache := runtimeCache(); cache != "" {
		src := filepath.Join(cache, "sandbox")
		if _, err := os.Stat(src); err == nil {
			preseedRuntimes(t, src, filepath.Join(dataDir, "sandbox"))
		}
	}

	s := &Server{DataDir: dataDir}
	// Registered BEFORE boot so it runs AFTER containment (t.Cleanup is LIFO): the cache must be
	// copied from a dead server's data dir, never from a live one still writing into it.
	// 在 boot **之前**注册，故跑在收容**之后**（t.Cleanup 是 LIFO）：缓存只能从已死 server 的数据目录拷，
	// 绝不能从仍在写盘的活 server 拷。
	t.Cleanup(s.saveRuntimeCache)
	s.boot(t, bin)
	return s
}

// boot launches the backend on s.DataDir + a free port, inside its OWN process group, registers the
// containment, and waits for health. Shared by Start and Restart so a restarted process is contained
// exactly as tightly as the original.
//
// boot 在 s.DataDir + 空闲端口上、于**独立进程组**内拉起 backend，注册收容，等 health。Start 与 Restart
// 共用它，使重启出的进程被同样严密地收容。
func (s *Server) boot(t *testing.T, bin string) {
	t.Helper()
	addr := fmt.Sprintf("127.0.0.1:%d", freePort(t))
	cmd := exec.Command(bin)
	cmd.Env = append(os.Environ(),
		"ANSELM_DATA_DIR="+s.DataDir,
		"ANSELM_ADDR="+addr,
	)
	cmd.Stdout = os.Stderr // backend logs interleave with test output for diagnosis. 后端日志混入测试输出便于诊断。
	cmd.Stderr = os.Stderr
	setupProcessGroup(cmd)
	if err := cmd.Start(); err != nil {
		t.Fatalf("harness: start backend: %v", err)
	}
	pgid := cmd.Process.Pid // Setpgid makes the child its own group leader → pgid == pid. Setpgid 令 child 自任组长 → pgid == pid。
	trackTree(pgid)
	s.cmd, s.pgid, s.BaseURL = cmd, pgid, "http://"+addr
	t.Cleanup(func() { containTree(t, cmd, pgid) })
	s.waitHealthy(t, 30*time.Second)
}

// containTree ends one backend process tree for good, then fails the test if anything survived.
//
// Layer 1 — SIGTERM. This is the ONLY thing that runs the backend's ordered graceful shutdown, and
// that chain is the only thing that kills the resident llama-server embedder (bootstrap's Shutdown
// calls search.Close near the end of it). os.Process.Kill sends an uncatchable SIGKILL, so a harness
// that "kills" the server skips the entire chain and orphans a llama-server per test — which then
// survives forever, because the backend's own reaper is a next-boot-on-the-same-data-dir safety net
// and testend hands every test a brand-new temp data dir that no later boot will ever revisit.
//
// Layer 2 — process-group SIGKILL. The safety net for everything layer 1 cannot cover: Kill9
// (SIGKILL by design — the crash in "crash recovery"), a wedged drain, a panicking server. The
// embedder is spawned with a bare exec.Command and sets no group of its own, so it inherits the
// server's group and one negative-pid signal reaps the whole subtree. macOS has no Pdeathsig, so on
// darwin this is the ONLY thing standing between a hard kill and a permanent orphan.
//
// containTree 彻底了结一棵 backend 进程树，然后在有幸存者时判测试失败。
// 第一层 SIGTERM：这是**唯一**能跑起 backend 有序优雅关停的方式，而那条链是唯一会杀常驻 llama-server
// embedder 的东西（bootstrap 的 Shutdown 在其尾部调 search.Close）。os.Process.Kill 发的是不可捕获的
// SIGKILL，故「杀」server 的 harness 会跳过整条链、每个测试孤儿掉一个 llama-server——且它将永远活着，因为
// backend 自己的回收器是「下次在同一数据目录上 boot」的安全网，而 testend 给每个测试一个全新临时数据目录、
// 再无任何 boot 会回访。
// 第二层进程组 SIGKILL：兜住第一层覆盖不到的一切：Kill9（刻意 SIGKILL——「崩溃恢复」里的那个崩溃）、卡死的
// 排空、panic 的 server。embedder 由裸 exec.Command 起、不自设进程组，故继承 server 的组，一个负 pid 信号
// 即收整棵子树。macOS 没有 Pdeathsig，故在 darwin 上这是硬杀与永久孤儿之间**唯一**的东西。
func containTree(t *testing.T, cmd *exec.Cmd, pgid int) {
	defer untrackTree(pgid)

	_ = terminate(cmd.Process) // already-exited (e.g. after Kill9) → ErrProcessDone, ignored. 已退出（如 Kill9 后）→ ErrProcessDone，忽略。
	exited := make(chan struct{})
	go func() { _, _ = cmd.Process.Wait(); close(exited) }()
	select {
	case <-exited:
	case <-time.After(gracefulStop):
		t.Errorf("harness: backend pid %d ignored SIGTERM for %s — its graceful shutdown is wedged (the group sweep below still contains it, but a wedged drain is a real backend defect)", cmd.Process.Pid, gracefulStop)
	}

	killProcessGroup(pgid)
	<-exited // SIGKILL is unstoppable; reap the leader so it stops counting as a group member. SIGKILL 不可挡；给组长收尸，免其仍算作组成员。

	deadline := time.Now().Add(groupReapWait)
	for processGroupAlive(pgid) {
		if time.Now().After(deadline) {
			t.Errorf("harness: PROCESS LEAK — process group %d still has live members %s after SIGTERM + group SIGKILL:\n%s",
				pgid, groupReapWait, groupSurvivors(pgid))
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// groupSurvivors renders the leftovers of a leaked group for the failure message — a bare pgid is
// unactionable, the command lines name the culprit.
//
// groupSurvivors 为失败信息渲染泄漏组的残留——光一个 pgid 无从下手，命令行才点得出元凶。
func groupSurvivors(pgid int) string {
	out, err := exec.Command("ps", "-o", "pid=,ppid=,command=", "-g", strconv.Itoa(pgid)).Output()
	if err != nil || len(strings.TrimSpace(string(out))) == 0 {
		return fmt.Sprintf("  (pgid %d: ps listed nothing — likely unreaped zombies)", pgid)
	}
	return strings.TrimRight(string(out), "\n")
}

// Ctrl-C safety net. Setpgid takes the backend OUT of the test binary's process group, so a SIGINT
// at the terminal now reaches only `go test` — which dies without ever running t.Cleanup. Tracking
// every live tree and sweeping them on the way out keeps Setpgid from trading the normal-exit leak
// for a Ctrl-C leak.
//
// Not covered: `go test -timeout` expiry (an in-process panic — no signal to catch) and a SIGKILL of
// the test binary itself. Both are irreducible here: on macOS there is no Pdeathsig, so nothing but
// the harness can notice the parent died, and a harness that is not running cannot notice anything.
//
// Ctrl-C 安全网。Setpgid 把 backend 移**出**了测试二进制的进程组，故终端 SIGINT 现在只触达 `go test`——它
// 会直接死掉、根本不跑 t.Cleanup。登记每棵活树并在退出路上清扫，使 Setpgid 不会拿「正常退出泄漏」换来
// 「Ctrl-C 泄漏」。未覆盖：`go test -timeout` 超时（进程内 panic，无信号可捕）与测试二进制自身被 SIGKILL。
// 二者在此不可约减：macOS 没有 Pdeathsig，故除 harness 外无人能察觉父进程已死，而不在运行的 harness 察觉不了任何事。
var (
	liveMu   sync.Mutex
	livePgid = map[int]struct{}{}
	sigOnce  sync.Once
)

func trackTree(pgid int) {
	liveMu.Lock()
	livePgid[pgid] = struct{}{}
	liveMu.Unlock()
	sigOnce.Do(func() {
		ch := make(chan os.Signal, 1)
		signal.Notify(ch, stopSignals...)
		go func() {
			<-ch
			liveMu.Lock()
			for pgid := range livePgid {
				killProcessGroup(pgid) // straight to the sweep: an interrupted run wants OUT, not a 20s drain per server. 直接清扫：被中断的跑要的是**退出**，不是每个 server 排空 20s。
			}
			liveMu.Unlock()
			os.Exit(130) // 128+SIGINT, the shell convention. 128+SIGINT，shell 惯例。
		}()
	})
}

func untrackTree(pgid int) {
	liveMu.Lock()
	delete(livePgid, pgid)
	liveMu.Unlock()
}

// saveRuntimeCache merges downloaded runtimes back into the shared cache per kind (first
// run pays, the rest ride). Per-kind, not all-or-nothing: python landing first must not
// block node/llamasrv/embedmodel downloaded by later waves from ever being cached.
//
// saveRuntimeCache 把已下载的运行时按 kind 合并回共享缓存（首跑买单、后跑搭车）。按 kind
// 而非 all-or-nothing：python 先落缓存不能挡住后续波次下的 node/llamasrv/embedmodel 入缓存。
func (s *Server) saveRuntimeCache() {
	cache := runtimeCache()
	if cache == "" {
		return
	}
	src := filepath.Join(s.DataDir, "sandbox", "runtimes")
	entries, err := os.ReadDir(src)
	if err != nil {
		return
	}
	// Parallel scenarios finish concurrently: the mutex serialises save-backs within this run, and
	// the copy-to-temp + atomic-rename below closes the cross-PROCESS window too (two agents running
	// `make testend` at once, R25) — a reader can never Stat a half-written kind into existence.
	// 并行场景并发收尾:互斥锁串行化本轮内的回存;拷到临时名+原子 rename 连跨进程窗口(R25 双 agent)
	// 一起关掉——读者绝不可能 Stat 到半写的 kind。
	cacheSaveMu.Lock()
	defer cacheSaveMu.Unlock()
	dst := filepath.Join(cache, "sandbox", "runtimes")
	_ = os.MkdirAll(dst, 0o755)
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		final := filepath.Join(dst, e.Name())
		if _, err := os.Stat(final); err == nil {
			continue // this kind already cached. 该 kind 已有缓存。
		}
		tmp := final + ".tmp-" + strconv.Itoa(os.Getpid())
		_ = os.RemoveAll(tmp) // a previous crashed save may have left this name. 上次崩掉的回存可能留过此名。
		if exec.Command("cp", "-R", filepath.Join(src, e.Name()), tmp).Run() != nil {
			_ = os.RemoveAll(tmp)
			continue
		}
		prunePIDFiles(tmp)
		if os.Rename(tmp, final) != nil {
			_ = os.RemoveAll(tmp) // another process landed the kind first — theirs is equivalent. 别的进程先落了,内容等价。
		}
	}
}

// cacheSaveMu serialises saveRuntimeCache across parallel scenarios in one run. 本轮内回存互斥。
var cacheSaveMu sync.Mutex

// prunePIDFiles strips pidfiles out of a freshly cached runtime kind. The backend's search engine
// parks its resident embedder's pid at runtimes/llamasrv/embedder.pid so the next boot on the same
// data dir can reap an orphan — a record that is meaningless outside the run that wrote it. This
// cache, by contrast, is seeded into EVERY future test's data dir and a kind is only ever copied
// once, so a pidfile riding along would be aimed, forever, at whatever unrelated process the OS has
// since recycled that number onto. The cache carries runtimes; it must never carry runtime STATE.
//
// prunePIDFiles 把 pidfile 从刚入缓存的运行时 kind 里剔掉。backend 搜索引擎把常驻 embedder 的 pid 存在
// runtimes/llamasrv/embedder.pid，供同一数据目录下次 boot 回收孤儿——该记录出了写它的那次运行即无意义。而本
// 缓存会被预置进**每个**未来测试的数据目录、且每个 kind 只拷一次，故搭车的 pidfile 将永远指向操作系统此后把
// 那个号码回收给了的某个无关进程。缓存装的是运行时，绝不能装运行时**状态**。
func prunePIDFiles(kindDir string) {
	entries, err := os.ReadDir(kindDir)
	if err != nil {
		return
	}
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".pid") {
			_ = os.Remove(filepath.Join(kindDir, e.Name()))
		}
	}
}

func (s *Server) waitHealthy(t *testing.T, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		resp, err := http.Get(s.BaseURL + "/api/v1/health")
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return
			}
		}
		time.Sleep(150 * time.Millisecond)
	}
	t.Fatalf("harness: backend never became healthy at %s", s.BaseURL)
}

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("harness: free port: %v", err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// Kill9 hard-kills the backend (SIGKILL — the crash in "crash recovery"). The data dir
// survives; pair with Restart to assert durable recovery.
//
// SIGKILL is the POINT here and must stay: softening it to SIGTERM would let the graceful chain run
// and delete the very wreckage — non-terminal message rows, unreaped subprocesses, uncheckpointed
// WAL — that the recovery half then asserts gets cleaned up. It would test nothing. The subprocesses
// this deliberately orphans are collected instead by containTree's process-group sweep at test end,
// which is exactly the case that sweep exists for.
//
// Kill9 硬杀 backend（SIGKILL——「崩溃恢复」里的那个崩溃）。数据目录幸存；与 Restart 配对断言持久化恢复。
// SIGKILL 在此正是**要点**、必须保留：软化成 SIGTERM 会让优雅链跑起来、把恢复半场要断言被清理的那些残骸
// （非终态消息行、未收尸的子进程、未 checkpoint 的 WAL）**本身**先删掉——那就什么都没测。它刻意孤儿掉的子进程
// 改由测试结束时 containTree 的进程组清扫收走，那正是该清扫存在的理由。
func (s *Server) Kill9(t *testing.T) {
	t.Helper()
	if err := s.cmd.Process.Kill(); err != nil {
		t.Fatalf("harness: kill -9: %v", err)
	}
	_, _ = s.cmd.Process.Wait()
}

// Restart boots a fresh process on the SAME data dir (new port) and waits for health —
// the recovery half of a crash test. The caller must re-derive clients (BaseURL changed).
//
// Restart 在**同一**数据目录上拉起新进程（新端口）并等 health——崩溃测试的恢复半场。
// 调用方需重取客户端（BaseURL 已变）。
func (s *Server) Restart(t *testing.T) {
	t.Helper()
	s.boot(t, binary(t)) // same containment as the original — a restarted server leaks exactly as hard. 与初始进程同等收容——重启出的 server 泄漏起来一模一样。
}
