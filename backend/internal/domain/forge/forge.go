// Package forge defines the trinity-forging SSE protocol: 4 closed event
// types (forge_started / forge_op_applied / forge_env_attempt /
// forge_completed) that stream per-entity forging progress (function /
// handler / workflow) to subscribers who care about an entity's lifecycle
// without subscribing to the full chat eventlog.
//
// Bridge keys by user_id (same pattern as eventlog + notifications post
// D-redo-2/3). Payload reuses eventlogdomain.Scope ({kind, id}) — kind is
// restricted here to function / handler / workflow (the 3 forge-able
// trinity entities; conversation / flowrun are eventlog scopes, not forge).
//
// See:
//   - documents/version-1.2/service-contract-documents/events-design.md §12
//   - documents/version-1.2/adhoc-topic-documents/forge_redesign/discussions/2026-05-12-env-and-sse-rework.md §B + §I.4
//
// Package forge 定义 trinity 锻造 SSE 协议:4 个封闭事件类型流式 entity 级
// 锻造进度(function/handler/workflow)。Bridge per-user(D-redo-2/3 模式);
// payload 复用 eventlogdomain.Scope,kind 限 3 个 forge-able trinity 实体。
package forge

import (
	"errors"
	"fmt"

	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
)

// Operation is the high-level lifecycle action. Closed enumeration —
// adding a value requires updating the protocol doc + frontend renderer
// in the same PR.
//
// Operation 是高层生命周期动作。封闭枚举;新增需先改协议文档。
const (
	OperationCreate = "create"
	OperationEdit   = "edit"
	OperationRevert = "revert"
	OperationDelete = "delete"
)

// IsValidOperation reports whether op is in the forge whitelist.
//
// IsValidOperation 报告 op 是否在 forge 白名单内。
func IsValidOperation(op string) bool {
	switch op {
	case OperationCreate, OperationEdit, OperationRevert, OperationDelete:
		return true
	}
	return false
}

// IsValidScopeKind reports whether kind is a forge-able trinity entity.
// Distinct from eventlogdomain.IsValidKind which also accepts conversation
// + flowrun (eventlog scopes, not forge).
//
// IsValidScopeKind 报告 kind 是否 forge-able(function/handler/workflow);
// 比 eventlogdomain.IsValidKind 严(后者还含 conversation/flowrun)。
func IsValidScopeKind(kind string) bool {
	switch kind {
	case eventlogdomain.KindFunction, eventlogdomain.KindHandler, eventlogdomain.KindWorkflow:
		return true
	}
	return false
}

// EnvAttemptStatus enumerates the per-attempt outcomes inside a forge_env_attempt
// event. Closed enumeration.
//
// EnvAttemptStatus 列举 forge_env_attempt 事件单次 attempt 的结果。封闭。
const (
	EnvAttemptInstalling = "installing"
	EnvAttemptFixing     = "fixing"
	EnvAttemptOK         = "ok"
	EnvAttemptFailed     = "failed"
)

// CompletedStatus enumerates the terminal status of a forge_completed event.
//
// CompletedStatus 列举 forge_completed 终态。
const (
	CompletedOK        = "ok"
	CompletedFailed    = "failed"
	CompletedCancelled = "cancelled"
)

// Event is the protocol unit. Concrete types (4) are ForgeStarted /
// ForgeOpApplied / ForgeEnvAttempt / ForgeCompleted. Adding a new type
// requires updating the protocol doc first.
//
// Event 是协议单位。4 个封闭具体类型;新增先改协议文档。
type Event interface {
	EventType() string
}

// Envelope wraps an Event with its bridge-assigned sequence number.
//
// Envelope 给 Event 套上 bridge 分配的 seq。
type Envelope struct {
	Seq   int64
	Event Event
}

// ── Event payload structs ─────────────────────────────────────────────

// ForgeStarted is emitted at the beginning of a forge operation. Pairs
// 1:1 with a terminal ForgeCompleted.
//
// ForgeStarted 锻造操作开头发;跟 ForgeCompleted 1:1 配对。
type ForgeStarted struct {
	Scope          eventlogdomain.Scope `json:"scope"`
	Operation      string               `json:"operation"`
	ConversationID string               `json:"conversationId,omitempty"`
	ToolCallID     string               `json:"toolCallId,omitempty"`
}

func (ForgeStarted) EventType() string { return "forge_started" }

// ForgeOpApplied is emitted after each ops engine op succeeds (index 0-N).
// NOTE: not currently emitted by the C4 implementation — the Service
// layer's ApplyOps does not yet expose a per-op callback to the tool
// layer. The event type is declared so future versions can fill it in
// without a protocol break.
//
// ForgeOpApplied 单 op 应用完成后发(index 0-N)。注:C4 版本暂未实现
// (Service.ApplyOps 还没暴露 per-op 回调给 tool 层);先定义类型,未来填
// 实现不破坏协议。
type ForgeOpApplied struct {
	Scope eventlogdomain.Scope `json:"scope"`
	Index int                  `json:"index"`
	Op    string               `json:"op"`
}

