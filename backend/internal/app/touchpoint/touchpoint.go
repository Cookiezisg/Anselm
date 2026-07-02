// Package touchpoint is the app layer of the conversation context ledger: it RECORDS touches
// (validate → hydrate the display-name snapshot → aggregate-upsert → live signal) and READS
// them back (the right island's paged list). Recording is best-effort by construction — every
// caller sits on a hot path (the tool loop, chat send), so a ledger failure logs and never
// blocks the work that caused the touch (the same discipline as relation's sync hooks).
//
// Package touchpoint 是对话上下文台账的 app 层:**记**触碰(校验 → hydrate 显示名快照 → 聚合
// upsert → 实时信号)与**读**回(右岛分页列表)。记账天生 best-effort——所有调用方都在热路径上
// (工具循环、chat 发送),台账失败只 log、绝不阻断产生触碰的工作(与 relation 的 sync hook 同纪律)。
package touchpoint

import (
	"context"
	"time"

	"go.uber.org/zap"

	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

// signalNodeType is the messages-stream node.type of a ledger live push. The scope anchors
// to the conversation (where the right island renders); the event identity lives here.
//
// signalNodeType 是台账实时推送的 messages 流 node.type。scope 锚定对话(右岛渲染处);
// 事件身份在这里。
const signalNodeType = "touchpoint"

// Namer resolves display names for a batch of one kind's item ids — the SAME shape as
// relationapp.Namer so bootstrap registers the very same source-domain resolvers into both
// (one vocabulary, zero drift); touchpoint adds only the attachment namer on top.
//
// Namer 批量解析某一类物 id 的显示名——与 relationapp.Namer 同形,bootstrap 把同一批
// source-domain resolver 注册进两边(一份词表、零漂移);touchpoint 只多注册 attachment 一种。
type Namer interface {
	NamesByIDs(ctx context.Context, ids []string) (map[string]string, error)
}

// Service records and lists touchpoints.
//
// Service 记录并列出触点。
type Service struct {
	repo   touchpointdomain.Repository
	bridge streamdomain.Bridge // messages SSE stream; nil → no live push (still persisted)
	namers map[string]Namer    // item kind → Namer; missing = snapshot stays as given
	log    *zap.Logger
}

// Config bundles dependencies. Bridge and Namers are optional (nil bridge = persist only;
// missing namer = the touch's own name, possibly empty). Repo/Log are mandatory.
//
// Config 打包依赖。Bridge 与 Namers 可选(nil bridge = 只持久化;缺 namer = 用 touch 自带名,
// 可能为空)。Repo/Log 必给。
type Config struct {
	Repo   touchpointdomain.Repository
	Bridge streamdomain.Bridge
	Namers map[string]Namer
	Log    *zap.Logger
}

// NewService constructs the ledger service.
//
// NewService 构造台账服务。
func NewService(cfg Config) *Service {
	if cfg.Repo == nil {
		panic("touchpointapp.NewService: repo is nil")
	}
	if cfg.Log == nil {
		panic("touchpointapp.NewService: logger is nil")
	}
	if cfg.Namers == nil {
		cfg.Namers = map[string]Namer{}
	}
	return &Service{repo: cfg.Repo, bridge: cfg.Bridge, namers: cfg.Namers, log: cfg.Log.Named("touchpointapp")}
}

// Record books one touch: best-effort, never returns — hot-path callers must not branch on
// ledger health. An invalid touch is a programming error in the caller's catalog entry and
// is logged loudly; a storage failure logs and drops (the next touch of the same row heals
// count drift no worse than any missed event).
//
// Record 记一次触碰:best-effort、无返回——热路径调用方不得因台账健康分叉。非法 touch 是调用方
// 目录条目的编程错误,大声 log;存储失败 log 后丢弃(同行下次触碰对 count 漂移的伤害不超过任何漏记)。
func (s *Service) Record(ctx context.Context, t touchpointdomain.Touch) {
	if t.At.IsZero() {
		t.At = time.Now().UTC()
	}
	if err := t.Validate(); err != nil {
		s.log.Warn("touchpoint.Record: invalid touch dropped",
			zap.String("conversationId", t.ConversationID), zap.String("itemKind", t.ItemKind),
			zap.String("itemId", t.ItemID), zap.String("verb", t.Verb), zap.Error(err))
		return
	}
	if t.ItemName == "" {
		t.ItemName = s.lookupName(ctx, t.ItemKind, t.ItemID)
	}
	row, err := s.repo.Upsert(ctx, &t, idgenpkg.New("tp"))
	if err != nil {
		s.log.Warn("touchpoint.Record: upsert failed",
			zap.String("conversationId", t.ConversationID), zap.String("itemId", t.ItemID), zap.Error(err))
		return
	}
	s.broadcast(ctx, row)
}

// List pages a conversation's ledger by recency; kind/verb filter when non-empty (enum-checked
// so a typo'd filter fails loudly instead of returning a silently empty page).
//
// List 按新鲜度分页对话台账;kind/verb 非空即过滤(枚举校验——拼错的过滤器大声失败,
// 而非静默空页)。
func (s *Service) List(ctx context.Context, conversationID, kind, verb, cursor string, limit int) ([]*touchpointdomain.Touchpoint, string, error) {
	if kind != "" && !touchpointdomain.IsValidItemKind(kind) {
		return nil, "", touchpointdomain.ErrInvalidKind
	}
	if verb != "" && !touchpointdomain.IsValidVerb(verb) {
		return nil, "", touchpointdomain.ErrInvalidVerb
	}
	return s.repo.ListByConversation(ctx, conversationID, kind, verb, cursor, limit)
}

// PurgeConversation drops the whole ledger of a dead conversation (the delete cascade).
//
// PurgeConversation 删除死亡对话的整份台账(删除级联)。
func (s *Service) PurgeConversation(ctx context.Context, conversationID string) error {
	return s.repo.PurgeConversation(ctx, conversationID)
}

// lookupName hydrates a display name via the kind's Namer; "" when no namer or no name —
// the row keeps whatever snapshot it already has.
//
// lookupName 经该 kind 的 Namer hydrate 显示名;无 namer 或无名返 ""——行保留既有快照。
func (s *Service) lookupName(ctx context.Context, kind, id string) string {
	n, ok := s.namers[kind]
	if !ok {
		return ""
	}
	names, err := n.NamesByIDs(ctx, []string{id})
	if err != nil {
		s.log.Warn("touchpoint.lookupName failed", zap.String("kind", kind), zap.String("id", id), zap.Error(err))
		return ""
	}
	return names[id]
}

// broadcast pushes the updated aggregate row as a durable signal on the messages stream,
// anchored to its conversation. The payload is one row (idempotent upsert view), so replay
// after reconnect converges — unlike a full-list push, it stays O(1) per touch. Best-effort:
// a missed push is recovered by the REST read.
//
// broadcast 把更新后的聚合行作为 durable signal 推上 messages 流、锚定其对话。payload 是单行
// (幂等 upsert 视图),重连重放收敛——不同于整列推送,每次触碰 O(1)。best-effort:漏推由 REST 读兜回。
func (s *Service) broadcast(ctx context.Context, row *touchpointdomain.Touchpoint) {
	if s.bridge == nil {
		return
	}
	content := streamdomain.JSONContent(row)
	if content == nil {
		s.log.Warn("touchpoint signal marshal failed", zap.String("id", row.ID))
		return
	}
	if _, err := s.bridge.Publish(ctx, streamdomain.Event{
		Scope: streamdomain.Scope{Kind: streamdomain.KindConversation, ID: row.ConversationID},
		ID:    row.ID,
		Frame: streamdomain.Signal{Node: streamdomain.Node{Type: signalNodeType, Content: content}},
	}); err != nil {
		s.log.Warn("touchpoint SSE push failed", zap.String("conversationId", row.ConversationID), zap.Error(err))
	}
}

// ctxKey carries the Service through the tool loop: the loop is entity-agnostic plumbing, so
// it discovers the recorder from ctx (the humanloop-broker pattern) instead of importing a
// wired dependency. Seeded once by the chat runner; subagent/invoke ctxs inherit it, and
// conversation-less paths (workflow dispatch, REST) simply never see one.
//
// ctxKey 把 Service 带进工具循环:loop 是实体无关的管道,从 ctx 发现记账器(humanloop broker
// 同款模式)而非 import 装配依赖。chat runner 种一次;subagent/invoke ctx 继承之,无对话路径
// (workflow 派发、REST)天然不见它。
type ctxKey struct{}

// With seeds the recorder into ctx.
//
// With 把记账器种进 ctx。
func With(ctx context.Context, s *Service) context.Context {
	return context.WithValue(ctx, ctxKey{}, s)
}

// From retrieves the recorder, or (nil, false) on recorder-less paths.
//
// From 取记账器;无记账器路径返 (nil, false)。
func From(ctx context.Context) (*Service, bool) {
	s, ok := ctx.Value(ctxKey{}).(*Service)
	return s, ok && s != nil
}
