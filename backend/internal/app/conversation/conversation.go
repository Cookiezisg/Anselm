// Package conversation owns the conversation CRUD Service (create / list / get / update /
// delete) for chat-thread containers. Workspace isolation is automatic at the orm layer, so the
// Service holds no workspace id. Lifecycle changes broadcast via notification.Emitter
// (conversation.<action>); relation hydrate + edge purge live in relations.go. The chat runtime
// reads SystemPrompt / AttachedDocuments / ModelOverride from the record — this layer only
// persists them.
//
// Package conversation 持有对话线程容器的 CRUD Service（建/列/取/改/删）。workspace 隔离在 orm 层
// 自动完成，故 Service 不持 workspace id。生命周期变更经 notification.Emitter（conversation.<动作>）
// 广播；relation hydrate + 边清理在 relations.go。chat 运行时从记录读 SystemPrompt /
// AttachedDocuments / ModelOverride——本层只持久化它们。
package conversation

import (
	"context"
	"maps"
	"strings"
	"time"

	"go.uber.org/zap"

	modelrefapp "github.com/sunweilin/anselm/backend/internal/app/modelref"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
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

	// querier is the optional in-flight-generation reader (chatapp, injected post-build): Get/List
	// derive each row's IsGenerating from it so a freshly-connected client cold-starts its live
	// activity dots. Symmetric to canceler — same DIP port that breaks the chat↔conversation cycle.
	// nil → IsGenerating stays false.
	//
	// querier 是可选在途生成读取器（chatapp，后注入）：Get/List 据它派生每行 IsGenerating，使刚连上的
	// 客户端冷启动活动圆点。与 canceler 对称——同款 DIP 端口破 chat↔conversation 环。nil → IsGenerating 恒 false。
	querier GeneratingQuerier

	// awaitingQuerier is the optional pending-interaction reader (chatapp, injected post-build): Get/List
	// derive each row's AwaitingInput from the in-memory humanloop broker so a freshly-connected client
	// cold-starts its "needs you" dot. Mirrors querier exactly — same DIP port. nil → AwaitingInput false.
	//
	// awaitingQuerier 是可选待决-interaction 读取器（chatapp，后注入）：Get/List 据内存 humanloop broker 派生每行
	// AwaitingInput，使刚连上的客户端冷启动「等你」点。与 querier 完全对称——同款 DIP 端口。nil → AwaitingInput 恒 false。
	awaitingQuerier AwaitingInputQuerier

	// docResolver is the optional document-existence hook (documentapp, injected post-build like
	// relations/canceler): Update validates attachedDocuments against it so a dangling/deleted doc id is
	// rejected at attach time (422) instead of silently accepted and only surfaced as a render warning
	// later. nil → no attach-time check (F167's render-time warning still backstops). (F168-M5)
	//
	// docResolver 是可选文档存在性钩子（documentapp，与 relations/canceler 同款后注入）：Update 据它校验
	// attachedDocuments，使悬挂/已删 doc id 在 attach 时即 422、而非静默接受、只在后续渲染时才警告。
	// nil → 不做 attach-time 校验（F167 渲染时警告仍兜底）。（F168-M5）
	docResolver DocumentResolver

	// keyChecker is the optional apikey existence hook (apikeyapp, injected post-build): Update rejects a
	// modelOverride pointing at a non-existent apiKeyId at write time (API_KEY_NOT_FOUND) instead of only
	// at chat time. nil → existence check skipped (the prior fail-loud-at-chat behavior). (F153)
	//
	// keyChecker 是可选 apikey 存在性钩子（apikeyapp，后注入）：Update 在写时拒绝指向不存在 apiKeyId 的
	// modelOverride（API_KEY_NOT_FOUND），而非只在 chat 时。nil → 跳过存在性校验（旧 fail-loud-at-chat）。（F153）
	keyChecker modelrefapp.KeyExistenceChecker
}

// DocumentResolver resolves attached-document references to their live documents (missing ids are
// dropped, not errored — the caller diffs requested vs returned). Implemented by documentapp.Service.
//
// DocumentResolver 把附加文档引用解析成存活文档（缺失 id 被丢弃、非报错——调用方比对 requested vs
// returned）。由 documentapp.Service 实现。
type DocumentResolver interface {
	ResolveAttached(ctx context.Context, atts []documentdomain.AttachedDocument) ([]*documentdomain.Document, error)
}