func (ForgeOpApplied) EventType() string { return "forge_op_applied" }

// ForgeEnvAttempt is emitted per env install attempt — initial install
// (attempt=1) + each LLM-suggested retry. status / stage / detail / error
// describe the current state of that attempt.
//
// ForgeEnvAttempt 每次装环境尝试发(初次 + LLM 修建议的重试)。
// status / stage / detail / error 描述当次状态。
type ForgeEnvAttempt struct {
	Scope    eventlogdomain.Scope `json:"scope"`
	Attempt  int                  `json:"attempt"`
	Status   string               `json:"status"` // installing / fixing / ok / failed
	Stage    string               `json:"stage,omitempty"`
	Detail   string               `json:"detail,omitempty"`
	Error    string               `json:"error,omitempty"`
}

func (ForgeEnvAttempt) EventType() string { return "forge_env_attempt" }

// ForgeCompleted is emitted at the end of a forge operation. Pairs 1:1
// with the opening ForgeStarted.
//
// ForgeCompleted 锻造结束发;跟 ForgeStarted 1:1 配对。
type ForgeCompleted struct {
	Scope        eventlogdomain.Scope `json:"scope"`
	Status       string               `json:"status"` // ok / failed / cancelled
	VersionID    string               `json:"versionId,omitempty"`
	EnvStatus    string               `json:"envStatus,omitempty"`
	AttemptsUsed int                  `json:"attemptsUsed,omitempty"`
	Error        string               `json:"error,omitempty"`
}

func (ForgeCompleted) EventType() string { return "forge_completed" }

// ── Errors ────────────────────────────────────────────────────────────

// ErrInvalidEvent is returned for malformed events (bad Scope, unknown
// Operation, etc.). Producer bug.
//
// ErrInvalidEvent 形状错误事件(Scope 非法、Operation 不识别等)。Producer bug。
var ErrInvalidEvent = errors.New("forge: invalid event")

// ErrSeqTooOld is returned by Bridge.Subscribe when fromSeq has been
// evicted from the replay buffer.
//
// ErrSeqTooOld Bridge.Subscribe 在 fromSeq 已被 replay buffer 淘汰时返。
var ErrSeqTooOld = errors.New("forge: requested seq too old (evicted from replay buffer)")

// ValidateEvent runs minimal shape checks on a forge event. Bridge
// implementations call this in Publish so producer bugs surface at the
// producer boundary.
//
// ValidateEvent 跑最小形状检查;Bridge 在 Publish 中调,让 producer bug 在
// 边界暴露。
func ValidateEvent(e Event) error {
	switch v := e.(type) {
	case ForgeStarted:
		if err := validateScope(v.Scope); err != nil {
			return err
		}
		if !IsValidOperation(v.Operation) {
			return fmt.Errorf("%w: forge_started: unknown operation %q", ErrInvalidEvent, v.Operation)
		}
	case ForgeOpApplied:
		if err := validateScope(v.Scope); err != nil {
			return err
		}
		if v.Op == "" {
			return fmt.Errorf("%w: forge_op_applied: empty op name", ErrInvalidEvent)
		}
	case ForgeEnvAttempt:
		if err := validateScope(v.Scope); err != nil {
			return err
		}
		if v.Attempt <= 0 {
			return fmt.Errorf("%w: forge_env_attempt: attempt must be >= 1, got %d", ErrInvalidEvent, v.Attempt)
		}
		if !isValidEnvAttemptStatus(v.Status) {
			return fmt.Errorf("%w: forge_env_attempt: unknown status %q", ErrInvalidEvent, v.Status)
		}
	case ForgeCompleted:
		if err := validateScope(v.Scope); err != nil {
			return err
		}
		if !isValidCompletedStatus(v.Status) {
			return fmt.Errorf("%w: forge_completed: unknown status %q", ErrInvalidEvent, v.Status)
		}
	default:
		return fmt.Errorf("%w: unknown event type %T", ErrInvalidEvent, e)
	}
	return nil
}

func validateScope(s eventlogdomain.Scope) error {
	if !IsValidScopeKind(s.Kind) {
		return fmt.Errorf("%w: scope.kind %q is not forge-able (must be function/handler/workflow)",
			ErrInvalidEvent, s.Kind)
	}
	if s.ID == "" {
		return fmt.Errorf("%w: scope.id is empty", ErrInvalidEvent)
	}
	return nil
}

func isValidEnvAttemptStatus(s string) bool {
	switch s {
	case EnvAttemptInstalling, EnvAttemptFixing, EnvAttemptOK, EnvAttemptFailed:
		return true
	}
	return false
}

func isValidCompletedStatus(s string) bool {
	switch s {
	case CompletedOK, CompletedFailed, CompletedCancelled:
		return true
	}
	return false
}
