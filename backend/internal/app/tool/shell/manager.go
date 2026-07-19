package shell

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"

	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

// bgBufferBytes caps the per-process ring buffer; oldest bytes drop on overflow.
//
// bgBufferBytes 限制单进程环形缓冲；溢出丢最旧字节。
const bgBufferBytes = 256 * 1024

// Status reports a background process's current lifecycle phase.
//
// Status 报告后台进程的生命周期阶段。
type Status string

const (
	StatusRunning Status = "running"
	StatusExited  Status = "exited"
	StatusKilled  Status = "killed"
	StatusErrored Status = "errored"
)

// ErrProcessNotFound: bash_id unknown.
//
// ErrProcessNotFound：bash_id 未知。
var ErrProcessNotFound = errorspkg.New(errorspkg.KindNotFound, "SHELL_PROCESS_NOT_FOUND", "background shell process not found")

// BgProcess holds one tracked background child; the output buffer + cursor are guarded by mu.
//
// BgProcess 是一个被追踪的后台子进程；输出缓冲与游标受 mu 保护。
type BgProcess struct {
	ID        string
	Command   string
	Cmd       *exec.Cmd
	StartedAt time.Time

	mu         sync.Mutex
	buf        []byte
	dropped    int64
	readCursor int
	status     Status
	exitCode   int
	finishedAt time.Time
	launchErr  error
}

// appendOutput appends b to the ring buffer; on overflow drops from the front and rewinds the cursor.
//
// appendOutput 把 b 追加到环形缓冲；溢出时从头丢并相应回退游标。
func (p *BgProcess) appendOutput(b []byte) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.buf = append(p.buf, b...)
	if len(p.buf) <= bgBufferBytes {
		return
	}
	overflow := len(p.buf) - bgBufferBytes
	p.dropped += int64(overflow)
	p.buf = p.buf[overflow:]
	p.readCursor -= overflow
	if p.readCursor < 0 {
		p.readCursor = 0
	}
}

// drainNew returns bytes appended since the last drain and advances the cursor.
//
// drainNew 返回上次以来追加的字节并推进游标。
func (p *BgProcess) drainNew() (newBytes []byte, dropped int64, status Status, exitCode int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	out := append([]byte(nil), p.buf[p.readCursor:]...)
	p.readCursor = len(p.buf)
	return out, p.dropped, p.status, p.exitCode
}

func (p *BgProcess) markFinished(status Status, exitCode int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.status = status
	p.exitCode = exitCode
	p.finishedAt = time.Now()
}

func (p *BgProcess) markErrored(err error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.status = StatusErrored
	p.launchErr = err
	p.finishedAt = time.Now()
}

// ProcessManager owns the registry of background shell processes.
//
// ProcessManager 持有后台 shell 进程的注册表。
type ProcessManager struct {
	mu    sync.Mutex
	procs map[string]*BgProcess

	// pidDir is the crash-recovery pid manifest: one <bsh_id>.pid file per live background
	// child, so the NEXT boot can reap whole process groups that survived an ungraceful exit
	// (SIGKILL / panic / OOM bypass Stop — the in-memory map dies with us, T3). Mirrors the
	// llama embedder pidfile (infra/search/engine) + the sandbox running_pid manifest
	// (app/sandbox/restore.go). Empty = persistence off (no data dir, e.g. unit tests).
	//
	// pidDir 是崩溃恢复 pid 清单：每个活着的后台子进程一个 <bsh_id>.pid,让下次 boot 能收割熬过
	// 非优雅退出的整个进程组(SIGKILL/panic/OOM 绕过 Stop——内存 map 随进程一起死,T3)。对标 llama
	// embedder pidfile + sandbox running_pid 清单。空 = 不持久化(无 data dir,如单测)。
	pidDir string
}

// NewProcessManager returns an empty manager persisting pids under pidDir ("" disables).
//
// NewProcessManager 返一个空 manager，pid 持久化到 pidDir（"" 关闭）。
func NewProcessManager(pidDir string) *ProcessManager {
	return &ProcessManager{procs: make(map[string]*BgProcess), pidDir: pidDir}
}

// Register stamps a bsh_ ID and stores the process; caller must have set Command + Cmd before calling.
//
// Register 派 bsh_ ID 并入库；调用方须已填好 Command + Cmd。
func (m *ProcessManager) Register(p *BgProcess) {
	if p.ID == "" {
		p.ID = idgenpkg.New("bsh")
	}
	if p.StartedAt.IsZero() {
		p.StartedAt = time.Now()
	}
	if p.status == "" {
		p.status = StatusRunning
	}
	m.mu.Lock()
	m.procs[p.ID] = p
	m.mu.Unlock()
	m.record(p)
}

// Get returns the process by ID or ErrProcessNotFound.
//
// Get 按 ID 返进程，找不到返 ErrProcessNotFound。
func (m *ProcessManager) Get(id string) (*BgProcess, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.procs[id]
	if !ok {
		return nil, ErrProcessNotFound
	}
	return p, nil
}

// Remove drops the entry; used by KillShell after killing + reaping. The group was just
// SIGKILLed, so the crash-recovery record goes with it.
//
// Remove 删除注册表条目；KillShell 杀完 reap 后调用。整组刚被 SIGKILL，崩溃恢复记录一并删。
func (m *ProcessManager) Remove(id string) {
	m.mu.Lock()
	delete(m.procs, id)
	m.mu.Unlock()
	m.clearRecord(id)
}

