// Package subagent is the recursive-subconversation engine: the Subagent (Task) tool and
// fork-mode skills call Spawn to run an isolated sub-agent over a focused task and get its final
// answer back synchronously. A subagent ≈ a recursive chat: it owns no table (its turn persists
// as a sub-message in the PARENT conversation, tagged SubagentID, its blocks nested under the
// spawning tool_call via E3), inherits the parent's effective (workspace dialogue) model, and
// cannot spawn further subagents (depth 1). It reuses the shared ReAct engine (app/loop) with a
// hybrid host: agentHost's prompt-history + static tool whitelist, plus chatHost's persist +
// message_stop on a detached context.
//
// Package subagent 是递归子对话引擎：Subagent（Task）工具与 fork 模式 skill 调 Spawn 在一段聚焦任务
// 上跑隔离子 agent 并同步拿回最终答案。subagent ≈ 递归 chat：无自己的表（回合作为 sub-message 落
// 父对话、带 SubagentID、blocks 经 E3 嵌派它的 tool_call 下），承袭父 effective（workspace dialogue）
// 模型，且不能再派 subagent（深度 1）。它复用共享 ReAct 引擎（app/loop）配混血 host：agentHost 的
// prompt 历史 + 静态工具白名单，加 chatHost 的 detached 落盘 + message_stop。
package subagent

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	agentstatepkg "github.com/sunweilin/anselm/backend/internal/pkg/agentstate"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// attrParentBlockID is the sub-message Attrs key holding the spawning tool_call's block id —
// the anchor a reload uses to nest the subagent subtree under its tool_call (the live stream
// carries the same link as the message node's Open.ParentID).
//
// attrParentBlockID 是 sub-message Attrs 里存派它的 tool_call block id 的键——reload 据此把
// subagent 子树嵌在其 tool_call 下（live 流由 message 节点的 Open.ParentID 携同一链接）。
const attrParentBlockID = "parentBlockId"

// Bundle is a ready-to-run LLM client + pre-filled base Request, self-contained so subagent
// doesn't import chatapp. The bootstrap resolver fills it (model.Resolve(ScenarioDialogue, …)).
//
// Bundle 是即用 LLM client + 预填 base Request，自包含使 subagent 不引 chatapp。由 bootstrap resolver 解析。
type Bundle struct {
	Client   llminfra.Client
	Request  llminfra.Request
	Provider string
}

// ----- DIP ports -----

// ModelResolver yields the model a subagent runs on — the workspace dialogue model, which is the
// parent's effective model in the common (no per-conversation override) case. Inheriting an
// explicit conv.ModelOverride is deferred (it would cross the pkg→domain boundary in reqctx).
//
// ModelResolver 给出 subagent 跑的模型——workspace dialogue 模型，在常见（无 per-conversation
// override）情形即父的 effective model。承袭显式 conv.ModelOverride 延后（会越 reqctx 的 pkg→domain）。
type ModelResolver interface {
	Resolve(ctx context.Context) (Bundle, error)
}

// ToolsProvider returns the parent tool set a subagent's type filters down from. What it
// contains (resident-only vs full) is the wiring's call; filterTools just applies the
// per-type allow-list + strips the Subagent tool.
//
// ToolsProvider 返回 subagent 类型据以过滤的父工具集。它含什么（仅 resident vs 全量）由装配定；
// filterTools 只套类型白名单 + 剔 Subagent 工具。
type ToolsProvider interface {
	Tools() []toolapp.Tool
}

// Deps are subagent's injected collaborators (DIP). Messages persists the sub-message; Resolver
// resolves the model; Tools is the parent registry; Bridge is the messages stream (nil → no live
// push, REST history still works).
//
// Deps 是 subagent 注入的协作者（DIP）。Messages 落 sub-message；Resolver 解析模型；Tools 是父注册表；
// Bridge 是 messages 流（nil → 无 live 推、REST 历史仍在）。
type Deps struct {
	Messages messagesdomain.Repository
	Resolver ModelResolver
	Tools    ToolsProvider
	Bridge   streamdomain.Bridge
}

