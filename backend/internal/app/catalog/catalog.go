// Package catalog (app/catalog) is the service layer for the Capability
// Catalog. Owns the registered CatalogSources, the in-memory cache that
// chat.runner reads on the hot path, the 1s polling loop that detects
// source changes via fingerprint short-circuit, and the cold-start
// cache load from ~/.forgify/.catalog.json.
//
// LLM-driven Generator (catalog.md §7) is plugged in via SetGenerator
// (D8-3 builds it; D8-2 ships with nil generator → every change goes
// straight to mechanical fallback, which is fine for the no-LLM-key
// case the design already mandates).
//
// Concurrency model:
//   - cache: atomic.Pointer[Catalog] — single writer (Refresh), many
//     readers (chat hot path); zero locking on read
//   - lastFP: atomic.Value (string) — same write-once-per-tick pattern
//   - busy: atomic.Bool — single-flight guard around Refresh; if a
//     prior tick is still running (>1s LLM call), the next tick skips
//   - sources: protected by sync.Mutex on RegisterSource only;
//     pollLoop snapshots the slice at the start of each tick
//
// Per catalog.md §3:
//   - polling NOT event subscription (avoids events-bridge concurrency)
//   - fingerprint = sha256(sort(source+name+description))
//   - lastFP always updates after Refresh (LLM or mechanical) → user-
//     activity-driven retry; no background backoff needed
//
// Package catalog（app/catalog）是 Capability Catalog 的 service 层。持
// 已注册 CatalogSource、chat.runner 热路径读的内存 cache、1s 轮询循环
// （fingerprint 短路检 source 变化）、~/.forgify/.catalog.json cold-start
// 加载。
//
// LLM-driven Generator（catalog.md §7）经 SetGenerator 注入（D8-3 构造；
// D8-2 接 nil 生成器，所有变化直走 mechanical fallback——design 本就要求
// 无 LLM key 时此行为）。
//
// 并发模型：cache atomic.Pointer 单写多读零锁；lastFP atomic.Value 同模式；
// busy atomic.Bool 单 flight 守 Refresh（>1s 的上次 tick 在跑就跳）；
// sources 仅 RegisterSource 持 sync.Mutex，pollLoop 每 tick 启时快照 slice。
package catalog

import (
	"context"
	"sync"
	"sync/atomic"
	"time"

	"go.uber.org/zap"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
)

// defaultPollInterval is the catalog.md §3 mandated 1-second polling
// cadence. Short enough that user-edited skills / installed mcp servers
// reach the system prompt within "feels instant"; long enough that the
// fingerprint short-circuit keeps idle CPU at noise level.
//
// defaultPollInterval：catalog.md §3 规定的 1 秒轮询周期。短到让用户编辑
// 的 skill / 装的 mcp server "立即"进 system prompt；长到让 fingerprint
// 短路把 idle CPU 控在噪音级。
const defaultPollInterval = 1 * time.Second

// Generator is the LLM-driven Summary builder. Defined as an interface
// so D8-3 can plug in the real implementation while D8-2 (and tests
// that don't want LLM coupling) can leave it nil — Service.Refresh
// gracefully falls back to mechanicalFallback when generator is nil
// or returns an error.
//
// Generator 是 LLM-driven Summary 构建。定义为接口让 D8-3 接真实现，
// D8-2（与不要 LLM 耦合的测试）可留 nil——Service.Refresh 在 generator
// 为 nil 或返错时优雅 fallback 到 mechanical。
type Generator interface {
	Generate(ctx context.Context, items []catalogdomain.Item, gMap map[string]catalogdomain.Granularity) (*catalogdomain.Catalog, error)
}

// Service ties the registered sources, the polling loop, the in-memory
// cache, the disk cache, and the (optional) Generator together.
// Constructed once in main.go; Start launches the polling goroutine
// and Stop shuts it down via ctx cancellation.
//
// Service 把注册 source、轮询循环、内存 cache、disk cache、（可选）
// Generator 串起来。main.go 一次构造；Start 启 polling goroutine，Stop
// 经 ctx cancel 关停。
type Service struct {
	cachePath    string
	pollInterval time.Duration
	notif        notificationspkg.Publisher
	log          *zap.Logger

	// Generator is plugged in by SetGenerator after construction so the
	// service can build standalone (e.g. unit tests, environments
	// without a chat model configured) and pick up LLM mode later.
	//
	// Generator 由 SetGenerator 后置注入，让服务能独立构造（单测、未配
	// chat model 环境）后续接 LLM。
	generator Generator

	// sources are protected by sourcesMu for the writer side (RegisterSource);
	// readers (pollLoop) snapshot under RLock at the start of each tick.
	//
	// sources 写侧（RegisterSource）持 sourcesMu；读侧（pollLoop）每 tick
	// 启时 RLock 快照。
	sourcesMu sync.RWMutex
	sources   []catalogdomain.CatalogSource

	cache  atomic.Pointer[catalogdomain.Catalog]
	lastFP atomic.Value // string
	busy   atomic.Bool

	versionMu sync.Mutex
	version   int

	// stopOnce + stopCancel + pollDone wire synchronous Stop():
	// stopCancel signals the pollLoop goroutine, pollDone closes
	// when the goroutine finishes its current tick + exits. Stop()
	// blocks on pollDone so callers (test harness cleanup, prod
	// shutdown) can be sure no further disk writes happen after
	// Stop returns. stopOnce makes Stop() idempotent.
	//
	// stopOnce + stopCancel + pollDone 实现同步 Stop()：stopCancel 给
	// pollLoop goroutine 发信号，pollDone 在 goroutine 跑完当前 tick +
	// 退出后关闭。Stop() 在 pollDone 上阻塞，让调用方（测试 harness
	// cleanup / 生产 shutdown）确信 Stop 返后无进一步 disk 写。
	// stopOnce 让 Stop() 幂等。
	stopOnce   sync.Once
	stopCancel context.CancelFunc
	pollDone   chan struct{}
}

