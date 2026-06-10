package loop

import (
	"context"
	"encoding/json"
	"fmt"
	"maps"
	"sort"
	"sync"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// toolResultContent is the tool_result node payload (the loop's slice of the messages
// vocabulary). A tool_result streams nothing — it is produced whole — so its content rides
// the open frame and the close carries only status/error.
//
// toolResultContent 是 tool_result 节点 payload（loop 那一份 messages 词表）。tool_result 无流式
// （一次性产出），故内容随 open 帧、close 只带 status/error。
type toolResultContent struct {
	Content string `json:"content,omitempty"`
}

// runTools executes calls in execution-group batches and returns tool_result blocks aligned
// to the input order. Same-group calls run concurrently (one WaitGroup per batch); groups
// run in ascending order. The result slice is index-aligned so a parallel batch's writes
// don't race on order.
//
// runTools 按 execution-group 分批执行 tool 调用，返回与输入同序的 tool_result block。同组并行
// （每批一个 WaitGroup）、组间按升序串行。结果切片按下标对齐，使并行批的写入不竞争顺序。
func runTools(
	ctx context.Context,
	calls []messagesdomain.ToolCallData,
	byName map[string]toolapp.Tool,
	parkEnabled bool,
	allowsTool func(name string) bool,
	log *zap.Logger,
) ([]messagesdomain.Block, []ParkRequest) {
	if len(calls) == 0 {
		return nil, nil
	}
	// Per-call block lists (progress* + tool_result), index-aligned so a parallel batch's writes
	// don't race on order; flattened in call order at the end.
	//
	// 每调用一组 block（progress* + tool_result），按下标对齐使并行批写入不竞争顺序；末尾按调用序拍平。
	perCall := make([][]messagesdomain.Block, len(calls))

	// First pass (R0064): a PRE-execution park — a dangerous call (not session-allowed) or an
	// InteractiveTool (ask_user) — does NOT execute; it writes a pending tool_result placeholder.
	// Safe calls (and tools that may POST-execution park, e.g. invoke_agent) run normally. Running
	// safe siblings while parking unsafe ones keeps every tool_call's result present (valid LLM
	// projection) and wastes no safe work.
	//
	// 第一遍（R0064）：**执行前** park——危险调用（未会话放行）或 InteractiveTool（ask_user）——不执行；写 pending
	// tool_result 占位。safe 调用（及可能**执行后** park 的工具，如 invoke_agent）照跑。park 不安全的同时跑 safe
	// 兄弟，使每个 tool_call 都有 result（LLM 投影合法）、不浪费 safe 工作。
	runnable := make([]indexedCall, 0, len(calls))
	em := newEmitter(ctx, log)
	for i, tc := range calls {
		if parkEnabled {
			if kind := parkKind(tc, byName[tc.Name], allowsTool); kind != "" {
				perCall[i] = []messagesdomain.Block{openPendingToolResult(ctx, em, tc, kind, nil)}
				continue
			}
		}
		runnable = append(runnable, indexedCall{idx: i, tc: tc})
	}

	for _, batch := range partitionByExecutionGroup(runnable) {
		if len(batch.items) == 1 {
			item := batch.items[0]
			perCall[item.idx] = runOneTool(ctx, byName[item.tc.Name], item.tc, parkEnabled, log)
			continue
		}
		var wg sync.WaitGroup
		for _, item := range batch.items {
			wg.Add(1)
			go func(it indexedCall) {
				defer wg.Done()
				// Each goroutine writes its own pre-assigned index — no shared-slot race, no lock.
				//
				// 每个 goroutine 只写自己预分配的下标——无共享槽竞争、无需锁。
				perCall[it.idx] = runOneTool(ctx, byName[it.tc.Name], it.tc, parkEnabled, log)
			}(item)
		}
		wg.Wait()
	}

	var blocks []messagesdomain.Block
	for _, bs := range perCall {
		blocks = append(blocks, bs...)
	}
	// Collect parks by scanning for pending tool_results (R0064) — this unifies the PRE-execution
	// parks written above and the POST-execution parks runOneTool wrote on a ParkSignal (invoke_agent
	// whose sub-run parked). The durable refs (kind, nested agent execution) ride each block's Attrs.
	//
	// 扫 pending tool_result 收集 parks（R0064）——统一上面的执行前 park 与 runOneTool 在 ParkSignal 上写的执行后
	// park（invoke_agent 的子运行 park）。耐久引用（kind、嵌套 agent execution）随各 block 的 Attrs。
	parks := collectParks(blocks, calls)
	return blocks, parks
}

// collectParks derives a ParkRequest from each pending tool_result block (the unified park marker).
// Args is the gated call's raw args (from the matching tool_call), for surfacing.
//
// collectParks 从每个 pending tool_result 块（统一的 park 标记）导出 ParkRequest。Args 是被门调用的裸 args
// （取自匹配的 tool_call），供露出。
func collectParks(blocks []messagesdomain.Block, calls []messagesdomain.ToolCallData) []ParkRequest {
	var parks []ParkRequest
	for _, b := range blocks {
		if b.Type != messagesdomain.BlockTypeToolResult || b.Status != messagesdomain.StatusPending {
			continue
		}
		kind, _ := b.Attrs["park"].(string)
		name, _ := b.Attrs["tool"].(string)
		args := ""
		for _, tc := range calls {
			if tc.ID == b.ParentBlockID {
				j, _ := json.Marshal(tc.Arguments)
				args = string(j)
				break
			}
		}
		parks = append(parks, ParkRequest{ToolCallID: b.ParentBlockID, Kind: kind, ToolName: name, Args: args})
	}
	return parks
}

// parkKind reports why a call must park — ParkKindAsk (an InteractiveTool, e.g. ask_user) or
// ParkKindDanger (a self-reported dangerous call the user hasn't session-allowed) — or "" if it
// runs normally. ask takes precedence (an ask_user call is never auto-allowed by always-allow).
//
// parkKind 报告调用为何须 park——ParkKindAsk（InteractiveTool 如 ask_user）或 ParkKindDanger（自报危险且用户
// 未会话放行）——否则 "" 正常跑。ask 优先（ask_user 永不被 always-allow 自动放行）。
func parkKind(tc messagesdomain.ToolCallData, t toolapp.Tool, allowsTool func(string) bool) string {
	if _, ok := t.(toolapp.InteractiveTool); ok {
		return ParkKindAsk
	}
	if tc.Danger == string(toolapp.DangerDangerous) && !allowsTool(tc.Name) {
		return ParkKindDanger
	}
	return ""
}

// openPendingToolResult writes the placeholder tool_result for a parked call: status=pending,
// empty content, parented to the tool_call. It is the durable marker the resolver fills (keyed by
// the tool_call id) and the inbox queries. Streams an Open frame (no Close — the close arrives at
// resolve, possibly a different turn / after a restart).
//
// openPendingToolResult 为 park 调用写占位 tool_result：status=pending、空内容、挂其 tool_call。它是 resolver
// 据 tool_call id 填充、收件箱查询的耐久标记。流式发 Open 帧（无 Close——close 在 resolve 时来，可能跨回合 / 重启后）。
func openPendingToolResult(ctx context.Context, em emitter, tc messagesdomain.ToolCallData, kind string, extra map[string]any) messagesdomain.Block {
	blockID := idgenpkg.New("blk")
	em.open(ctx, blockID, tc.ID, messagesdomain.BlockTypeToolResult, nil)
	// park=kind ("ask"|"danger"|"agent") lets the resolver act without re-deriving the tool's type;
	// tool is the gated tool name. extra carries kind-specific refs (agent: the nested execution id
	// + leaf tool_call ids the resolver threads down to).
	//
	// park=kind（"ask"|"danger"|"agent"）使 resolver 无需重判工具类型；tool 是被门工具名。extra 携带 kind 专属
	// 引用（agent：resolver 向下穿的嵌套 execution id + leaf tool_call id）。
	attrs := map[string]any{"tool": tc.Name, "park": kind}
	maps.Copy(attrs, extra)
	return messagesdomain.Block{
		ID:            blockID,
		Type:          messagesdomain.BlockTypeToolResult,
		ParentBlockID: tc.ID,
		Status:        messagesdomain.StatusPending,
		Attrs:         attrs,
	}
}

// runOneTool executes one tool call and returns its tool_result block, live-pushing the block
// lifecycle. Two parks happen here (R0064, only when parkEnabled): the LLM's self-reported danger
// is gated PRE-execution by the caller (runTools); POST-execution, a tool that returns a ParkSignal
// (invoke_agent whose sub-run parked) yields a pending tool_result carrying the nested refs instead
// of a normal result — propagating the park up so the caller's turn parks too.
//
// runOneTool 执行一次 tool 调用、返回其 tool_result block，并实时推 block 生命周期。两种 park（R0064，仅 parkEnabled
// 时）：LLM 自报的 danger 由调用方（runTools）**执行前**门控；**执行后**，返回 ParkSignal 的工具（invoke_agent 的
// 子运行 park 了）产出携嵌套引用的 pending tool_result 而非正常结果——把 park 向上传播使调用方回合也 park。
func runOneTool(ctx context.Context, t toolapp.Tool, tc messagesdomain.ToolCallData, parkEnabled bool, log *zap.Logger) []messagesdomain.Block {
	argsJSON, _ := json.Marshal(tc.Arguments)
	// Seed this call's id so a tool can learn its own tool_call block id (the Subagent tool
	// anchors the subagent's message subtree under it, E3) and ToolProgress nests its progress
	// block under it. The capture lets a tool's live progress (bash output, env-fix log, …)
	// persist with the turn alongside the tool_result.
	//
	// 埋本次调用的 id，使工具能得知自己的 tool_call block id（Subagent 据此把 subagent message 子树锚其下，
	// E3；ToolProgress 据此把 progress 块嵌其下）。capture 使工具的实时进度（bash 输出、env-fix log…）随回合
	// 与 tool_result 一并持久化。
	ctx = reqctxpkg.SetToolCallID(ctx, tc.ID)
	pcap := &progressCapture{}
	ctx = withProgressCapture(ctx, pcap)
	output, errMsg, ok, rawErr := executeTool(ctx, t, tc.Name, argsJSON, log)

	// POST-execution park: the tool ran but its nested run paused for human input (invoke_agent).
	// Emit a pending tool_result carrying the nested refs so the caller's turn parks; the resolver
	// threads the resolution down via ResumeExecution.
	//
	// 执行后 park：工具跑了但其嵌套运行为等人输入暂停（invoke_agent）。产出携嵌套引用的 pending tool_result 使
	// 调用方回合 park；resolver 经 ResumeExecution 把决议向下穿。
	if parkEnabled {
		if ps, isPark := AsParkSignal(rawErr); isPark {
			em := newEmitter(ctx, log)
			leafIDs := make([]string, 0, len(ps.Leaves))
			for _, lf := range ps.Leaves {
				leafIDs = append(leafIDs, lf.ToolCallID)
			}
			pending := openPendingToolResult(ctx, em, tc, ParkKindAgent, map[string]any{
				"agentExecutionId": ps.ExecutionID,
				"leafToolCallIds":  leafIDs,
			})
			return append(pcap.take(), pending)
		}
	}

	status := messagesdomain.StatusCompleted
	if !ok {
		status = messagesdomain.StatusError
	}

	em := newEmitter(ctx, log)
	blockID := idgenpkg.New("blk")
	em.open(ctx, blockID, tc.ID, messagesdomain.BlockTypeToolResult, streamdomain.JSONContent(toolResultContent{Content: output}))
	em.close(ctx, blockID, status, nil, errMsg)

	errVal := ""
	if !ok {
		errVal = errMsg
	}
	result := messagesdomain.Block{
		ID:            blockID,
		Type:          messagesdomain.BlockTypeToolResult,
		Content:       output,
		ParentBlockID: tc.ID,
		Error:         errVal,
		Attrs:         map[string]any{"tool": tc.Name},
	}
	// Progress blocks (emitted during Execute) precede the tool_result — chronological + correct
	// sibling order under the tool_call. Usually empty (most tools emit no progress).
	//
	// progress 块（Execute 期间发的）排在 tool_result 前——时序 + tool_call 下正确的兄弟序。通常为空
	// （多数工具不发进度）。
	return append(pcap.take(), result)
}

// executeTool runs ValidateInput then Execute and shapes the (output, errMsg, ok) tuple.
// There is no permission gate (M1.9 dissolved central gating) and no error rewriting: a
// tool owns the quality of its own error message (clean text, any next-step hint), so loop
// stays a neutral engine and just surfaces err.Error() to the LLM.
//
// executeTool 跑 ValidateInput 再 Execute，整形 (output, errMsg, ok) 三元组。无权限门控
// （M1.9 解散中央门控）、无错误改写：工具自负其 error message 质量（干净文本、必要的 next-step
// 提示），故 loop 保持中立引擎、只把 err.Error() 透传给 LLM。
func executeTool(ctx context.Context, t toolapp.Tool, name string, argsJSON []byte, log *zap.Logger) (output, errMsg string, ok bool, rawErr error) {
	if t == nil {
		// The LLM named a tool not in this turn's set — a wiring bug or a stale catalog.
		// LLM 点了本回合工具集外的工具——接线 bug 或过期 catalog。
		log.Warn("executeTool: tool not in registry — likely wiring bug or stale catalog", zap.String("tool", name))
		msg := fmt.Sprintf("tool %q not found", name)
		return msg, msg, false, nil
	}

	if err := t.ValidateInput(argsJSON); err != nil {
		log.Warn("tool validate failed", zap.String("tool", name), zap.Error(err))
		return "input validation failed: " + err.Error(), err.Error(), false, err
	}

	output, err := t.Execute(ctx, string(argsJSON))
	if err != nil {
		// A ParkSignal is NOT a failure — it propagates a nested park; the caller (runOneTool)
		// converts it, so don't log it as an error.
		//
		// ParkSignal 不是失败——它传播嵌套 park；调用方（runOneTool）转换它，故不当错误记日志。
		if _, isPark := AsParkSignal(err); !isPark {
			log.Warn("tool execute failed", zap.String("tool", name), zap.Error(err))
		}
		if output != "" {
			return output + "\n\n" + err.Error(), err.Error(), false, err
		}
		return err.Error(), err.Error(), false, err
	}
	return output, "", true, nil
}

type indexedCall struct {
	idx int
	tc  messagesdomain.ToolCallData
}

type executionBatch struct {
	items []indexedCall
}

// autoGroupBase is where auto-assigned groups (calls with ExecutionGroup ≤ 0) start, kept
// above any plausible explicit group so they always sort after explicitly-grouped batches.
//
// autoGroupBase 是自动分组（ExecutionGroup ≤ 0 的调用）的起点，置于任何合理显式组之上，使其
// 总排在显式分组批之后。
const autoGroupBase = 1000

// partitionByExecutionGroup buckets the runnable calls by ExecutionGroup; ≤0 get sequential
// auto-groups (each its own batch) placed after the explicit ones. Same explicit group → one batch
// → concurrent; distinct groups → separate batches → ordered. Takes indexedCalls (the original
// call index preserved) so a parallel batch's writes land in the right slot after park calls were
// filtered out (R0064).
//
// partitionByExecutionGroup 把可运行调用按 ExecutionGroup 分桶；≤0 获顺序自动组（各自一批）排在显式组之后。
// 同一显式组 → 一批 → 并行；不同组 → 分批 → 有序。收 indexedCall（保留原始调用下标），使过滤掉 park 调用后并行
// 批的写入仍落对槽（R0064）。
func partitionByExecutionGroup(items []indexedCall) []executionBatch {
	if len(items) == 0 {
		return nil
	}

	maxExplicit := 0
	for _, it := range items {
		maxExplicit = max(maxExplicit, it.tc.ExecutionGroup)
	}
	nextAuto := max(maxExplicit+1, autoGroupBase)

	buckets := map[int][]indexedCall{}
	var groupNums []int
	for _, it := range items {
		g := it.tc.ExecutionGroup
		if g <= 0 {
			g = nextAuto
			nextAuto++
		}
		if _, ok := buckets[g]; !ok {
			groupNums = append(groupNums, g)
		}
		buckets[g] = append(buckets[g], it)
	}

	sort.Ints(groupNums)
	out := make([]executionBatch, 0, len(groupNums))
	for _, g := range groupNums {
		out = append(out, executionBatch{items: buckets[g]})
	}
	return out
}
