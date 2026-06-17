// Package control (app layer) orchestrates the control-logic domain: building versions
// from a full branch set (no ops — branches are an atomic whole), compiling every
// branch's when/emit via pkg/cel at create/edit time, and the relation / catalog
// adapters. The version model is a linear, append-only history with a free-moving
// ActiveVersionID pointer — no pending/accept. Create/edit write a new version and take
// effect immediately; revert just moves the pointer. There is no run/executions: a
// control node is pure control flow evaluated by the durable interpreter, never
// an activity — the Service exposes Resolve so the interpreter reads the pinned version's
// branches.
//
// Package control（app 层）编排 control 逻辑 domain：从完整 branch 组构建版本（无 ops——branches
// 是整体）、create/edit 时用 pkg/cel 编译每个分支的 when/emit、relation / catalog 适配器。版本
// 模型线性、只增 + 可自由移动的 ActiveVersionID 指针——无 pending/accept。create/edit 写新版本并
// 立即生效；revert 只移指针。无 run/executions——control 节点是纯控制流，由 durable 解释器
// 求值、绝非 activity——Service 暴露 Resolve 供解释器读 pin 版本的 branches。
package control

import (
	"context"

	"go.uber.org/zap"

	controldomain "github.com/sunweilin/anselm/backend/internal/domain/control"
	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// RelationSyncer is the slice of relationapp.Service control consumes (nil-tolerant).
//
// RelationSyncer 是 control 消费的 relationapp.Service 切片（允许 nil）。
type RelationSyncer interface {
	SyncIncoming(ctx context.Context, toKind, toID string, kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// Service orchestrates the control-logic domain.
//
// Service 编排 control 逻辑 domain。
type Service struct {
	repo      controldomain.Repository
	search    searchdomain.Notifier      // nil → search indexing disabled. nil → 不接搜索索引。
	notif     notificationdomain.Emitter // nil-tolerant
	relations RelationSyncer             // nil disables relation hooks
	log       *zap.Logger
}

// NewService wires the service; nil repo / log is a wiring bug (log defaults to nop).
//
// NewService 装配 service；nil repo / log 是装配 bug（log 默认 nop）。
func NewService(repo controldomain.Repository, notif notificationdomain.Emitter, log *zap.Logger) *Service {
	if repo == nil {
		panic("controlapp.NewService: repo is nil")
	}
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{repo: repo, notif: notif, log: log}
}

// SetRelationSyncer installs the relation Service post-construction (avoids an init cycle).
//
// SetRelationSyncer 装配后注入 relation Service（避 init 环）。
func (s *Service) SetRelationSyncer(r RelationSyncer) { s.relations = r }

// publish emits a control lifecycle notification; nil emitter is a no-op.
//
// publish 发一条 control 生命周期通知；nil emitter 为 no-op。
func (s *Service) publish(ctx context.Context, action, controlID string, extra map[string]any) {
	s.notifySearch(ctx, controlID)
	if s.notif == nil {
		return
	}
	payload := map[string]any{"controlId": controlID}
	for k, v := range extra {
		payload[k] = v
	}
	if err := s.notif.Emit(ctx, "control."+action, payload); err != nil {
		s.log.Warn("controlapp.publish: emit failed", zap.String("action", action), zap.Error(err))
	}
}