// GenerationCanceler is the chat-side hook for conversation lifecycle (chatapp.Service satisfies it):
// Cancel stops in-flight generation (also used by the stream DELETE endpoint, so it must NOT drop
// per-conversation grants), while ForgetConversation tears down conversation-scoped chat state — the
// humanloop always-allow whitelist — and is delete-only (a deleted conversation's grants must not
// linger on the app-wide broker).
//
// GenerationCanceler 是对话生命周期的 chat 侧钩子（chatapp.Service 满足之）：Cancel 停在途生成（stream
// DELETE 端点也用，故**不能**丢对话级授权），ForgetConversation 拆除对话级 chat 状态——humanloop
// always-allow 白名单——仅删除时调（已删对话的授权不该残留在 app 级 broker）。
type GenerationCanceler interface {
	Cancel(ctx context.Context, conversationID string) error
	ForgetConversation(conversationID string)
}

// SetGenerationCanceler injects the chat cancel hook after construction (bootstrap breaks the
// chat→conversation→chat cycle this way, same as SetRelationSyncer).
//
// SetGenerationCanceler 构造后注入 chat cancel 钩子（bootstrap 以此破 chat→conversation→chat
// 环，与 SetRelationSyncer 同款）。
func (s *Service) SetGenerationCanceler(c GenerationCanceler) { s.canceler = c }

// GeneratingQuerier reports whether a conversation has an in-flight assistant turn (chatapp.Service
// satisfies it via its per-conversation queue registry).
//
// GeneratingQuerier 报告某对话是否有在途 assistant 回合（chatapp.Service 经其 per-conversation 队列
// 登记满足之）。
type GeneratingQuerier interface {
	IsGenerating(conversationID string) bool
}

// SetGeneratingQuerier injects the chat generation-state reader post-construction (same cycle-break
// as SetGenerationCanceler).
//
// SetGeneratingQuerier 构造后注入 chat 生成态读取器（与 SetGenerationCanceler 同款破环）。
func (s *Service) SetGeneratingQuerier(q GeneratingQuerier) { s.querier = q }

// AwaitingInputQuerier reports whether a conversation has ≥1 pending human-in-loop interaction
// (chatapp.Service satisfies it via the in-memory humanloop broker). Short-circuits on the first match
// so List can call it per-row cheaply.
//
// AwaitingInputQuerier 报告某对话是否有 ≥1 个待决人在环 interaction（chatapp.Service 经内存 humanloop
// broker 满足之）。首个匹配即短路，使 List 可逐行廉价调用。
type AwaitingInputQuerier interface {
	HasAwaitingInteraction(conversationID string) bool
}

// SetAwaitingInputQuerier injects the chat pending-interaction reader post-construction (same
// cycle-break as SetGeneratingQuerier).
//
// SetAwaitingInputQuerier 构造后注入 chat 待决-interaction 读取器（与 SetGeneratingQuerier 同款破环）。
func (s *Service) SetAwaitingInputQuerier(q AwaitingInputQuerier) { s.awaitingQuerier = q }

// markRuntime fills the derived runtime flags on each row — IsGenerating from the chat registry,
// AwaitingInput from the humanloop broker — each independently a no-op when its querier is unwired.
// Pure in-memory reads, no DB/IO, so it is cheap even per-row in List.
//
// markRuntime 给每行填派生运行时标志——IsGenerating 据 chat 登记、AwaitingInput 据 humanloop broker——各自在对应
// querier 未接时 no-op。纯内存读、无 DB/IO，故即便 List 逐行也廉价。
func (s *Service) markRuntime(rows ...*conversationdomain.Conversation) {
	for _, c := range rows {
		if c == nil {
			continue
		}
		if s.querier != nil {
			c.IsGenerating = s.querier.IsGenerating(c.ID)
		}
		if s.awaitingQuerier != nil {
			c.AwaitingInput = s.awaitingQuerier.HasAwaitingInteraction(c.ID)
		}
	}
}

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

// SetDocumentResolver installs the document-existence hook post-construction (documentapp; no cycle —
// document does not depend on conversation). Enables Update's attach-time validation (F168-M5).
//
// SetDocumentResolver 装配后注入文档存在性钩子（documentapp；无环——document 不依赖 conversation）。
// 使 Update 的 attach-time 校验生效（F168-M5）。
func (s *Service) SetDocumentResolver(r DocumentResolver) { s.docResolver = r }

