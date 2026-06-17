package trigger

import (
	"context"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// RelationSyncer is the subset of the relation Service that trigger consumes (nil-tolerant).
// The relation app's *Service satisfies it directly (same signatures) — plain injection.
//
// RelationSyncer 是 trigger 消费的 relation Service 子集（nil-tolerant）。relation app 的 *Service
// 直接满足（签名一致）——纯注入。
type RelationSyncer interface {
	SyncOutgoing(ctx context.Context, fromKind, fromID string, kindScope []string, edges []relationdomain.SyncEdge) error
	SyncIncoming(ctx context.Context, toKind, toID string, kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// NamesByIDs implements relationapp.Namer: batch id→name for trigger nodes in the graph.
//
// NamesByIDs 实现 relationapp.Namer：批量 id→name，供图中 trigger 节点 hydrate 名字。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetTriggersByIDs(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, t := range rows {
		out[t.ID] = t.Name
	}
	return out, nil
}

// syncSensorBinding re-syncs the trigger's outgoing `equip` edge to the function/handler a
// sensor probes. A non-sensor trigger (or a sensor with no target) syncs an empty set, which
// clears any prior binding. Recomputed on create / edit.
//
// syncSensorBinding 重 sync trigger 指向其 sensor 探测的 function/handler 的出向 `equip` 边。非 sensor
// （或无目标的 sensor）sync 空集，清除旧绑定。create/edit 后重算。
func (s *Service) syncSensorBinding(ctx context.Context, t *triggerdomain.Trigger) {
	if s.relations == nil {
		return
	}
	var edges []relationdomain.SyncEdge
	if t.Kind == triggerdomain.KindSensor {
		sc := triggerdomain.ParseSensorConfig(t.Config)
		if sc.TargetID != "" {
			otherKind := relationdomain.EntityKindFunction
			switch sc.TargetKind {
			case triggerdomain.SensorTargetHandler:
				otherKind = relationdomain.EntityKindHandler
			case triggerdomain.SensorTargetMCP:
				otherKind = relationdomain.EntityKindMCP
			}
			edges = append(edges, relationdomain.SyncEdge{
				OtherKind: otherKind,
				OtherID:   sc.TargetID,
				Kind:      relationdomain.KindEquip,
			})
		}
	}
	if err := s.relations.SyncOutgoing(ctx, relationdomain.EntityKindTrigger, t.ID,
		[]string{relationdomain.KindEquip}, edges); err != nil {
		s.log.Warn("triggerapp: sync sensor binding failed", zapTrigger(t.ID), zapErr(err))
	}
}

// syncBuiltEdge records the "create" edge from the originating conversation (if the trigger
// was built in one). No conversation in ctx → clears the edge (UI-created trigger).
//
// syncBuiltEdge 记录来自构建对话的 "create" 边（若 trigger 在对话中创建）。ctx 无对话 → 清边（UI 创建）。
func (s *Service) syncBuiltEdge(ctx context.Context, triggerID string) {
	if s.relations == nil {
		return
	}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	var edges []relationdomain.SyncEdge
	if convID != "" {
		edges = append(edges, relationdomain.SyncEdge{
			OtherKind: relationdomain.EntityKindConversation,
			OtherID:   convID,
			Kind:      relationdomain.KindCreate,
		})
	}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindTrigger, triggerID,
		[]string{relationdomain.KindCreate}, edges); err != nil {
		s.log.Warn("triggerapp: sync built edge failed", zapTrigger(triggerID), zapErr(err))
	}
}

// purgeRelations hard-deletes every edge touching the trigger (called on Delete).
//
// purgeRelations 硬删触及该 trigger 的所有边（Delete 时调）。
func (s *Service) purgeRelations(ctx context.Context, triggerID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindTrigger, triggerID); err != nil {
		s.log.Warn("triggerapp: purge relations failed", zapTrigger(triggerID), zapErr(err))
	}
}
