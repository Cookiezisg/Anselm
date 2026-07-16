// Package trigger (app) is the trigger entity surface: CRUD + the reference-counted listen
// registry (a trigger's listener runs only while ≥1 active workflow references it) + fan-out
// of fires into durable Firings + the per-action Activation log. It owns four source
// listeners (cron/webhook/fsnotify/sensor) behind one report callback. The claim of Firings
// into flowruns is the scheduler's job.
//
// Package trigger（app）是 trigger 实体入口：CRUD + 引用计数监听表（listener 仅在 ≥1 个 active
// workflow 引用时运行）+ 把 fire 扇成 durable Firing + 逐动作 Activation 日志。它在一个 report
// 回调后持有 4 个 source listener。Firing→flowrun 的 claim 是 scheduler 的事。
package trigger

import (
	"context"
	"net/http"
	"sync"
	"time"

	"go.uber.org/zap"

	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
	croninfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/cron"
	fsnotifyinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/fsnotify"
	sensorinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/sensor"
	webhookinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/webhook"
)

// listenEntry is the in-memory registration for one REFERENCED trigger: which workspace it
// belongs to, its source kind, the set of workflows referencing it, and the subset of those that
// are ONE-SHOT (staged via AttachOnce) — auto-detached after their single fire. paused mirrors the
// persisted triggers.paused switch (scheduler 工单⑦): a paused entry keeps its reference set but
// its underlying source listener is UNREGISTERED (cron entry removed / webhook path 404 / fs watch
// stopped / sensor probes stopped), so pausing stops the machinery, not just the fan-out — and
// onReport drops any report that races in before the unregister lands.
//
// listenEntry 是某个**被引用** trigger 的内存注册：所属 workspace、source 种类、引用它的 workflow 集、
// 以及其中**一次性**（经 AttachOnce 试运行）的子集——单次扇出后自动 Detach。paused 镜像持久化的
// triggers.paused 开关（scheduler 工单⑦）：暂停的 entry 保留引用集，但底层 source listener 已**注销**
// （cron 摘 entry / webhook 路径 404 / fs watch 停 / sensor 探测停）——暂停停掉的是机器本身、不只扇出；
// onReport 再兜住 unregister 落地前抢进来的在飞报告。
type listenEntry struct {
	workspaceID string
	kind        string
	// workflows maps each listening workflowID to its ATTACH EPOCH — zero for a boot-replayed
	// reference ("listening since before this process"), the attach instant for a post-boot one.
	// The misfire sweep (scheduler 工单⑨) uses the epoch as a per-workflow lower bound so a
	// workflow that started listening at 10:00 never gets ticks before 10:00 booked as missed.
	//
	// workflows 把每个监听 workflowID 映到其**挂载纪元**——boot 重放的引用为零值（「本进程之前就在
	// 监听」），boot 后挂载的为挂载时刻。misfire sweep（scheduler 工单⑨）以纪元作 per-workflow 下界：
	// 10:00 才开始监听的 workflow 绝不会被把 10:00 之前的刻度记成它的 missed。
	workflows map[string]time.Time
	once      map[string]bool // workflowID → drop after one fire (stage_workflow)
	paused    bool            // mirrors triggers.paused; true → source listener unregistered. 镜像 triggers.paused；true → 底层已注销。
}

// Service is the unified trigger surface.
//
// Service 是统一的 trigger 入口。
type Service struct {
	repo   triggerdomain.Repository
	search searchdomain.Notifier // nil → search indexing disabled. nil → 不接搜索索引。

	cron     triggerinfra.Listener
	webhook  triggerinfra.Listener
	fsnotify triggerinfra.Listener
	sensor   triggerinfra.Listener

	mu        sync.RWMutex
	listeners map[string]*listenEntry // key: triggerID

	relations     RelationSyncer
	sensorTargets SensorTargetValidator // nil → skip eager sensor-target existence check
	entities      streamdomain.Bridge   // entities stream (SSE-C); nil → no trigger-panel firing feed
	log           *zap.Logger
}