// New constructs a Service rooted at cachePath (typically
// ~/.forgify/.catalog.json). pollInterval defaults to 1s when zero.
// Start MUST be called before chat.runner queries GetForSystemPrompt
// (Start blocks briefly to load the disk cache + then launches the
// polling goroutine).
//
// New 构造 Service 根 cachePath（典型 ~/.forgify/.catalog.json）。
// pollInterval 为 0 时取默认 1s。chat.runner 查 GetForSystemPrompt 前
// 必须先调 Start（Start 短暂阻塞加载 disk cache + 启 polling goroutine）。
func New(cachePath string, notif notificationspkg.Publisher, log *zap.Logger) *Service {
	if log == nil {
		panic("catalog.New: logger is nil")
	}
	if notif == nil {
		notif = notificationspkg.New(nil, log)
	}
	s := &Service{
		cachePath:    cachePath,
		pollInterval: defaultPollInterval,
		notif:        notif,
		log:          log,
	}
	s.lastFP.Store("")
	return s
}

// SetGenerator plugs the LLM Generator. Called after New + before Start
// (post-injection breaks an import cycle: Generator wants apikey/model
// services that themselves don't depend on catalog).
//
// SetGenerator 接 LLM Generator。New 后 Start 前调（后置注入打破循环：
// Generator 要 apikey/model 服务，二者本身不依赖 catalog）。
func (s *Service) SetGenerator(g Generator) {
	s.generator = g
}

// SetPollInterval overrides the default 1s tick. Tests use this to
// drive scenarios faster (e.g. 10ms) without waiting real time;
// production should leave it at default.
//
// SetPollInterval 覆盖 1s 默认 tick。测试用此快速驱动场景（如 10ms），
// 不等真实时间；生产保持默认。
func (s *Service) SetPollInterval(d time.Duration) {
	if d > 0 {
		s.pollInterval = d
	}
}

// RegisterSource adds a source to the polling rotation. Safe to call
// at any time — the next tick picks up the new source. Registering
// twice with the same Name is allowed but will be flagged by the
// fingerprint validation if it produces duplicate Source+ID pairs.
//
// RegisterSource 把 source 加入轮询。任意时点调安全——下一 tick 拾。
// 同名重注册允许，但 fingerprint 校验会在产生重复 Source+ID 对时标记。
func (s *Service) RegisterSource(src catalogdomain.CatalogSource) {
	s.sourcesMu.Lock()
	defer s.sourcesMu.Unlock()
	s.sources = append(s.sources, src)
}

// snapshotSources returns a copy of the registered source slice for
// the current tick. Holds the RLock briefly; tick can iterate the
// snapshot without re-locking.
//
// snapshotSources 返本 tick 的注册 source 副本。短持 RLock；tick 无需
// 再锁即可遍历。
func (s *Service) snapshotSources() []catalogdomain.CatalogSource {
	s.sourcesMu.RLock()
	defer s.sourcesMu.RUnlock()
	out := make([]catalogdomain.CatalogSource, len(s.sources))
	copy(out, s.sources)
	return out
}

// Get returns the current cached Catalog (or nil if Refresh hasn't
// produced one yet — boot window or all-sources-failed-and-no-cache
// scenario). Caller must treat the returned pointer as read-only;
// concurrent Refresh swaps the underlying pointer atomically.
//
// Get 返当前缓存 Catalog（或 nil，若 Refresh 还没产出——boot 窗口或全
// source 挂且无 cache 情形）。调用方视返回指针为只读；并发 Refresh 原
// 子 swap 底层指针。
func (s *Service) Get() *catalogdomain.Catalog {
	return s.cache.Load()
}

// GetForSystemPrompt returns the cached Summary text formatted for direct
// prepend into chat's system prompt. Empty string when no catalog has been
// built yet — caller should silently skip the section.
//
// GetForSystemPrompt 返缓存 Summary 文本（已格式化可直接前置 chat system
// prompt）。catalog 未构造时返空——调用方应静默跳过。
func (s *Service) GetForSystemPrompt() string {
	cat := s.cache.Load()
	if cat == nil {
		return ""
	}
	return cat.Summary
}

// nextVersion increments + returns the version counter. Caller holds no
// lock; this method serializes all increments.
//
// nextVersion 自增 + 返版本计数器。调用方无锁；本方法串化全部自增。
func (s *Service) nextVersion() int {
	s.versionMu.Lock()
	defer s.versionMu.Unlock()
	s.version++
	return s.version
}
