// tools.go — Tool call execution within the ReAct loop.
// Calls are partitioned by IsConcurrencySafe: adjacent safe calls run in
// parallel batches; non-safe calls each get their own serial batch.
// Each call passes through ValidateInput + CheckPermissions before Execute.
//
// SSE: this file does NOT publish events directly. After each tool finishes,
// runTools publishes an updated chat.message snapshot via publishMessageSnapshot
// (parentBlocks + tool-result blocks accumulated so far). Mid-tool internal
// streaming (e.g. forge code generation) is published by the tool itself
// using its own domain event (forge), not chat.message.
//
// tools.go — ReAct 循环内的工具调用执行。
// 调用按 IsConcurrencySafe 分批：相邻 safe 调用合并并行 batch；non-safe 调用各自独立串行。
// 每个调用进 Execute 前先过 ValidateInput + CheckPermissions。
//
// SSE：本文件**不直接推事件**。每个 tool 跑完后，runTools 通过
// publishMessageSnapshot 推一次 chat.message 快照（parentBlocks + 已收集的
// tool-result blocks）。Tool 内部流（如 forge 代码生成）由 tool 自己用所属
// domain 事件（forge）推，不进 chat.message。
package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// runTools executes all tool calls grouped by concurrency safety, publishing
// a chat.message snapshot after each tool completes. parentBlocks are the
// blocks accumulated from earlier in this assistant message (text, tool calls)
// — snapshots prepend them so subscribers always see the full message-so-far.
//
// runTools 按并发安全性分组执行所有 tool 调用，每个 tool 跑完即推一次
// chat.message 快照。parentBlocks 是当前 assistant 消息已积累的 blocks
// （text、tool calls）——快照前置它们让订阅者始终看到完整 message-so-far。
func (s *Service) runTools(
	ctx context.Context,
	calls []chatdomain.ToolCallData,
	convID, msgID, uid string,
	parentBlocks []chatdomain.Block,
) []chatdomain.Block {
	if len(calls) == 0 {
		return nil
	}
	byName := s.toolsByName()
	batches := partitionByConcurrencySafety(calls, byName)

	blocks := make([]chatdomain.Block, len(calls))

	// Snapshot publish — guarded by a mutex so concurrent tool completions
	// don't race when reading the blocks slice. Reads are cheap (a slice copy
	// inside joinBlocks); the lock holds only during snapshot construction.
	//
	// 快照发布——加 mutex 保证并发 tool 完成时读 blocks 切片不竞争。
	// 读开销小（joinBlocks 内做 slice copy）；锁只在快照构造期间持有。
	var mu sync.Mutex
	publishProgress := func() {
		mu.Lock()
		current := make([]chatdomain.Block, len(blocks))
		copy(current, blocks)
		mu.Unlock()
		s.publishMessageSnapshot(ctx, msgID, convID, uid,
			joinBlocks(parentBlocks, current),
			chatdomain.StatusStreaming, "", "", "", 0, 0)
	}

	for _, b := range batches {
		if b.safe && len(b.items) > 1 {
			// Parallel batch.
			// 并行 batch。
			var wg sync.WaitGroup
			for _, item := range b.items {
				wg.Add(1)
				go func(it indexedCall) {
					defer wg.Done()
					blk := s.runOneTool(ctx, byName[it.tc.Name], it.tc, msgID, it.idx)
					mu.Lock()
					blocks[it.idx] = blk
					mu.Unlock()
					publishProgress()
				}(item)
			}
			wg.Wait()
		} else {
			// Serial batch (single non-safe call, or single safe call alone).
			// 串行 batch（单个 non-safe，或仅一个 safe）。
			for _, item := range b.items {
				blk := s.runOneTool(ctx, byName[item.tc.Name], item.tc, msgID, item.idx)
				mu.Lock()
				blocks[item.idx] = blk
				mu.Unlock()
				publishProgress()
			}
		}
	}
	return blocks
}

// runOneTool executes a single tool call: runs ValidateInput / CheckPermissions
// / Execute, returns the tool_result block. Never returns an error — failures
// become ok=false results so the LLM can react. Wall time and structured error
// message are captured into the block for later inspection / UI.
//
// runOneTool 执行单个 tool 调用：跑 ValidateInput / CheckPermissions / Execute，
// 返回 tool_result block。永不返 error——失败以 ok=false 结果呈现，让 LLM 可响应。
// wall time 与结构化错误消息一起记到 block，便于事后查看 / UI 展示。
func (s *Service) runOneTool(
	ctx context.Context,
	t toolapp.Tool,
	tc chatdomain.ToolCallData,
	msgID string,
	seq int,
) chatdomain.Block {
	argsJSON, _ := json.Marshal(tc.Arguments)

	toolCtx := reqctxpkg.WithMessageID(ctx, msgID)
	toolCtx = reqctxpkg.WithToolCallID(toolCtx, tc.ID)

	start := time.Now()
	output, errMsg, ok := s.executeTool(toolCtx, t, tc.Name, argsJSON)
	elapsedMs := time.Since(start).Milliseconds()

	d, _ := json.Marshal(chatdomain.ToolResultData{
		ToolCallID: tc.ID,
		OK:         ok,
		Result:     output,
		ErrorMsg:   errMsg,
		ElapsedMs:  elapsedMs,
	})
	return chatdomain.Block{
		ID:        newBlockID(),
		Seq:       seq,
		Type:      chatdomain.BlockTypeToolResult,
		Data:      string(d),
		CreatedAt: time.Now().UTC(),
	}
}