// SetKeyChecker installs the apikey existence probe post-construction (apikeyapp; no cycle — apikey
// depends on none of agent/conversation/workspace). Enables Update to reject a modelOverride pointing
// at a non-existent apiKeyId at write time (F153). nil → existence check skipped.
//
// SetKeyChecker 装配后注入 apikey 存在性探针（apikeyapp；无环）。使 Update 在写时拒绝指向不存在 apiKeyId
// 的 modelOverride（F153）。nil → 跳过存在性校验。
func (s *Service) SetKeyChecker(c modelrefapp.KeyExistenceChecker) { s.keyChecker = c }

// validateAttachedDocs rejects a PATCH that attaches a doc id which does not exist (F168-M5). Only the
// NEW list is checked (old data is not re-validated — F167's render-time warning backstops that); an
// empty list (clearing all attachments) and a nil resolver both pass. ResolveAttached drops missing
// ids silently, so we diff the requested (deduped, non-blank) ids against the returned documents.
//
// validateAttachedDocs 拒绝 attach 不存在 doc id 的 PATCH（F168-M5）。只校验**新**列表（不回溯老数据——
// F167 渲染警告兜底）；空列表（清空全部附件）与 nil resolver 都放行。ResolveAttached 静默丢缺失 id，故
// 拿请求的（去重、非空）id 集与返回文档比对。
func (s *Service) validateAttachedDocs(ctx context.Context, atts []documentdomain.AttachedDocument) error {
	if s.docResolver == nil || len(atts) == 0 {
		return nil
	}
	docs, err := s.docResolver.ResolveAttached(ctx, atts)
	if err != nil {
		return err
	}
	have := make(map[string]bool, len(docs))
	for _, d := range docs {
		have[d.ID] = true
	}
	var missing []string
	seen := map[string]bool{}
	for _, a := range atts {
		id := strings.TrimSpace(a.DocumentID)
		if id == "" || seen[id] {
			continue
		}
		seen[id] = true
		if !have[id] {
			missing = append(missing, id)
		}
	}
	if len(missing) > 0 {
		return conversationdomain.ErrAttachedDocumentNotFound.WithDetails(map[string]any{"missing": missing})
	}
	return nil
}

// Create makes a new conversation with the given title (may be empty → chat auto-titles later).
//
// Create 创建一个新对话，title 可为空（→ chat 后续自动命名）。
func (s *Service) Create(ctx context.Context, title string) (*conversationdomain.Conversation, error) {
	return s.CreateWithSystemPrompt(ctx, title, "")
}

