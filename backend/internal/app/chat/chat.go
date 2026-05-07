// Package chat (app/chat) orchestrates the chat pipeline: queueing,
// attachment handling, auto-titling, and SSE event publishing. The ReAct
// engine itself lives in internal/app/loop — chat is one of its callers
// (subagent / Skill fork / Phase 4 workflow LLM nodes are the others).
// Owns no SQL — persistence is delegated to infra/store/chat.
//
// Concurrency: each conversation has a convQueue with a buffered task
// channel; one worker goroutine drains it sequentially, so messages within
// one conversation execute one at a time in order.
//
// Package chat（app/chat）编排聊天管线：队列、附件处理、自动命名、SSE 推送。
// ReAct 引擎本身在 internal/app/loop——chat 只是它的调用方之一（subagent /
// Skill fork / Phase 4 workflow LLM 节点是其他调用方）。不含 SQL，持久化
// 委托给 infra/store/chat。
//
// Files:
//
//	chat.go     — public API (Send, Cancel, ListMessages, UploadAttachment)
//	runner.go   — queue, processTask → loop.Run, autoTitle, system prompt
//	host.go     — chatHost implements loop.Host (writes chat_messages, fires chat.message)
//	history.go  — buildHistory + buildUserLLMMessage + attachment resolve
//	util.go     — ID generators, file helpers, truncate
package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	agentstatepkg "github.com/sunweilin/forgify/backend/internal/pkg/agentstate"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// queueCapacity is the maximum number of messages that can queue behind
// the currently running Agent for one conversation.
//
// queueCapacity 是单个 conversation 在当前 Agent 之后最多排队的消息数。
const queueCapacity = 5

// convQueue manages sequential Agent execution for one conversation.
// agentState carries cross-tool state (most notably SeenFiles for the
// must-Read-first guard); it lives as long as the queue itself, so it
// is GC'd together with the conversation when the idle timer fires.
//
// convQueue 管理单个 conversation 的顺序 Agent 执行。
// agentState 携带跨 tool 状态（最重要的是 must-Read-first 守卫用的 SeenFiles）；
// 生命周期跟 queue 同步，conversation idle 触发清队列时一并 GC。
type convQueue struct {
	ch         chan queuedTask
	mu         sync.Mutex
	cancel     context.CancelFunc // nil when idle
	agentState *agentstatepkg.AgentState
}

// queuedTask is one pending chat turn waiting to be processed.
//
// queuedTask 是等待处理的一次对话请求。
type queuedTask struct {
	ctx       context.Context
	conv      *convdomain.Conversation
	uid       string
	userMsgID string // ID of the user message that triggered this task
}

// Service orchestrates LLM calls, attachment handling, and SSE event publishing.
//
// Service 编排 LLM 调用、附件处理和 SSE 事件推送。
type Service struct {
	repo        chatdomain.Repository
	convRepo    convdomain.Repository
	modelPicker modeldomain.ModelPicker
	keyProvider apikeydomain.KeyProvider
	llmFactory  *llminfra.Factory
	tools       []toolapp.Tool
	bridge      eventsdomain.Bridge
	emitter     eventlogpkg.Emitter // event-log Phase 2: dual-write Bridge alongside legacy bridge
	dataDir     string
	log         *zap.Logger
	queues      sync.Map // conversationID → *convQueue

	// catalog (optional) provides the Capability Catalog summary that
	// gets prepended to every system prompt. Nil-tolerant: when not
	// wired (unit tests, environments without the catalog subsystem),
	// the system prompt skips the catalog block. Set via
	// SetSystemPromptProvider after construction (post-injection avoids
	// a circular dep — catalog imports chat would create one).
	//
	// catalog（可选）提供 Capability Catalog summary，前置每个 system
	// prompt。容忍 nil（单测、无 catalog 环境跳）。SetSystemPromptProvider
	// 后置注入避循环依赖（catalog import chat 就会循环）。
	catalog catalogdomain.SystemPromptProvider
}

// NewService wires Service dependencies. Panics on nil logger.
//
// emitter is the event-log Emitter used for the dual-write protocol
// (Phase 2). Pass a no-op emitter (or nil → falls back to no-op) when
// the new bridge is not desired (legacy-only tests).
//
// NewService 装配依赖。nil logger 立刻 panic。
//
// emitter 是事件日志协议（Phase 2 dual-write）的 Emitter。不需要新
// bridge 时传 no-op（或传 nil 回退到 no-op，遗留单测路径）。
func NewService(
	repo chatdomain.Repository,
	convRepo convdomain.Repository,
	modelPicker modeldomain.ModelPicker,
	keyProvider apikeydomain.KeyProvider,
	llmFactory *llminfra.Factory,
	bridge eventsdomain.Bridge,
	emitter eventlogpkg.Emitter,
	dataDir string,
	log *zap.Logger,
) *Service {
	if log == nil {
		panic("chat.NewService: logger is nil")
	}
	if dataDir == "" {
		dataDir = filepath.Join(os.TempDir(), "forgify")
	}
	if emitter == nil {
		emitter = eventlogpkg.From(context.Background()) // no-op fallback
	}
	return &Service{
		repo:        repo,
		convRepo:    convRepo,
		modelPicker: modelPicker,
		keyProvider: keyProvider,
		llmFactory:  llmFactory,
		bridge:      bridge,
		emitter:     emitter,
		dataDir:     dataDir,
		log:         log,
	}
}

