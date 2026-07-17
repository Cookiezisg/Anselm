// Package bootstrap is the composition root: the one place allowed to import across every app
// and infra package. Build wires the SQLite DB, all stores, infra singletons, the 28 app
// Services, every cross-Service adapter (see resolvers/dispatch/refresolver/renderers/sensor),
// the tool set, the HTTP router, and the boot/shutdown lifecycle into a single *App. Nothing
// imports bootstrap, so there is no dependency cycle. cmd/server/main.go is a thin shell over it.
//
// Package bootstrap 是 composition root：唯一允许横跨所有 app/infra 包 import 的地方。Build 把 SQLite
// DB、所有 store、infra 单例、28 个 app Service、每个跨 Service 适配器、工具集、HTTP router、boot/
// shutdown 生命周期焊成一个 *App。无人 import bootstrap，故无依赖环。main.go 是它的薄壳。
package bootstrap

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"time"

	"go.uber.org/zap"

	settingsapp "github.com/sunweilin/anselm/backend/internal/app/settings"
	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	loggerinfra "github.com/sunweilin/anselm/backend/internal/infra/logger"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
	handlershttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/handlers"
	routerhttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/router"
)

// Config parameterizes Build. DataDir empty → in-memory DB (tests). Addr defaults to 127.0.0.1:8080
// (loopback-only — the client overrides with 127.0.0.1:<free-port>). AuthToken is the per-launch
// loopback bearer secret (ANSELM_AUTH_TOKEN); "" disables bearer enforcement (dev / testend).
// Fingerprint is the machine-stable seed for the at-rest encryption key (api-key & mcp secrets).
//
// Config 参数化 Build。DataDir 空 → 内存 DB（测试）。Addr 默认 127.0.0.1:8080（仅 loopback;客户端用
// 127.0.0.1:<空闲端口> 覆盖）。AuthToken 是每次启动的 loopback bearer 密钥（ANSELM_AUTH_TOKEN），""
// 关闭 bearer 强制（dev/testend）。Fingerprint 是落盘加密密钥的机器稳定种子。
type Config struct {
	DataDir     string
	Addr        string
	AuthToken   string
	Fingerprint string
	Dev         bool
	// Version is the build-stamped app version served by GET /api/v1/version ("dev" un-stamped).
	// 构建期盖章的版本号(GET /api/v1/version 下发;未盖章="dev")。
	Version string
}

// App is the assembled application: the HTTP handler plus the boot/shutdown lifecycle for the
// background-owning Services (sandbox runtime, handler/mcp processes, trigger listeners, the
// scheduler firing-drain ticker).
//
// App 是装配好的应用：HTTP handler + 持后台工作的 Service 的 boot/shutdown 生命周期。
type App struct {
	Handler       http.Handler
	Addr          string
	log           *zap.Logger
	svc           *services
	db            *ormpkg.DB
	tickStop      context.CancelFunc
	drainDone     chan struct{}      // closed when drainLoop returns; Shutdown waits on it. drainLoop 退出时关闭，Shutdown 等它。
	timeoutStop   context.CancelFunc // stops the independent timeout-sweep loop (F174: decoupled from drain so a slow node can't starve approval timeouts). 停独立超时扫描循环。
	timeoutDone   chan struct{}      // closed when timeoutLoop returns. timeoutLoop 退出时关闭。
	misfireStop   context.CancelFunc // stops the misfire-accounting loop (scheduler 工单⑨). 停 misfire 记账循环。
	misfireDone   chan struct{}      // closed when misfireLoop returns. misfireLoop 退出时关闭。
	retentionStop context.CancelFunc // stops the run-history retention sweep loop (scheduler 工单⑬). 停 run 历史保留清理循环。
	retentionDone chan struct{}      // closed when retentionLoop returns. retentionLoop 退出时关闭。
	// retentionKick asks the sweep loop for an off-schedule pass — buffered(1) + non-blocking send,
	// so N kicks during one sweep coalesce into exactly one follow-up. Fed by the settings service's
	// retention-changed hook (a tightened line must reclaim NOW, not in 6h) and primed once at Boot
	// so the startup sweep runs on the loop's goroutine instead of delaying serving.
	// retentionKick 请清理循环跑一趟计划外的——buffered(1) + 非阻塞发送，故一次清理期间的 N 次踢合并成
	// 恰好一次后续。由 settings service 的 retention-changed 钩子喂（收紧的线必须**现在**回收、不是 6 小时后），
	// 并在 Boot 时预置一次，使启动清理跑在循环的 goroutine 上、而非拖慢开始服务。
	retentionKick chan struct{}
}

const drainInterval = 5 * time.Second

// misfireInterval paces the missed-tick sweep (scheduler 工单⑨). Deliberately slow: it exists to
// notice a wall-clock GAP (sleep/suspend), which is minutes-to-hours wide — cron's own resolution is
// a minute, so sweeping faster would just re-walk an empty window. Boot runs it once eagerly.
//
// misfireInterval 定 missed 刻度扫描的节律（scheduler 工单⑨）。刻意慢：它的存在是为察觉墙钟**缺口**
// （睡眠/挂起），那是分钟到小时级的宽度——cron 自身分辨率就是分钟，扫得更快只是反复走空窗。boot 时已
// 主动跑过一次。
const misfireInterval = time.Minute

// retentionInterval paces the run-history retention sweep (scheduler 工单⑬). Deliberately very slow:
// the retention line is measured in DAYS, so anything sub-daily already over-samples it — the ticker
// exists only so a machine left running for weeks still honours the line without a restart. Boot
// primes one pass, and a retention PATCH kicks one, so the ticker is never how a user learns their
// setting works.
//
// retentionInterval 定 run 历史保留清理的节律（scheduler 工单⑬）。刻意**很**慢：保留线以**天**计，故任何
// 亚日级的频率本就过采样——ticker 存在只是为了让连开数周的机器不重启也照样守线。boot 预置一趟、retention
// PATCH 踢一趟，故用户绝不会靠 ticker 才知道自己的设置生效了。
const retentionInterval = 6 * time.Hour

