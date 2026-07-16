// Package flowrun is the domain layer for one workflow execution's DURABLE STATE — the
// truth a crash recovers from. It is NOT a buildable entity (no catalog / relation / version);
// it is a runtime log written by the scheduler as it interprets a pinned graph.
//
// The model is node-result MEMOIZATION (DBOS / Conductor style), NOT an event-sourcing journal
// (Temporal style): there is no user code to replay, only a graph interpreter whose entire state
// is "which (node, iteration) completed with what result". That lives in flowrun_nodes — the one
// truth table. Re-running the interpreter (crash recovery / :replay) is idempotent because a
// completed row is copied, never re-executed (record-once on UNIQUE(flowrun_id,node_id,iteration)).
//
// Package flowrun 是「一次 workflow 执行的持久化状态」的 domain 层——崩溃从这里恢复。它不是可构建
// 实体（无 catalog/relation/版本），是 scheduler 解释钉死的图时写的运行时日志。
//
// 模型是**节点结果记忆化**（DBOS/Conductor 式），不是事件溯源日志（Temporal 式）：没有用户代码可
// 重放，只有图解释器，其全部状态 = 「哪些 (节点,轮次) 完成了、result 是啥」——这住在 flowrun_nodes
// 这张唯一真相表里。重跑解释器（崩溃恢复 / :replay）幂等，因为 completed 行被抄、绝不重跑
// （record-once 落在 UNIQUE(flowrun_id,node_id,iteration) 上）。
package flowrun

