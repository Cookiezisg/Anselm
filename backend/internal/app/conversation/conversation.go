// Package conversation owns the conversation CRUD Service (create / list / get / update /
// delete) for chat-thread containers. Workspace isolation is automatic at the orm layer, so the
// Service holds no workspace id. Lifecycle changes broadcast via notification.Emitter
// (conversation.<action>); relation hydrate + edge purge live in relations.go. The chat runtime
// (M5.2) reads SystemPrompt / AttachedDocuments / ModelOverride from the record — this layer only
// persists them.
//
// Package conversation 持有对话线程容器的 CRUD Service（建/列/取/改/删）。workspace 隔离在 orm 层
// 自动完成，故 Service 不持 workspace id。生命周期变更经 notification.Emitter（conversation.<动作>）
// 广播；relation hydrate + 边清理在 relations.go。chat 运行时（M5.2）从记录读 SystemPrompt /
// AttachedDocuments / ModelOverride——本层只持久化它们。
package conversation

import (
	"context"
	"maps"
	"strings"

	"go.uber.org/zap"

	conversationdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	notificationdomain "github.com/sunweilin/forgify/backend/internal/domain/notification"
	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// Re-export the domain payload types so handlers depend on the app package only.
//
// 复用 domain 载荷类型，使 handler 只依赖 app 包。
type (
	ListFilter  = conversationdomain.ListFilter
	UpdateInput = conversationdomain.UpdateInput
)

// Service is the conversation CRUD application façade.
//
// Service 是对话 CRUD 应用 façade。
type Service struct {
	repo    conversationdomain.Repository
	search  searchdomain.Notifier // nil → search indexing disabled. nil → 不接搜索索引。
	emitter notificationdomain.Emitter
	log     *zap.Logger

	// relations is the optional relation hook; nil disables edge purge + the Namer is harmless.
	// relations 是可选 relation 钩子；nil 时禁用边清理、Namer 仍无害。
	relations RelationSyncer

	// canceler is the optional generation hook (chatapp, injected post-build like relations):
	// Delete cancels any in-flight generation so a deleted conversation can't keep burning
	// tokens and streaming into the void. nil → deletion alone.
	//
	// canceler 是可选生成钩子（chatapp，与 relations 同款后注入）：Delete 取消在途生成，使已删
	// 对话不再烧 token、不再对空推流。nil → 只删除。
	canceler GenerationCanceler
}

// GenerationCanceler stops a conversation's in-flight generation (chatapp.Service satisfies it).
//
// GenerationCanceler 停止对话的在途生成（chatapp.Service 满足之）。
type GenerationCanceler interface {
	Cancel(ctx context.Context, conversationID string) error
}

// SetGenerationCanceler injects the chat cancel hook after construction (bootstrap breaks the
// chat→conversation→chat cycle this way, same as SetRelationSyncer).
//
// SetGenerationCanceler 构造后注入 chat cancel 钩子（bootstrap 以此破 chat→conversation→chat
// 环，与 SetRelationSyncer 同款）。
func (s *Service) SetGenerationCanceler(c GenerationCanceler) { s.canceler = c }

// New constructs a Service; panics on nil logger. A nil emitter disables notifications (best-effort).
//
// New 构造 Service；nil logger panic。emitter 为 nil 时禁用通知（best-effort）。
func NewService(repo conversationdomain.Repository, emitter notificationdomain.Emitter, log *zap.Logger) *Service {
	if log == nil {
		panic("conversationapp.New: nil logger")
	}
	return &Service{repo: repo, emitter: emitter, log: log}
}

// SetRelationSyncer installs the relation Service post-construction (avoids an init cycle:
// relation needs conversation's Namer, conversation needs relation's syncer).
//
// SetRelationSyncer 装配后注入 relation Service（避免 init 环：relation 要 conversation 的 Namer，
// conversation 要 relation 的 syncer）。
func (s *Service) SetRelationSyncer(r RelationSyncer) { s.relations = r }

// Create makes a new conversation with the given title (may be empty → chat auto-titles later).
//
// Create 创建一个新对话，title 可为空（→ chat 后续自动命名）。
func (s *Service) Create(ctx context.Context, title string) (*conversationdomain.Conversation, error) {
	return s.CreateWithSystemPrompt(ctx, title, "")
}

// CreateWithSystemPrompt creates a thread pre-stamped with a system-prompt section — used by the
// ask-ai / triage spawner (M6) so the LLM sees entity context from turn 1.
//
// CreateWithSystemPrompt 创建带 system prompt 的新对话——ask-ai / triage（M6）用，LLM 从第 1 轮起
// 就看到 entity 上下文。
func (s *Service) CreateWithSystemPrompt(ctx context.Context, title, systemPrompt string) (*conversationdomain.Conversation, error) {
	c := &conversationdomain.Conversation{
		ID:           idgenpkg.New("cv"),
		Title:        strings.TrimSpace(title),
		SystemPrompt: systemPrompt,
	}
	if err := s.repo.Insert(ctx, c); err != nil {
		return nil, err
	}
	s.emit(ctx, c.ID, "created", map[string]any{"title": c.Title})
	return c, nil
}

// Get fetches one conversation by id (workspace-scoped by the orm layer).
//
// Get 按 id 取一条对话（orm 层按 workspace 过滤）。
func (s *Service) Get(ctx context.Context, id string) (*conversationdomain.Conversation, error) {
	return s.repo.Get(ctx, id)
}

// List returns a page of conversations.
//
// List 返回对话的一页。
func (s *Service) List(ctx context.Context, filter ListFilter) ([]*conversationdomain.Conversation, string, error) {
	return s.repo.List(ctx, filter)
}

// Update applies a PATCH (nil = leave; for ModelOverride nil = leave, &nil = clear, &(&ref) = set).
//
// Update 部分更新（nil = 不动；ModelOverride nil = 不动、&nil = 清除、&(&ref) = 设置）。
func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*conversationdomain.Conversation, error) {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	action := "updated"
	if in.Title != nil {
		c.Title = strings.TrimSpace(*in.Title)
	}
	if in.SystemPrompt != nil {
		c.SystemPrompt = *in.SystemPrompt
	}
	if in.AttachedDocuments != nil {
		c.AttachedDocuments = *in.AttachedDocuments
	}
	if in.Archived != nil && c.Archived != *in.Archived {
		c.Archived = *in.Archived
		if c.Archived {
			action = "archived"
		} else {
			action = "unarchived"
		}
	}
	if in.Pinned != nil && c.Pinned != *in.Pinned {
		c.Pinned = *in.Pinned
		if c.Pinned {
			action = "pinned"
		} else {
			action = "unpinned"
		}
	}
	if in.ModelOverride != nil {
		ref := *in.ModelOverride // *ModelRef; nil = clear
		if err := validateModelOverride(ref); err != nil {
			return nil, err
		}
		c.ModelOverride = ref
		action = "model_override"
	}
	if err := s.repo.Update(ctx, c); err != nil {
		return nil, err
	}
	s.emit(ctx, c.ID, action, map[string]any{"title": c.Title, "archived": c.Archived, "pinned": c.Pinned})
	return c, nil
}

