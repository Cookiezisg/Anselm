// Package askai is the shared AI orchestration layer for the ask-ai endpoints
// (forges :iterate and flowruns :triage). It spawns a user-visible conversation,
// stamps it with a context-rich system prompt, sends the first user message,
// and returns the conversation ID so frontend can subscribe to eventlog +
// forge stream for AI's reasoning + pending version creation.
//
// Package askai 是 ask-ai 端点（forges :iterate 和 flowruns :triage）共享的
// AI 编排层。起一个用户可见的对话、打上含上下文的 system prompt、发送首条
// 用户消息、返回 conversation ID 让前端订阅 eventlog + forge stream 看 AI
// 推理 + pending version 落地。
package askai

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	chatapp "github.com/sunweilin/forgify/backend/internal/app/chat"
	convapp "github.com/sunweilin/forgify/backend/internal/app/conversation"
)

// Spawner glues conversation + chat services for one-shot AI invocations.
//
// Spawner 把 conversation + chat 服务串起来做单发 AI 调用。
type Spawner struct {
	conv *convapp.Service
	chat *chatapp.Service
	log  *zap.Logger
}

// New constructs a Spawner; both services required.
//
// New 装配 Spawner；两个 service 都必填。
func New(conv *convapp.Service, chat *chatapp.Service, log *zap.Logger) *Spawner {
	if conv == nil {
		panic("askai.New: conversation service is nil")
	}
	if chat == nil {
		panic("askai.New: chat service is nil")
	}
	if log == nil {
		log = zap.NewNop()
	}
	return &Spawner{conv: conv, chat: chat, log: log.Named("askai")}
}

// SpawnInput is the request shape for both :iterate and :triage.
//
// SpawnInput 是 :iterate 和 :triage 共用的请求形状。
type SpawnInput struct {
	// SystemPrompt is the entity context + role guidance written into
	// Conversation.SystemPrompt; LLM sees it as a "user_systemPrompt" section
	// from turn 1.
	//
	// SystemPrompt 是 entity 上下文 + 角色指引，写进 Conversation.SystemPrompt；
	// LLM 从第 1 轮起把它当 "user_systemPrompt" section 看到。
	SystemPrompt string

	// UserPrompt is the first user message. Empty allowed — caller (triage)
	// may want LLM to start without prompting (system prompt alone is enough).
	// Empty UserPrompt skips the Send call entirely; frontend will see a
	// conversation with just the seed context, waiting for the user to type
	// in the chat UI.
	//
	// UserPrompt 是首条用户消息。允许为空——triage 场景中用户按按钮但没输入，
	// 系统提示自带"分析"指示足够。空时不调 Send，前端看到一个仅含 system 上下文
	// 的对话，等用户在聊天 UI 输入。
	UserPrompt string
}

// SpawnResult tells the caller where to find the new conversation; frontend
// subscribes /api/v1/eventlog (filtered client-side by conversationId).
//
// SpawnResult 告诉调用方新对话在哪；前端订阅 /api/v1/eventlog（按 conversationId 客户端 demux）。
type SpawnResult struct {
	ConversationID string `json:"conversationId"`
	UserMessageID  string `json:"userMessageId,omitempty"` // empty when UserPrompt was empty
}

// Spawn creates a new conversation pre-stamped with the system prompt, then
// optionally sends the first user message which kicks off the agent loop
// (chat.Send is async — returns 202 semantics after enqueueing).
//
// Spawn 创建带 system prompt 的新对话，然后可选地发送首条用户消息触发 agent 循环
// （chat.Send 是异步的——入队后立即返）。
func (sp *Spawner) Spawn(ctx context.Context, in SpawnInput) (*SpawnResult, error) {
	conv, err := sp.conv.CreateWithSystemPrompt(ctx, "", in.SystemPrompt)
	if err != nil {
		return nil, fmt.Errorf("askai.Spawn: %w", err)
	}
	out := &SpawnResult{ConversationID: conv.ID}
	if in.UserPrompt == "" {
		return out, nil
	}
	msgID, err := sp.chat.Send(ctx, conv.ID, chatapp.SendInput{Content: in.UserPrompt})
	if err != nil {
		// Don't roll back the conversation — user can still see it and retype
		// their prompt in the chat UI. Log the failure for debugging.
		sp.log.Warn("askai.Spawn: initial Send failed; conversation kept",
			zap.String("conversation_id", conv.ID), zap.Error(err))
		return out, fmt.Errorf("askai.Spawn: %w", err)
	}
	out.UserMessageID = msgID
	return out, nil
}
