package skill

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/foryx/backend/internal/domain/relation"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

// RelationSyncer is the slice of the relation Service that skill consumes (nil-tolerant).
// skill produces BOTH outgoing equip edges (its allowed-tools → function/handler) and an
// incoming create edge (the conversation that authored it), so it needs both directions.
//
// RelationSyncer 是 skill 消费的 relation Service 切片（nil-tolerant）。skill 既产出边
// （allowed-tools → function/handler 的 equip）又有入边（创作它的 conversation 的 create），
// 故两个方向都要。
type RelationSyncer interface {
	SyncOutgoing(ctx context.Context, fromKind, fromID string, kindScope []string, edges []relationdomain.SyncEdge) error
	SyncIncoming(ctx context.Context, toKind, toID string, kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// SetRelationSyncer installs the relation Service post-construction (avoids an init cycle).
//
// SetRelationSyncer 装配后注入 relation Service（避 init 环）。
func (s *Service) SetRelationSyncer(r RelationSyncer) { s.relations = r }

// NamesByIDs implements the relation Namer port: a file-based skill's id IS its name, so the
// display name maps to itself (no DB lookup needed).
//
// NamesByIDs 实现 relation 的 Namer 端口：文件式 skill 的 id 即 name，故显示名映射到自身
// （无需查库）。
func (s *Service) NamesByIDs(_ context.Context, ids []string) (map[string]string, error) {
	out := make(map[string]string, len(ids))
	for _, id := range ids {
		out[id] = id
	}
	return out, nil
}

// syncEquipEdges replaces skill→(function/handler) equip edges parsed from allowed-tools.
// Built-in tool names (Read, Bash(...)) have no entity prefix → KindForID returns "" → skipped.
// (mcp:<name>/<tool> refs are skipped too — KindForID matches the <prefix>_<hex> id scheme, not
// the colon form mcp tools are referenced by.)
//
// syncEquipEdges 用从 allowed-tools 解析出的 skill→(function/handler) equip 边整组替换。
// 内置工具名（Read、Bash(...)）无实体前缀 → KindForID 返 "" → 跳过。（mcp:<name>/<tool> 引用
// 也跳过——KindForID 匹配 <前缀>_<hex> id 方案，不认 mcp 工具引用的冒号形式。）
func (s *Service) syncEquipEdges(ctx context.Context, name string, allowedTools []string) {
	if s.relations == nil {
		return
	}
	var edges []relationdomain.SyncEdge
	for _, ref := range allowedTools {
		kind, ok := relationdomain.KindForID(ref)
		if !ok {
			continue
		}
		edges = append(edges, relationdomain.SyncEdge{
			OtherKind: kind,
			OtherID:   ref,
			Kind:      relationdomain.KindEquip,
		})
	}
	if err := s.relations.SyncOutgoing(ctx, relationdomain.EntityKindSkill, name,
		[]string{relationdomain.KindEquip}, edges); err != nil {
		s.log.Warn("skillapp: sync equip edges failed", zap.String("skill", name), zap.Error(err))
	}
}

// syncBuiltEdge records the conversation→skill create edge when a skill is authored in a chat.
//
// syncBuiltEdge 在 skill 于对话中被创作时记 conversation→skill 的 create 边。
func (s *Service) syncBuiltEdge(ctx context.Context, name string) {
	if s.relations == nil {
		return
	}
	convID, ok := reqctxpkg.GetConversationID(ctx)
	if !ok || convID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   convID,
		Kind:      relationdomain.KindCreate,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindSkill, name,
		[]string{relationdomain.KindCreate}, edges); err != nil {
		s.log.Warn("skillapp: sync build edge failed", zap.String("skill", name), zap.Error(err))
	}
}

// purgeRelations removes every edge touching this skill on delete.
//
// purgeRelations 在删除时移除触及该 skill 的所有边。
func (s *Service) purgeRelations(ctx context.Context, name string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindSkill, name); err != nil {
		s.log.Warn("skillapp: purge relations failed", zap.String("skill", name), zap.Error(err))
	}
}