// drainShutdownGrace bounds how long Shutdown lets an in-flight workflow Advance finish its current
// node before interrupting it (R3 option C — clean durability for fast nodes, bounded shutdown for
// slow). Kept under shutdownGrace so the rest of the ordered shutdown keeps budget.
//
// WHY 2s (T8, WRK-070): this grace is the first term of the shutdown chain's worst-case SERIAL
// floor — drainShutdownGrace + 2×shell.WaitDelay (StopPool then chat.Shutdown each wait out a
// cancelled Bash's pipe floor) — which must stay strictly under the app's 8s SIGTERM grace, or
// SIGKILL undoes the whole ordered shutdown. 2+2+2=6s ≤ shutdownGrace < 8s; the golden test in
// shutdown_budget_test.go pins all three inequalities. A node that misses 2s is interrupted,
// records failed, and resumes next boot (record-once) — strictly better than being SIGKILLed
// mid-write, which is what a longer grace buys.
//
// drainShutdownGrace 限 Shutdown 给在飞 Advance 跑完当前节点的时长，超则打断（R3 选项 C——快节点干净、慢节点有界）。
// 留在 shutdownGrace 之下，使关停其余步骤仍有预算。
//
// 为什么是 2s（T8，WRK-070）：这段宽限是关停链最坏**串行**地板的第一项——drainShutdownGrace +
// 2×shell.WaitDelay（StopPool、chat.Shutdown 各要等满一个被取消 Bash 的管道地板）——必须严格小于
// app 侧 8s SIGTERM 宽限，否则 SIGKILL 让整个有序关停前功尽弃。2+2+2=6s ≤ shutdownGrace < 8s；
// shutdown_budget_test.go 的 golden 测试钉死全部三条不等式。没赶上 2s 的节点被打断、记 failed、
// 下次 boot 续走（record-once）——严格好于写到一半被 SIGKILL，而更长的宽限买到的正是后者。
const drainShutdownGrace = 2 * time.Second

// Build assembles the whole backend. The returned App is ready to serve immediately (health works
// before Boot); call Boot to start background work and Shutdown to stop it.
//
// Build 装配整个后端。返回的 App 立即可服务（Boot 前 health 即通）；调 Boot 启后台、Shutdown 停。
func Build(cfg Config) (*App, error) {
	log, err := loggerinfra.New(cfg.Dev, filepath.Join(cfg.DataDir, "logs"))
	if err != nil {
		return nil, fmt.Errorf("bootstrap: logger: %w", err)
	}
	database, err := openDB(cfg.DataDir, log)
	if err != nil {
		return nil, err
	}
	enc, err := newEncryptor(cfg.Fingerprint, cfg.DataDir)
	if err != nil {
		return nil, err
	}

	// settings.json (limits) loads before services so every consumer's first read sees
	// user-tuned values; a malformed file fails boot loudly.
	// settings.json（limits）先于服务加载，使所有消费方首读即见用户调校值；坏文件大声喊停。
	settingsSvc, err := settingsapp.Load(cfg.DataDir)
	if err != nil {
		return nil, fmt.Errorf("bootstrap: %w", err)
	}

	st := buildStores(database, enc, cfg.DataDir)
	inf := infra{factory: llminfra.NewFactory(), encryptor: enc}
	bus := newBuses()

	// One mux: trigger registers webhook routes on it; the 28 resource handlers register theirs;
	// then Chain wraps it with the middleware stack (workspace identify/require, locale, cors…).
	mux := http.NewServeMux()
	svc := buildServices(st, inf, bus, mux, cfg.DataDir, log)
	svc.settings = settingsSvc
	registerHandlers(mux, svc, bus, cfg, log)
	registerDebug(mux, cfg.Dev, log) // dev-only /debug/pprof + /debug/stats (observability)

	addr := cfg.Addr
	if addr == "" {
		addr = "127.0.0.1:8080" // loopback-only default (was :8080/all-interfaces) — loopback hardening
	}
	return &App{
		Handler: routerhttpapi.Chain(mux, log, svc.workspace, cfg.AuthToken),
		Addr:    addr,
		log:     log,
		svc:     svc,
		db:      database,
	}, nil
}

