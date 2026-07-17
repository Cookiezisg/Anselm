package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"go.uber.org/zap"

	schedulerapp "github.com/sunweilin/anselm/backend/internal/app/scheduler"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// FlowrunHandler hosts the durable-execution HTTP surface: list/inspect runs, start one manually
// ("Run now"), replay a failed one, cancel a running one, and decide a parked approval. A flowrun is
// a runtime record (no version, no build) — so there is no Create-as-edit / :revert here; "create"
// is starting a run and its body is the entry trigger's declared Outputs (the manual payload form).
//
// FlowrunHandler 持持久化执行的 HTTP 面：列/查 run、手动起一个（「Run now」）、replay 失败的、cancel
// 在跑的、决策 parked 审批。flowrun 是运行时记录（无版本、无构建）——故无 Create-as-edit/:revert；
// 「create」就是起一个 run，body 形如入口 trigger 声明的 Outputs（手动 payload 表单）。
type FlowrunHandler struct {
	svc *schedulerapp.Service
	log *zap.Logger
}

func NewFlowrunHandler(svc *schedulerapp.Service, log *zap.Logger) *FlowrunHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &FlowrunHandler{svc: svc, log: log.Named("handlers.flowrun")}
}

func (h *FlowrunHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/flowruns", h.List)
	mux.HandleFunc("POST /api/v1/flowruns", h.Start)
	mux.HandleFunc("GET /api/v1/flowrun-inbox", h.Inbox)
	mux.HandleFunc("GET /api/v1/flowrun-stats", h.Stats)
	mux.HandleFunc("GET /api/v1/flowrun-matrix", h.Matrix)
	mux.HandleFunc("GET /api/v1/flowruns/{id}", h.Get)
	mux.HandleFunc("GET /api/v1/flowruns/{id}/activity", h.Activity)
	mux.HandleFunc("POST /api/v1/flowruns/{idAction}", h.postOnRun)
	mux.HandleFunc("POST /api/v1/flowruns/{id}/approvals/{nodeAction}", h.postOnApproval)
}