// CreateWithSystemPrompt creates a thread pre-stamped with a system-prompt section — used by the
// ask-ai / triage spawner so the LLM sees entity context from turn 1.
//
// CreateWithSystemPrompt 创建带 system prompt 的新对话——ask-ai / triage 用，LLM 从第 1 轮起
// 就看到 entity 上下文。
func (s *Service) CreateWithSystemPrompt(ctx context.Context, title, systemPrompt string) (*conversationdomain.Conversation, error) {
	c := &conversationdomain.Conversation{
		ID:           idgenpkg.New("cv"),
		Title:        strings.TrimSpace(title),
		SystemPrompt: systemPrompt,
		// Seed recency to creation time so a brand-new (message-less) thread sorts by when it was
		// opened until chat bumps it on the first message (last_message_at is NOT NULL).
		// 用创建时间种 recency，使全新（无消息）线程在 chat 首条消息刷新前按开启时间排序（NOT NULL）。
		LastMessageAt: time.Now().UTC(),
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
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	s.markRuntime(c)
	return c, nil
}

// List returns a page of conversations, each row's derived IsGenerating filled from the chat
// registry (recency-sorted by last_message_at in the store).
//
// List 返回对话的一页，每行派生 IsGenerating 据 chat 登记填（store 按 last_message_at 最近活跃排序）。
func (s *Service) List(ctx context.Context, filter ListFilter) ([]*conversationdomain.Conversation, string, error) {
	rows, next, err := s.repo.List(ctx, filter)
	if err != nil {
		return nil, "", err
	}
	s.markRuntime(rows...)
	return rows, next, nil
}

// TouchLastMessage records that a message just landed in a conversation — chat calls it when a
// message is added so the list re-sorts by recent activity and the unread flag tracks whether there is
// an unseen assistant reply. `unread` is the new unread state (false on the user's own send, true on a
// completed assistant finalize). A single cheap atomic UPDATE; best-effort (a failed touch only
// mis-sorts / mis-flags, never blocks the turn).
//
// TouchLastMessage 记一条消息刚落入对话——chat 在消息加入时调,使列表按最近活跃重排、unread 标志跟踪有无未读
// assistant 回复。unread 是新未读态（用户自己发送 false、assistant 完成终态 true）。一次廉价原子 UPDATE；
// best-effort（touch 失败只是排序/标志略偏，绝不阻塞回合）。
func (s *Service) TouchLastMessage(ctx context.Context, id string, t time.Time, unread bool) error {
	return s.repo.TouchLastMessage(ctx, id, t, unread)
}

// MarkSeen clears a conversation's unread flag — the :seen action, called when the user opens a
// thread without sending (a thin delegate to the repo's focused unread-only UPDATE). Does NOT go
// through Update/emit: mark-seen is high-frequency (every open), single-user, and tells no other
// client anything, so it deliberately broadcasts NO notification (would spam the SSE for nothing).
//
// MarkSeen 清某对话的 unread 标志——:seen 动作，用户没发消息只是打开线程时调（薄薄转发到 repo 的 unread-only UPDATE）。
// 不走 Update/emit：mark-seen 高频（每次打开）、单用户、对别的客户端无意义，故刻意**不发任何通知**（否则白白刷爆 SSE）。
func (s *Service) MarkSeen(ctx context.Context, id string) error {
	return s.repo.MarkSeen(ctx, id)
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
		if err := s.validateAttachedDocs(ctx, *in.AttachedDocuments); err != nil {
			return nil, err
		}
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
		if err := modelrefapp.Validate(ctx, ref, conversationdomain.ErrInvalidModelOverride, s.keyChecker); err != nil {
			return nil, err
		}
		c.ModelOverride = ref
		action = "model_override"
	}
	if err := s.repo.Update(ctx, c); err != nil {
		return nil, err
	}
	s.emit(ctx, c.ID, action, map[string]any{"title": c.Title, "archived": c.Archived, "pinned": c.Pinned})
	// Fill the derived flag so a PATCH (e.g. pinning a conversation mid-generation) returns the same
	// accurate isGenerating the frontend sees in List/Get — never a stale false.
	// 填派生标志，使 PATCH（如生成中置顶）返回与 List/Get 一致的准确 isGenerating，不返回过期 false。
	s.markRuntime(c)
	return c, nil
}

// Delete soft-deletes a conversation and purges its relation edges.
//
// Delete 软删对话并清除其 relation 边。
// SetAutoTitle sets a conversation's auto-generated title (chat's auto-title). It writes
// both Title and AutoTitled — a path PATCH deliberately doesn't expose (auto-title is chat-owned)
// — and emits conversation.auto_titled. A title that already exists (user-set or previously
// auto-titled) is left untouched, so a manual rename is never clobbered.
//
// SetAutoTitle 设置对话的自动生成标题（chat auto-title）。写 Title + AutoTitled——PATCH 故意
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

// SetSummary writes the compaction summary + its watermark (app/contextmgr). A PATCH-invisible
// path (only the compactor writes it). The watermark `coversUpToSeq` is the max block seq the
// summary now folds in, so the next compaction summarizes only `(coversUpToSeq, …]` — the
// idempotent re-summarization guard. Emits conversation.compacted.
//
// SetSummary 写压缩摘要 + 其水位线（app/contextmgr）。PATCH 不暴露的路径（只压缩器写）。水位
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
		// Drop the conversation's humanloop always-allow grants — they are conversation-scoped state
		// on the app-wide broker that would otherwise leak past deletion. Delete-only (Cancel alone,
		// from the stream-stop endpoint, must keep grants for the still-live conversation).
		// 丢弃对话的 humanloop always-allow 授权——它是 app 级 broker 上的对话级状态，否则会越过删除泄漏。
		// 仅删除时（单独 Cancel 来自 stream-stop 端点，须为仍活的对话保留授权）。
		s.canceler.ForgetConversation(id)
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

// Unarchive clears the archived flag (no-op when already active) — chat's auto-unarchive on
// Send: messaging an archived thread implicitly brings it back.
//
// Unarchive 清除归档标志（已活跃则 no-op）——chat Send 的自动解档：给归档线程发消息即隐式唤回。
func (s *Service) Unarchive(ctx context.Context, id string) error {
	f := false
	_, err := s.Update(ctx, id, UpdateInput{Archived: &f})
	return err
}
