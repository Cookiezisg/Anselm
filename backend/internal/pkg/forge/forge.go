// Package forge provides the producer-side helper around the forge
// Bridge: a Publisher with one method per event type so LLM tool code
// calls high-level intent ("PublishStarted", "PublishCompleted") without
// constructing event structs by hand. Mirrors pkg/notifications.Publisher
// in spirit; the difference is forge events are typed (closed schema)
// vs notifications' open-vocabulary string types.
//
// Service code holds the Publisher as a struct field (constructor-
// injected); bridge=nil falls back to a noop Publisher so tests / unwired
// services stay safe.
//
// Package forge 提供 forge Bridge 的 producer 侧 helper:Publisher 暴露每
// event type 一个高层方法,LLM tool 代码按意图调("PublishStarted"等)无须
// 手构 event struct。镜像 pkg/notifications.Publisher;区别 forge 事件类型
// 固定(封闭 schema),notifications 是开放词表 string type。
package forge

import (
	"context"

	"go.uber.org/zap"

	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
)

// Publisher is the high-level API for emitting forge events. Methods
// build the corresponding forgedomain event struct and call
// Bridge.Publish. Failures log + best-effort (forge events are
// observability — losing one shouldn't fail the underlying create/edit).
//
// Publisher 是 forge 事件的高层 API。每方法构 forgedomain event struct +
// 调 Bridge.Publish。失败 log + best-effort(forge 事件是可观测性,丢一条
// 不影响底层 create/edit)。
type Publisher interface {
	// PublishStarted emits forge_started at the beginning of a forge
	// operation. convID + toolCallID can be "" for HTTP-driven (non-chat)
	// forging.
	//
	// PublishStarted 锻造起点发 forge_started。convID/toolCallID 可空
	// (HTTP 直触发非 chat 锻造)。
	PublishStarted(ctx context.Context, scope eventlogdomain.Scope, operation, convID, toolCallID string)

	// PublishOpApplied emits forge_op_applied after each successful op.
	// Currently unused (Service.ApplyOps doesn't expose per-op callbacks
	// yet); declared for future use.
	//
	// PublishOpApplied 单 op 成功后发。当前未用(Service.ApplyOps 还没
	// 暴露 per-op 回调);先定义给未来用。
	PublishOpApplied(ctx context.Context, scope eventlogdomain.Scope, index int, op string)

	// PublishEnvAttempt emits forge_env_attempt for each install attempt.
	// status ∈ {installing, fixing, ok, failed}; stage / detail / err are
	// optional context.
	//
	// PublishEnvAttempt 每次装尝试发。status 4 值;stage/detail/err 可选。
	PublishEnvAttempt(ctx context.Context, scope eventlogdomain.Scope, attempt int, status, stage, detail string, err error)

	// PublishCompleted emits forge_completed at the terminal of a forge
	// operation. Pairs 1:1 with PublishStarted.
	//
	// PublishCompleted 锻造终态发,跟 PublishStarted 1:1 配。
	PublishCompleted(ctx context.Context, scope eventlogdomain.Scope, status, versionID, envStatus string, attemptsUsed int, err error)
}

// New constructs a Publisher backed by bridge. log may be nil (zap.Nop).
// bridge nil → returns a noop Publisher (so service / tool constructors
// can safely fall back without nil-checking).
//
// New 构造由 bridge 支撑的 Publisher。log 可 nil。bridge nil 返 noop。
func New(bridge forgedomain.Bridge, log *zap.Logger) Publisher {
	if bridge == nil {
		return noopPublisher{}
	}
	if log == nil {
		log = zap.NewNop()
	}
	return &publisher{bridge: bridge, log: log.Named("forge.publisher")}
}

type publisher struct {
	bridge forgedomain.Bridge
	log    *zap.Logger
}

func (p *publisher) PublishStarted(ctx context.Context, scope eventlogdomain.Scope, operation, convID, toolCallID string) {
	p.emit(ctx, forgedomain.ForgeStarted{
		Scope:          scope,
		Operation:      operation,
		ConversationID: convID,
		ToolCallID:     toolCallID,
	})
}

func (p *publisher) PublishOpApplied(ctx context.Context, scope eventlogdomain.Scope, index int, op string) {
	p.emit(ctx, forgedomain.ForgeOpApplied{
		Scope: scope, Index: index, Op: op,
	})
}

func (p *publisher) PublishEnvAttempt(ctx context.Context, scope eventlogdomain.Scope, attempt int, status, stage, detail string, err error) {
	errStr := ""
	if err != nil {
		errStr = err.Error()
	}
	p.emit(ctx, forgedomain.ForgeEnvAttempt{
		Scope: scope, Attempt: attempt, Status: status, Stage: stage, Detail: detail, Error: errStr,
	})
}

func (p *publisher) PublishCompleted(ctx context.Context, scope eventlogdomain.Scope, status, versionID, envStatus string, attemptsUsed int, err error) {
	errStr := ""
	if err != nil {
		errStr = err.Error()
	}
	p.emit(ctx, forgedomain.ForgeCompleted{
		Scope: scope, Status: status, VersionID: versionID, EnvStatus: envStatus,
		AttemptsUsed: attemptsUsed, Error: errStr,
	})
}

func (p *publisher) emit(ctx context.Context, e forgedomain.Event) {
	if _, err := p.bridge.Publish(ctx, e); err != nil {
		p.log.Warn("forge publish failed",
			zap.String("type", e.EventType()),
			zap.Error(err))
	}
}

// ── no-op fallback ───────────────────────────────────────────────────

type noopPublisher struct{}

func (noopPublisher) PublishStarted(context.Context, eventlogdomain.Scope, string, string, string) {
}
func (noopPublisher) PublishOpApplied(context.Context, eventlogdomain.Scope, int, string) {}
func (noopPublisher) PublishEnvAttempt(context.Context, eventlogdomain.Scope, int, string, string, string, error) {
}
func (noopPublisher) PublishCompleted(context.Context, eventlogdomain.Scope, string, string, string, int, error) {
}
