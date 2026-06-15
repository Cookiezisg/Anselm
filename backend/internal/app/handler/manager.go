package handler

import (
	"context"
	"sync"

	"go.uber.org/zap"

	handlerdomain "github.com/sunweilin/foryx/backend/internal/domain/handler"
	handlerinfra "github.com/sunweilin/foryx/backend/internal/infra/handler"
	idgenpkg "github.com/sunweilin/foryx/backend/internal/pkg/idgen"
)

// Instance is one live resident HandlerInstance subprocess + its RPC client. There is
// at most ONE per handler (singleton) — no per-owner / per-conversation copies. Stderr
// is the instance's stderr fan-out: calls attach per-call sinks to receive the print()/
// log output emitted in their window (see stderrFan).
//
// Instance 是一个活的常驻 HandlerInstance 子进程 + 其 RPC 客户端。每 handler 至多一个（单例）——
// 无 per-owner / per-conversation 副本。Stderr 是实例的 stderr 扇出：调用挂 per-call sink，
// 收取自己窗口内发出的 print()/日志输出（见 stderrFan）。
type Instance struct {
	ID        string
	HandlerID string
	VersionID string
	Client    handlerinfra.Client
	Kill      func() error
	Stderr    *stderrFan
}

// spawnFn builds a fresh resident Instance for handlerID (load active version + config,
// ensure env, write code, SpawnLongLived, Init). Supplied by the Service.
//
// spawnFn 为 handlerID 构造一个新的常驻 Instance（加载 active 版本 + config、装 env、写代码、
// SpawnLongLived、Init）。由 Service 提供。
type spawnFn func(ctx context.Context, handlerID string) (*Instance, error)

// instanceManager keeps one resident instance per handler, MCP-server style: spawned at
// boot / first call, kept alive, restarted on edit / config-change / crash, gracefully
// shut down on app exit.
//
// instanceManager 按 MCP-server 风格每 handler 保一个常驻实例：开局 / 首调 spawn、保活、
// edit / 改 config / crash 时重启、退出软件优雅关闭。
type instanceManager struct {
	mu        sync.Mutex
	instances map[string]*Instance     // handlerID → the one resident instance
	spawning  map[string]chan struct{} // handlerID → closed when the in-flight spawn finishes
	spawn     spawnFn
	log       *zap.Logger
}

func newInstanceManager(spawn spawnFn, log *zap.Logger) *instanceManager {
	if log == nil {
		log = zap.NewNop()
	}
	return &instanceManager{
		instances: make(map[string]*Instance),
		spawning:  make(map[string]chan struct{}),
		spawn:     spawn,
		log:       log.Named("manager"),
	}
}

// Get returns the live instance for handlerID, spawning if absent or crashed.
//
// Get 返 handlerID 的活实例；不存在或 crashed 则 spawn。
func (m *instanceManager) Get(ctx context.Context, handlerID string) (*Instance, error) {
	m.mu.Lock()
	if inst, ok := m.instances[handlerID]; ok {
		if !inst.Client.Crashed() {
			m.mu.Unlock()
			return inst, nil
		}
		delete(m.instances, handlerID) // crashed → reap + respawn below
		go func() { _ = inst.Kill() }()
	}
	// Single-flight: a spawn is expensive (env + process + __init__, seconds). Concurrent
	// callers — chat's parallel tool batch hitting two methods of the same handler — wait for
	// the in-flight spawn instead of paying for a duplicate that gets thrown away.
	//
	// 单飞：spawn 很贵（env + 进程 + __init__，秒级）。并发调用方——chat 并行工具批同时打同一
	// handler 的两个方法——等在飞的 spawn，而不是花钱造一个注定被扔的副本。
	if ch, busy := m.spawning[handlerID]; busy {
		m.mu.Unlock()
		select {
		case <-ch:
			return m.Get(ctx, handlerID) // spawn settled (registered or failed) — re-check
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	ch := make(chan struct{})
	m.spawning[handlerID] = ch
	m.mu.Unlock()

	inst, err := m.spawn(ctx, handlerID)

	m.mu.Lock()
	delete(m.spawning, handlerID)
	close(ch)
	if err != nil {
		m.mu.Unlock()
		return nil, err
	}
	m.instances[handlerID] = inst
	m.mu.Unlock()
	return inst, nil
}

// Restart gracefully stops the current instance and spawns a fresh one (picks up new
// config / code). Returns the new instance.
//
// Restart 优雅停当前实例并 spawn 新的（吃新 config / 代码）。返回新实例。
func (m *instanceManager) Restart(ctx context.Context, handlerID string) (*Instance, error) {
	m.Stop(ctx, handlerID)
	return m.Get(ctx, handlerID)
}

// Stop gracefully shuts down + removes the instance for handlerID (no respawn).
//
// Stop 优雅关闭 + 移除 handlerID 的实例（不重生）。
func (m *instanceManager) Stop(ctx context.Context, handlerID string) {
	m.mu.Lock()
	inst, ok := m.instances[handlerID]
	delete(m.instances, handlerID)
	m.mu.Unlock()
	if ok {
		_ = inst.Client.Shutdown(ctx)
		_ = inst.Kill()
	}
}

// StopAll gracefully shuts down every resident instance (app exit).
//
// StopAll 优雅关闭所有常驻实例（退出软件）。
func (m *instanceManager) StopAll(ctx context.Context) {
	m.mu.Lock()
	insts := make([]*Instance, 0, len(m.instances))
	for _, inst := range m.instances {
		insts = append(insts, inst)
	}
	m.instances = make(map[string]*Instance)
	m.mu.Unlock()
	for _, inst := range insts {
		_ = inst.Client.Shutdown(ctx)
		_ = inst.Kill()
	}
}

// State reports running / stopped / crashed for one handler (observability).
//
// State 报某 handler 的 running / stopped / crashed（观测）。
func (m *instanceManager) State(handlerID string) string {
	m.mu.Lock()
	defer m.mu.Unlock()
	inst, ok := m.instances[handlerID]
	if !ok {
		return handlerdomain.RuntimeStateStopped
	}
	if inst.Client.Crashed() {
		return handlerdomain.RuntimeStateCrashed
	}
	return handlerdomain.RuntimeStateRunning
}

// newInstanceID mints a fresh instance id (hdi_ prefix).
//
// newInstanceID 生成新实例 id（hdi_ 前缀）。
func newInstanceID() string { return idgenpkg.New("hdi") }
