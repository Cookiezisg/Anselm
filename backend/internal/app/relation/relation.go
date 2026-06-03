// Package relation (app layer) implements relationdomain.Service:
// diff-sync edge writes, cascade purge, neighborhood BFS, and full relgraph snapshot.
//
// Package relation (app 层) 实现 relationdomain.Service：
// diff-sync 边写入、级联 purge、邻域 BFS、完整 relgraph 快照。
package relation

import (
	"context"
	"fmt"
	"reflect"
	"sort"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// EntityMeta alias for backward-compat readability (defined in relationdomain).
type EntityMeta = relationdomain.EntityMeta

// Per-domain reader ports (read-only contracts relation Service consumes).
// Each domain provides a thin adapter implementing one of these. nil-tolerant:
// a nil reader contributes zero nodes for that kind in GetRelgraph.
//
// 各 domain 的 reader port（relation Service 消费的只读契约）。
// 每个 domain 提供薄适配器实现其中之一。允许 nil：reader=nil 时该 kind 在 GetRelgraph 中贡献 0 节点。

type FunctionReader interface {
	ListAllMeta(ctx context.Context, userID string) ([]relationdomain.EntityMeta, error)
}

type HandlerReader interface {
	ListAllMeta(ctx context.Context, userID string) ([]relationdomain.EntityMeta, error)
}

type WorkflowReader interface {
	ListAllMeta(ctx context.Context, userID string) ([]relationdomain.EntityMeta, error)
}

type DocumentReader interface {
	ListAllMeta(ctx context.Context, userID string) ([]relationdomain.EntityMeta, error)
}

type SkillReader interface {
	ListAllMeta(ctx context.Context, userID string) ([]relationdomain.EntityMeta, error)
}

type McpReader interface {
	ListAllMeta(ctx context.Context, userID string) ([]relationdomain.EntityMeta, error)
}

type AgentReader interface {
	ListAllMeta(ctx context.Context, userID string) ([]relationdomain.EntityMeta, error)
}

type ConversationReader interface {
	GetMetaBatch(ctx context.Context, userID string, ids []string) ([]relationdomain.EntityMeta, error)
}

// Service orchestrates relation CRUD and aggregated reads.
//
// Service 编排 relation CRUD 与聚合读。
type Service struct {
	repo               relationdomain.Repository
	functionReader     FunctionReader
	handlerReader      HandlerReader
	workflowReader     WorkflowReader
	documentReader     DocumentReader
	skillReader        SkillReader
	mcpReader          McpReader
	agentReader        AgentReader
	conversationReader ConversationReader
	log                *zap.Logger
}

// Config bundles all dependencies; reader fields may be nil (no contribution to relgraph).
//
// Config 打包所有依赖；reader 字段可 nil（对 relgraph 无贡献）。
type Config struct {
	Repo               relationdomain.Repository
	FunctionReader     FunctionReader
	HandlerReader      HandlerReader
	WorkflowReader     WorkflowReader
	DocumentReader     DocumentReader
	SkillReader        SkillReader
	McpReader          McpReader
	AgentReader        AgentReader
	ConversationReader ConversationReader
	Log                *zap.Logger
}

// NewService wires Service; Repo + Log required, readers optional.
//
// NewService 装配 Service；Repo + Log 必填，readers 可选。
func NewService(cfg Config) *Service {
	if cfg.Repo == nil {
		panic("relationapp.NewService: Repo is nil")
	}
	if cfg.Log == nil {
		panic("relationapp.NewService: Log is nil")
	}
	return &Service{
		repo:               cfg.Repo,
		functionReader:     cfg.FunctionReader,
		handlerReader:      cfg.HandlerReader,
		workflowReader:     cfg.WorkflowReader,
		documentReader:     cfg.DocumentReader,
		skillReader:        cfg.SkillReader,
		mcpReader:          cfg.McpReader,
		agentReader:        cfg.AgentReader,
		conversationReader: cfg.ConversationReader,
		log:                cfg.Log,
	}
}

// SyncOutgoing — see relationdomain.Service.
func (s *Service) SyncOutgoing(ctx context.Context, fromKind, fromID string,
	kindScope []string, edges []relationdomain.SyncEdge) error {

	if err := validateEntityRef(fromKind, fromID); err != nil {
		return fmt.Errorf("relationapp.SyncOutgoing: %w", err)
	}
	if err := validateKindScope(kindScope); err != nil {
		return fmt.Errorf("relationapp.SyncOutgoing: %w", err)
	}
	for _, e := range edges {
		if err := validateEntityRef(e.OtherKind, e.OtherID); err != nil {
			return fmt.Errorf("relationapp.SyncOutgoing: edge: %w", err)
		}
		if !relationdomain.IsValidKind(e.Kind) {
			return fmt.Errorf("relationapp.SyncOutgoing: %w", relationdomain.ErrInvalidKind)
		}
		if fromKind == e.OtherKind && fromID == e.OtherID {
			return fmt.Errorf("relationapp.SyncOutgoing: %w", relationdomain.ErrSelfLoop)
		}
	}

	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("relationapp.SyncOutgoing: %w", err)
	}

	existing, err := s.repo.ListByFromAndKinds(ctx, userID, fromKind, fromID, kindScope)
	if err != nil {
		return fmt.Errorf("relationapp.SyncOutgoing: %w", err)
	}
	return s.diffSync(ctx, userID, existing, edges, fromKind, fromID, /*direction=outgoing*/ true)
}

