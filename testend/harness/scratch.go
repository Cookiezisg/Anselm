// Per-run scratch containment: everything a run writes to temp lives under ONE predictable root
// that the run itself removes on the way out — and that the NEXT run removes if this one never got
// the chance.
//
// 每轮的临时收容：一轮写进 temp 的一切都落在**一个可预测的根**下，由本轮退出时自己删——本轮若没
// 机会删，则由**下一轮**删。
package harness

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// scratchRootName is the one predictable directory under TMPDIR that all runs share. Predictable is
// the whole point: a random root could only be cleaned by the process that knows its name, and the
// case we must survive is exactly the one where that process is gone.
//
// scratchRootName 是 TMPDIR 下所有轮次共享的那个可预测目录。**可预测**正是要害：随机根只有知道其名
// 字的进程才删得掉，而我们必须扛住的恰恰是「那个进程已经没了」的场景。
const scratchRootName = "anselm-testend"

// RunTests runs a package's tests inside a self-cleaning scratch root, then exits with their code.
// Wire it as the package's TestMain.
//
// Two leaks make this necessary, both structural rather than accidental:
//
//   - binary() builds the server ONCE per run (sync.Once), so no t.Cleanup can own the result — any
//     one test's cleanup would delete a binary every other test is still executing. TestMain is the
//     only hook whose lifetime is "once per package run", and it is the pattern the Go standard
//     library itself uses for a shared build artifact.
//   - `go test -timeout` fires a panic, and a panic skips every t.Cleanup AND everything after
//     m.Run() (golang/go#42217 — not a bug we can fix, a documented consequence). So NOTHING inside
//     a timing-out process can be trusted to clean up after it. The next run cleans up instead.
//
// Pointing TMPDIR at the per-run dir sweeps t.TempDir() in too (os.TempDir resolves TMPDIR on every
// call), so a timed-out run's data dirs are reclaimed by the next run rather than lingering until
// macOS gets around to /var/folders.
//
// RunTests 让一个包的测试跑在自清的 scratch 根里，然后以其退出码退出；接成该包的 TestMain。
// 两处泄漏使它成为必需，且都是结构性的、非偶然：① binary() 每轮只编一次（sync.Once），故没有任何
// t.Cleanup 有资格拥有它——任一测试的 cleanup 都会删掉别的测试正在执行的二进制；TestMain 是唯一生命
// 期等于「每包每轮一次」的挂点，也是 Go 标准库自己对共享构建产物用的模式。② `go test -timeout` 是
// panic，而 panic 跳过所有 t.Cleanup **以及 m.Run() 之后的一切**（golang/go#42217——不是我们能修的
// bug，是有据可查的后果）：故超时进程内部**没有任何东西**可信来给自己收尾，改由下一轮收。
// 把 TMPDIR 指向本轮目录顺带把 t.TempDir() 也收了进来（os.TempDir 每次调用都重读 TMPDIR），使超时那
// 轮的数据目录由下一轮回收，而不是躺在 /var/folders 里等 macOS 哪天想起来。
func RunTests(m *testing.M) {
	dir, err := claimScratch()
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness: cannot claim a scratch root: %v\n", err)
		os.Exit(1)
	}
	code := m.Run()
	// os.Exit runs no defers, so the normal-path cleanup is deliberately explicit and last.
	// os.Exit 不跑 defer，故正常路径的清理刻意写成显式的最后一步。
	_ = os.RemoveAll(dir)
	os.Exit(code)
}

