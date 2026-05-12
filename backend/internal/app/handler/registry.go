// registry.go — in-memory Instance registry implementing caller-owns lifetime
// per spec D3 + user-clarified model (2026-05-12):
//
//   - chat scope:       per-call (NOT tracked in registry; Service.Call
//                       branches and spawns+destroys in one go)
//   - workflow / test / session scope:
//                       persistent instance (handler_name) per owner;
//                       destroyed by DestroyOwner hook on scope end
//
// No idle GC — chat is per-call so no idle handles accumulate; workflow/test/
// session terminate cleanly via explicit scope-end hooks.
//
// Owner.Kind values: "workflow" / "flowrun" / "test" / "session"; chat handler
// calls don't pass through the registry at all.
//
// registry.go —— in-memory Instance registry,实现 caller-owns lifetime。
// chat 不进 registry;workflow/test/session = persistent,scope 结束时
// DestroyOwner 显式调。无 idle GC。

package handler

import (
	"context"
	"sync"

	handlerinfra "github.com/sunweilin/forgify/backend/internal/infra/handler"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// Owner identifies a caller-context scope for instance lifetime. Kind is the
// scope type ("workflow"/"flowrun"/"test"/"session"); ID is the scope instance
// id (run id / test id / session id). chat scope handlers don't appear in the
// registry — Service.Call branches before reaching here.
//
// Owner 标识 caller-context scope。Kind = scope 类型;ID = scope 实例 id。
// chat 不进 registry。
type Owner struct {
	Kind string `json:"kind"`
	ID   string `json:"id"`
}

// Instance is one live HandlerInstance subprocess + its RPC client.
//
// Instance 是单个活的 HandlerInstance subprocess + 其 RPC 客户端。
type Instance struct {
	ID         string                // hdi_<16hex>
	HandlerID  string                // hd_<16hex>
	Owner      Owner                 // owning scope
	Client     handlerinfra.Client   // stdio JSON-line client
	Kill       func() error          // kills the subprocess (registry-set wrapper around handle.Kill)
}

// instanceRegistry tracks persistent instances per (owner, handlerName).
//
// instanceRegistry 按 (owner, handlerName) 跟踪 persistent instance。
type instanceRegistry struct {
	mu        sync.Mutex
	instances map[Owner]map[string]*Instance
}

func newInstanceRegistry() *instanceRegistry {
	return &instanceRegistry{
		instances: make(map[Owner]map[string]*Instance),
	}
}

// SpawnFn is the callback Acquire invokes when no live instance exists for
// (owner, handlerName). It must build a fresh Instance — registry doesn't
// know how to spawn (Service injects this with sandbox + config + client
// factory baked in).
//
// SpawnFn 是 Acquire 在 (owner, handlerName) 没有活实例时调的回调,
// 由 Service 注入(带 sandbox + config + client factory 闭包)。
type SpawnFn func(ctx context.Context) (*Instance, error)

// Acquire returns the live instance for (owner, handlerName), spawning via
// spawnFn if none exists or the existing one crashed.
//
// Acquire 返 (owner, handlerName) 的活 instance;不存在或已 crashed 时
// 用 spawnFn 起一个。
func (r *instanceRegistry) Acquire(ctx context.Context, owner Owner, handlerName string, spawnFn SpawnFn) (*Instance, error) {
	r.mu.Lock()
	if om, ok := r.instances[owner]; ok {
		if inst, ok := om[handlerName]; ok && !inst.Client.Crashed() {
			r.mu.Unlock()
			return inst, nil
		}
		// crashed → drop reference; we'll respawn below.
		// 已 crashed → 丢引用,下面重建。
		if inst, ok := om[handlerName]; ok {
			_ = inst.Client.Shutdown(ctx)
			_ = inst.Kill()
			delete(om, handlerName)
		}
	}
	r.mu.Unlock()

	inst, err := spawnFn(ctx)
	if err != nil {
		return nil, err
	}

	// Race resolution: another goroutine may have spawned concurrently.
	// If so, prefer the registered one and discard our fresh spawn.
	//
	// 竞态消解:可能有并发 goroutine 已 spawn;若有,优先用已注册的,
	// 丢弃我们的。
	r.mu.Lock()
	defer r.mu.Unlock()
	om, ok := r.instances[owner]
	if !ok {
		om = make(map[string]*Instance)
		r.instances[owner] = om
	}
	if existing, ok := om[handlerName]; ok && !existing.Client.Crashed() {
		// Discard our fresh spawn — someone else won the race.
		// 丢弃,别人赢竞态。
		go func() {
			_ = inst.Client.Shutdown(context.Background())
			_ = inst.Kill()
		}()
		return existing, nil
	}
	om[handlerName] = inst
	return inst, nil
}

// DestroyOwner destroys every instance scoped to the given owner. Called by
// workflow.run.End / test.End / session.Release lifecycle hooks.
//
// DestroyOwner 销毁 owner 下全部 instance;workflow run end / test end /
// session release 钩子调。
func (r *instanceRegistry) DestroyOwner(ctx context.Context, owner Owner) {
	r.mu.Lock()
	om := r.instances[owner]
	delete(r.instances, owner)
	r.mu.Unlock()

	for _, inst := range om {
		_ = inst.Client.Shutdown(ctx)
		_ = inst.Kill()
	}
}

// DestroyEverything tears down every live instance across all owners. Called
// at process shutdown to release subprocesses cleanly.
//
// DestroyEverything 关停全部 owner 全部 instance;进程退出时调。
func (r *instanceRegistry) DestroyEverything(ctx context.Context) {
	r.mu.Lock()
	owners := make([]Owner, 0, len(r.instances))
	for o := range r.instances {
		owners = append(owners, o)
	}
	r.mu.Unlock()

	for _, o := range owners {
		r.DestroyOwner(ctx, o)
	}
}

// Snapshot returns a copy of the (owner → handlerName → InstanceID) map for
// observability endpoints. Not a hot path — locks once and returns scalar
// strings (no live Client / Kill references).
//
// Snapshot 返 (owner → handlerName → InstanceID) 的拷贝,给观察类端点用。
func (r *instanceRegistry) Snapshot() map[Owner]map[string]string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make(map[Owner]map[string]string, len(r.instances))
	for o, om := range r.instances {
		inner := make(map[string]string, len(om))
		for name, inst := range om {
			inner[name] = inst.ID
		}
		out[o] = inner
	}
	return out
}

// CountForOwner returns the live instance count for one owner (Snapshot tells
// us this, but Snapshot allocates the whole copy; this is the cheap variant).
//
// CountForOwner 返单 owner 的活 instance 数(便宜版,不拷整 map)。
func (r *instanceRegistry) CountForOwner(owner Owner) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.instances[owner])
}

// NewInstanceID mints a fresh Instance ID with the per-§S15 prefix `hdi_`.
//
// NewInstanceID 用 §S15 前缀 `hdi_` 生成 Instance ID。
func NewInstanceID() string {
	return idgenpkg.New("hdi")
}