// SyncIncoming — see relationdomain.Service.
func (s *Service) SyncIncoming(ctx context.Context, toKind, toID string,
	kindScope []string, edges []relationdomain.SyncEdge) error {

	if err := validateEntityRef(toKind, toID); err != nil {
		return fmt.Errorf("relationapp.SyncIncoming: %w", err)
	}
	if err := validateKindScope(kindScope); err != nil {
		return fmt.Errorf("relationapp.SyncIncoming: %w", err)
	}
	for _, e := range edges {
		if err := validateEntityRef(e.OtherKind, e.OtherID); err != nil {
			return fmt.Errorf("relationapp.SyncIncoming: edge: %w", err)
		}
		if !relationdomain.IsValidKind(e.Kind) {
			return fmt.Errorf("relationapp.SyncIncoming: %w", relationdomain.ErrInvalidKind)
		}
		if toKind == e.OtherKind && toID == e.OtherID {
			return fmt.Errorf("relationapp.SyncIncoming: %w", relationdomain.ErrSelfLoop)
		}
	}

	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("relationapp.SyncIncoming: %w", err)
	}

	existing, err := s.repo.ListByToAndKinds(ctx, userID, toKind, toID, kindScope)
	if err != nil {
		return fmt.Errorf("relationapp.SyncIncoming: %w", err)
	}
	return s.diffSync(ctx, userID, existing, edges, toKind, toID, /*direction=outgoing*/ false)
}

// diffSync is the shared diff-and-apply core for SyncOutgoing/SyncIncoming.
// When outgoing=true, fixedKind/fixedID becomes the FROM side and OtherKind/OtherID is TO;
// when outgoing=false (incoming), fixedKind/fixedID becomes TO and OtherKind/OtherID is FROM.
//
// diffSync 是 SyncOutgoing/SyncIncoming 共享的 diff-and-apply 内核。
// outgoing=true 时 fixed 作 FROM 端，Other 作 TO；outgoing=false 时反之。
func (s *Service) diffSync(ctx context.Context, userID string,
	existing []*relationdomain.Relation, want []relationdomain.SyncEdge,
	fixedKind, fixedID string, outgoing bool) error {

	type edgeKey struct{ k1, i1, kind string }

	keyOf := func(other1Kind, other1ID, kind string) edgeKey {
		return edgeKey{other1Kind, other1ID, kind}
	}

	existingByKey := map[edgeKey]*relationdomain.Relation{}
	for _, r := range existing {
		var k edgeKey
		if outgoing {
			k = keyOf(r.ToKind, r.ToID, r.Kind)
		} else {
			k = keyOf(r.FromKind, r.FromID, r.Kind)
		}
		existingByKey[k] = r
	}

	wantByKey := map[edgeKey]relationdomain.SyncEdge{}
	for _, e := range want {
		k := keyOf(e.OtherKind, e.OtherID, e.Kind)
		wantByKey[k] = e
	}

	var (
		toInsert    []*relationdomain.Relation
		toUpdateID  []string
		toUpdateMap []map[string]any
		toDeleteIDs []string
	)

	for k, e := range wantByKey {
		if r, found := existingByKey[k]; found {
			if !attrsEqual(r.Attrs, e.Attrs) {
				toUpdateID = append(toUpdateID, r.ID)
				toUpdateMap = append(toUpdateMap, e.Attrs)
			}
			continue
		}
		// new edge to insert
		newRel := &relationdomain.Relation{
			ID:     newID(),
			UserID: userID,
			Kind:   e.Kind,
			Attrs:  e.Attrs,
		}
		if outgoing {
			newRel.FromKind, newRel.FromID = fixedKind, fixedID
			newRel.ToKind, newRel.ToID = e.OtherKind, e.OtherID
		} else {
			newRel.FromKind, newRel.FromID = e.OtherKind, e.OtherID
			newRel.ToKind, newRel.ToID = fixedKind, fixedID
		}
		toInsert = append(toInsert, newRel)
	}

	for k, r := range existingByKey {
		if _, keep := wantByKey[k]; !keep {
			toDeleteIDs = append(toDeleteIDs, r.ID)
		}
	}

	if len(toInsert) > 0 {
		if err := s.repo.InsertBatch(ctx, toInsert); err != nil {
			return fmt.Errorf("diffSync.InsertBatch: %w", err)
		}
	}
	for i, id := range toUpdateID {
		if err := s.repo.UpdateAttrs(ctx, id, toUpdateMap[i]); err != nil {
			return fmt.Errorf("diffSync.UpdateAttrs: %w", err)
		}
	}
	if len(toDeleteIDs) > 0 {
		if err := s.repo.DeleteByIDs(ctx, toDeleteIDs); err != nil {
			return fmt.Errorf("diffSync.DeleteByIDs: %w", err)
		}
	}
	return nil
}

