// Package aispawn opens an AI working conversation pre-seeded with context — the engine behind the
// :iterate and :triage verbs. Both verbs reduce
// to "open a conversation that already carries the relevant context, then let the normal chat loop
// work": iterate seeds an ENTITY (function / handler / agent / workflow / document) via an
// @-mention so its current definition is frozen into the first message; triage seeds an EXECUTION
// RECORD (any kind — function / handler / agent / flowrun) by rendering it into the system prompt.
// It owns no context-building of its own: iterate reuses the existing mention resolvers, triage
// reuses the existing execution-detail reads (via the ExecutionRenderer port).
//
// Package aispawn 开一个预置上下文的 AI 工作对话——`:iterate` 与 `:triage` 动词的引擎。
// 两个动词都归约成「开一个已携带相关上下文的对话、再让普通 chat loop 干活」：iterate 经 @-mention 种一个**实体**
// （其当前定义冻结进首条消息）；triage 把一条**执行记录**（任意类型——function/handler/agent/flowrun）渲进 system
// prompt。它自己不造任何上下文：iterate 复用现有 mention resolver，triage 复用现有执行详情读取（经 ExecutionRenderer 端口）。
package aispawn

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	mentiondomain "github.com/sunweilin/anselm/backend/internal/domain/mention"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Errors that bubble to HTTP (S20 — Kind→status + stable wire code).
//
// 冒泡到 HTTP 的错误（S20——Kind→status + 稳定 wire code）。
var ErrEmptyRequest = errorspkg.New(errorspkg.KindInvalid, "EMPTY_ITERATE_REQUEST", "iterate needs a request describing what to change")

// ----- DIP ports: aispawn composes conversation + chat + execution reads, depending only on
// capabilities so it stays testable with fakes. -----
//
// ----- DIP 端口：aispawn 组合 conversation + chat + 执行读取，只依赖能力，故可用 fake 测。-----

// ConversationStarter opens a fresh conversation pre-stamped with a system prompt. convapp's
// CreateWithSystemPrompt satisfies it (a bootstrap adapter unwraps the id).
//
// ConversationStarter 开一个预置 system prompt 的新对话。convapp 的 CreateWithSystemPrompt 满足之（bootstrap 适配器拆出 id）。
type ConversationStarter interface {
	StartSeeded(ctx context.Context, systemPrompt string) (conversationID string, err error)
}

// TurnSender sends the first user turn (carrying @-mentions) which kicks off the chat loop. The
// chatapp.Service satisfies it via a bootstrap adapter (wraps chat.Send with a SendInput).
//
// TurnSender 发首条用户回合（携 @-mention）以触发 chat loop。chatapp.Service 经 bootstrap 适配器满足（包 chat.Send）。
type TurnSender interface {
	SendSeed(ctx context.Context, conversationID, content string, mentions []mentiondomain.MentionInput) (messageID string, err error)
}

// ExecutionRenderer renders any execution record (resolved by its id prefix) into prompt text —
// triage's context source. The bootstrap adapter prefix-dispatches to the right service's detail
// read and serializes it, so adding an execution type is one more branch, not a new prose template.
//
// ExecutionRenderer 把任意执行记录（按 id 前缀解析）渲成 prompt 文本——triage 的上下文源。bootstrap 适配器按前缀
// 分发到对的 service 详情读取并序列化，故新增执行类型是多一个分支、而非新 prose 模板。
type ExecutionRenderer interface {
	Render(ctx context.Context, executionID string) (string, error)
}

// Service is the iterate/triage engine.
//
// Service 是 iterate/triage 引擎。
type Service struct {
	conv     ConversationStarter
	chat     TurnSender
	renderer ExecutionRenderer
	log      *zap.Logger
}

func NewService(conv ConversationStarter, chat TurnSender, renderer ExecutionRenderer, log *zap.Logger) *Service {
	if conv == nil || chat == nil {
		panic("aispawn.New: nil conversation starter or turn sender")
	}
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{conv: conv, chat: chat, renderer: renderer, log: log.Named("aispawn")}
}