// Service runs subagents. It satisfies skilldomain.SubagentRunner so skill fork can dispatch
// through it, and the Subagent tool calls the same Spawn.
//
// Service 跑 subagent。它满足 skilldomain.SubagentRunner 使 skill fork 经它派发，Subagent 工具调同一 Spawn。
type Service struct {
	deps   Deps
	search searchdomain.Notifier // nil → search indexing disabled. nil → 不接搜索索引。
	reg    *Registry
	log    *zap.Logger
}

// New constructs the Service. nil log → no-op logger.
//
// New 构造 Service。nil log → no-op logger。
func NewService(deps Deps, log *zap.Logger) *Service {
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{deps: deps, reg: NewRegistry(), log: log.Named("subagentapp")}
}

var _ skilldomain.SubagentRunner = (*Service)(nil)

// Registry exposes the built-in type registry (the Subagent tool reads Names() for its enum).
//
// Registry 暴露内置类型注册表（Subagent 工具读 Names() 作 enum）。
func (s *Service) Registry() *Registry { return s.reg }

// Spawn runs one subagent over prompt and returns its final answer. Synchronous: it builds the
// hybrid host, runs the ReAct loop, and the host persists the sub-message + streams it. A bad
// type / model-resolve error returns an error string the caller surfaces as the tool_result (no
// HTTP error — subagent failures are tool-level, not request-level). Recursion is refused here
// too (defense in depth; the Subagent tool also guards).
//
// Spawn 在 prompt 上跑一个 subagent 并返回最终答案。同步：构造混血 host、跑 ReAct 循环，host 落
// sub-message + 推流。坏类型 / 模型解析错返 error 串、由调用方作 tool_result 暴露（无 HTTP 错——
// subagent 失败是工具级、非请求级）。递归在此也拒（防御纵深；Subagent 工具亦守卫）。
func (s *Service) Spawn(ctx context.Context, agentType, prompt string) (string, error) {
	if _, inSub := reqctxpkg.GetSubagentID(ctx); inSub {
		return "", fmt.Errorf("subagent: a subagent cannot spawn another subagent")
	}
	typ, ok := s.reg.Get(agentType)
	if !ok {
		return "", fmt.Errorf("subagent: unknown type %q (have %v)", agentType, s.reg.Names())
	}

	bundle, err := s.deps.Resolver.Resolve(ctx)
	if err != nil {
		return "", fmt.Errorf("subagent: resolve model: %w", err)
	}

	var parentTools []toolapp.Tool
	if s.deps.Tools != nil {
		parentTools = s.deps.Tools.Tools()
	}
	tools := filterTools(typ, parentTools)

	convID, _ := reqctxpkg.GetConversationID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx) // the spawning tool_call — E3 anchor (empty for a fork skill not under a tool_call)
	runID := idgenpkg.New("subagt")
	subMsgID := idgenpkg.New("msg")

	// Open the sub-message (streaming) so its id anchors the live stream + persists the turn,
	// then emit message_start under the spawning tool_call (E3).
	//
	// 开 sub-message（streaming）使其 id 锚 live 流 + 落盘回合，再在派它的 tool_call 下发 message_start（E3）。
	subMsg := &messagesdomain.Message{
		ID:             subMsgID,
		ConversationID: convID,
		SubagentID:     runID,
		Role:           messagesdomain.RoleAssistant,
		Status:         messagesdomain.StatusStreaming,
		Provider:       bundle.Provider,
		ModelID:        bundle.Request.ModelID,
	}
	if toolCallID != "" {
		subMsg.Attrs = map[string]any{attrParentBlockID: toolCallID}
	}
	if err := s.deps.Messages.CreateMessage(ctx, subMsg, nil); err != nil {
		return "", fmt.Errorf("subagent: open sub-message: %w", err)
	}
	s.emitMessageStart(ctx, convID, subMsgID, toolCallID)

	// Sub-run context: mark it a subagent (recursion guard + todo scope), a fresh AgentState
	// (no SeenFiles/discovered pollution of the parent), and MessageID = subMsgID so loop's
	// blocks nest under the sub-message. Bridge / conversation / workspace / locale are inherited.
	//
	// 子运行 ctx：标记 subagent（递归守卫 + todo 作用域）、全新 AgentState（不污染父 SeenFiles/
	// discovered）、MessageID = subMsgID 使 loop 的 block 挂 sub-message 下。Bridge / conversation /
	// workspace / locale 继承。
	subCtx := reqctxpkg.SetSubagentID(ctx, runID)
	subCtx = reqctxpkg.WithAgentState(subCtx, agentstatepkg.New())
	subCtx = reqctxpkg.SetMessageID(subCtx, subMsgID)

	host := &subagentHost{
		svc:            s,
		conversationID: convID,
		subMsg:         subMsg,
		userPrompt:     prompt,
		systemPrompt:   composeSystemPrompt(typ, reqctxpkg.GetLocale(ctx)),
		tools:          tools,
	}
	req := bundle.Request
	req.System = host.systemPrompt

	// Own whole-run wall clock (F152). Unlike chat (processTask's ChatTurnSec) and agent invoke
	// (runLoop's AgentInvokeSec), Spawn calls loop.Run DIRECTLY — loop.Run has no time bound of its
	// own (only maxSteps + the provider's per-stream cap), so without this the subagent is bounded
	// ONLY by inheriting the parent chat turn's deadline. We reuse ChatTurnSec (same budget the parent
	// already grants), so the common path sees no change; the explicit bound is defense-in-depth that
	// keeps a subagent finite even if a future path (scheduler/fork) reaches Spawn without a parent
	// turn deadline. A timed-out run finalizes cancelled and annotateTerminal surfaces the cutoff.
	//
	// 自有整运行墙钟（F152）。不同于 chat（processTask 的 ChatTurnSec）和 agent invoke（runLoop 的
	// AgentInvokeSec），Spawn **直接**调 loop.Run——loop.Run 自身无时间界（只 maxSteps + provider 单流
	// cap），故没这道时 subagent 仅靠继承父 chat 回合 deadline 兜。复用 ChatTurnSec（父本就给的预算）故
	// 常规路径零变化；显式界是防御纵深，使未来从无父回合 deadline 的路径（scheduler/fork）到达 Spawn 时
	// subagent 仍有限。超时 run 收尾为 cancelled，annotateTerminal 浮出截断。
	runCtx, cancel := context.WithTimeout(subCtx, time.Duration(limitspkg.Current().Timeout.ChatTurnSec)*time.Second)
	defer cancel()

	result := loopapp.Run(runCtx, host, bundle.Client, req, typ.DefaultMaxTurns, s.log)
	return annotateTerminal(result), nil
}