// SensorTargetValidator checks that a sensor's probe target (function/handler/mcp entity) exists, so
// a dangling target is rejected at create/edit instead of only failing at the first probe — eager
// validation mirroring F96/F98/F112. Implemented at boot over the function/handler/mcp services'
// existence lookups; nil-tolerant (nil skips the check, e.g. tests without the full wiring).
//
// SensorTargetValidator 校验 sensor 的探测目标（function/handler/mcp 实体）存在，使 dangling 目标在
// create/edit 即被拒、而非仅首次探测才失败——eager 校验，与 F96/F98/F112 同族。boot 时基于 function/
// handler/mcp 服务的存在性查询实现；允许 nil（nil 跳过，如未全装配的测试）。
type SensorTargetValidator interface {
	ValidateSensorTarget(ctx context.Context, targetKind, targetID, method string) error
}

// SetEntitiesBridge installs the entities stream post-construction (SSE-C): every fan-out emits a
// fire signal scoped to the trigger, so the trigger panel shows firings live.
//
// SetEntitiesBridge 装配后装入 entities 流（SSE-C）：每次扇出发一条 trigger scope 的 fire 信号，使 trigger
// 面板实时显示触发。
func (s *Service) SetEntitiesBridge(b streamdomain.Bridge) { s.entities = b }

// SetSensorTargetValidator installs the eager sensor-target existence check post-construction.
//
// SetSensorTargetValidator 装配后装入 sensor 目标存在性的 eager 校验。
func (s *Service) SetSensorTargetValidator(v SensorTargetValidator) { s.sensorTargets = v }

// NewService constructs the Service and wires the four listeners to s.onReport. mux is shared
// with the HTTP server (webhook routes mount on it); invoker resolves sensor targets
// (function/handler), injected at boot.
//
// NewService 构造 Service 并把 4 个 listener 接到 s.onReport。mux 与 HTTP server 共享（webhook 路由挂其上）；
// invoker 解析 sensor 目标（function/handler），boot 注入。
func NewService(repo triggerdomain.Repository, mux *http.ServeMux, invoker sensorinfra.SensorInvoker, log *zap.Logger) *Service {
	if log == nil {
		log = zap.NewNop()
	}
	s := &Service{
		repo:      repo,
		listeners: make(map[string]*listenEntry),
		log:       log.Named("triggerapp"),
	}
	s.cron = croninfra.New(log, s.onReport)
	s.webhook = webhookinfra.New(mux, log, s.onReport)
	s.fsnotify = fsnotifyinfra.New(log, s.onReport)
	s.sensor = sensorinfra.New(invoker, log, s.onReport)
	return s
}

// SetRelationSyncer attaches the relation syncer post-construction (avoids a DI cycle).
//
// SetRelationSyncer 构造后注入 relation syncer（避开 DI 循环）。
func (s *Service) SetRelationSyncer(r RelationSyncer) { s.relations = r }

// listenerFor returns the listener for a source kind; nil for an unknown kind (callers guard).
//
// listenerFor 返回某 source 种类的 listener；未知 kind 返 nil（调用方守卫）。
func (s *Service) listenerFor(kind string) triggerinfra.Listener {
	switch kind {
	case triggerdomain.KindCron:
		return s.cron
	case triggerdomain.KindWebhook:
		return s.webhook
	case triggerdomain.KindFsnotify:
		return s.fsnotify
	case triggerdomain.KindSensor:
		return s.sensor
	}
	return nil
}

// Start boots all listeners (cron starts its scheduler; push listeners no-op). Call once at boot.
//
// Start 启动所有 listener（cron 启调度器；push 型 no-op）。boot 调一次。
func (s *Service) Start() {
	s.cron.Start()
	s.webhook.Start()
	s.fsnotify.Start()
	s.sensor.Start()
}

// Shutdown stops all listeners; call at process exit.
//
// Shutdown 停止所有 listener；进程退出调。
func (s *Service) Shutdown() {
	s.cron.Stop()
	s.webhook.Stop()
	s.fsnotify.Stop()
	s.sensor.Stop()
}