// List pages a workspace's runs (newest-first). Filters compose with AND (scheduler 工单⑥):
// ?workflowId / ?triggerId (equality), ?status / ?origin (closed sets — an out-of-enum value is a
// loud 422 with the allowed set in Details), and ?startedAfter / ?startedBefore (RFC3339, the
// half-open window [after, before) on started_at; a non-RFC3339 value is a loud 422).
//
// List 分页一个 workspace 的 run（最新优先）。过滤 AND 组合（scheduler 工单⑥）：?workflowId /
// ?triggerId（等值）、?status / ?origin（封闭集——枚举外值 422 大声拒、Details 带合法集）、
// ?startedAfter / ?startedBefore（RFC3339，started_at 上的半开窗 [after, before)；非 RFC3339 一律 422）。
func (h *FlowrunHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	query := r.URL.Query()
	startedAfter, err := parseListTime(query.Get("startedAfter"), "startedAfter", flowrundomain.ErrInvalidListFilter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	startedBefore, err := parseListTime(query.Get("startedBefore"), "startedBefore", flowrundomain.ErrInvalidListFilter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	completedAfter, err := parseListTime(query.Get("completedAfter"), "completedAfter", flowrundomain.ErrInvalidListFilter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	completedBefore, err := parseListTime(query.Get("completedBefore"), "completedBefore", flowrundomain.ErrInvalidListFilter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	runs, next, err := h.svc.ListRuns(r.Context(), flowrundomain.ListFilter{
		WorkflowID:      query.Get("workflowId"),
		Status:          query.Get("status"),
		TriggerID:       query.Get("triggerId"),
		Origin:          query.Get("origin"),
		StartedAfter:    startedAfter,
		StartedBefore:   startedBefore,
		CompletedAfter:  completedAfter,
		CompletedBefore: completedBefore,
		Cursor:          p.Cursor,
		Limit:           p.Limit,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, runs, next, next != "")
}

// parseListTime parses one half-open window bound (?startedAfter / ?startedBefore on flowruns,
// ?createdAfter / ?createdBefore on firings): absent → zero time (unbounded), RFC3339 → normalized
// to UTC (stored timestamps are UTC — a mixed-zone bound would compare wrong as driver-serialized
// text). Anything else is a loud 422 with the offending param + value in Details (scheduler 工单⑥,
// reused verbatim by 工单⑭). Deliberately NOT the parseSince grammar: a window bound is an absolute
// instant, not a look-back duration.
//
// The caller passes its own domain's sentinel because the code must name the resource the client is
// actually listing — answering a bad ?createdAfter on /firings with FLOWRUN_LIST_INVALID_FILTER
// would be a lie. The PARSING is one implementation on purpose: two resources with two spellings of
// "an RFC3339 window bound" is how the two spellings start to drift.
//
// parseListTime 解析一个半开窗的界（flowruns 上的 ?startedAfter/?startedBefore、firings 上的
// ?createdAfter/?createdBefore）：缺席 → 零值时间（不设界），RFC3339 → 归一到 UTC（存储时间戳是
// UTC——混时区界经 driver 文本序列化会比错）。其余一律 422 大声拒、Details 带出错参数 + 原值
// （scheduler 工单⑥，工单⑭ 逐字复用）。刻意不用 parseSince 文法：窗口界是绝对时刻、非回看时长。
//
// 调用方传自己域的 sentinel——码必须点名客户端**实际在列**的那个资源，拿
// FLOWRUN_LIST_INVALID_FILTER 去答 /firings 上一个坏的 ?createdAfter 就是撒谎。而**解析**刻意只有
// 一份实现：两个资源各写一套「RFC3339 窗口界」，正是两套写法开始漂移的方式。
func parseListTime(raw, param string, invalid *errorspkg.Error) (time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, nil
	}
	ts, err := time.Parse(time.RFC3339, raw)
	if err != nil {
		return time.Time{}, invalid.WithDetails(map[string]any{"param": param, "got": raw, "want": "RFC3339"})
	}
	return ts.UTC(), nil
}

// Start is the manual-trigger path ("Run now"): create + advance a run. The payload conforms to the
// entry trigger's Outputs; entryNode disambiguates a multi-trigger graph. Returns the run + nodes
// (which may already be completed, failed, or running-parked since advance is synchronous in v1).
//
// Start 是手动 trigger 路径（「Run now」）：建 + advance 一个 run。payload 形如入口 trigger 的 Outputs；
// entryNode 在多 trigger 图里消歧。返 run + 节点（v1 advance 同步，故可能已 completed/failed/running-parked）。
func (h *FlowrunHandler) Start(w http.ResponseWriter, r *http.Request) {
	var req struct {
		WorkflowID string         `json:"workflowId"`
		EntryNode  string         `json:"entryNode"`
		Payload    map[string]any `json:"payload"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	id, err := h.svc.StartRun(r.Context(), schedulerapp.StartInput{
		WorkflowID: req.WorkflowID,
		EntryNode:  req.EntryNode,
		Payload:    req.Payload,
		Origin:     flowrundomain.OriginManual, // POST /flowruns IS the human "Run now" (run provenance)
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	h.writeRun(w, r, id, responsehttpapi.Created)
}

// Get returns one run header + all its node rows (the full memoization).
//
// Get 返一个 run 头 + 它全部节点行（完整记忆化）。
func (h *FlowrunHandler) Get(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	run, nodes, next, err := h.svc.GetRunWithNodesPage(r.Context(), r.PathValue("id"), p.Cursor, p.Limit)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"flowrun": run, "nodes": nodes, "nextCursor": next})
}

// Activity pages a run's execution-log activity (scheduler 工单⑤) in gantt order (startedAt
// ascending, N4 ?cursor&limit): rows {nodeId, iteration, kind, execId, status, startedAt, endedAt,
// elapsedMs, readyAt?} — the four execution-log tables UNIONed by flowrun_id, readyAt joined off
// the flowrun_nodes truth row (工单⑫; absent on pre-⑫ rows / no matching truth row). 404
// FLOWRUN_NOT_FOUND when the run does not exist.
//
// Activity 分页一个 run 的执行日志活动（scheduler 工单⑤），甘特序（startedAt 升序，N4 ?cursor&limit）：
// 行 {nodeId, iteration, kind, execId, status, startedAt, endedAt, elapsedMs, readyAt?}——四张执行
// 日志表按 flowrun_id UNION、readyAt join 自 flowrun_nodes 真相行（工单⑫；⑫ 前旧行/无对应真相行则
// 缺席）。run 不存在 404 FLOWRUN_NOT_FOUND。
func (h *FlowrunHandler) Activity(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	rows, next, err := h.svc.ListActivity(r.Context(), r.PathValue("id"), p.Cursor, p.Limit)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, rows, next, next != "")
}

// Inbox returns every parked approval node in the workspace (the approval inbox). Each row is the
// parked node enriched with workflow context (scheduler 工单④): workflowId + workflowName (joined
// from the run header; a soft-deleted workflow's name falls back to the bare id) + optional
// deadline (parkedAt + the pinned approval version's timeout; absent when the form never times
// out). Enrichment lives in the app service (ListInbox) — this handler just writes it.
//
// Inbox 返 workspace 内所有 parked approval 节点（审批收件箱）。每行 = parked 节点行 + workflow
// 上下文 enrich（scheduler 工单④）：workflowId + workflowName（join 自 run 头；软删 workflow 名
// 回落裸 id）+ 可空 deadline（parkedAt + 钉死 approval 版本 timeout；表永不超时则键缺席）。
// enrich 住 app 服务（ListInbox）——本 handler 只负责写出。
func (h *FlowrunHandler) Inbox(w http.ResponseWriter, r *http.Request) {
	parked, err := h.svc.ListInbox(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"parked": parked})
}

// Stats is the operational statistics batch (scheduler 工单③): workspace totals + one health row
// per ?workflowIds=<csv, ≤50 after dedup> workflow. ?recentN (default 10, clamped to 20) sizes the
// per-workflow status beads; ?since (RFC3339 timestamp or look-back duration like 24h / 7d,
// default 7d) is the single window for completedSince/failedSince/successRate/avgElapsedMs. A
// bounded batch — N4-exempt from cursor pagination.
//
// Stats 是运营统计批查（scheduler 工单③）：workspace 聚合 + ?workflowIds=<csv,去重后 ≤50> 每
// workflow 一条健康行。?recentN（默认 10、钳到 20）定逐 workflow 状态珠数；?since（RFC3339 时间戳
// 或回看时长如 24h / 7d，默认 7d）统一 completedSince/failedSince/successRate/avgElapsedMs 的窗口。
// 有界批查——N4 分页豁免。
func (h *FlowrunHandler) Stats(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	recentN, err := parseRecentN(query.Get("recentN"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	since, err := parseSince(query.Get("since"), time.Now().UTC())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	stats, err := h.svc.RunStats(r.Context(), flowrundomain.StatsQuery{
		WorkflowIDs: splitCSV(query.Get("workflowIds")),
		RecentN:     recentN,
		Since:       since,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, stats)
}

// Matrix is the node×run status grid (scheduler 工单⑩): ?flowrunIds=<csv, ≤50 after dedup;
// REQUIRED — an empty set is a 400, over-cap a loud 422> returns {cols, rows, cells} for exactly
// those runs — columns in the canonical newest→oldest (started_at, id) DESC order REGARDLESS of
// request order, rows the union of node ids in first-appearance order, cells SPARSE (a node a run
// never reached has none). Unknown ids are silently absent (cols carry explicit keys). Which runs
// are on screen is the client's business — it pages GET /flowruns with the time-range grammar and
// batch-fetches the grid per page. Bounded batch — N4 pagination exempt.
//
// Matrix 是节点×run 状态格阵（scheduler 工单⑩）：?flowrunIds=<csv，去重后 ≤50；**必填**——空集 400、
// 越上限大声 422> 返恰为这些 run 的 {cols, rows, cells}——列按正典新→旧 (started_at, id) DESC 序、
// **与请求顺序无关**，行是 node id 并集按首次出现序，格**稀疏**（某 run 没跑到的节点无格）。未知 id
// 静默缺席（cols 自带显式键）。哪些 run 在屏上是客户端的事——它按时间窗文法翻 GET /flowruns、逐页批取
// 格阵。有界批查——N4 分页豁免。
func (h *FlowrunHandler) Matrix(w http.ResponseWriter, r *http.Request) {
	matrix, err := h.svc.RunMatrix(r.Context(), flowrundomain.MatrixQuery{
		FlowrunIDs: splitCSV(r.URL.Query().Get("flowrunIds")),
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, matrix)
}

// parseRecentN parses ?recentN with the same semantics as a page limit (ParsePage): absent → 0
// (the app applies the default), non-numeric or < 1 → ErrInvalidRequest; the upper clamp is the
// app's.
//
// parseRecentN 解析 ?recentN，语义同 page limit（ParsePage）：缺席 → 0（app 应用默认），非数字或
// <1 → ErrInvalidRequest；上限钳制归 app。
func parseRecentN(raw string) (int, error) {
	if raw == "" {
		return 0, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 1 {
		return 0, errorspkg.ErrInvalidRequest
	}
	return n, nil
}

// parseSince parses ?since as either an RFC3339 timestamp (absolute window start) or a positive
// look-back duration — Go duration syntax (24h, 90m) plus the whole-days form <n>d the spec
// speaks (7d). Absent → zero time (the app applies the 7d default). Anything else is a loud 422
// with the offending value in Details.
//
// parseSince 解析 ?since：RFC3339 时间戳（窗口绝对起点）或正的回看时长——Go duration 语法（24h、
// 90m）+ 规范口径的整天形 <n>d（7d）。缺席 → 零值时间（app 应用 7d 默认）。其余一律 422 大声拒、
// Details 带原值。
func parseSince(raw string, now time.Time) (time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, nil
	}
	if ts, err := time.Parse(time.RFC3339, raw); err == nil {
		return ts.UTC(), nil
	}
	if days, ok := strings.CutSuffix(raw, "d"); ok {
		if n, err := strconv.Atoi(days); err == nil && n > 0 {
			return now.Add(-time.Duration(n) * 24 * time.Hour), nil
		}
	} else if dur, err := time.ParseDuration(raw); err == nil && dur > 0 {
		return now.Add(-dur), nil
	}
	return time.Time{}, flowrundomain.ErrStatsInvalidSince.WithDetails(map[string]any{"got": raw})
}

// postOnRun dispatches POST /flowruns/{id}:<action> (:replay | :cancel). Both respond 202 with the
// run's post-action state in the same envelope shape as Get ({flowrun, first node page, nextCursor}).
//
// postOnRun 派发 POST /flowruns/{id}:<action>（:replay | :cancel）。两者都以 202 返动作后 run 态，
// 信封形同 Get（{flowrun, 节点首页, nextCursor}）。
func (h *FlowrunHandler) postOnRun(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
		return
	}
	switch action {
	case "replay":
		if err := h.svc.Replay(r.Context(), id); err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		h.writeRun(w, r, id, func(w http.ResponseWriter, data any) { responsehttpapi.Success(w, http.StatusAccepted, data) })
	case "cancel":
		// Cancel a single running run (scheduler 工单②): only running is cancellable — anything else
		// (including a first-wins loss to the run's natural terminal) is a clean 422.
		// 取消单个 running run（scheduler 工单②）：仅 running 可取消——其余（含输给自然终态的
		// first-wins 竞态）一律干净 422。
		if err := h.svc.CancelRun(r.Context(), id); err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		h.writeRun(w, r, id, func(w http.ResponseWriter, data any) { responsehttpapi.Success(w, http.StatusAccepted, data) })
	default:
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
	}
}

// postOnApproval dispatches POST /flowruns/{id}/approvals/{nodeId}:decide with a {decision,reason} body.
//
// postOnApproval 派发 POST /flowruns/{id}/approvals/{nodeId}:decide，body {decision,reason}。
func (h *FlowrunHandler) postOnApproval(w http.ResponseWriter, r *http.Request) {
	nodeID, action, ok := idAndAction(r, "nodeAction")
	if !ok || action != "decide" {
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
		return
	}
	var req struct {
		Decision string `json:"decision"`
		Reason   string `json:"reason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if err := h.svc.DecideApproval(r.Context(), r.PathValue("id"), nodeID, req.Decision, req.Reason); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	h.writeRun(w, r, r.PathValue("id"), func(w http.ResponseWriter, data any) { responsehttpapi.Success(w, http.StatusAccepted, data) })
}

// writeRun re-reads the run + nodes and writes them with the given responder (so a caller sees the
// run's post-action state).
//
// writeRun 重读 run + 节点并用给定 responder 写出（使调用方见动作后的 run 态）。
func (h *FlowrunHandler) writeRun(w http.ResponseWriter, r *http.Request, id string, respond func(http.ResponseWriter, any)) {
	// A post-action confirmation shows the run + its FIRST node page (newest-first); the client pages the
	// rest via GET /flowruns/{id}?cursor= — same bounded shape as Get, never the full dump (F168-M7).
	// 动作后确认显示 run + 其节点首页（最新在前）；客户端经 GET ?cursor= 翻其余——与 Get 同一有界形状、绝不全量倾倒。
	run, nodes, next, err := h.svc.GetRunWithNodesPage(r.Context(), id, "", responsehttpapi.DefaultLimit)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	respond(w, map[string]any{"flowrun": run, "nodes": nodes, "nextCursor": next})
}
