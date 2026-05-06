// manager.go — in-process registry for background shell processes the
// Bash tool spawns. Owns process IDs, ring-buffered stdout+stderr per
// process, and the read cursor BashOutput uses to stream incremental
// output back to the LLM.
//
// Lifecycle: backend-process scoped. Survives multiple chat conversations
// but is wiped on backend restart (acceptable for local single-user
// Forgify; persisting bg state across restarts would invite stale-PID
// pitfalls without buying much).
//
// Concurrency: one mutex per BgProcess for output append + read cursor;
// one mutex on ProcessManager for the ID → process map. No global lock
// across all processes so concurrent BashOutput polls don't serialise.
//
// manager.go — Bash 工具 spawn 的后台 shell 进程进程内注册表。
// 持有进程 ID、每进程的环形 stdout+stderr 缓冲、以及 BashOutput 用于增量
// 流回 LLM 的读游标。
//
// 生命周期：进程级。跨多次对话存活，但后端重启即清——本地单用户的 Forgify
// 不必持久化后台 PID（且持久化反而带来僵尸 PID 隐患）。
//
// 并发：每个 BgProcess 一把锁管输出追加 + 读游标；ProcessManager 一把锁管
// ID→进程映射。无全局锁，并发 BashOutput 轮询不会互相阻塞。
package shell

import (
	"errors"
	"os/exec"
	"sync"
	"time"

	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// ── Buffer & limits ───────────────────────────────────────────────────────────

const (
	// bgBufferBytes caps the per-process output buffer. When exceeded, the
	// oldest bytes are dropped (ring-buffer semantics) so a forever-running
	// process can't consume unbounded RAM. 256 KB matches roughly 4-6 KB of
	// terminal output per second for a minute.
	//
	// bgBufferBytes 限制单进程输出缓冲。超出丢最旧（环形）。
	// 256 KB ≈ 1 分钟内 4-6 KB/s 的终端输出。
	bgBufferBytes = 256 * 1024
)

// ── Status enum ───────────────────────────────────────────────────────────────

// Status reports a background process's current lifecycle phase.
//
// Status 报告后台进程的生命周期阶段。
type Status string

const (
	StatusRunning Status = "running"
	StatusExited  Status = "exited"
	StatusKilled  Status = "killed"
	StatusErrored Status = "errored" // launch / IO failure separate from a non-zero exit
)

// ── Sentinel errors ───────────────────────────────────────────────────────────

var (
	// ErrProcessNotFound: BashOutput / KillShell got an unknown bash_id.
	// ErrProcessNotFound：BashOutput / KillShell 收到未知 bash_id。
	ErrProcessNotFound = errors.New("background shell process not found")
)

// ── BgProcess ─────────────────────────────────────────────────────────────────

// BgProcess holds one tracked child. The output buffer + cursor are
// guarded by mu; everything else is set once at creation or via
// finishedAt assignment under the same lock.
//
// BgProcess 是一个被追踪的子进程。output 缓冲与游标走 mu；其余字段创建时
// 一次写入，或在同一把锁下更新 finishedAt。
type BgProcess struct {
	ID         string
	ConvID     string // conversation that started it (informational)
	Command    string
	Cmd        *exec.Cmd
	StartedAt  time.Time

	mu         sync.Mutex
	buf        []byte // ring buffer (cap bgBufferBytes)
	dropped    int64  // bytes dropped due to ring overflow (informational)
	readCursor int    // index in buf already returned to caller
	status     Status
	exitCode   int
	finishedAt time.Time
	launchErr  error // set when status == StatusErrored
}

// appendOutput is the io.Writer side of the stdout/stderr pumps. Bytes
// past bgBufferBytes are dropped from the front to keep the buffer
// bounded. The read cursor is rewound proportionally so a cursor that
// pointed inside the dropped region snaps to "start of remaining buffer."
//
// appendOutput 是 stdout/stderr pump 的 Writer 侧。超出 bgBufferBytes 的
// 字节从头丢；读游标按比例回退，原本指在被丢区域内的游标贴齐到剩余缓冲头。
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

// drainNew returns bytes appended since the last drainNew call, advancing
// the cursor. snapshot ensures BashOutput reads consistent state without
// holding the lock during downstream regex filtering.
//
// drainNew 返回上次 drainNew 之后追加的字节并推进游标；snapshot 让 BashOutput
// 在下游正则过滤时不持锁。
func (p *BgProcess) drainNew() (newBytes []byte, dropped int64, status Status, exitCode int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	out := append([]byte(nil), p.buf[p.readCursor:]...)
	p.readCursor = len(p.buf)
	return out, p.dropped, p.status, p.exitCode
}

// markFinished records terminal status. Called from the goroutine that
// Wait()s on the child.
//
// markFinished 写入终态。由 Wait() 子进程的 goroutine 调用。
func (p *BgProcess) markFinished(status Status, exitCode int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.status = status
	p.exitCode = exitCode
	p.finishedAt = time.Now()
}

// markErrored records a launch / IO failure that prevented the child
// from running normally.
//
// markErrored 写入启动 / IO 失败。
func (p *BgProcess) markErrored(err error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.status = StatusErrored
	p.launchErr = err
	p.finishedAt = time.Now()
}

// ── ProcessManager ────────────────────────────────────────────────────────────

// ProcessManager owns the registry of background shell processes.
//
// ProcessManager 持有后台 shell 进程的注册表。
type ProcessManager struct {
	mu    sync.Mutex
	procs map[string]*BgProcess
}

// NewProcessManager returns an empty manager ready to track processes.
//
// NewProcessManager 返一个空 manager，可立即追踪进程。
func NewProcessManager() *ProcessManager {
	return &ProcessManager{procs: make(map[string]*BgProcess)}
}

// Register stamps an ID and stores the process. Caller must have set
// command + cmd + startedAt + initial status before calling.
//
// Register 派 ID 并入库。调用方传入前应已填好 command / cmd / startedAt / 初状态。
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
	defer m.mu.Unlock()
	m.procs[p.ID] = p
}