// Delete soft-deletes a conversation and purges its relation edges.
//
// Delete 软删对话并清除其 relation 边。
// SetAutoTitle sets a conversation's auto-generated title (chat's auto-title, R0057). It writes
// both Title and AutoTitled — a path PATCH deliberately doesn't expose (auto-title is chat-owned)
// — and emits conversation.auto_titled. A title that already exists (user-set or previously
// auto-titled) is left untouched, so a manual rename is never clobbered.
//
// SetAutoTitle 设置对话的自动生成标题（chat auto-title，R0057）。写 Title + AutoTitled——PATCH 故意
// 不暴露的路径（auto-title 由 chat 专写）——并发 conversation.auto_titled。已存在的标题（用户设或已
// 自动标题）不动，故手动改名永不被覆盖。
func (s *Service) SetAutoTitle(ctx context.Context, id, title string) error {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return err
	}
	if c.AutoTitled || strings.TrimSpace(c.Title) != "" {
		return nil
	}
	c.Title = strings.TrimSpace(title)
	c.AutoTitled = true
	if err := s.repo.Update(ctx, c); err != nil {
		return err
	}
	s.emit(ctx, c.ID, "auto_titled", map[string]any{"title": c.Title})
	return nil
}

// SetSummary writes the compaction summary + its watermark (contextmgr M5.3). A PATCH-invisible
// path (only the compactor writes it). The watermark `coversUpToSeq` is the max block seq the
// summary now folds in, so the next compaction summarizes only `(coversUpToSeq, …]` — the
// idempotent re-summarization guard. Emits conversation.compacted.
//
// SetSummary 写压缩摘要 + 其水位线（contextmgr M5.3）。PATCH 不暴露的路径（只压缩器写）。水位
// `coversUpToSeq` 是摘要现已并入的最大 block seq，故下次压缩只摘要 `(coversUpToSeq, …]`——幂等
// 重摘守卫。发 conversation.compacted。
func (s *Service) SetSummary(ctx context.Context, id, summary string, coversUpToSeq int64) error {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return err
	}
	c.Summary = summary
	c.SummaryCoversUpToSeq = coversUpToSeq
	if err := s.repo.Update(ctx, c); err != nil {
		return err
	}
	s.emit(ctx, c.ID, "compacted", map[string]any{"coversUpToSeq": coversUpToSeq, "summaryBytes": len(summary)})
	return nil
}