// annotateTerminal returns the subagent's final text, prefixed with the terminal condition when the
// run did NOT finish cleanly (error / cancelled / max_steps). The Subagent tool_result otherwise reads
// as a clean completion carrying only the subagent's preamble text — hiding from the parent (and the
// parent LLM) that the work was cut short, so the parent treats a partial/failed answer as
// authoritative (F150). On a clean completion the text passes through unchanged.
//
// annotateTerminal 返回 subagent 终答；run **非干净收尾**（error/cancelled/max_steps）时前缀终态原因。否则
// Subagent tool_result 读着像干净完成、只带 subagent preamble 文本——向父（及父 LLM）隐藏工作被截断，使父
// 把部分/失败的答案当权威（F150）。干净完成则文本原样透传。
func annotateTerminal(result loopapp.Result) string {
	if result.Status == messagesdomain.StatusCompleted {
		return result.LastMessage
	}
	reason := result.StopReason
	if result.ErrMsg != "" {
		reason = result.ErrMsg
	}
	if reason == "" {
		reason = result.Status
	}
	note := fmt.Sprintf("[subagent did not finish cleanly (%s) — its answer below is partial, not authoritative]", reason)
	if result.LastMessage == "" {
		return note
	}
	return note + "\n\n" + result.LastMessage
}