// iterateSteer is the one generic instruction for every iterate flow — the entity's current
// definition arrives via the @-mention on the first message, so this needs no per-entity prose.
//
// iterateSteer 是每个 iterate 流共用的一句通用引导——实体当前定义经首条消息的 @-mention 到达，故无需 per-entity prose。
const iterateSteer = "You are helping the user iterate on the Anselm entity they have @-mentioned " +
	"in the message below — its current definition is attached to that mention. Read it, briefly " +
	"explain your plan, then call the matching edit_* tool (edit_function / edit_handler / edit_agent " +
	"/ edit_workflow / edit_document) with that entity's id to produce a pending version the user will " +
	"review. Do NOT call any create_* tool, and do NOT modify any other entity. After the edit " +
	"succeeds, summarize what changed."

// triageSteer is the one generic instruction for every triage flow — the rendered execution record
// is appended after it.
//
// triageSteer 是每个 triage 流共用的一句通用引导——渲染出的执行记录拼在其后。
const triageSteer = "You are helping the user diagnose a Anselm execution. The execution record is " +
	"below. Analyze what happened — which step or call went wrong, what any error means, whether " +
	"inputs and outputs line up. Use the read/search tools to dig into the underlying function / " +
	"handler / agent / workflow if you need more context. Explain the root cause in plain language. " +
	"If you can propose a fix, call the matching edit_* tool to produce a pending version (the user " +
	"reviews and retries manually). Do NOT auto-rerun anything; do NOT create new entities."

// Iterate opens an AI working conversation to edit one entity: the entity is @-mentioned into the
// first message (its current definition frozen in by the mention resolver) and the LLM is steered
// to call the matching edit_* tool. Returns the new conversation id (the turn streams over SSE).
//
// Iterate 开一个 AI 工作对话以编辑一个实体：该实体被 @-mention 进首条消息（其当前定义经 mention resolver 冻结进来），
// LLM 被引导去调对应 edit_* 工具。返回新对话 id（回合经 SSE 流式）。
func (s *Service) Iterate(ctx context.Context, mentionType mentiondomain.MentionType, entityID, request string) (string, error) {
	if request == "" {
		return "", ErrEmptyRequest
	}
	return s.spawn(ctx, iterateSteer, request, []mentiondomain.MentionInput{{Type: mentionType, ID: entityID}})
}

// Triage opens an AI working conversation to diagnose one execution record: the record (resolved by
// its id prefix — function / handler / agent / flowrun) is rendered into the system prompt and the
// LLM is steered to find the root cause and optionally propose a fix. Returns the conversation id.
//
// Triage 开一个 AI 工作对话以诊断一条执行记录：该记录（按 id 前缀解析——function/handler/agent/flowrun）渲进 system
// prompt，LLM 被引导找根因并可选地提 fix。返回对话 id。
func (s *Service) Triage(ctx context.Context, executionID, note string) (string, error) {
	if s.renderer == nil {
		return "", fmt.Errorf("aispawn.Triage: no execution renderer wired")
	}
	render, err := s.renderer.Render(ctx, executionID)
	if err != nil {
		return "", err
	}
	systemPrompt := triageSteer + "\n\n=== Execution record ===\n" + render
	message := note
	if message == "" {
		message = "Please diagnose this execution."
	}
	return s.spawn(ctx, systemPrompt, message, nil)
}

// spawn creates the seeded conversation, then sends the first turn (which starts the chat loop).
// The conversation is kept even if the send fails — the user can retype in the chat UI.
//
// spawn 建预置对话、再发首条回合（启动 chat loop）。send 失败也保留对话——用户可在聊天 UI 重打。
func (s *Service) spawn(ctx context.Context, systemPrompt, firstMessage string, mentions []mentiondomain.MentionInput) (string, error) {
	convID, err := s.conv.StartSeeded(ctx, systemPrompt)
	if err != nil {
		return "", fmt.Errorf("aispawn.spawn: %w", err)
	}
	if firstMessage == "" && len(mentions) == 0 {
		return convID, nil
	}
	if _, err := s.chat.SendSeed(ctx, convID, firstMessage, mentions); err != nil {
		s.log.Warn("aispawn.spawn: seed send failed; conversation kept", zap.String("conversationId", convID), zap.Error(err))
		return convID, fmt.Errorf("aispawn.spawn: %w", err)
	}
	return convID, nil
}