// executeTool runs the tool's pre-Execute hooks (ValidateInput,
// CheckPermissions) then Execute, returning (output, errMsg, ok). On success
// errMsg is ""; on failure errMsg holds the structured failure reason and
// output may be either an LLM-facing fallback string or the same as errMsg.
// Phase 3: mode is hardcoded to PermissionModeDefault; Phase 4+ scheduler
// will pass real modes.
//
// executeTool 跑 tool 的 pre-Execute 钩子（ValidateInput, CheckPermissions）
// 然后 Execute，返回 (output, errMsg, ok)。成功 errMsg 为 ""；失败时 errMsg
// 存结构化失败原因，output 可能是给 LLM 的 fallback 字符串或与 errMsg 一致。
// Phase 3 mode 硬编码 PermissionModeDefault；Phase 4+ scheduler 才传真 mode。
func (s *Service) executeTool(ctx context.Context, t toolapp.Tool, name string, argsJSON []byte) (string, string, bool) {
	if t == nil {
		msg := fmt.Sprintf("tool %q not found", name)
		return msg, msg, false
	}

	if err := t.ValidateInput(argsJSON); err != nil {
		s.log.Warn("tool validate failed",
			zap.String("tool", name), zap.Error(err))
		return fmt.Sprintf("input validation failed: %s", err.Error()), err.Error(), false
	}

	switch t.CheckPermissions(argsJSON, toolapp.PermissionModeDefault) {
	case toolapp.PermissionDeny:
		s.log.Warn("tool permission denied",
			zap.String("tool", name))
		return "permission denied for this call", "permission denied", false
	case toolapp.PermissionAsk:
		// Phase 4+ scheduler with user-gating UI will treat Ask as a real
		// suspension. Phase 3 falls through (treat as Allow) — single-user
		// local desktop has nobody to ask in real time anyway.
		//
		// Phase 4+ 带用户审批 UI 的 scheduler 会把 Ask 当真的挂起处理。
		// Phase 3 落到 Allow——单用户本地桌面也没有真实询问通道。
	}

	output, err := t.Execute(ctx, string(argsJSON))
	if err != nil {
		s.log.Warn("tool execute failed",
			zap.String("tool", name), zap.Error(err))
		if output != "" {
			return output, err.Error(), false
		}
		return err.Error(), err.Error(), false
	}
	return output, "", true
}

// ── Concurrency partitioning ──────────────────────────────────────────────────

// indexedCall pairs a tool call with its original index in the calls slice
// so block ordering survives parallel scheduling.
//
// indexedCall 把 tool 调用与其在原 calls slice 的索引绑定，
// 让 block 顺序在并行调度后仍能还原。
type indexedCall struct {
	idx int
	tc  chatdomain.ToolCallData
}

// concurrencyBatch is one execution group: either parallel (safe) or serial.
//
// concurrencyBatch 是一个执行组：要么并行（safe）要么串行。
type concurrencyBatch struct {
	safe  bool
	items []indexedCall
}

// partitionByConcurrencySafety groups calls into batches where adjacent
// IsConcurrencySafe calls merge for parallel execution and non-safe calls
// each get a singleton serial batch.
//
// Example: calls [A=safe, B=safe, C=unsafe, D=safe, E=unsafe]
//
//	→ batch 1: [A, B]   parallel
//	  batch 2: [C]      serial
//	  batch 3: [D]      parallel-of-1 (cannot merge across the unsafe boundary)
//	  batch 4: [E]      serial
//
// partitionByConcurrencySafety 按相邻 IsConcurrencySafe 合并的规则分组：
// 相邻 safe 合并并行执行；non-safe 各自独立串行。
func partitionByConcurrencySafety(
	calls []chatdomain.ToolCallData,
	byName map[string]toolapp.Tool,
) []concurrencyBatch {
	var out []concurrencyBatch
	for i, tc := range calls {
		argsRaw, _ := json.Marshal(tc.Arguments)
		safe := false
		if t, ok := byName[tc.Name]; ok {
			safe = t.IsConcurrencySafe(argsRaw)
		}
		// Merge into the last batch only if both it and the new call are safe.
		// Otherwise the unsafe boundary forces a new batch.
		// 仅当上一 batch 和新调用都 safe 时合并；否则 unsafe 边界强制起新 batch。
		if last := len(out) - 1; last >= 0 && out[last].safe && safe {
			out[last].items = append(out[last].items, indexedCall{idx: i, tc: tc})
		} else {
			out = append(out, concurrencyBatch{
				safe:  safe,
				items: []indexedCall{{idx: i, tc: tc}},
			})
		}
	}
	return out
}

// toolsByName returns a name → Tool map. Built per-call because s.tools is
// set once at startup and rebuilds are O(small N).
//
// toolsByName 返回 name → Tool 的 map。每次调用重建——s.tools 在启动时
// 设置一次后不变，重建是 O(小 N)。
func (s *Service) toolsByName() map[string]toolapp.Tool {
	m := make(map[string]toolapp.Tool, len(s.tools))
	for _, t := range s.tools {
		m[t.Name()] = t
	}
	return m
}
