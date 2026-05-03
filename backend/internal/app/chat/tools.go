// tools.go — Tool call execution within the ReAct loop.
// Calls are partitioned by the LLM-supplied ExecutionGroup field: same group
// = parallel batch; different groups = sequential in ascending order.
// Calls without an explicit group (ExecutionGroup ≤ 0) get a unique
// auto-assigned group placed after all explicit ones, so the safe default
// is "run alone, sequentially."
// Each call passes through ValidateInput + CheckPermissions before Execute.
//
// SSE: this file does NOT publish events directly. After each tool finishes,
// runTools publishes an updated chat.message snapshot via publishMessageSnapshot
// (parentBlocks + tool-result blocks accumulated so far). Mid-tool internal
// streaming (e.g. forge code generation) is published by the tool itself
// using its own domain event (forge), not chat.message.
//
// tools.go — ReAct 循环内的工具调用执行。
// 调用按 LLM 提供的 ExecutionGroup 字段分批：同 group = 并行 batch；不同
// group = 升序串行。无显式 group（ExecutionGroup ≤ 0）的调用获得唯一的
// 自动 group 排在所有显式 group 之后，因此安全默认是"独自运行，串行"。
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
	"sort"
	"sync"
	"time"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// runTools executes all tool calls grouped by LLM-supplied ExecutionGroup,
// publishing a chat.message snapshot after each tool completes. parentBlocks
// are the blocks accumulated from earlier in this assistant message (text,
// tool calls) — snapshots prepend them so subscribers always see the full
// message-so-far.
//
// runTools 按 LLM 提供的 ExecutionGroup 分组执行所有 tool 调用，每个 tool
// 跑完即推一次 chat.message 快照。parentBlocks 是当前 assistant 消息已积累
// 的 blocks（text、tool calls）——快照前置它们让订阅者始终看到完整
// message-so-far。
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
	batches := partitionByExecutionGroup(calls)

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
		if len(b.items) > 1 {
			// Parallel batch — LLM grouped these calls together by giving
			// them the same execution_group, asserting they have no
			// interdependence and no shared mutable state.
			//
			// 并行 batch——LLM 通过给这些调用分配相同 execution_group 把它们
			// 归在一起，断言它们之间无依赖、无共享可变状态。
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
			// Single-item batch (auto-assigned group, or a singleton
			// explicit group). Run inline to skip goroutine setup.
			//
			// 单项 batch（自动分配的 group，或仅一项的显式 group）。
			// 内联运行，省一次 goroutine 启动开销。
			item := b.items[0]
			blk := s.runOneTool(ctx, byName[item.tc.Name], item.tc, msgID, item.idx)
			mu.Lock()
			blocks[item.idx] = blk
			mu.Unlock()
			publishProgress()
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

// ── ExecutionGroup partitioning ───────────────────────────────────────────────

// indexedCall pairs a tool call with its original index in the calls slice
// so block ordering survives parallel scheduling.
//
// indexedCall 把 tool 调用与其在原 calls slice 的索引绑定，
// 让 block 顺序在并行调度后仍能还原。
type indexedCall struct {
	idx int
	tc  chatdomain.ToolCallData
}

// executionBatch is one set of calls that runs in parallel — its members
// share an execution_group number (or all hit the auto-assignment fallback,
// in which case each is in its own singleton batch). Distinct
// executionBatches run sequentially in ascending group-number order.
//
// executionBatch 是一组并行执行的调用——成员共享一个 execution_group 号
// （或都落入自动分配的 fallback，那种情况下每个独立成单项 batch）。
// 不同 executionBatch 之间按 group 号升序串行。
type executionBatch struct {
	items []indexedCall
}

// autoGroupBase is the floor used when assigning auto groups to calls
// that omitted execution_group. Picking a value visibly higher than typical
// LLM-supplied numbers makes auto assignments easy to spot in logs / tracing
// while still preserving correct ordering (auto groups always sort after
// any explicit group).
//
// autoGroupBase 是给省略了 execution_group 的调用分配自动 group 时的下限。
// 选一个显著高于 LLM 典型值的数让自动分配在 log/trace 里一眼可见，同时
// 保持顺序正确（自动 group 永远排在显式 group 之后）。
const autoGroupBase = 1000

// partitionByExecutionGroup buckets calls by their LLM-provided
// ExecutionGroup field. Any call with ExecutionGroup ≤ 0 (missing or
// negative) gets a unique auto-assigned group higher than autoGroupBase
// (and higher than any explicit group), so unspecified calls run alone
// after all the explicit batches.
//
// Example: calls [A:1, B:1, C:0, D:2, E:0]
//
//	maxExplicit = 2 → autoStart = max(maxExplicit+1, autoGroupBase) = 1000
//	assignments: A:1, B:1, C:1000, D:2, E:1001
//	sorted groups: [1, 2, 1000, 1001]
//	batches:
//	  batch 1: [A, B]   parallel (group 1)
//	  batch 2: [D]      single   (group 2)
//	  batch 3: [C]      single   (group 1000, auto)
//	  batch 4: [E]      single   (group 1001, auto)
//
// partitionByExecutionGroup 按 LLM 提供的 ExecutionGroup 字段分桶。
// 任何 ExecutionGroup ≤ 0（缺失或负值）的调用获得唯一的自动 group 号
// （高于 autoGroupBase 且高于任何显式 group），未指定的调用独自运行，
// 且都排在显式 batch 之后。
func partitionByExecutionGroup(calls []chatdomain.ToolCallData) []executionBatch {
	if len(calls) == 0 {
		return nil
	}

	// Find max explicit group to keep auto assignments cleanly separated.
	// 找最大显式 group，让自动分配干净分隔。
	maxExplicit := 0
	for _, tc := range calls {
		if tc.ExecutionGroup > maxExplicit {
			maxExplicit = tc.ExecutionGroup
		}
	}
	nextAuto := maxExplicit + 1
	if nextAuto < autoGroupBase {
		nextAuto = autoGroupBase
	}

	// Bucket by group, preserving original call index inside each bucket.
	// Iteration order over calls is deterministic, so the per-bucket
	// item order matches LLM emission order — important for stable
	// snapshot rendering.
	//
	// 按 group 分桶，桶内保留原 call 索引。calls 的迭代顺序确定，
	// 桶内 item 顺序匹配 LLM 发送顺序——快照渲染稳定的前提。
	buckets := map[int][]indexedCall{}
	var groupNums []int
	for i, tc := range calls {
		g := tc.ExecutionGroup
		if g <= 0 {
			g = nextAuto
			nextAuto++
		}
		if _, ok := buckets[g]; !ok {
			groupNums = append(groupNums, g)
		}
		buckets[g] = append(buckets[g], indexedCall{idx: i, tc: tc})
	}

	sort.Ints(groupNums)
	out := make([]executionBatch, 0, len(groupNums))
	for _, g := range groupNums {
		out = append(out, executionBatch{items: buckets[g]})
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
