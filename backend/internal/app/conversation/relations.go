package conversation

import (
	"context"

	"go.uber.org/zap"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// RelationSyncer is the subset of the relation Service conversation consumes (nil-tolerant).
// The relation app's *Service satisfies it directly — same signature — so wiring is a plain
// injection with no adapter.
//
// RelationSyncer 是 conversation 消费的 relation Service 子集（nil-tolerant）。relation app 的
// *Service 直接满足它——签名一致——故装配是纯注入、无需适配器。
type RelationSyncer interface {
	PurgeEntity(ctx context.Context, kind, id string) error
	SyncIncoming(ctx context.Context, toKind, toID string, kindScope []string, edges []relationdomain.SyncEdge) error
}

// syncForkEdge records a fork's lineage in the relation graph.
//
// The verb is the legislated `create` — "conversation created the entity (v1)" is literally what
// happened: the source thread produced this thread's first version. No 5th edge verb is minted for
// it (the 4-verb set is a CHECK-enforced closed vocabulary; the endpoints' from_kind/to_kind
// already say "conversation → conversation", so the pair is unambiguous without a new word), and
// the authoritative lineage lives in the forked_from_* columns regardless.
//
// Written from the FORK's INCOMING side on purpose. SyncIncoming replaces the whole edge set
// matching (fixed endpoint, kindScope), and a fork has exactly one parent forever — so replace-all
// is exact here and re-forking is idempotent. The mirror call keyed on the SOURCE's outgoing side
// would be a disaster: it would wipe every `create` edge to the functions/handlers/agents that
// conversation ever built.
//
// syncForkEdge 把分叉血缘记入关系图。
//
// 动词用已立法的 `create`——「conversation 创造实体（产生 v1）」正是实际发生的事：源线程产出了本
// 线程的第一版。**不**为它新铸第 5 个边动词（4 动词集是 CHECK 强制的封闭词汇；两端的
// from_kind/to_kind 已说明「conversation → conversation」，故无需新词即无歧义），况且权威血缘
// 本就在 forked_from_* 两列里。
//
// **刻意**从分叉的**入向**侧写。SyncIncoming 会替换匹配（固定端, kindScope）的整个边集，而一个
// 分叉永远只有一个父——故此处 replace-all 恰好精确、重复 fork 幂等。镜像地按**源**的出向侧写会是
// 灾难：它会抹掉该对话曾建过的所有 function/handler/agent 的 `create` 边。
func (s *Service) syncForkEdge(ctx context.Context, forkID, sourceID string) {
	if s.relations == nil {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   sourceID,
		Kind:      relationdomain.KindCreate,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindConversation, forkID,
		[]string{relationdomain.KindCreate}, edges); err != nil {
		s.log.Warn("conversation fork: sync lineage edge failed",
			zap.String("conversationId", forkID), zap.String("sourceId", sourceID), zap.Error(err))
	}
}

// purgeRelations cascade-removes every edge touching the deleted conversation.
//
// purgeRelations 级联清除触及被删对话的所有边。
func (s *Service) purgeRelations(ctx context.Context, convID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindConversation, convID); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("conversationId", convID), zap.Error(err))
	}
}

// TouchpointPurger is the subset of the touchpoint Service conversation consumes
// (nil-tolerant) — the context ledger's cascade twin of RelationSyncer.
//
// TouchpointPurger 是 conversation 消费的 touchpoint Service 子集(nil-tolerant)——
// 上下文台账的级联端口,与 RelationSyncer 同款。
type TouchpointPurger interface {
	PurgeConversation(ctx context.Context, conversationID string) error
}

// SetTouchpointPurger installs the ledger cascade post-construction (touchpoint does not
// depend on conversation; the setter mirrors SetRelationSyncer for wiring symmetry).
//
// SetTouchpointPurger 装配后注入台账级联(touchpoint 不依赖 conversation;setter 与
// SetRelationSyncer 同款、装配对称)。
func (s *Service) SetTouchpointPurger(p TouchpointPurger) { s.touchpoints = p }

// purgeTouchpoints cascade-removes the deleted conversation's context ledger.
//
// purgeTouchpoints 级联清除被删对话的上下文台账。
func (s *Service) purgeTouchpoints(ctx context.Context, convID string) {
	if s.touchpoints == nil {
		return
	}
	if err := s.touchpoints.PurgeConversation(ctx, convID); err != nil {
		s.log.Warn("touchpoint purge failed",
			zap.String("conversationId", convID), zap.Error(err))
	}
}

// NamesByIDs implements relation's Namer port for the conversation kind: id → display label
// (Title, else a Summary preview, else a placeholder). relation's read-time hydrate calls it to
// label conversation nodes/edges; a missing id simply gets no name (falls back to the raw id there).
//
// NamesByIDs 实现 relation 的 Namer 端口（conversation 类）：id → 显示标签（Title，否则 Summary
// 预览，否则占位）。relation 读时 hydrate 调它给 conversation 节点/边贴名；缺失 id 直接无名（那边
// 回退原始 id）。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetBatch(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, c := range rows {
		out[c.ID] = label(c)
	}
	return out, nil
}

// label derives a conversation's display name: Title, else a 30-rune Summary preview, else a
// placeholder — so an unnamed thread still shows something useful in the relation graph.
//
// label 推导对话的显示名：Title，否则 30 字 Summary 预览，否则占位——使未命名线程在 relation 图里
// 仍显示有用信息。
func label(c *conversationdomain.Conversation) string {
	if c.Title != "" {
		return c.Title
	}
	if c.Summary != "" {
		r := []rune(c.Summary)
		if len(r) > 30 {
			return string(r[:30]) + "…"
		}
		return c.Summary
	}
	return "(未命名对话)"
}