// PurgeEntity — see relationdomain.Service.
func (s *Service) PurgeEntity(ctx context.Context, kind, id string) error {
	if err := validateEntityRef(kind, id); err != nil {
		return fmt.Errorf("relationapp.PurgeEntity: %w", err)
	}
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("relationapp.PurgeEntity: %w", err)
	}
	n, err := s.repo.PurgeEntity(ctx, userID, kind, id)
	if err != nil {
		return fmt.Errorf("relationapp.PurgeEntity: %w", err)
	}
	if n > 0 {
		s.log.Info("relation purge",
			zap.String("kind", kind),
			zap.String("id", id),
			zap.Int64("removed", n))
	}
	return nil
}

// List — see relationdomain.Service.
func (s *Service) List(ctx context.Context, filter relationdomain.Filter,
	cursor string, limit int) ([]*relationdomain.Relation, string, bool, error) {

	if err := validateFilter(filter); err != nil {
		return nil, "", false, fmt.Errorf("relationapp.List: %w", err)
	}
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, "", false, fmt.Errorf("relationapp.List: %w", err)
	}
	return s.repo.List(ctx, userID, filter, cursor, limit)
}

// Neighborhood — see relationdomain.Service. BFS with from↔to direction alternation.
func (s *Service) Neighborhood(ctx context.Context, kind, id string, depth int) ([]*relationdomain.Relation, error) {
	if err := validateEntityRef(kind, id); err != nil {
		return nil, fmt.Errorf("relationapp.Neighborhood: %w", err)
	}
	if depth < relationdomain.MinNeighborhoodDepth || depth > relationdomain.MaxNeighborhoodDepth {
		return nil, fmt.Errorf("relationapp.Neighborhood: %w", relationdomain.ErrDepthOutOfRange)
	}
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, fmt.Errorf("relationapp.Neighborhood: %w", err)
	}

	type entityRef struct{ k, i string }
	visited := map[entityRef]bool{{k: kind, i: id}: true}
	edgesSeen := map[string]bool{}
	var result []*relationdomain.Relation
	frontier := []entityRef{{k: kind, i: id}}

	for hop := 0; hop < depth; hop++ {
		var nextFrontier []entityRef
		for _, e := range frontier {
			outgoing, err := s.repo.ListByFromAndKinds(ctx, userID, e.k, e.i, nil)
			if err != nil {
				return nil, fmt.Errorf("relationapp.Neighborhood: %w", err)
			}
			incoming, err := s.repo.ListByToAndKinds(ctx, userID, e.k, e.i, nil)
			if err != nil {
				return nil, fmt.Errorf("relationapp.Neighborhood: %w", err)
			}
			for _, r := range outgoing {
				if !edgesSeen[r.ID] {
					edgesSeen[r.ID] = true
					result = append(result, r)
				}
				next := entityRef{k: r.ToKind, i: r.ToID}
				if !visited[next] {
					visited[next] = true
					nextFrontier = append(nextFrontier, next)
				}
			}
			for _, r := range incoming {
				if !edgesSeen[r.ID] {
					edgesSeen[r.ID] = true
					result = append(result, r)
				}
				next := entityRef{k: r.FromKind, i: r.FromID}
				if !visited[next] {
					visited[next] = true
					nextFrontier = append(nextFrontier, next)
				}
			}
		}
		frontier = nextFrontier
		if len(frontier) == 0 {
			break
		}
	}

	return result, nil
}