func (s *Service) Delete(ctx context.Context, id string) error {
	// Stop any in-flight generation first: a deleted conversation must not keep calling the
	// LLM or streaming to a thread nobody can see.
	//
	// 先停在途生成：已删对话不该继续调 LLM、不该往没人能看的线程推流。
	if s.canceler != nil {
		if err := s.canceler.Cancel(ctx, id); err != nil {
			s.log.Warn("conversation.Delete: cancel generation failed", zap.String("id", id), zap.Error(err))
		}
	}
	if err := s.repo.SoftDelete(ctx, id); err != nil {
		return err
	}
	s.emit(ctx, id, "deleted", nil)
	s.purgeRelations(ctx, id)
	return nil
}

// emit raises a conversation.<action> notification (persisted + SSE signal); nil emitter is a
// best-effort no-op, a soft-fail logs but never blocks the mutation.
//
// emit 发一条 conversation.<动作> 通知（持久化 + SSE signal）；nil emitter 即 best-effort no-op，
// 软失败只 log、绝不挡 mutation。
func (s *Service) emit(ctx context.Context, convID, action string, extra map[string]any) {
	s.notifySearch(ctx, convID)
	if s.emitter == nil {
		return
	}
	payload := map[string]any{"conversationId": convID}
	maps.Copy(payload, extra)
	if err := s.emitter.Emit(ctx, "conversation."+action, payload); err != nil {
		s.log.Warn("conversation emit failed",
			zap.String("conversationId", convID), zap.String("action", action), zap.Error(err))
	}
}

// validateModelOverride requires both apiKeyId and modelId when an override is set; mirrors
// agent — structural only, no key-existence probe (resolved, possibly failing gracefully, at chat time).
//
// validateModelOverride 在设了 override 时要求 apiKeyId 和 modelId 都非空；照 agent——仅结构、不探
// key 存在性（在 chat 时解析，可优雅失败）。
func validateModelOverride(o *modeldomain.ModelRef) error {
	if o == nil {
		return nil
	}
	if strings.TrimSpace(o.APIKeyID) == "" || strings.TrimSpace(o.ModelID) == "" {
		return conversationdomain.ErrInvalidModelOverride
	}
	return nil
}

// Unarchive clears the archived flag (no-op when already active) — chat's auto-unarchive on
// Send: messaging an archived thread implicitly brings it back (review PD-2).
//
// Unarchive 清除归档标志（已活跃则 no-op）——chat Send 的自动解档：给归档线程发消息即隐式唤回
// （评审 PD-2）。
func (s *Service) Unarchive(ctx context.Context, id string) error {
	f := false
	_, err := s.Update(ctx, id, UpdateInput{Archived: &f})
	return err
}