// Get returns the process by ID, or ErrProcessNotFound.
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

// Remove drops the entry from the registry. Used by KillShell after the
// child has been killed and reaped.
//
// Remove 从注册表删除。KillShell 杀完且 reap 后调用。
func (m *ProcessManager) Remove(id string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.procs, id)
}

// Snapshot is a non-mutating, read-side view of one BgProcess for the
// /dev/bash-processes inspection endpoint. Output sample is the last
// `sampleBytes` bytes of the buffer (does NOT advance the BashOutput
// read cursor) so testers can peek without affecting the LLM's polling.
//
// Snapshot 是单进程的只读快照，给 /dev/bash-processes 用。output 取尾
// `sampleBytes` 字节（不动 BashOutput 游标）让测试者偷看不干扰 LLM。
type Snapshot struct {
	ID         string    `json:"id"`
	ConvID     string    `json:"convId,omitempty"`
	Command    string    `json:"command"`
	Status     Status    `json:"status"`
	ExitCode   int       `json:"exitCode"`
	StartedAt  time.Time `json:"startedAt"`
	FinishedAt time.Time `json:"finishedAt,omitempty"`
	BufLen     int       `json:"bufLen"`
	Dropped    int64     `json:"dropped"`
	ReadCursor int       `json:"readCursor"`
	Sample     string    `json:"sample,omitempty"`
	LaunchErr  string    `json:"launchErr,omitempty"`
}

// snapshot returns a non-mutating view; sampleBytes truncated from tail.
//
// snapshot 返非破坏性视图；sampleBytes 取尾。
func (p *BgProcess) snapshot(sampleBytes int) Snapshot {
	p.mu.Lock()
	defer p.mu.Unlock()
	s := Snapshot{
		ID:         p.ID,
		ConvID:     p.ConvID,
		Command:    p.Command,
		Status:     p.status,
		ExitCode:   p.exitCode,
		StartedAt:  p.StartedAt,
		FinishedAt: p.finishedAt,
		BufLen:     len(p.buf),
		Dropped:    p.dropped,
		ReadCursor: p.readCursor,
	}
	if p.launchErr != nil {
		s.LaunchErr = p.launchErr.Error()
	}
	if sampleBytes > 0 && len(p.buf) > 0 {
		start := 0
		if len(p.buf) > sampleBytes {
			start = len(p.buf) - sampleBytes
		}
		s.Sample = string(p.buf[start:])
	}
	return s
}

// Snapshots returns a snapshot of every tracked process, newest first.
// sampleBytes caps the per-process tail (0 = no sample).
//
// Snapshots 返每个追踪进程的快照，最新优先。sampleBytes 限制 per 进程尾。
func (m *ProcessManager) Snapshots(sampleBytes int) []Snapshot {
	m.mu.Lock()
	procs := make([]*BgProcess, 0, len(m.procs))
	for _, p := range m.procs {
		procs = append(procs, p)
	}
	m.mu.Unlock()
	out := make([]Snapshot, 0, len(procs))
	for _, p := range procs {
		out = append(out, p.snapshot(sampleBytes))
	}
	// Sort newest first by StartedAt.
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && out[j].StartedAt.After(out[j-1].StartedAt); j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	return out
}

// Stop kills every running child. Called from cmd/server during
// graceful shutdown so we don't leak processes when the backend exits.
// Best-effort: failures are swallowed — the OS will reap orphans.
//
// Stop 杀掉所有 running 子进程。cmd/server 优雅关停时调用，避免后端退出
// 漏进程。尽力而为；失败咽下——OS 会 reap 孤儿。
func (m *ProcessManager) Stop() {
	m.mu.Lock()
	procs := make([]*BgProcess, 0, len(m.procs))
	for _, p := range m.procs {
		procs = append(procs, p)
	}
	m.mu.Unlock()
	for _, p := range procs {
		if p.Cmd == nil || p.Cmd.Process == nil {
			continue
		}
		_ = p.Cmd.Process.Kill()
	}
}