// emitUserMessage publishes the user message_start + each block + message_stop
// to the new event-log bridge as a self-contained burst. User messages are
// not streamed (saved synchronously in Send), so all five events fire at
// once. Best-effort: any failure logs and continues — legacy bridge still
// works for the message itself via the existing chat.message snapshot path.
//
// emitUserMessage 把 user message_start + 每个 block + message_stop 一次性
// burst 推到新事件日志 bridge。user message 不是流式（Send 中同步落库），
// 5 个事件一次性发完。Best-effort：失败 log 后继续——legacy bridge 通过
// chat.message 快照路径仍能传 user message。
func (s *Service) emitUserMessage(ctx context.Context, msg *chatdomain.Message) {
	em := s.emitter
	em.EmitMessageStart(ctx, msg.ID, msg.Role, "", nil)
	for _, b := range msg.Blocks {
		em.EmitBlockStart(ctx, b.ID, msg.ID, msg.ID, b.Type, nil)
		// For text blocks, push the text as a single delta. Other types
		// (attachment_ref) carry no streaming content — the metadata
		// lives in attrs / DB row, not in delta text.
		//
		// 文本 block 把文本作为单条 delta 推。其他类型（attachment_ref）
		// 无流式正文——元数据在 attrs / DB 行，不在 delta 文本里。
		if b.Type == chatdomain.BlockTypeText {
			var td chatdomain.TextData
			if err := json.Unmarshal([]byte(b.Data), &td); err == nil && td.Text != "" {
				em.DeltaBlock(ctx, b.ID, td.Text)
			}
		}
		em.StopBlock(ctx, b.ID, eventlogdomain.StatusCompleted, nil)
	}
	em.StopMessage(ctx, msg.ID, eventlogdomain.StatusCompleted, "", "", "", 0, 0)
}

// SetTools injects system tools into the ReAct Agent.
// Safe to call before any conversation starts.
//
// SetTools 将 system tools 注入 ReAct Agent，在任何对话启动前调用均安全。
func (s *Service) SetTools(tools []toolapp.Tool) {
	s.tools = tools
}

// SetSystemPromptProvider plugs the Capability Catalog (or any
// implementation of catalogdomain.SystemPromptProvider) so its summary
// gets prepended to every conversation's system prompt. Safe to leave
// nil — buildSystemPrompt skips the catalog block when not wired.
// Call after main.go constructs the catalog Service.
//
// SetSystemPromptProvider 接 Capability Catalog（或任何
// catalogdomain.SystemPromptProvider 实现）让其 summary 前置每个对话
// system prompt。留 nil 安全——buildSystemPrompt 在未接时跳。main.go 构
// 造 catalog Service 后调。
func (s *Service) SetSystemPromptProvider(p catalogdomain.SystemPromptProvider) {
	s.catalog = p
}

// SendInput is the payload for Service.Send.
//
// SendInput 是 Service.Send 的请求载荷。
type SendInput struct {
	Content       string
	AttachmentIDs []string
}

// UploadAttachment copies fileBytes to the data directory, stores metadata
// in DB, and returns the created Attachment.
//
// UploadAttachment 把 fileBytes 复制到 data 目录，把元数据存入 DB，返回创建好的 Attachment。
func (s *Service) UploadAttachment(ctx context.Context, fileBytes []byte, mimeType, fileName string) (*chatdomain.Attachment, error) {
	if int64(len(fileBytes)) > chatdomain.MaxAttachmentBytes {
		return nil, chatdomain.ErrAttachmentTooLarge
	}
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, fmt.Errorf("chat.Service.UploadAttachment: %w", err)
	}

	id := newAttachmentID()
	ext := filepath.Ext(fileName)
	storageDir := filepath.Join(s.dataDir, "attachments", id)
	storagePath := filepath.Join(storageDir, "original"+ext)

	if err := os.MkdirAll(storageDir, 0750); err != nil {
		return nil, fmt.Errorf("chat.Service.UploadAttachment: mkdir: %w", err)
	}
	if err := os.WriteFile(storagePath, fileBytes, 0640); err != nil {
		return nil, fmt.Errorf("chat.Service.UploadAttachment: write: %w", err)
	}

	a := &chatdomain.Attachment{
		ID:          id,
		UserID:      uid,
		FileName:    fileName,
		MimeType:    mimeType,
		SizeBytes:   int64(len(fileBytes)),
		StoragePath: storagePath,
	}
	if err := s.repo.SaveAttachment(ctx, a); err != nil {
		if cleanErr := os.RemoveAll(storageDir); cleanErr != nil {
			s.log.Warn("failed to clean up attachment directory after save error",
				zap.String("dir", storageDir), zap.Error(cleanErr))
		}
		return nil, err
	}
	return a, nil
}