// GetRelgraph — see relationdomain.Service.
// Composes: all edges + all entities (6 kinds full, conversation only if edge-connected).
func (s *Service) GetRelgraph(ctx context.Context) (*relationdomain.Snapshot, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, fmt.Errorf("relationapp.GetRelgraph: %w", err)
	}

	edges, err := s.repo.ListAll(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("relationapp.GetRelgraph: %w", err)
	}

	type readerCall struct {
		kind   string
		reader interface {
			ListAllMeta(ctx context.Context, userID string) ([]EntityMeta, error)
		}
	}
	calls := []readerCall{
		{relationdomain.EntityKindFunction, s.functionReader},
		{relationdomain.EntityKindHandler, s.handlerReader},
		{relationdomain.EntityKindWorkflow, s.workflowReader},
		{relationdomain.EntityKindDocument, s.documentReader},
		{relationdomain.EntityKindSkill, s.skillReader},
		{relationdomain.EntityKindMCP, s.mcpReader},
		{relationdomain.EntityKindAgent, s.agentReader},
	}

	var nodes []relationdomain.GraphNode
	for _, c := range calls {
		// Treat reader as nil only when it's actually nil (interface holding nil concrete is also nil-able).
		if c.reader == nil || reflect.ValueOf(c.reader).IsNil() {
			continue
		}
		metas, err := c.reader.ListAllMeta(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("relationapp.GetRelgraph: %s reader: %w", c.kind, err)
		}
		for _, m := range metas {
			nodes = append(nodes, relationdomain.GraphNode{Kind: c.kind, ID: m.ID, Label: m.Label, Sub: m.Sub})
		}
	}

	// Conversations: only those referenced by some edge
	if s.conversationReader != nil && !reflect.ValueOf(s.conversationReader).IsNil() {
		convIDSet := map[string]bool{}
		for _, r := range edges {
			if r.FromKind == relationdomain.EntityKindConversation {
				convIDSet[r.FromID] = true
			}
			if r.ToKind == relationdomain.EntityKindConversation {
				convIDSet[r.ToID] = true
			}
		}
		convIDs := make([]string, 0, len(convIDSet))
		for id := range convIDSet {
			convIDs = append(convIDs, id)
		}
		sort.Strings(convIDs)
		if len(convIDs) > 0 {
			metas, err := s.conversationReader.GetMetaBatch(ctx, userID, convIDs)
			if err != nil {
				return nil, fmt.Errorf("relationapp.GetRelgraph: conversation reader: %w", err)
			}
			for _, m := range metas {
				nodes = append(nodes, relationdomain.GraphNode{
					Kind: relationdomain.EntityKindConversation,
					ID:   m.ID, Label: m.Label, Sub: m.Sub,
				})
			}
		}
	}

	return &relationdomain.Snapshot{Nodes: nodes, Edges: edges}, nil
}

// validateEntityRef rejects empty fields or unknown kinds.
//
// validateEntityRef 拒绝空字段或未知 kind。
func validateEntityRef(kind, id string) error {
	if kind == "" || id == "" {
		return relationdomain.ErrInvalidEntityRef
	}
	if !relationdomain.IsValidEntityKind(kind) {
		return relationdomain.ErrInvalidEntityRef
	}
	return nil
}

// validateFilter checks (kind, id) pairs are complete or both absent.
//
// validateFilter 检查 (kind, id) 对要么都给要么都不给。
func validateFilter(f relationdomain.Filter) error {
	if (f.FromKind == "") != (f.FromID == "") {
		return relationdomain.ErrIncompleteFilter
	}
	if (f.ToKind == "") != (f.ToID == "") {
		return relationdomain.ErrIncompleteFilter
	}
	if f.FromKind != "" && !relationdomain.IsValidEntityKind(f.FromKind) {
		return relationdomain.ErrInvalidEntityRef
	}
	if f.ToKind != "" && !relationdomain.IsValidEntityKind(f.ToKind) {
		return relationdomain.ErrInvalidEntityRef
	}
	if f.Kind != "" && !relationdomain.IsValidKind(f.Kind) {
		return relationdomain.ErrInvalidKind
	}
	return nil
}

func validateKindScope(scope []string) error {
	for _, k := range scope {
		if !relationdomain.IsValidKind(k) {
			return relationdomain.ErrInvalidKind
		}
	}
	return nil
}

// attrsEqual compares two attrs maps semantically (JSON-equivalent).
//
// attrsEqual 语义上比较两个 attrs（JSON 等价即等）。
func attrsEqual(a, b map[string]any) bool {
	if len(a) == 0 && len(b) == 0 {
		return true
	}
	return reflect.DeepEqual(a, b)
}

func newID() string { return idgenpkg.New("rel") }
