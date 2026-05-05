// Package loop is the shared ReAct engine. chat / subagent / Skill fork /
// Phase 4 workflow LLM nodes all consume it through the Host interface —
// this is the single source of truth for stream → tool dispatch → history
// extension → finalize. No service-specific knowledge lives here.
//
// Package loop 是共享的 ReAct 引擎。chat / subagent / Skill fork /
// Phase 4 workflow LLM 节点全部通过 Host 接口使用——是 stream → 工具调度
// → 历史扩展 → 终态 这条链路的唯一事实源。本包不持有任何 service 特有知识。
package loop

import (
	"context"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// Host is the per-run hook surface. chat implements it via chatHost (writes
// chat_messages, fires chat.message events for the conversation); subagent
// implements it via subagentHost (writes subagent_messages, fires
// chat.message events with subagentRun snapshot embedded).
//
// Host 是每次 run 的钩子面。chat 通过 chatHost 实现（写 chat_messages，
// 给对话发 chat.message 事件）；subagent 通过 subagentHost 实现（写
// subagent_messages，发带 subagentRun 快照的 chat.message 事件）。
type Host interface {
	// LoadHistory returns the LLM-wire history that seeds the first step.
	// LoadHistory 返回种子第一步的 LLM 历史。
	LoadHistory(ctx context.Context) ([]llminfra.LLMMessage, error)

	// Tools returns the filtered tool registry for this run. chat returns
	// the global registry; subagent returns the type-filtered subset
	// (Subagent itself excluded).
	//
	// Tools 返回本次 run 的已过滤 tool 列表。chat 返全局；subagent 返按类型
	// 过滤后的子集（Subagent 自身已排除）。
	Tools() []toolapp.Tool

	// Publish emits a snapshot-only event (no DB write). Called many times
	// per step from streamLLM (per LLM event) and runTools (per tool finish).
	// Status is typically "streaming"; tokens are running totals.
	//
	// Publish 推送一次快照事件（不落库）。streamLLM 的每个流事件 + runTools
	// 的每个 tool 完成都会调一次。status 通常是 "streaming"；tokens 是累计值。
	Publish(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int)

	// WriteCheckpoint persists the in-progress message and emits a snapshot
	// after each ReAct step's tools complete. status is always "streaming";
	// failures should warn-and-continue (don't block the loop).
	//
	// WriteCheckpoint 在每个 ReAct 步骤的 tools 完成后落盘 + 推快照。status
	// 恒为 "streaming"；失败应 warn-and-continue 不挡 loop。
	WriteCheckpoint(ctx context.Context, blocks []chatdomain.Block, in, out int)

	// WriteFinalize persists the terminal message + emits its snapshot.
	// Hosts must use a detached context for the persist write so a cancelled
	// upstream ctx doesn't lose the terminal record.
	//
	// WriteFinalize 持久化终态消息 + 推快照。host 必须用 detached context 写盘
	// 防止上游 cancel 让终态丢失。
	WriteFinalize(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int)
}

// Result is what loop.Run hands back to the caller.
//
// Result 是 loop.Run 给调用方的回执。
type Result struct {
	Blocks      []chatdomain.Block
	Status      string // completed / cancelled / error
	StopReason  string
	TokensIn    int
	TokensOut   int
	Steps       int
	LastMessage string // last assistant text content; subagent uses this as tool_result
}

// Run executes the ReAct loop. baseReq.System and baseReq.Messages are
// composed by Run (Messages from host.LoadHistory, Tools from host.Tools).
// maxSteps caps the loop; pass 20 for the chat default. log is required.
//
// Run 执行 ReAct 循环。baseReq.System 与 baseReq.Messages 由 Run 内部装配
// （Messages 来自 host.LoadHistory，Tools 来自 host.Tools）。maxSteps 是循环
// 上限，chat 默认传 20。log 必需。
func Run(
	ctx context.Context,
	host Host,
	client llminfra.Client,
	baseReq llminfra.Request,
	maxSteps int,
	log *zap.Logger,
) Result {
	if log == nil {
		log = zap.NewNop()
	}

	history, err := host.LoadHistory(ctx)
	if err != nil {
		host.WriteFinalize(ctx, nil,
			chatdomain.StatusError, chatdomain.StopReasonError,
			"INTERNAL_ERROR", "load history: "+err.Error(), 0, 0)
		return Result{Status: chatdomain.StatusError, StopReason: chatdomain.StopReasonError}
	}

	tools := host.Tools()
	baseReq.Tools = toolapp.ToLLMDefs(tools)
	byName := toolsByName(tools)

	// Initial publish — open the assistant slot in the UI.
	// 初始发布——打开前端的 assistant 槽位。
	host.Publish(ctx, nil, chatdomain.StatusStreaming, "", "", "", 0, 0)

	var (
		allBlocks    []chatdomain.Block
		totalIn      int
		totalOut     int
		stopReason   = chatdomain.StopReasonEndTurn
		errCode      string
		errMsg       string
		finalWritten bool
		stepsRun     int
	)

	for step := range maxSteps {
		req := baseReq
		req.Messages = history

		stepsRun = step + 1

		aBlocks, toolCalls, sr, em, iT, oT := streamLLM(ctx, client, req, host, allBlocks)
		allBlocks = append(allBlocks, aBlocks...)
		totalIn += iT
		totalOut += oT
		if sr != "" {
			stopReason = sr
		}

		if stopReason == chatdomain.StopReasonCancelled || stopReason == chatdomain.StopReasonError {
			status := chatdomain.StatusCancelled
			if stopReason == chatdomain.StopReasonError {
				status = chatdomain.StatusError
				errCode = "LLM_STREAM_ERROR"
				errMsg = em
			}
			host.WriteFinalize(ctx, allBlocks, status, stopReason, errCode, errMsg, totalIn, totalOut)
			finalWritten = true
			break
		}

		if len(toolCalls) == 0 {
			host.WriteFinalize(ctx, allBlocks, chatdomain.StatusCompleted, stopReason, "", "", totalIn, totalOut)
			finalWritten = true
			break
		}

		rBlocks := runTools(ctx, toolCalls, byName, host, allBlocks, log)
		allBlocks = append(allBlocks, rBlocks...)

		host.WriteCheckpoint(ctx, allBlocks, totalIn, totalOut)

		history, err = extendHistory(history, aBlocks, rBlocks)
		if err != nil {
			log.Error("extend history failed", zap.Error(err))
			stopReason = chatdomain.StopReasonError
			errCode = "HISTORY_EXTEND_FAILED"
			errMsg = err.Error()
			host.WriteFinalize(ctx, allBlocks, chatdomain.StatusError, stopReason, errCode, errMsg, totalIn, totalOut)
			finalWritten = true
			break
		}

		log.Debug("react step complete", zap.Int("step", step))
	}

	if !finalWritten {
		stopReason = chatdomain.StopReasonMaxTokens
		host.WriteFinalize(ctx, allBlocks, chatdomain.StatusCompleted, stopReason, "", "", totalIn, totalOut)
	}

	return Result{
		Blocks:      allBlocks,
		Status:      chatdomain.StatusCompleted,
		StopReason:  stopReason,
		TokensIn:    totalIn,
		TokensOut:   totalOut,
		Steps:       stepsRun,
		LastMessage: ExtractTextContent(allBlocks),
	}
}

// toolsByName indexes tools for O(1) dispatch lookup inside runTools.
// toolsByName 给 runTools 做 O(1) 派发查表。
func toolsByName(tools []toolapp.Tool) map[string]toolapp.Tool {
	m := make(map[string]toolapp.Tool, len(tools))
	for _, t := range tools {
		m[t.Name()] = t
	}
	return m
}