// registerHandlers constructs each resource handler over its Service and registers its routes on
// the shared mux, plus the static health probe (exempt from RequireWorkspace).
//
// registerHandlers 用各自 Service 构造每个资源 handler 并把路由注册到共享 mux，外加静态 health 探针。
func registerHandlers(mux *http.ServeMux, s *services, bus buses, cfg Config, log *zap.Logger) {
	mux.HandleFunc("GET /api/v1/health", handleHealth)

	regs := []interface {
		Register(handlershttpapi.Registrar)
	}{
		handlershttpapi.NewWorkspacesHandler(s.workspace, log),
		handlershttpapi.NewSearchHandler(s.search, log),
		handlershttpapi.NewAPIKeyHandler(s.apikey, cfg.Dev, log),
		handlershttpapi.NewModelCapabilitiesHandler(s.modelCaps, log),
		handlershttpapi.NewScenariosHandler(),
		handlershttpapi.NewRelationHandler(s.relation, log),
		handlershttpapi.NewCatalogHandler(s.catalog, log),
		handlershttpapi.NewNotificationHandler(s.notification, log),
		handlershttpapi.NewStreamHandler(bus.messages, bus.entities, bus.notifications, log),
		handlershttpapi.NewMemoryHandler(s.memory, log),
		handlershttpapi.NewSandboxHandler(s.sandbox, log),
		handlershttpapi.NewLimitsHandler(s.settings, log),
		handlershttpapi.NewSystemHandler(s.settings, cfg.Version, log),
		handlershttpapi.NewFreetierHandler(s.freetierQuota, s.freetier, log),
		handlershttpapi.NewDocumentHandler(s.document, s.aispawn, log),
		handlershttpapi.NewTodoHandler(s.todo, log),
		handlershttpapi.NewTouchpointHandler(s.touchpoint, log),
		handlershttpapi.NewAttachmentHandler(s.attachment, log),
		handlershttpapi.NewFunctionHandler(s.function, s.aispawn, log),
		handlershttpapi.NewHandlerHandler(s.handler, s.aispawn, log),
		handlershttpapi.NewAgentHandler(s.agent, s.aispawn, log),
		handlershttpapi.NewTriggerHandler(s.trigger, s.aispawn, log),
		handlershttpapi.NewMCPHandler(s.mcp, log),
		handlershttpapi.NewSkillHandler(s.skill, log),
		handlershttpapi.NewControlHandler(s.control, s.aispawn, log),
		handlershttpapi.NewApprovalHandler(s.approval, s.aispawn, log),
		handlershttpapi.NewWorkflowHandler(s.workflow, s.aispawn, log),
		handlershttpapi.NewFlowrunHandler(s.scheduler, log),
		handlershttpapi.NewConversationHandler(s.conversation, log),
		handlershttpapi.NewChatHandler(s.chat, log),
		handlershttpapi.NewTriageHandler(s.aispawn, log),
	}
	for _, h := range regs {
		h.Register(mux)
	}
}