// Stop best-effort kills every running child during graceful shutdown, dropping each
// crash-recovery record (mirrors the llama killProcess: graceful kill → remove the pidfile
// so the next boot doesn't chase a dead — possibly recycled — pid).
//
// Stop 优雅关停时尽力杀掉所有 running 子进程，并逐个删崩溃恢复记录（对标 llama killProcess：
// 优雅杀 → 删 pidfile，下次 boot 不去追一个已死、可能被复用的 pid）。
func (m *ProcessManager) Stop() {
	m.mu.Lock()
	procs := make([]*BgProcess, 0, len(m.procs))
	for _, p := range m.procs {
		procs = append(procs, p)
	}
	m.mu.Unlock()
	for _, p := range procs {
		if p.Cmd != nil && p.Cmd.Process != nil {
			_ = killProcessTree(p.Cmd)
		}
		m.clearRecord(p.ID)
	}
}

// record persists the just-started child's pid to <pidDir>/<bsh_id>.pid. Identity is certain
// at write time (it is OUR OWN direct child, spawned into its own process group — never a
// name/scan match), and every exit path removes the record (noteExited with the group fully
// dead / KillShell / graceful Stop / boot reap), so the pid-reuse window is only a crash
// while the group was actually alive — the same accepted window as the llama pidfile.
//
// record 把刚启动子进程的 pid 落到 <pidDir>/<bsh_id>.pid。写入时身份百分之百确定（是我们
// 自己的直接子进程、自成进程组——绝非名字/扫描匹配），且每条退出路径都删记录（noteExited 整组
// 已死 / KillShell / 优雅 Stop / boot 回收），pid 复用窗口只剩「组还活着时崩溃」——与 llama
// pidfile 同一条被接受的窗口。
func (m *ProcessManager) record(p *BgProcess) {
	if m.pidDir == "" || p.Cmd == nil || p.Cmd.Process == nil {
		return
	}
	_ = os.MkdirAll(m.pidDir, 0o755)
	_ = os.WriteFile(m.recordPath(p.ID), []byte(strconv.Itoa(p.Cmd.Process.Pid)), 0o644)
}

func (m *ProcessManager) recordPath(id string) string {
	return filepath.Join(m.pidDir, id+".pid")
}

func (m *ProcessManager) clearRecord(id string) {
	if m.pidDir == "" {
		return
	}
	_ = os.Remove(m.recordPath(id))
}

// noteExited narrows the crash-recovery record after the direct child was reaped: if the
// whole process group is gone the record is deleted on the spot (closing the pid-reuse
// window for short-lived jobs); if grandchildren still hold the group alive (sh -c 'daemon &')
// the record MUST stay — POSIX reserves a pgid while any member lives, so the record remains
// provably ours and KillShell / Stop / the next boot can still take the survivors out.
//
// noteExited 在直接子进程被收尸后收窄崩溃恢复记录：整组已死 → 当场删记录（短命作业的 pid 复用
// 窗口立即关闭）；孙进程还撑着组活着（sh -c 'daemon &'）→ 记录必须留——POSIX 保留有存活成员的
// pgid，记录仍可证明是我们的，KillShell / Stop / 下次 boot 仍能收割幸存者。
func (m *ProcessManager) noteExited(p *BgProcess) {
	if m.pidDir == "" || p.Cmd == nil || p.Cmd.Process == nil {
		return
	}
	if !groupAlive(p.Cmd.Process.Pid) {
		m.clearRecord(p.ID)
	}
}

// ReapStaleOnBoot best-effort kills background process groups recorded by a PRIOR run that
// survived an ungraceful exit (SIGKILL / panic / OOM / power loss bypass Stop — T3, the crash
// half R1 left open). Mirrors the sandbox boot scan (app/sandbox/restore.go
// RestoreOrCleanupOnBoot) and the llama embedder reapStalePID: probe, kill the whole group
// (negative pgid), delete the record either way. A dead pid is a harmless no-op; misparsed
// records are dropped.
//
// ReapStaleOnBoot best-effort 收割上次运行记录、熬过非优雅退出的后台进程组（SIGKILL/panic/OOM/
// 断电绕过 Stop——T3，R1 留下的崩溃半）。对标 sandbox boot 扫描与 llama reapStalePID：探活、
// 整组杀（负 pgid）、记录无论生死一律删。死 pid 无害 no-op；解析不了的记录直接丢弃。
func (m *ProcessManager) ReapStaleOnBoot(log *zap.Logger) {
	if m.pidDir == "" {
		return
	}
	entries, err := os.ReadDir(m.pidDir)
	if err != nil {
		return // no manifest dir → nothing was ever recorded. 无清单目录 → 从未有记录。
	}
	killed, alreadyDead := 0, 0
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !strings.HasSuffix(name, ".pid") {
			continue
		}
		path := filepath.Join(m.pidDir, name)
		raw, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		pid, err := strconv.Atoi(strings.TrimSpace(string(raw)))
		if err != nil || pid <= 0 {
			_ = os.Remove(path)
			continue
		}
		if reapStaleGroup(pid) {
			killed++
			log.Info("shell boot scan: killed stale background process group",
				zap.String("bash_id", strings.TrimSuffix(name, ".pid")),
				zap.Int("pid", pid))
		} else {
			alreadyDead++
		}
		_ = os.Remove(path)
	}
	if killed+alreadyDead > 0 {
		log.Info("shell boot scan complete",
			zap.Int("scanned", killed+alreadyDead),
			zap.Int("killed", killed),
			zap.Int("already_dead", alreadyDead))
	}
}