// Send saves the user message (with attachment_ref blocks) and enqueues an
// Agent task. Returns immediately with the user message ID (202 semantics).
// Returns ErrStreamInProgress only when the queue is full.
//
// Send 保存用户消息（含 attachment_ref blocks）并把 Agent 任务加入队列，立刻返回
// 用户消息 ID（202 语义）。仅在队列已满时返回 ErrStreamInProgress。
func (s *Service) Send(ctx context.Context, conversationID string, in SendInput) (string, error) {
	conv, err := s.convRepo.Get(ctx, conversationID)
	if err != nil {
		return "", err
	}
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return "", fmt.Errorf("chat.Service.Send: %w", err)
	}

	blocks, err := s.buildUserBlocks(ctx, in)
	if err != nil {
		return "", fmt.Errorf("chat.Service.Send: build blocks: %w", err)
	}

	msgID := newMsgID()
	userMsg := &chatdomain.Message{
		ID:             msgID,
		ConversationID: conversationID,
		UserID:         uid,
		Role:           chatdomain.RoleUser,
		Status:         chatdomain.StatusCompleted,
		Blocks:         blocks,
	}
	if err := s.repo.Save(ctx, userMsg); err != nil {
		return "", err
	}

	// Event-log dual-write: emit the user message burst. Bridge needs
	// conversationID via reqctx; ctx from the HTTP layer doesn't carry
	// it, so we stamp here.
	//
	// 事件日志 dual-write：burst 推 user message。Bridge 经 reqctx 取
	// conversationID；HTTP 层 ctx 不带，这里打。
	emitCtx := reqctxpkg.WithConversationID(ctx, conversationID)
	emitCtx = eventlogpkg.With(emitCtx, s.emitter)
	s.emitUserMessage(emitCtx, userMsg)

	agentCtx := reqctxpkg.SetUserID(context.Background(), uid)
	agentCtx = reqctxpkg.SetLocale(agentCtx, reqctxpkg.GetLocale(ctx))

	q := s.getOrCreateQueue(conversationID)
	task := queuedTask{ctx: agentCtx, conv: conv, uid: uid, userMsgID: msgID}
	select {
	case q.ch <- task:
	default:
		return "", chatdomain.ErrStreamInProgress
	}

	s.log.Info("chat task enqueued",
		zap.String("conversation_id", conversationID),
		zap.String("user_message_id", msgID),
		zap.Int("queue_depth", len(q.ch)))
	return msgID, nil
}

// buildUserBlocks constructs the block slice for a user message.
// Attachment blocks are populated with full metadata from the DB so the
// frontend can display filenames and icons without extra API calls.
//
// buildUserBlocks 构建 user 消息的 block 列表。
// 附件 block 从 DB 查询完整元数据，前端无需额外 API 调用即可展示文件名和图标。
func (s *Service) buildUserBlocks(ctx context.Context, in SendInput) ([]chatdomain.Block, error) {
	var blocks []chatdomain.Block
	seq := 0

	if in.Content != "" {
		d, _ := json.Marshal(chatdomain.TextData{Text: in.Content})
		blocks = append(blocks, chatdomain.Block{
			ID: newBlockID(), Seq: seq, Type: chatdomain.BlockTypeText, Data: string(d),
		})
		seq++
	}

	for _, attID := range in.AttachmentIDs {
		att, err := s.repo.GetAttachment(ctx, attID)
		if err != nil {
			return nil, fmt.Errorf("buildUserBlocks: attachment %q not found: %w", attID, err)
		}
		d, _ := json.Marshal(chatdomain.AttachmentRefData{
			AttachmentID: attID,
			FileName:     att.FileName,
			MimeType:     att.MimeType,
		})
		blocks = append(blocks, chatdomain.Block{
			ID: newBlockID(), Seq: seq, Type: chatdomain.BlockTypeAttachmentRef, Data: string(d),
		})
		seq++
	}
	return blocks, nil
}

// Cancel stops the currently running Agent and drains any pending tasks.
//
// Cancel 停止当前正在运行的 Agent 并清空队列中待处理的任务。
func (s *Service) Cancel(_ context.Context, conversationID string) error {
	v, ok := s.queues.Load(conversationID)
	if !ok {
		return chatdomain.ErrStreamNotFound
	}
	q := v.(*convQueue)
	q.mu.Lock()
	cancel := q.cancel
	q.mu.Unlock()
	if cancel == nil {
		return chatdomain.ErrStreamNotFound
	}
	cancel()
	for {
		select {
		case <-q.ch:
		default:
			return nil
		}
	}
}

// ListMessages returns a paginated list of messages (with Blocks) for the conversation.
//
// ListMessages 返回对话的分页消息列表（含 Blocks）。
func (s *Service) ListMessages(ctx context.Context, conversationID string, filter chatdomain.ListFilter) ([]*chatdomain.Message, string, error) {
	return s.repo.ListByConversation(ctx, conversationID, filter)
}