// handleHealth reports liveness as the N1 success envelope.
//
// handleHealth 以 N1 成功 envelope 返回存活状态。
func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"data":{"status":"ok"}}`))
}

// shutdownGrace bounds the whole graceful drain (HTTP + background + DB).
//
// WHY 6s (T8, WRK-070): the app gives this process 8 seconds of SIGTERM grace (frontend
// backend_controller.dart `shutdownGrace`) before escalating to SIGKILL — and SIGKILL forfeits
// everything the ordered shutdown exists for (children orphaned, background bash trees leaked,
// WAL checkpoint skipped). So the backend's WHOLE budget must stay strictly under 8s with
// margin. 6s covers the ctx-bounded steps; the ctx-free serial floors (drainShutdownGrace +
// 2×shell.WaitDelay = 6s worst case) fit the same envelope. Golden test:
// shutdown_budget_test.go parses the app-side constant and pins every inequality.
//
// shutdownGrace 限定整个优雅排空（HTTP + 后台 + DB）。
//
// 为什么是 6s（T8，WRK-070）：app 侧只给本进程 8 秒 SIGTERM 宽限（前端 backend_controller.dart
// `shutdownGrace`），超过即升级 SIGKILL——而 SIGKILL 让有序关停存在的意义全部作废（子进程成孤儿、
// 后台 bash 整树失管、WAL checkpoint 被跳过）。故后端**总**预算必须留余量地严格小于 8s。6s 罩住
// ctx 有界各步；不认 ctx 的串行地板（drainShutdownGrace + 2×shell.WaitDelay，最坏 6s）落在同一
// 包络内。golden 测试 shutdown_budget_test.go 解析 app 侧常量、钉死每条不等式。
const shutdownGrace = 6 * time.Second

// Serve owns the entire server lifecycle and blocks until ctx is cancelled (the entry shell wires
// SIGINT/SIGTERM to it) or the listener fails. The graceful-shutdown ORDER is a backend concern, not
// the shell's, and it must be exactly this — otherwise it is NOT graceful:
//
//  1. cancel the base request context FIRST — every request derives from it, so the frontend's three
//     resident SSE streams (never idle) end at once. Without this, http.Shutdown would block the full
//     grace window waiting for those connections to go idle (they never do).
//  2. http.Shutdown — now drains instantly (only short requests remain).
//  3. App.Shutdown — stop background work, then close the DB last.
//
// Returns the listener error, or nil on a clean signal-triggered stop.
//
// Serve 拥有整个服务生命周期，阻塞到 ctx 取消（入口壳把 SIGINT/SIGTERM 接到它）或 listener 失败。优雅关停的
// **顺序**是后端的事、不是壳的事，且必须正是这个顺序——否则就不优雅：① 先取消 base 请求 ctx——每个请求都从它派
// 生，故前端三条常驻 SSE 流（永不 idle）一起结束；否则 http.Shutdown 会干等满整个 grace 窗口等这些永不 idle 的
// 连接。② http.Shutdown——这下瞬间排空（只剩短请求）。③ App.Shutdown——停后台、最后关 DB。
func (a *App) Serve(ctx context.Context) error {
	a.Boot(context.Background())

	baseCtx, cancelBase := context.WithCancel(context.Background())
	srv := &http.Server{
		Addr:        a.Addr,
		Handler:     a.Handler,
		BaseContext: func(net.Listener) context.Context { return baseCtx },
	}

	serveErr := make(chan error, 1)
	go func() {
		a.log.Info("serving", zap.String("addr", a.Addr))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
	}()

	var listenErr error
	select {
	case <-ctx.Done(): // SIGINT/SIGTERM
	case listenErr = <-serveErr:
	}

	sctx, cancel := context.WithTimeout(context.Background(), shutdownGrace)
	defer cancel()
	a.log.Info("shutting down gracefully")
	cancelBase() // 1. end resident SSE streams so HTTP can drain
	if err := srv.Shutdown(sctx); err != nil {
		a.log.Warn("bootstrap: http shutdown", zap.Error(err))
	}
	a.Shutdown(sctx) // 2. stop background work + close DB
	return listenErr
}

// Boot starts background work: sandbox runtime bootstrap + env-manager registration, resident
// handler & mcp processes, trigger listeners, scheduler crash-recovery, and the firing-drain
// ticker. Each step is best-effort logged — a single subsystem failing to boot degrades that
// feature, never the whole server.
//
// Boot 启后台工作：sandbox runtime bootstrap + env manager 注册、常驻 handler & mcp 进程、trigger
// listener、scheduler 崩溃恢复、firing-drain ticker。每步 best-effort 记日志——单子系统 boot 失败只
// 降级该功能，绝不拖垮整个 server。
func (a *App) Boot(ctx context.Context) {
	if err := a.svc.sandbox.Bootstrap(ctx); err != nil {
		a.log.Warn("bootstrap: sandbox bootstrap failed (runtimes degraded)", zap.Error(err))
	}
	registerSandboxStack(a.svc.sandbox)
	a.svc.sandbox.RestoreOrCleanupOnBoot(ctx)
	// Reap run_in_background shell groups a prior UNGRACEFUL exit orphaned — Stop() at line ~700
	// only runs on graceful Shutdown; the pid manifest is the crash half's only net (T3).
	// 收割上次非优雅退出留下的 run_in_background 进程组——Stop() 只在优雅 Shutdown 可达,
	// pid 清单是崩溃半唯一的网(T3)。
	a.svc.shellMgr.ReapStaleOnBoot(a.log)
	a.svc.trigger.Start()
	// search index worker + per-workspace reconcile (self-healing for dropped events /
	// crashes / schema bumps); never blocks boot.
	// 搜索索引 worker + 逐 workspace 对账（丢事件/崩溃/schema 升版的自愈）；绝不阻塞 boot。
	if workspaces, err := a.svc.workspace.List(ctx); err == nil {
		ids := make([]string, 0, len(workspaces))
		for _, w := range workspaces {
			ids = append(ids, w.ID)
		}
		a.svc.search.Start(ids)
	} else {
		a.log.Warn("bootstrap: list workspaces for search start", zap.Error(err))
		a.svc.search.Start(nil)
	}
	// Start the Advance worker pool BEFORE Recover so recovered runs resume ON the pool (off this boot
	// goroutine): a slow recovered node must not block boot, and pooled phase-2 Advance is the whole
	// point of F174. Recover enqueues; the workers drive concurrently with the rest of boot below.
	// 在 Recover **之前**启动 Advance worker 池，使恢复的 run 在池上恢复（脱离 boot goroutine）：慢的恢复
	// 节点不该卡 boot，池化的阶段 2 Advance 正是 F174 的目的。Recover 入队；worker 与下面的 boot 余下部分并发驱动。
	a.svc.scheduler.StartPool()
	if err := a.svc.scheduler.Recover(ctx); err != nil {
		a.log.Warn("bootstrap: scheduler recover failed", zap.Error(err))
	}
	// Background entry points run OFF any request, so ctx carries no workspace — but
	// handler/mcp Boot and ReattachActive read workspace-scoped tables (the orm ,ws filter
	// would reject a bare ctx with MISSING_WORKSPACE_ID). The ONE convention for background
	// work: seed a Detached workspace ctx per workspace and replay the entry point in each
	// (same family as Recover's per-run seeding and onReport's Detached(wsID)).
	//
	// 后台入口在任何请求之外跑，ctx 不带 workspace——而 handler/mcp Boot 与 ReattachActive 读
	// workspace 隔离表（orm 的 ,ws 过滤会以 MISSING_WORKSPACE_ID 拒裸 ctx）。后台工作的唯一惯例：
	// 逐 workspace 种 Detached ctx、在每个里重放入口（与 Recover 的 per-run 播种、onReport 的
	// Detached(wsID) 同族）。
	a.forEachWorkspace(ctx, func(wsCtx context.Context) {
		a.svc.handler.Boot(wsCtx)
		a.svc.mcp.Boot(wsCtx)
		// Backfill the built-in free-tier credential for every existing workspace (idempotent: a
		// no-op where it already exists; self-heals a workspace whose prior install failed). New
		// workspaces created after boot are covered by the workspace OnCreated hook. Best-effort —
		// EnsureForWorkspace always returns nil, a degraded free tier never blocks boot.
		// 为每个已存在 workspace 回填内置免费档凭证（幂等：已存在即 no-op；自愈上次 install 失败的）。
		// boot 后新建的由 workspace OnCreated 钩子覆盖。best-effort——EnsureForWorkspace 恒返 nil，
		// 降级的免费档绝不挂 boot。
		a.svc.freetier.EnsureForWorkspace(wsCtx)
		// Reconcile turns orphaned mid-stream by a hard crash (messages' scheduler.Recover
		// counterpart): pending/streaming rows become cancelled so the UI never shows a
		// forever-spinning bubble.
		// 对账被硬崩溃卡在流式中的孤儿回合（messages 版 scheduler.Recover）：pending/streaming 行
		// 置 cancelled，UI 不再出现永久转圈气泡。
		a.svc.chat.SweepOrphans(wsCtx)
		// Reclaim orphaned attachment blobs (content-addressed bytes whose last live metadata row was
		// deleted). GC runs at boot — NOT on delete — because a delete-time sweep races an in-flight
		// upload (blob Put precedes row Create; a concurrent GC between them would sweep the just-Put
		// blob). Boot has no concurrent uploads, so ListLiveSHAs → Sweep is race-free. A long session
		// accumulates orphans until restart; that is bounded (not unbounded across restarts) and
		// acceptable for a single-user desktop app, matching the boot-reconciliation pattern above.
		// 回收孤儿附件 blob（内容寻址字节，其最后一条 live 元数据行已删）。GC 在 boot 跑——**非**删除时——因为删除时
		// 扫描会与在飞上传竞态（blob Put 先于行 Create；其间的并发 GC 会扫掉刚 Put 的 blob）。boot 无并发上传，故
		// ListLiveSHAs→Sweep 无竞态。长会话会累积孤儿到重启；这是有界的（跨重启不无界）、对单用户桌面 app 可接受,
		// 与上方 boot 对账模式一致。
		if n, err := a.svc.attachment.GC(wsCtx); err != nil {
			a.log.Warn("bootstrap: attachment blob GC failed", zap.Error(err))
		} else if n > 0 {
			a.log.Info("bootstrap: reclaimed orphaned attachment blobs", zap.Int("count", n))
		}
		// D1: the trigger listen-registry is in-memory, so re-engage the listener for every
		// active workflow ("replay active references on boot").
		// D1：trigger 监听注册表是内存的，为每个 active workflow 重挂监听（boot 重放 active 引用）。
		if err := a.svc.workflow.ReattachActive(wsCtx); err != nil {
			a.log.Warn("bootstrap: workflow reattach-active failed", zap.Error(err))
		}
		// Account cron ticks that came due while the app was down (scheduler 工单⑨, 判决⑥): each
		// becomes a `missed` firing — NOT re-run (a wake-up run-storm is the local-app hazard).
		// STRICTLY after ReattachActive: the sweep reads the listen registry to know who was
		// listening, and an empty registry would silently account nothing.
		// 把 app 停机期间到期的 cron 刻度入账（scheduler 工单⑨，判决⑥）：每个变成一条 `missed` firing——
		// **不补跑**（睡醒补跑风暴是本地 app 的危险）。**严格**在 ReattachActive 之后：sweep 读监听表才知道
		// 谁在监听，表空则会静默什么都不记。
		if n, err := a.svc.trigger.SweepMisfires(wsCtx); err != nil {
			a.log.Warn("bootstrap: misfire sweep failed", zap.Error(err))
		} else if n > 0 {
			a.log.Info("bootstrap: accounted missed cron ticks", zap.Int("missed", n))
		}
	})

	// Firing-drain ticker: trigger listeners persist Firings to the durable inbox; the scheduler claims
	// them here on a fixed cadence and enqueues each onto the Advance pool. The approval/timer timeout
	// sweep runs on its OWN ticker (F174) so a saturated pool can never starve approval-timeout settling
	// — they used to share the drain closure, where a slow Advance blocked CheckTimeouts.
	// firing-drain ticker：trigger 监听把 Firing 落到耐久收件箱；scheduler 在此按固定节律 claim 并把每条入队到
	// Advance 池。审批/计时超时扫描跑在**自己**的 ticker 上（F174），故满载的池绝不饿死审批超时结算——它们原来
	// 共用 drain 闭包、慢 Advance 阻塞 CheckTimeouts。
	tickCtx, stop := context.WithCancel(context.Background())
	a.tickStop = stop
	a.drainDone = make(chan struct{})
	go a.drainLoop(tickCtx)
	timeoutCtx, tstop := context.WithCancel(context.Background())
	a.timeoutStop = tstop
	a.timeoutDone = make(chan struct{})
	go a.timeoutLoop(timeoutCtx)
	// Misfire sweep on its OWN slow ticker (scheduler 工单⑨): the boot sweep only catches a
	// shutdown, but a laptop that sleeps an hour and wakes with the process ALIVE misfires exactly
	// the same way — nothing reboots, so only a running sweep ever notices those ticks fell.
	// misfire 扫描跑在**自己**的慢 ticker 上（scheduler 工单⑨）：boot sweep 只逮得住关机，而笔记本睡一
	// 小时醒来、进程**还活着**的 misfire 一模一样——没有重启，故只有正在跑的 sweep 才会发现刻度掉了。
	misfireCtx, mstop := context.WithCancel(context.Background())
	a.misfireStop = mstop
	a.misfireDone = make(chan struct{})
	go a.misfireLoop(misfireCtx)
	// Run-history retention on its OWN very slow ticker (scheduler 工单⑬), kicked by a retention
	// PATCH. Primed with one buffered kick INSTEAD of sweeping inline here: the first sweep after a
	// long-retention backlog can purge thousands of runs, and boot runs BEFORE ListenAndServe — an
	// inline pass would delay serving by exactly as long as the user's neglect. On the loop's
	// goroutine it starts immediately and costs boot nothing.
	// run 历史保留跑在**自己**的极慢 ticker 上（scheduler 工单⑬），由 retention PATCH 踢。用一次 buffered
	// kick 预置、**而非**在此内联清理：长保留积压后的首次清理可能清掉数千 run，而 boot 跑在 ListenAndServe
	// **之前**——内联一趟会让开始服务恰好延迟用户疏于打理的那么久。放在循环的 goroutine 上它立刻开始、且不
	// 花 boot 一分钱。
	retentionCtx, rstop := context.WithCancel(context.Background())
	a.retentionStop = rstop
	a.retentionDone = make(chan struct{})
	a.retentionKick = make(chan struct{}, 1)
	a.retentionKick <- struct{}{}
	a.svc.settings.SetOnRetentionChanged(a.kickRetention)
	go a.retentionLoop(retentionCtx)
}

// bgWarn logs a background-loop failure — unless the loop is simply shutting down. Now that the
// loops' ctx reaches the work (forEachWorkspace), every in-flight DB op fails with context.Canceled
// the moment Shutdown cancels; that is the ordered shutdown WORKING, not a fault. A warning on every
// clean exit is how a real one gets ignored.
//
// bgWarn 记后台循环的失败——除非那只是循环在关停。既然循环的 ctx 现在能抵达工作（forEachWorkspace），
// Shutdown 一取消，所有在飞 DB 操作都会以 context.Canceled 失败；那是有序关停在**正常工作**、不是故障。
// 每次干净退出都喊一嗓子，真正的警告就是这样被无视的。
func (a *App) bgWarn(ctx context.Context, msg string, err error) {
	if ctx.Err() != nil {
		return
	}
	a.log.Warn(msg, zap.Error(err))
}

// kickRetention asks for an off-schedule retention sweep, dropping the ask if one is already queued
// (the pending sweep will read the settings fresh anyway, so a second is redundant). Never blocks —
// it runs on the HTTP handler's goroutine (the settings retention-changed hook).
//
// kickRetention 请一趟计划外的保留清理，若已排队则丢弃这次请求（待跑的那趟本就会现读 settings，故第二趟
// 是多余的）。**绝不阻塞**——它跑在 HTTP handler 的 goroutine 上（settings 的 retention-changed 钩子）。
func (a *App) kickRetention() {
	select {
	case a.retentionKick <- struct{}{}:
	default:
	}
}

// forEachWorkspace runs fn once per workspace, each in a ctx seeded with that workspace's id. The
// workspaces table is global (no ,ws column), so listing works on a bare ctx; everything inside fn
// is then properly isolated. Listing fresh per call keeps a workspace created after boot
// participating in the next tick.
//
// The seed is applied TO THE CALLER'S ctx, not to a fresh Background: every caller is a background
// loop whose ctx IS its shutdown signal (Boot's is Background and never cancels, so it is unaffected).
// Seeding onto Background instead — which reqctx.Detached does, since its job is escaping a REQUEST's
// cancellation, a hazard no loop here has — silently threw that signal away: the loops' shutdown
// waits, and SweepRunRetention's between-batch `ctx.Err()` check (工单⑬), were reading a ctx that
// could never be cancelled. The wait would sit out a long purge to the full grace and the check was
// dead code. Cancellation now reaches the work: a sweep stops at its next batch boundary (every
// committed batch stays committed), and the remaining workspaces are skipped rather than started
// after the process was asked to stop.
//
// forEachWorkspace 对每个 workspace 跑一次 fn，各自在种了该 workspace id 的 ctx 里。workspaces 表是全局表
// （无 ,ws 列），裸 ctx 可列；fn 内部随之正确隔离。每次调用现列，使 boot 后新建的 workspace 在下一个 tick 即参与。
//
// 种子盖在**调用方的** ctx 上、而非另起一个 Background：这里每个调用方都是后台循环，其 ctx **就是**它的关停
// 信号（Boot 的是 Background、永不取消，故不受影响）。改盖在 Background 上——即 reqctx.Detached 所做的，因为
// 它的职责是逃开**请求**的取消，而此处没有任何循环面对那个危险——等于把信号静默扔了：循环的关停等待、以及
// SweepRunRetention 的批间 `ctx.Err()` 检查（工单⑬），读的都是一个永不可能被取消的 ctx。等待会为一次长清理
// 干坐满整个宽限，而那个检查是死代码。现在取消能真正抵达工作：清理在下一个批边界停（已提交的批保持提交），
// 且剩余 workspace 被跳过、而不是在进程已被要求停止之后才开工。
func (a *App) forEachWorkspace(ctx context.Context, fn func(wsCtx context.Context)) {
	workspaces, err := a.svc.workspace.List(ctx)
	if err != nil {
		a.log.Warn("bootstrap: list workspaces for background work", zap.Error(err))
		return
	}
	for _, ws := range workspaces {
		if ctx.Err() != nil {
			return
		}
		fn(reqctxpkg.SetWorkspaceID(ctx, ws.ID))
	}
}

// drainLoop periodically claims pending firings (enqueuing each onto the Advance pool) until the app
// shuts down — per workspace per tick (the firings table is workspace-scoped). Now FAST: it only
// claims + enqueues, never executes a node, so a slow run can't stall it (F174). Timeouts are swept by
// timeoutLoop, not here.
//
// drainLoop 周期 claim 待处理 firing（把每条入队到 Advance 池）直到 app 关停——每 tick 逐 workspace
// （firings 表按 workspace 隔离）。现在**很快**：只 claim + 入队、绝不执行节点，故慢 run 卡不住它（F174）。
// 超时由 timeoutLoop 扫描、不在此处。
func (a *App) drainLoop(ctx context.Context) {
	defer close(a.drainDone)
	t := time.NewTicker(drainInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			a.forEachWorkspace(ctx, func(wsCtx context.Context) {
				if err := a.svc.scheduler.DrainFirings(wsCtx); err != nil {
					a.bgWarn(ctx, "bootstrap: drain firings", err)
				}
			})
		}
	}
}

// timeoutLoop sweeps approval/timer timeouts on its own ticker, decoupled from drainLoop (F174) so a
// saturated Advance pool can never delay approval-timeout settling — it only resolves parked nodes
// (pure DB) and ENQUEUES any re-drive, never executing a node inline. Per workspace per tick (parked-
// nodes table is workspace-scoped; CheckTimeouts' contract is "the caller ticks it per workspace").
//
// timeoutLoop 在自己的 ticker 上扫描审批/计时超时，与 drainLoop 解耦（F174），故满载的 Advance 池绝不延迟
// 审批超时结算——它只结算 parked 节点（纯 DB）并**入队**重驱动、绝不内联执行节点。每 tick 逐 workspace
// （parked-nodes 表按 workspace 隔离；CheckTimeouts 契约就是「调用方逐 workspace tick」）。
// misfireLoop accounts cron ticks that a wall-clock gap ate, on its own slow ticker (scheduler
// 工单⑨) — per workspace per tick, like its siblings. It only writes ledger rows (and, for a
// catchup_one trigger, hands ONE fan-out to the normal firing path), so it can never stall the
// drain: the two loops share nothing but the workspace list.
//
// misfireLoop 在自己的慢 ticker 上把墙钟缺口吃掉的 cron 刻度入账（scheduler 工单⑨）——与兄弟循环一样
// 每 tick 逐 workspace。它只写台账行（catchup_one 的 trigger 则交**一次**扇出给正常 firing 径），故绝不
// 会卡住 drain：两个循环除 workspace 列表外毫无共享。
func (a *App) misfireLoop(ctx context.Context) {
	defer close(a.misfireDone)
	t := time.NewTicker(misfireInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			a.forEachWorkspace(ctx, func(wsCtx context.Context) {
				if n, err := a.svc.trigger.SweepMisfires(wsCtx); err != nil {
					a.bgWarn(ctx, "bootstrap: misfire sweep", err)
				} else if n > 0 {
					a.log.Info("bootstrap: accounted missed cron ticks", zap.Int("missed", n))
				}
			})
		}
	}
}

// retentionLoop enforces the run-history retention line (scheduler 工单⑬, 判决④) — per workspace per
// pass, like its siblings — on a very slow ticker OR on demand (a retention PATCH kicks it). It reads
// the line fresh every pass, so a PATCH needs no hot-swap plumbing; a 0 line ("keep forever") makes
// the pass a no-op WITHOUT touching the DB, which is the physical guarantee behind the setting.
//
// retentionLoop 执行 run 历史保留线（scheduler 工单⑬、判决④）——与兄弟循环一样每趟逐 workspace——跑在极慢
// ticker 上**或**按需（retention PATCH 踢它）。它每趟现读线，故 PATCH 不需要热换管道；线为 0（「永久保留」）
// 让这趟成为**碰都不碰 DB** 的 no-op，这正是该设置背后的物理保证。
func (a *App) retentionLoop(ctx context.Context) {
	defer close(a.retentionDone)
	t := time.NewTicker(retentionInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			a.sweepRetention(ctx)
		case <-a.retentionKick:
			a.sweepRetention(ctx)
		}
	}
}

// sweepRetention translates the configured line into a cutoff and purges each workspace past it.
// The line→cutoff translation is bootstrap's (it owns the settings), so the scheduler service stays
// a pure "purge terminal runs before T" — trivially testable, no settings dependency.
//
// sweepRetention 把配置的线翻译成 cutoff 并逐 workspace 清理越线的。「线→cutoff」的翻译归 bootstrap
// （它拥有 settings），故 scheduler service 保持纯粹的「清掉 T 之前的终态 run」——极易测、无 settings 依赖。
func (a *App) sweepRetention(ctx context.Context) {
	days := a.svc.settings.Retention().RunRetentionDays
	if days <= 0 {
		return // keep forever — never touch the DB. 永久保留——碰都不碰 DB。
	}
	cutoff := time.Now().UTC().AddDate(0, 0, -days)
	var purged int
	a.forEachWorkspace(ctx, func(wsCtx context.Context) {
		if n, err := a.svc.scheduler.SweepRunRetention(wsCtx, cutoff); err != nil {
			a.bgWarn(ctx, "bootstrap: run retention sweep", err)
		} else if n > 0 {
			purged += n
			a.log.Info("bootstrap: purged runs past the retention line", zap.Int("runs", n), zap.Int("retentionDays", days))
		}
	})
	// Reclaim the freed pages to the filesystem ONCE per sweep (VACUUM/incremental_vacuum are DB-global,
	// not workspace-scoped) — only when a purge actually deleted rows, and only if the dead space clears
	// the reclaim gate (routine churn reuses freed pages; a tightened retention line does not). Deleting
	// rows alone frees nothing on disk (SQLite's ratchet), which is the whole T4 bug. Best-effort: a
	// reclaim failure is not a retention failure. ctx is checked so shutdown skips it.
	// 每趟清理**一次**把腾出的页还给文件系统（VACUUM/incremental_vacuum 是 DB 全局、非 workspace 隔离）——仅当
	// 清理真删了行、且死空间越过回收闸时（日常 churn 复用腾出的页；收紧保留线则不会）。光删行在磁盘上什么都不腾
	// （SQLite 的棘轮）,正是 T4 bug 本身。尽力而为：回收失败不是清理失败。查 ctx 使关停时跳过。
	if purged > 0 && ctx.Err() == nil {
		if reclaimed, err := dbinfra.ReclaimFreePages(ctx, a.db); err != nil {
			a.bgWarn(ctx, "bootstrap: reclaim free pages", err)
		} else if reclaimed > 0 {
			a.log.Info("bootstrap: reclaimed disk from purged run history", zap.Int64("reclaimedBytes", reclaimed))
		}
	}
}

func (a *App) timeoutLoop(ctx context.Context) {
	defer close(a.timeoutDone)
	t := time.NewTicker(drainInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-t.C:
			a.forEachWorkspace(ctx, func(wsCtx context.Context) {
				if err := a.svc.scheduler.CheckTimeouts(wsCtx, now.UTC()); err != nil {
					a.bgWarn(ctx, "bootstrap: check timeouts", err)
				}
			})
		}
	}
}

// Shutdown stops everything in reverse dependency order, then closes the DB last. ctx bounds the
// graceful drain. Order: stop the firing-drain ticker (no new runs) → bounded-grace the in-flight
// workflow Advance to finish its current node, then cancel every in-flight Advance + wait for the
// drain loop to return (R3, option C — so nothing keeps spawning or races db.Close) → trigger
// listeners → chat queues → mcp / handler resident processes → sandbox (kills any remaining spawned
// long-lived handles its consumers didn't) → shell background jobs (run_in_background children + their
// trees, R1) → flush logs → close the DB (checkpoints the SQLite WAL). Each step is best-effort logged
// so one stuck subsystem cannot block the rest.
//
// Shutdown 逆依赖序停一切、最后关 DB。ctx 限优雅排空。顺序：停 firing-drain ticker（不再起新 run）→
// 给在飞 Advance 有限宽限跑完当前节点、再取消所有在飞 Advance + 等 drain 循环返回（R3 选项 C——免其继续
// spawn 或撞 db.Close）→ trigger listener → chat 队列 → mcp / handler 常驻进程 → sandbox（杀消费者没杀干净的
// spawned long-lived handle）→ shell 后台任务（run_in_background 子进程 + 整树，R1）→ flush 日志 → 关 DB
// （checkpoint SQLite WAL）。每步 best-effort 记日志，一个卡死子系统不拖垮其余。
func (a *App) Shutdown(ctx context.Context) {
	if a.tickStop != nil {
		a.tickStop() // no new firing drains → no new enqueues from the drain ticker
	}
	if a.timeoutStop != nil {
		a.timeoutStop() // no new timeout sweeps → no new enqueues from the timeout ticker
	}
	if a.misfireStop != nil {
		a.misfireStop() // no new misfire sweeps → no new ledger writes / catchup fan-outs (工单⑨)
	}
	if a.retentionStop != nil {
		a.retentionStop() // no new retention sweeps → no new purges (工单⑬)
	}
	// R3 (option C), F174 pool: the drain/timeout tickers stop FEEDING the pool; their loops return
	// fast (they only claim + enqueue now). Then give the in-flight POOL workers a bounded grace to
	// finish their CURRENT node — record-once makes a completed node durable, so the run resumes cleanly
	// next boot. If the grace expires, cancel every in-flight Advance (pooled AND manual :trigger) so it
	// can't keep spawning subprocesses or race db.Close, then WAIT for the pool workers to exit BEFORE
	// db.Close (StopPool's WaitGroup) — drainDone alone no longer means "all Advance done", it only means
	// the drain ticker stopped. The interrupted run records failed (:replay-able).
	// R3 选项 C + F174 池：drain/timeout ticker 停止**喂**池；其循环快速返回（现在只 claim+入队）。再给在飞的
	// **池 worker** 有限宽限跑完当前节点（record-once 持久化、下次 boot 干净续）。宽限超时则取消所有在飞 Advance
	// （池上 + 手动 :trigger），免其继续 spawn 子进程或撞 db.Close，再**等池 worker 退出**才 db.Close（StopPool 的
	// WaitGroup）——drainDone 单独已不再表示「所有 Advance 完」、只表示 drain ticker 停了。被打断的 run 记 failed、可 :replay。
	// Bound BOTH waits by the shutdown ctx: the loops return fast now (claim + enqueue only, F174), but a
	// wedged DB op inside forEachWorkspace must never turn SIGTERM into a SIGKILL (the F101 shutdown-hang
	// symptom). If a loop overruns the grace we proceed anyway — the pool's send is panic-safe (sendJob),
	// so a still-feeding loop racing StopPool can no longer crash the process; its late enqueue is dropped
	// and the run resumes next boot.
	// 两个等待都受 shutdown ctx 上界约束：循环现在很快返回（只 claim+enqueue，F174），但 forEachWorkspace 里
	// 卡死的 DB 操作绝不能把 SIGTERM 拖成 SIGKILL（F101 关停挂起症状）。循环超出宽限则照常往下走——池的发送已
	// panic-safe（sendJob），仍在喂的循环撞上 StopPool 不再崩进程，其迟到入队被丢、run 下次 boot 续。
	if a.drainDone != nil {
		select {
		case <-a.drainDone: // drain ticker loop returned (fast — claim + enqueue only)
		case <-ctx.Done():
			a.log.Warn("bootstrap: drain loop did not return within shutdown grace; proceeding")
		}
	}
	if a.timeoutDone != nil {
		select {
		case <-a.timeoutDone: // timeout ticker loop returned
		case <-ctx.Done():
			a.log.Warn("bootstrap: timeout loop did not return within shutdown grace; proceeding")
		}
	}
	// Wait out the misfire loop too (工单⑨): it writes firing rows, so a straggler racing db.Close
	// is the same hazard the drain/timeout waits exist for.
	// 同样等 misfire 循环退出（工单⑨）：它写 firing 行，掉队者撞 db.Close 与 drain/timeout 等待所防的是同一危险。
	if a.misfireDone != nil {
		select {
		case <-a.misfireDone: // misfire ticker loop returned
		case <-ctx.Done():
			a.log.Warn("bootstrap: misfire loop did not return within shutdown grace; proceeding")
		}
	}
	// Wait out the retention loop too (工单⑬): it DELETES rows, so a straggler racing db.Close is the
	// sharpest form of the hazard these waits exist for. Its batches are short and it checks ctx
	// between them, so it returns at the next batch boundary.
	// 同样等保留清理循环退出（工单⑬）：它**删**行，故掉队者撞 db.Close 是这些等待所防危险中最锋利的一种。
	// 它的批很短、且批间查 ctx，故它在下一个批边界返回。
	if a.retentionDone != nil {
		select {
		case <-a.retentionDone: // retention ticker loop returned
		case <-ctx.Done():
			a.log.Warn("bootstrap: retention loop did not return within shutdown grace; proceeding")
		}
	}
	a.svc.scheduler.WaitPoolDrained(ctx, drainShutdownGrace) // bounded grace for in-flight nodes to finish cleanly
	a.svc.scheduler.Shutdown()                               // cancel every still-in-flight Advance (pooled + manual :trigger)
	a.svc.scheduler.StopPool()                               // close the queue + wait for workers to exit before db.Close
	a.svc.trigger.Shutdown()
	a.svc.chat.Shutdown()
	a.svc.search.Close(ctx) // bounded by the shutdown ctx — a first-demand model download can't stall shutdown (R14)
	a.svc.mcp.Shutdown(ctx)
	a.svc.handler.Shutdown(ctx)
	if err := a.svc.sandbox.Shutdown(ctx); err != nil {
		a.log.Warn("bootstrap: sandbox shutdown", zap.Error(err))
	}
	a.svc.shellMgr.Stop() // reap run_in_background children + their whole process trees (R1)
	_ = a.log.Sync()
	if err := a.db.Close(); err != nil {
		a.log.Warn("bootstrap: db close", zap.Error(err))
	}
}