import (
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Run statuses. A run is running until terminal; "等人审批" is a NODE state (NodeParked), not a
// run state — "which runs await a human" is derived from parked flowrun_nodes rows, not a header
// column. cancelled is the kill terminal: a user hard-stopped the workflow (kill_workflow / :kill),
// distinct from failed (an activity errored) — it carries no engine fault, the run was simply
// terminated by hand.
//
// Run 状态。run 终态前一直 running；「等人审批」是**节点**状态（NodeParked）、不是 run 状态——
// 「哪些 run 在等人」从 parked 的 flowrun_nodes 行派生，不在头上冗余。cancelled 是 kill 终态：用户
// 硬停了 workflow（kill_workflow / :kill），区别于 failed（activity 出错）——它不带引擎故障，run 只是被手动终止。
const (
	StatusRunning   = "running"
	StatusCompleted = "completed"
	StatusFailed    = "failed"
	StatusCancelled = "cancelled"
)

// RunStatuses is the closed set of flowrun (run-header) statuses — used to reject illegal list-filter
// values. parked is a NODE status (below), NOT a run status: a parked run is derived from a parked
// node row, so it is intentionally absent here.
//
// RunStatuses 是 flowrun（run 头）状态的封闭集——用于拒非法 list 过滤值。parked 是节点级状态（见下）、
// 非 run 状态（parked run 由 parked 节点行派生），故此处刻意不含。
var RunStatuses = []string{StatusRunning, StatusCompleted, StatusFailed, StatusCancelled}

// Run origins — WHO started this run (provenance, stamped at creation, never mutated). manual is a
// human "Run now" (UI/API); chat is an agent's trigger_workflow inside a conversation (the run then
// also carries ConversationID); the four trigger words mirror the trigger domain's source kinds
// verbatim (cron/webhook/fsnotify/sensor) so a firing's kind IS its run's origin — one vocabulary,
// no mapping table to drift.
//
// Run 来源——这个 run 是**谁**起的（溯源，创建时盖章、永不改写）。manual = 人点「Run now」（UI/API）；
// chat = 对话里 agent 调 trigger_workflow（run 同时带 ConversationID）；四个 trigger 词与 trigger 域
// source kind 逐字同词（cron/webhook/fsnotify/sensor），firing 的 kind 即其 run 的 origin——同一词表、
// 无映射表可漂移。
const (
	OriginManual   = "manual"
	OriginChat     = "chat"
	OriginCron     = "cron"
	OriginWebhook  = "webhook"
	OriginFsnotify = "fsnotify"
	OriginSensor   = "sensor"
)

// RunOrigins is the closed origin set (mirrors the DB CHECK). A NULL origin is a pre-provenance
// row (created before the columns existed) — the wire omits it and clients fall back to "unknown".
//
// RunOrigins 是 origin 封闭集（与 DB CHECK 一致）。origin 为 NULL 的是 provenance 之前的旧行——
// 线缆不发、客户端按 unknown 兜底。
var RunOrigins = []string{OriginManual, OriginChat, OriginCron, OriginWebhook, OriginFsnotify, OriginSensor}

// Node statuses. Rows are written TERMINAL-ONLY (no transient "running" row): an action runs and
// completes within one synchronous advance() pass, so there is no mid-flight node state to persist
// — a crash before the row is written simply re-runs (at-least-once). parked is the one non-terminal
// state: an approval writes it before suspending, then a decision flips it to completed (first-wins
// conditional update).
//
// Node 状态。行只写**终态**（无瞬时 running 行）：action 在一次同步 advance() 内跑完，无中途节点态
// 可存——写行前崩溃就重跑（at-least-once）。parked 是唯一非终态：approval 挂起前写它，
// 决策再把它翻成 completed（first-wins 条件更新）。
const (
	NodeCompleted = "completed"
	NodeFailed    = "failed"
	NodeParked    = "parked"
)

// Result keys — the per-kind shape of FlowRunNode.Result. control/approval results are structured
// (a port/decision drives routing + carried data); action/agent results are the raw callable/agent
// output stored as-is.
//
// Result keys —— FlowRunNode.Result 的 per-kind 形状。control/approval 的 result 有结构（port/decision
// 驱动路由 + 携带数据）；action/agent 的 result 是 callable/agent 原始输出原样存。
const (
	// ResultKeyPort: a control node's chosen routing port, stored under this RESERVED key ALONGSIDE
	// the chosen branch's emitted fields (which are stored FLAT) — so downstream reads
	// gate.<emitField> directly while the interpreter reads gate.__port for routing. The
	// double-underscore avoids colliding with a user emit field.
	// ResultKeyPort：control 节点选中的路由 port，存在这个**保留**键下，与选中分支 emit 的字段（扁平存）
	// 并列——故下游直接读 gate.<emit字段>，解释器读 gate.__port 路由。双下划线避免撞 emit 字段。
	ResultKeyPort     = "__port"   // control: chosen branch port (reserved routing key)
	ResultKeyDecision = "decision" // approval: yes | no (also downstream-readable)
	ResultKeyReason   = "reason"   // approval: human reason (optional)
	ResultKeyRendered = "rendered" // approval (parked): the rendered markdown for the inbox UI
)

// ControlResult builds a control node's memoized result: the chosen branch's emitted fields FLAT
// (so downstream reads gate.feedback) plus the reserved __port routing key.
//
// ControlResult 构造 control 节点的记忆化 result：选中分支 emit 的字段**扁平**（下游读 gate.feedback）
// + 保留的 __port 路由键。
func ControlResult(port string, emit map[string]any) map[string]any {
	out := make(map[string]any, len(emit)+1)
	for k, v := range emit {
		out[k] = v
	}
	out[ResultKeyPort] = port
	return out
}

// ApprovalDecision builds a decided approval node's result. decision ∈ {yes,no}; reason may be "".
//
// ApprovalDecision 构造已决策 approval 节点的 result。decision ∈ {yes,no}；reason 可空。
func ApprovalDecision(decision, reason string) map[string]any {
	return map[string]any{ResultKeyDecision: decision, ResultKeyReason: reason}
}

// FlowRun is the execution header: the FROZEN topology (VersionID) + the FROZEN referenced-entity
// versions (PinnedRefs) an interpreter walks, plus status + replay bookkeeping. Pinning is the
// two locks that make replay deterministic: a mid-run edit to the workflow or any referenced
// entity cannot change a running flow. This is a Log table — NO soft delete (D1).
//
// FlowRun 是执行头：钉死的拓扑（VersionID）+ 钉死的引用实体版本（PinnedRefs），加状态 + replay 记账。
// pin 是让重放确定的两把锁：运行中编辑 workflow 或任何引用实体都改不动在途 run。这是 Log 表——无软删（D1）。
type FlowRun struct {
	ID          string            `db:"id,pk"               json:"id"`
	WorkspaceID string            `db:"workspace_id,ws"     json:"-"`
	WorkflowID  string            `db:"workflow_id"         json:"workflowId"`
	VersionID   string            `db:"version_id"          json:"versionId"`           // pinned wfv_ (graph topology)
	PinnedRefs  map[string]string `db:"pinned_refs,json"    json:"pinnedRefs"`          // BuildPinClosure {entity_id: active_version_id}
	TriggerID   string            `db:"trigger_id"          json:"triggerId,omitempty"` // entry trg_ (empty for a manual :trigger)
	FiringID    string            `db:"firing_id"           json:"firingId,omitempty"`  // source trf_ (single-tx claim)
	// Origin / ConversationID are creation-time provenance (see RunOrigins). Nullable pointers, not
	// "" — rows created before these columns existed are NULL and must stay distinguishable from a
	// stamped value (the wire omits NULL; clients render "unknown"). ConversationID is set only for
	// origin=chat: the cv_ whose turn called trigger_workflow.
	//
	// Origin / ConversationID 是创建时溯源（见 RunOrigins）。可空指针而非 ""——两列诞生前的旧行是 NULL，
	// 必须与已盖章值可区分（线缆不发 NULL、客户端渲 unknown）。ConversationID 仅 origin=chat 时有：
	// 调 trigger_workflow 的那个 cv_。
	Origin         *string `db:"origin"          json:"origin,omitempty"`
	ConversationID *string `db:"conversation_id" json:"conversationId,omitempty"`

	Status      string     `db:"status"              json:"status"`          // running | completed | failed | cancelled
	ReplayCount int        `db:"replay_count"        json:"replayCount"`     // :replay increments; NOT a generation
	Error       string     `db:"error"               json:"error,omitempty"` // terminal-failed reason
	StartedAt   time.Time  `db:"started_at,created"  json:"startedAt"`
	CompletedAt *time.Time `db:"completed_at"        json:"completedAt,omitempty"`
	UpdatedAt   time.Time  `db:"updated_at,updated"  json:"updatedAt"`
}

// FlowRunNode is ★the truth: one (node, iteration) of a run with its memoized result. action /
// agent / control / approval each write their own row. UNIQUE(flowrun_id, node_id, iteration) is
// the record-once key — INSERT OR IGNORE makes the first write win (replay copies, never
// re-executes; approval first-wins falls out of it). Log table — NO soft delete (D1).
//
// FlowRunNode 是★真相：一个 run 的某 (节点,轮次) 及其记忆化 result。action/agent/control/approval
// 各写自己的行。UNIQUE(flowrun_id,node_id,iteration) 是 record-once 键——INSERT OR IGNORE 让首写赢
// （重放抄、绝不重跑；approval first-wins 由它落出）。Log 表——无软删（D1）。
type FlowRunNode struct {
	ID          string         `db:"id,pk"               json:"id"`
	WorkspaceID string         `db:"workspace_id,ws"     json:"-"`
	FlowRunID   string         `db:"flowrun_id"          json:"flowrunId"`
	NodeID      string         `db:"node_id"             json:"nodeId"`    // graph-local id (= the downstream reference name)
	Iteration   int            `db:"iteration"           json:"iteration"` // loop turn, 0-based
	Kind        string         `db:"kind"                json:"kind"`      // trigger|action|agent|control|approval
	Ref         string         `db:"ref"                 json:"ref"`       // pinned entity ref (audit)
	Status      string         `db:"status"              json:"status"`    // completed | failed | parked
	Result      map[string]any `db:"result,json"         json:"result"`    // per-kind shape (Result keys)
	Error       string         `db:"error"               json:"error,omitempty"`

	// ReadyAt / StartedAt are the queue-segment stamps (scheduler 工单⑫), captured IN MEMORY during
	// a drive and persisted on the row's single record-once INSERT — the row is still written once,
	// terminal/parked-only; there is never an insert-then-finalize. ReadyAt = when a walk turn first
	// computed this (node, iteration) ready (queue start); StartedAt = when the engine began
	// processing it (input CEL eval + dispatch — the execution entity's own start lives on its audit
	// row). Semantics under replay / recovery (legislated in database.md): a :replay re-run writes a
	// NEW row with fresh stamps at the same iteration (the failed row was physically cleared);
	// completed rows keep their original stamps (record-once — copied, never re-executed); after a
	// crash the in-memory stamps are gone, so a recovered re-run's ReadyAt is the RECOVERED drive's
	// walk time — recovery is a new queue start, never a pretend-seamless resume. Both nullable:
	// rows born before the columns, and seed trigger rows (never scheduled), stay NULL — the wire
	// omits them.
	//
	// ReadyAt / StartedAt 是排队段时间戳（scheduler 工单⑫）：驱动期间**内存**暂存、随该行唯一一次
	// record-once INSERT 落盘——行仍只写一次、只写终态/parked，绝无先插后终化。ReadyAt = 某轮 walk 首次
	// 算出该 (节点,轮次) ready 的时刻（排队起点）；StartedAt = 引擎开始处理它的时刻（input CEL 求值 +
	// 派发——执行实体自身的起点在其审计行）。replay/恢复语义（立法在 database.md）：:replay 重跑在同
	// iteration 写**新行新戳**（failed 行已物理清）；completed 行戳原样保留（record-once——抄、绝不重跑）；
	// 崩溃后内存戳即失，恢复重跑的 ReadyAt 是**恢复驱动**的 walk 时刻——恢复是新的排队起点、绝不伪装无缝。
	// 两列可空：列诞生前旧行与 seed trigger 行（从不排队）保持 NULL、线缆不发。
	ReadyAt   *time.Time `db:"ready_at"   json:"readyAt,omitempty"`
	StartedAt *time.Time `db:"started_at" json:"startedAt,omitempty"`

	CreatedAt   time.Time  `db:"created_at,created"  json:"createdAt"`             // terminal write / park time
	CompletedAt *time.Time `db:"completed_at"        json:"completedAt,omitempty"` // nil while parked
	UpdatedAt   time.Time  `db:"updated_at,updated"  json:"updatedAt"`
}

// Activity kinds — which execution-log family an ActivityRow came from (scheduler 工单⑤). The axis
// is the audit table, not the graph node kind: an `action` node fans into function/handler/mcp by
// its ref prefix, and only dispatched entity nodes leave audit rows (control/approval are
// inline-evaluated — their timing lives on the flowrun_nodes truth row alone).
//
// Activity kind——ActivityRow 来自哪张执行日志表（scheduler 工单⑤）。轴是审计表、非图节点 kind：
// `action` 节点按 ref 前缀散入 function/handler/mcp，且只有被派发的实体节点留审计行（control/approval
// 内联求值——其时序只在 flowrun_nodes 真相行上）。
const (
	ActivityKindFunction = "function"
	ActivityKindHandler  = "handler"
	ActivityKindAgent    = "agent"
	ActivityKindMCP      = "mcp"
)

// ActivityRow is one execution-log entry of a run, projected for the gantt/ledger view (scheduler
// 工单⑤): the UNION of the four execution-log tables filtered by flowrun_id, joined to the
// flowrun_nodes truth row for the queue stamp. StartedAt/EndedAt/ElapsedMs are the audit row's own
// (the execution segment); ReadyAt is the record-once truth row's queue start (工单⑫) — nullable
// (pre-⑫ rows / no matching truth row), and under at-least-once + :replay an OLD audit attempt can
// predate the surviving truth row's ReadyAt, so presenters clamp the queue segment at ≥ 0.
//
// ActivityRow 是一个 run 的一条执行日志行，为甘特/台账投影（scheduler 工单⑤）：四张执行日志表按
// flowrun_id 的 UNION，join flowrun_nodes 真相行取排队戳。StartedAt/EndedAt/ElapsedMs 是审计行自己的
// （执行段）；ReadyAt 是 record-once 真相行的排队起点（工单⑫）——可空（⑫ 前旧行 / 无对应真相行），且
// at-least-once + :replay 下**旧**审计尝试可早于存活真相行的 ReadyAt，呈现端把排队段钳制在 ≥ 0。
type ActivityRow struct {
	NodeID    string     `json:"nodeId"`
	Iteration int        `json:"iteration"`
	Kind      string     `json:"kind"`   // function | handler | agent | mcp (ActivityKind*)
	ExecID    string     `json:"execId"` // audit row id: fne_ | hcl_ | agx_ | mcl_
	Status    string     `json:"status"` // ok | failed | cancelled | timeout (the audit vocabulary)
	ReadyAt   *time.Time `json:"readyAt,omitempty"`
	StartedAt time.Time  `json:"startedAt"`
	EndedAt   time.Time  `json:"endedAt"`
	ElapsedMs int64      `json:"elapsedMs"`
}

var (
	// ErrNotFound: flowrun id miss (scoped to workspace).
	// ErrNotFound：flowrun id 未命中（按 workspace 隔离）。
	ErrNotFound = errorspkg.New(errorspkg.KindNotFound, "FLOWRUN_NOT_FOUND", "flowrun not found")

	// ErrNotReplayable: :replay called on a run that is not in a failed state (nothing to fix).
	// ErrNotReplayable：对非 failed 状态的 run 调 :replay（没坏东西可修）。
	ErrNotReplayable = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_NOT_REPLAYABLE", "flowrun is not in a replayable (failed) state")

	// ErrNotCancellable: :cancel called on a run that is not running — including the first-wins
	// loser whose cancel raced the run's natural terminal in the same instant (the recorded
	// terminal stands; the guarded UPDATE matched 0 rows).
	// ErrNotCancellable：对非 running 的 run 调 :cancel——含与 run 自然终态同瞬竞态的 first-wins
	// 输家（已记录的终态为准；守卫 UPDATE 匹配 0 行）。
	ErrNotCancellable = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_NOT_CANCELLABLE", "flowrun is not in a cancellable (running) state")

	// ErrNodeNotParked: an approval decision targeted a node that is not awaiting a signal (already
	// decided / timed out / never parked) — the first-wins loser, surfaced as a clean 422.
	// ErrNodeNotParked：审批决策指向一个不在等信号的节点（已决/已超时/从未 park）——first-wins 的输家，
	// 以干净 422 上呈。
	ErrNodeNotParked = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_APPROVAL_NOT_PARKED", "approval node is not awaiting a decision")

	// ErrInvalidEntry: a manual :trigger named an entry node that is missing or not a trigger, or
	// omitted entryNode for a graph with multiple trigger nodes (ambiguous). Details carry the reason.
	// ErrInvalidEntry：手动 :trigger 指定的 entry 节点缺失/非 trigger，或多 trigger 图未指定 entryNode
	// （歧义）。details 带原因。
	ErrInvalidEntry = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_INVALID_ENTRY", "invalid or ambiguous trigger entry node")

	// ErrInvalidDecision: an approval decision was neither "yes" nor "no".
	// ErrInvalidDecision：审批决策既非 "yes" 也非 "no"。
	ErrInvalidDecision = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_INVALID_DECISION", "approval decision must be 'yes' or 'no'")

	// ErrInvalidStatus: a list filter passed a status outside RunStatuses. Returned 422 with the allowed
	// set in Details so the caller (REST or the search_flowruns LLM tool) self-corrects, instead of
	// silently getting an empty page — an illegal status (e.g. "parked", a node status) matched zero rows,
	// reading as a false "no such runs exist" (F168-M2).
	//
	// ErrInvalidStatus：list 过滤传了 RunStatuses 外的状态。返 422、Details 带合法集，让调用方（REST 或
	// search_flowruns 工具）自纠，而非静默拿空页——非法状态（如 "parked"，那是节点状态）匹配 0 行、读作
	// 假「无此类 run」（F168-M2）。
	ErrInvalidStatus = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_INVALID_STATUS", "flowrun status filter must be one of: running, completed, failed, cancelled")

	// ErrInvalidListFilter: a list filter value outside its grammar — ?origin not in RunOrigins, or
	// ?startedAfter / ?startedBefore not RFC3339 (scheduler 工单⑥). Same loud-422 stance as
	// ErrInvalidStatus (F168-M2): Details carry the offending param + got (+ allowed for enums) so
	// the caller self-corrects instead of reading a silent empty page as "no such runs".
	//
	// ErrInvalidListFilter：list 过滤值出文法——?origin 不在 RunOrigins，或 ?startedAfter/?startedBefore
	// 非 RFC3339（scheduler 工单⑥）。与 ErrInvalidStatus 同一 422 大声拒立场（F168-M2）：Details 带
	// 出错参数 + 原值（枚举再带 allowed），让调用方自纠、而非把静默空页读作「无此类 run」。
	ErrInvalidListFilter = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_LIST_INVALID_FILTER", "invalid flowrun list filter value")
)
