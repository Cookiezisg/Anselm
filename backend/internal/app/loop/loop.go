// Package loop is the shared ReAct engine. chat and subagent consume it
// through the Host interface today; future phases (Phase 4 workflow LLM
// nodes) will join the same way. This is the single source of truth for
// stream → tool dispatch → history extension → finalize. No service-
// specific knowledge lives here.
//
// Package loop 是共享的 ReAct 引擎。chat / subagent 经 Host 接口使用，未来
// Phase（Phase 4 workflow LLM 节点）以同样方式接入。是 stream → 工具调度
// → 历史扩展 → 终态 这条链路的唯一事实源。本包不持有任何 service 特有知识。
package loop

import (
	"context"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// Host is the per-run hook surface. chat implements it via chatHost
// (writes the assistant Message row at terminal); subagent implements
// it via subagentHost (writes the sub-Message row with parent_block_id
// + attrs). Block writes happen real-time via the eventlog Emitter
// (pkg/eventlog) — Host is NOT involved in block persistence.
//
// Host 是每次 run 的钩子面。chat 通过 chatHost 实现（终态时写 assistant
// Message 行）；subagent 通过 subagentHost 实现（写 sub-Message 行含
// parent_block_id + attrs）。Block 写实时走 eventlog Emitter
// （pkg/eventlog）——Host 不参与 block 持久化。
type Host interface {
	// LoadHistory returns the LLM-wire history that seeds the first step.
	//
	// LoadHistory 返回种子第一步的 LLM 历史。
	LoadHistory(ctx context.Context) ([]llminfra.LLMMessage, error)

	// Tools returns the filtered tool registry for this run. chat returns
	// the global registry; subagent returns the type-filtered subset.
	//
	// Tools 返回本次 run 的已过滤 tool 列表。chat 返全局；subagent 返按
	// 类型过滤后的子集。
	Tools() []toolapp.Tool

	// WriteFinalize persists the terminal Message row + emits message_stop
	// to the eventlog Bridge. Hosts must use a detached context for the
	// persist write so a cancelled upstream ctx doesn't lose the terminal
	// record.
	//
	// WriteFinalize 持久化终态 Message 行 + 给 eventlog Bridge 发
	// message_stop。host 必须用 detached context 写盘防止上游 cancel 让
	// 终态丢失。
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

	var (
		allBlocks    []chatdomain.Block
		totalIn      int
		totalOut     int
		stopReason   = chatdomain.StopReasonEndTurn
		finalStatus  = chatdomain.StatusCompleted
		errCode      string
		errMsg       string
		finalWritten bool
		stepsRun     int
	)

	for step := range maxSteps {
		req := baseReq
		req.Messages = history

		stepsRun = step + 1

		aBlocks, toolCalls, sr, em, iT, oT := streamLLM(ctx, client, req)
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
			finalStatus = status
			host.WriteFinalize(ctx, allBlocks, status, stopReason, errCode, errMsg, totalIn, totalOut)
			finalWritten = true
			break
		}

		if len(toolCalls) == 0 {
			host.WriteFinalize(ctx, allBlocks, chatdomain.StatusCompleted, stopReason, "", "", totalIn, totalOut)
			finalWritten = true
			break
		}

		rBlocks := runTools(ctx, toolCalls, byName, log)
		allBlocks = append(allBlocks, rBlocks...)

		history, err = extendHistory(log, history, aBlocks, rBlocks)
		if err != nil {
			log.Error("extend history failed", zap.Error(err))
			stopReason = chatdomain.StopReasonError
			errCode = "HISTORY_EXTEND_FAILED"
			errMsg = err.Error()
			finalStatus = chatdomain.StatusError
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
		Status:      finalStatus,
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