// claimScratch reaps dead runs' leftovers, then takes this run's own dir and points TMPDIR at it.
//
// claimScratch 收掉已死轮次的残留，然后取本轮自己的目录并把 TMPDIR 指过去。
func claimScratch() (string, error) {
	root := filepath.Join(os.TempDir(), scratchRootName)
	if err := os.MkdirAll(root, 0o700); err != nil {
		return "", err
	}
	reapStaleScratch(root)

	dir := filepath.Join(root, strconv.Itoa(os.Getpid()))
	// Pids recycle: a long-dead run may have owned this exact name. Its leftovers are not ours to
	// inherit. pid 会复用：很久以前某轮可能占过这个名字，其残留不该被我们继承。
	if err := os.RemoveAll(dir); err != nil {
		return "", err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	// Must stay on the same volume as before (it does — this is still under TMPDIR): the runtime-cache
	// pre-seed clones with APFS clonefile, which returns EXDEV across volumes and would silently fall
	// back to a 645MB byte-for-byte copy per test case (R23).
	// 必须与原先同卷（确实——它仍在 TMPDIR 下）：运行时缓存预置走 APFS clonefile，跨卷会返 EXDEV，
	// 从而静默退化成每用例 645MB 逐字节拷贝（R23）。
	if err := os.Setenv("TMPDIR", dir); err != nil {
		return "", err
	}
	return dir, nil
}

// reapStaleScratch removes the scratch of runs that are no longer alive.
//
// Liveness — not age — is the predicate, because two agents really do run `make testend`
// concurrently on this machine (R25 records it happening), and an age-based sweep would delete a
// live run's data dir out from under it mid-test. Only a dead pid's scratch is ever removed; a
// recycled pid that now names some live process is simply skipped, and the next run gets it.
//
// reapStaleScratch 删掉已不存活轮次的 scratch。判据是**存活性**而非年龄——因为本机真的会有两个 agent
// 同时 `make testend`（R25 记载确实发生过），而按年龄清扫会在测试跑到一半时把活轮次的数据目录删掉。
// 只有死 pid 的 scratch 会被删；pid 被复用、现在指向某个活进程的，直接跳过，留给下一轮。
func reapStaleScratch(root string) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return
	}
	self := os.Getpid()
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil || pid == self || processAlive(pid) {
			continue
		}
		dir := filepath.Join(root, e.Name())
		// Kill BEFORE unlinking: a survivor holding these files keeps their inodes alive, so removing
		// the dir under it frees the names but not one byte of the disk.
		// 先杀再删：幸存者持着这些文件，其 inode 就还活着——在它脚下删目录只释放了名字、不释放一个字节。
		killScratchOrphans(dir)
		_ = os.RemoveAll(dir)
	}
}

// killScratchOrphans SIGKILLs whatever is still running out of a dead run's scratch.
//
// A `go test -timeout` panic skips t.Cleanup, so the harness's own containment (SIGTERM → group
// SIGKILL) never runs and that run's backend + its resident ~400MB llama-server embedder are
// orphaned to init — the exact "机器又烫又卡" symptom, and the one hole R22's containment cannot
// plug, because no code inside a panicking process gets to run. The next run can reach them though,
// which is the same lever the scratch reaping above pulls.
//
// The predicate is the dead run's own scratch path — absolute, under TMPDIR, and carrying a pid that
// is already proven dead. Only a process this harness started can name it, so a match is proof of
// ownership. That precision is the point: matching on a bare process name like "llama-server" would
// sweep up a CONCURRENT run's healthy children (R22 records that exact mistake being made once,
// against a live parallel suite), and a developer's own running app.
//
// killScratchOrphans 杀掉仍在某个已死轮次的 scratch 里运行的一切。`go test -timeout` 的 panic 跳过
// t.Cleanup，故座架自己的收容（SIGTERM → 组 SIGKILL）从不运行，那轮的 backend 及其常驻 ~400MB
// llama-server embedder就被孤儿给 init——正是「机器又烫又卡」那个症状，也是 R22 的收容堵不上的唯一
// 窟窿：panic 的进程里没有任何代码有机会跑。但**下一轮**够得着它们，与上面回收 scratch 是同一根杠杆。
// 判据是那个已死轮次自己的 scratch 路径——绝对路径、在 TMPDIR 下、且带着一个**已证实死亡**的 pid。
// 只有本座架起的进程叫得出这个名字，故命中即所有权证明。这份精确正是要害：拿「llama-server」这种裸进程
// 名去匹配，会连并发轮次的健康子进程一起扫掉（R22 记载这个错误真的犯过一次，对着一个活的并行套件），
// 还会扫到开发者自己在跑的 app。
func killScratchOrphans(dir string) {
	out, err := exec.Command("ps", "-Ao", "pid=,command=").Output()
	if err != nil {
		return
	}
	self := os.Getpid()
	for line := range strings.SplitSeq(string(out), "\n") {
		if !strings.Contains(line, dir) {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		pid, err := strconv.Atoi(fields[0])
		if err != nil || pid == self {
			continue
		}
		killProcess(pid)
	}
}
