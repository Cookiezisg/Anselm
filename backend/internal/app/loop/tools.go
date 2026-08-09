package loop

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"sync"

	"go.uber.org/zap"

	humanloopapp "github.com/sunweilin/anselm/backend/internal/app/humanloop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	fspathpkg "github.com/sunweilin/anselm/backend/internal/pkg/fspath"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
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

// toolCancelledProse is the neutral result shown when the user wins the cancellation race while a
// tool is executing. The underlying context error stays in the backend journal, never in the
// tool_result wire error field or the user's transcript.
//
// toolCancelledProse 是用户在工具执行中赢得取消竞态时看到的中性结果。底层 context 错误仍进后端
// journal，但绝不进入 tool_result wire error 或用户转录。
const toolCancelledProse = "The tool was cancelled before it finished."

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
	log *zap.Logger,
) []messagesdomain.Block {
	blocks, _ := runToolsWithLedger(ctx, calls, byName, nil, log)
	return blocks
}

// runToolsWithLedger is runTools plus a per-Run ledger of calls that have already been handled.
// The ledger is deliberately owned by loop.Run rather than persisted or attached to a conversation:
// an identical call in a later user turn is a new intent and must remain executable. Calls repeated
// across ReAct steps are suppressed before dispatch, so they cannot open another approval gate or
// repeat a side effect after a successful/denied execution. Successful safe calls are also recorded;
// a safe call that failed is deliberately not recorded so the model retains a real retry path. A
// protected duplicate asks Run to end the turn (the model must not bypass a denied/guarded action),
// while a safe duplicate only returns the cached suppression result and lets the model continue.
//
// runToolsWithLedger 是 runTools 加上「本次 Run 已处理调用」台账。台账刻意由 loop.Run 持有，而不
// 持久化或挂在对话上：后续用户回合的同参数调用是新意图，必须仍可执行。跨 ReAct 步重复调用在
// dispatch 前被压制，故成功/拒绝后既不会再开批准闸，也不会再做一次副作用；安全读调用成功后也
// 不会重复花费时间，失败的安全调用则仍可重试。
func runToolsWithLedger(
	ctx context.Context,
	calls []messagesdomain.ToolCallData,
	byName map[string]toolapp.Tool,
	handled map[string]handledCall,
	log *zap.Logger,
) ([]messagesdomain.Block, bool) {
	if len(calls) == 0 {
		return nil, false
	}
	for i := range calls {
		calls[i].Danger = string(toolapp.EffectiveDanger(byName[calls[i].Name], toolapp.DangerLevel(calls[i].Danger)))
	}
	if handled == nil {
		handled = make(map[string]handledCall)
	}
	// Per-call block lists (progress* + tool_result), index-aligned so a parallel batch's writes
	// don't race on order; flattened in call order at the end.
	//
	// 每调用一组 block（progress* + tool_result），按下标对齐使并行批写入不竞争顺序；末尾按调用序拍平。
	perCall := make([][]messagesdomain.Block, len(calls))
	duplicates := duplicateToolCalls(calls, byName)
	prior := make(map[int]handledCall)
	haltOnRepeat := false
	for i, tc := range calls {
		if key, ok := canonicalToolCallKey(tc, byName[tc.Name]); ok {
			if first, exists := handled[key]; exists {
				prior[i] = first
				haltOnRepeat = haltOnRepeat || first.haltOnRepeat
			}
		}
	}

	for _, batch := range partitionByExecutionGroup(calls) {
		if len(batch.items) == 1 {
			item := batch.items[0]
			if first, ok := prior[item.idx]; ok {
				perCall[item.idx] = runTurnDuplicateTool(ctx, item.tc, first, log)
			} else if first, ok := duplicates[item.idx]; ok {
				perCall[item.idx] = runDuplicateTool(ctx, item.tc, first, log)
			} else {
				perCall[item.idx] = runOneTool(ctx, byName[item.tc.Name], item.tc, log)
			}
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
				if first, ok := prior[it.idx]; ok {
					perCall[it.idx] = runTurnDuplicateTool(ctx, it.tc, first, log)
				} else if first, ok := duplicates[it.idx]; ok {
					perCall[it.idx] = runDuplicateTool(ctx, it.tc, first, log)
				} else {
					perCall[it.idx] = runOneTool(ctx, byName[it.tc.Name], it.tc, log)
				}
			}(item)
		}
		wg.Wait()
	}

	// Record only the first new key in this batch. Writes happen after all parallel execution is
	// complete, so the goroutines never race on the ledger map.
	//
	// 只记录本批新 key 的第一次出现。待并行执行全部结束后再写，故 goroutine 不会竞争台账 map。
	firstNew := make(map[string]handledCall)
	for i, tc := range calls {
		key, ok := canonicalToolCallKey(tc, byName[tc.Name])
		if !ok {
			continue
		}
		if _, exists := prior[i]; exists {
			continue
		}
		if _, exists := firstNew[key]; !exists {
			if remember, halt, terminal := rememberHandledCall(ctx, tc, byName[tc.Name], perCall[i]); remember {
				firstNew[key] = handledCall{call: indexedCall{idx: i, tc: tc}, haltOnRepeat: halt, terminalRepeat: terminal}
			}
		}
	}
	for key, first := range firstNew {
		handled[key] = first
	}

	var blocks []messagesdomain.Block
	for _, bs := range perCall {
		blocks = append(blocks, bs...)
	}
	return blocks, haltOnRepeat
}

// rememberHandledCall decides whether a call is safe to suppress on a later ReAct step. A
// protected mutation is remembered even when the user denied it, preserving the existing
// no-second-gate invariant. Any other call is remembered only after a successful tool_result;
// this keeps transient read failures retryable while preventing a successful search from being
// needlessly executed over and over.
//
// rememberHandledCall 决定后续 ReAct 步是否可以抑制调用。受保护 mutation 即使被用户拒绝也记账，
// 保持不再开第二个人闸的不变量；其它调用只有 tool_result 成功才记账，既保留临时读失败的重试路，
// 又不让成功搜索被无谓重复执行。
func rememberHandledCall(ctx context.Context, tc messagesdomain.ToolCallData, t toolapp.Tool, blocks []messagesdomain.Block) (remember, haltOnRepeat, terminalRepeat bool) {
	if repeatGuardedCall(ctx, tc, map[string]toolapp.Tool{tc.Name: t}) {
		return true, true, false
	}
	for _, b := range blocks {
		if b.Type == messagesdomain.BlockTypeToolResult {
			terminal := toolapp.HaltOnRepeat(t, b.Content, b.Error)
			if terminal {
				return true, true, true
			}
			return b.Error == "", false, false
		}
	}
	return false, false, false
}

// canonicalToolCallKey excludes framework standard fields because they describe the model's
// presentation of a call, not its business identity. A tool may provide a narrower CallIdentity
// for guarded mutations; otherwise json.Marshal sorts map keys so logically identical object
// arguments have one stable key even when a provider streams another order.
//
// canonicalToolCallKey 排除 framework 标准字段，因为它们描述模型如何呈现调用，不是业务身份。受保护
// mutation 可提供更窄的 CallIdentity；否则 json.Marshal 排序 map key，使参数顺序不同仍只有一个键。
func canonicalToolCallKey(tc messagesdomain.ToolCallData, t toolapp.Tool) (string, bool) {
	args, err := json.Marshal(tc.Arguments)
	if err != nil {
		return "", false
	}
	if identity := toolapp.CallIdentity(t, args); identity != "" {
		return tc.Name + "\x00" + identity, true
	}
	return tc.Name + "\x00" + string(args), true
}

// repeatGuardedCall limits the cross-step ledger to calls that already carry a human-facing safety
// boundary: a dangerous self-report or a residency write that physically leaves the mounted root.
// Read/retry tools remain repeatable after an execution error; otherwise a transient read failure
// would be turned into a silent suppression instead of the existing recovery path.
//
// repeatGuardedCall 只把跨步台账用于已有用户安全边界的调用：LLM 自报 dangerous，或实际写出驻地根的
// 调用。读/重试工具在执行报错后仍可重复，否则一次临时读失败会被静默压制，破坏原有恢复路径。
func repeatGuardedCall(ctx context.Context, tc messagesdomain.ToolCallData, byName map[string]toolapp.Tool) bool {
	if toolapp.EffectiveDanger(byName[tc.Name], toolapp.DangerLevel(tc.Danger)) == toolapp.DangerDangerous {
		return true
	}
	t := byName[tc.Name]
	argsJSON, err := json.Marshal(tc.Arguments)
	return err == nil && writesOutsideWorkDir(ctx, t, argsJSON)
}

// duplicateToolCalls identifies byte-equivalent business calls within one assistant response. A
// hosted model can emit the same mutation twice in one tool-call batch after recovering from an
// earlier argument error. Execute the first and return an honest completed suppression result for
// the rest; a later user turn with the same arguments is not affected.
//
// duplicateToolCalls 标出一次 assistant 响应内业务参数完全相同的调用。托管模型可能在修正早期参数
// 错误时于同一批重复吐出 mutation；只执行首个，其余给诚实的 completed suppression 结果。后续用户回合
// 主动重复同样参数不受影响。
func duplicateToolCalls(calls []messagesdomain.ToolCallData, byName map[string]toolapp.Tool) map[int]indexedCall {
	firstByKey := make(map[string]indexedCall)
	duplicates := make(map[int]indexedCall)
	for i, tc := range calls {
		key, ok := canonicalToolCallKey(tc, byName[tc.Name])
		if !ok {
			continue
		}
		first, exists := firstByKey[key]
		if exists {
			duplicates[i] = first
			continue
		}
		firstByKey[key] = indexedCall{idx: i, tc: tc}
	}
	return duplicates
}

func runDuplicateTool(ctx context.Context, tc messagesdomain.ToolCallData, first indexedCall, log *zap.Logger) []messagesdomain.Block {
	blockID := idgenpkg.New("blk")
	content := fmt.Sprintf("Duplicate tool call suppressed: identical %s call %s was already handled in this assistant batch.", tc.Name, first.tc.ID)
	em := newEmitter(ctx, log)
	em.open(ctx, blockID, tc.ID, messagesdomain.BlockTypeToolResult, streamdomain.JSONContent(toolResultContent{}))
	em.close(ctx, blockID, messagesdomain.StatusCompleted,
		&streamdomain.Node{Type: messagesdomain.BlockTypeToolResult, Content: streamdomain.JSONContent(toolResultContent{Content: content})}, "")
	return []messagesdomain.Block{{
		ID:            blockID,
		Type:          messagesdomain.BlockTypeToolResult,
		Content:       content,
		ParentBlockID: tc.ID,
		Attrs:         map[string]any{"tool": tc.Name, "duplicateSuppressed": true},
	}}
}

func runTurnDuplicateTool(ctx context.Context, tc messagesdomain.ToolCallData, first handledCall, log *zap.Logger) []messagesdomain.Block {
	blockID := idgenpkg.New("blk")
	content := fmt.Sprintf("Duplicate tool call suppressed: identical %s call %s was already handled earlier in this turn; no second approval or execution was requested.", tc.Name, first.call.tc.ID)
	if first.terminalRepeat {
		content = fmt.Sprintf("Duplicate tool call suppressed: terminal rejection for identical %s call %s; no second execution was requested.", tc.Name, first.call.tc.ID)
	}
	em := newEmitter(ctx, log)
	em.open(ctx, blockID, tc.ID, messagesdomain.BlockTypeToolResult, streamdomain.JSONContent(toolResultContent{}))
	em.close(ctx, blockID, messagesdomain.StatusCompleted,
		&streamdomain.Node{Type: messagesdomain.BlockTypeToolResult, Content: streamdomain.JSONContent(toolResultContent{Content: content})}, "")
	return []messagesdomain.Block{{
		ID:            blockID,
		Type:          messagesdomain.BlockTypeToolResult,
		Content:       content,
		ParentBlockID: tc.ID,
		Attrs: map[string]any{
			"tool":                     tc.Name,
			"duplicateSuppressed":      true,
			"duplicateScope":           "turn",
			"duplicateOf":              first.call.tc.ID,
			"terminalRepeatSuppressed": first.terminalRepeat,
		},
	}}
}

// runOneTool executes one tool call and returns its tool_result block, live-pushing the block
// lifecycle. When a humanloop broker is in ctx (chat / nested agent) the call may be gated for human
// approval first — either because the LLM self-reported `dangerous` or because it would write outside
// the conversation's residency (see dispatchWithGate). Otherwise pure trust: the danger level rode the
// tool_call node and the call just runs.
//
// runOneTool 执行一次 tool 调用、返回其 tool_result block，并实时推 block 生命周期。当 ctx 里有 humanloop
// broker 时（chat / 嵌套 agent），该调用可能先被门控到人批准——或因 LLM 自报 `dangerous`、或因它会写到对话
// 驻地之外（见 dispatchWithGate）。否则纯信任——danger 已随 tool_call 节点上行、调用直接跑。
func runOneTool(ctx context.Context, t toolapp.Tool, tc messagesdomain.ToolCallData, log *zap.Logger) []messagesdomain.Block {
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
	// The tool-call close means only that the MODEL finished writing its arguments.  The actual
	// execution starts here, possibly much later (first Python runtime / venv setup is the visible
	// example).  Open the existing tool_result node at that real boundary and close it with the
	// durable result snapshot below.  This gives every consumer one honest execution lifecycle
	// without adding a block type for it or making reconnect replay ambiguous.
	//
	// tool_call 的 Close 只表示模型写完参数，绝不表示工具已完成；真实执行从这里才开始（首次 Python
	// runtime/venv 准备尤其可见）。复用既有 tool_result：此处 Open，结束时带耐久结果快照 Close，既给
	// 消费端一条诚实执行生命周期，又不为它新增块型、不断重连回放。
	em := newEmitter(ctx, log)
	blockID := idgenpkg.New("blk")
	em.open(ctx, blockID, tc.ID, messagesdomain.BlockTypeToolResult, streamdomain.JSONContent(toolResultContent{}))
	output, errMsg, ok, executed, humanApproved := dispatchWithGate(ctx, t, tc, argsJSON, log)

	status := messagesdomain.StatusCompleted
	if ctx.Err() != nil {
		// A user cancellation is a distinct product outcome, not a failed tool. In particular,
		// search/shell implementations may return the raw context error; never leak that internal
		// executor detail into the transcript. The execution journal still contains the WARN.
		status = messagesdomain.StatusCancelled
		if executed {
			output = toolCancelledProse
		}
		errMsg = ""
	} else if !ok {
		status = messagesdomain.StatusError
	}
	recordTouches(ctx, t, tc, output, ok && executed)

	em.close(ctx, blockID, status,
		&streamdomain.Node{Type: messagesdomain.BlockTypeToolResult, Content: streamdomain.JSONContent(toolResultContent{Content: output})},
		errMsg)

	errVal := ""
	if !ok {
		errVal = errMsg
	}
	attrs := map[string]any{"tool": tc.Name}
	if humanApproved {
		attrs[messagesdomain.AttrHumanApproval] = true
	}
	result := messagesdomain.Block{
		ID:            blockID,
		Type:          messagesdomain.BlockTypeToolResult,
		Content:       output,
		Status:        status,
		ParentBlockID: tc.ID,
		Error:         errVal,
		Attrs:         attrs,
	}
	// Progress blocks (emitted during Execute) precede the tool_result — chronological + correct
	// sibling order under the tool_call. Usually empty (most tools emit no progress).
	//
	// progress 块（Execute 期间发的）排在 tool_result 前——时序 + tool_call 下正确的兄弟序。通常为空
	// （多数工具不发进度）。
	return append(pcap.take(), result)
}

// toolDisabledResults closes provider-emitted calls that arrived after a run-local tool
// shutdown request. No resolved Tool is consulted and no Execute path is reachable here.
//
// toolDisabledResults 收束「本次 run 已请求停用工具」之后 provider 仍吐出的调用。这里不解析任何
// 真实 Tool，也不进入 Execute 路径，故模型无法绕过这道终止闸。
func toolDisabledResults(ctx context.Context, calls []messagesdomain.ToolCallData, log *zap.Logger) []messagesdomain.Block {
	const message = "No tools are available in this turn because the isolated fork already returned; provide the final textual response instead."
	blocks := make([]messagesdomain.Block, 0, len(calls))
	for _, tc := range calls {
		blockID := idgenpkg.New("blk")
		em := newEmitter(ctx, log)
		em.open(ctx, blockID, tc.ID, messagesdomain.BlockTypeToolResult, streamdomain.JSONContent(toolResultContent{}))
		em.close(ctx, blockID, messagesdomain.StatusError,
			&streamdomain.Node{Type: messagesdomain.BlockTypeToolResult, Content: streamdomain.JSONContent(toolResultContent{Content: message})}, message)
		blocks = append(blocks, messagesdomain.Block{
			ID:            blockID,
			Type:          messagesdomain.BlockTypeToolResult,
			Content:       message,
			ParentBlockID: tc.ID,
			Error:         message,
			Attrs:         map[string]any{"tool": tc.Name, "toolsDisabled": true},
		})
	}
	return blocks
}

// dispatchWithGate runs the tool, first gating it on human approval when a humanloop broker is in ctx
// (chat / nested agent runs seed one; subagent / workflow do not → pure trust). TWO things open the gate:
//
//   - The LLM self-reported `dangerous`. Bypassable, because the model's own judgement is what raised
//     it: approve_always session-whitelists the (conversation, tool) pair, and the active skill's
//     allowed-tools pre-authorize the tools a skill declared it would use (see skillPreApproves).
//   - The call would WRITE OUTSIDE the conversation's residency (WRK-077 WD1). NOT bypassable, and it
//     ignores the self-reported level entirely — see writesOutsideWorkDir for why a fact about the target
//     path outranks the model's opinion about it, and the block below for why neither bypass applies.
//
// It is interrupt-before-side-effect: a denied tool never executes — the denial is recorded as the result
// so the model re-routes; a cancelled ctx (the run aborted) records that.
//
// dispatchWithGate 跑工具，但当 ctx 里有 humanloop broker 时（chat / 嵌套 agent 运行 seed 之；subagent /
// workflow 不 → 纯信任），先把它门控到人批准。**两件事**会开这道闸：
//
//   - LLM 自报 `dangerous`。**可豁免**，因为抬起它的正是模型自己的判断：approve_always 会话白名单
//     (对话, 工具) 这一对，active skill 的 allowed-tools 预授权它声明会用的工具（见 skillPreApproves）。
//   - 该调用会**写到对话驻地之外**（WRK-077 WD1）。**不可豁免**，且它**完全无视**自报等级——为何一个关于
//     目标路径的**事实**盖过模型对它的**意见**，见 writesOutsideWorkDir；为何两个豁免都不适用，见下方那一块。
//
// interrupt-before-side-effect：被拒的工具绝不执行——拒绝记为结果使模型改道；ctx 取消（运行中止）记下之。
// The fourth return (executed) tells the ledger apart from the model: deny / cancel-before-run
// return ok=true (a smooth "didn't run" RESULT the model reroutes on), yet the tool never
// executed — recording a touch for it would book a phantom (e.g. a DENIED delete_agent must
// not produce a `deleted` ledger row). The fifth return records an explicit human approval for
// the model-history projection without adding that fact to the visible tool-result text.
//
// 第四个返回值(executed)把台账与模型区分开:deny / 运行前取消返 ok=true(给模型改道的平滑
// 「没跑」结果),但工具从未执行——为其记触碰即幽灵账(被**拒绝**的 delete_agent 绝不能产生
// `deleted` 台账行)。第五个返回值记录明确的人批准，供模型历史投影使用，但不污染用户可见的工具结果文本。
func dispatchWithGate(ctx context.Context, t toolapp.Tool, tc messagesdomain.ToolCallData, argsJSON []byte, log *zap.Logger) (output, errMsg string, ok, executed, humanApproved bool) {
	if t != nil && t.Name() != tc.Name {
		msg := fmt.Sprintf("tool dispatch mismatch: requested %q but resolved %q; no tool was executed", tc.Name, t.Name())
		log.Error("tool dispatch mismatch", zap.String("requested_tool", tc.Name), zap.String("resolved_tool", t.Name()))
		return msg, msg, false, false, false
	}
	// Validate before opening a dangerous gate. A malformed mutation must not show an "Allowed"
	// card and only then reveal that nothing could execute; that sequence teaches users to approve
	// blind and can leave the model asking for a second destructive gate for the same intent.
	//
	// 先校验再开危险闸。畸形 mutation 不得先显示「Allowed」再说根本没法执行；那会教用户盲点批准，
	// 还可能让模型为同一意图再开第二道破坏性人闸。
	if t != nil {
		if err := t.ValidateInput(argsJSON); err != nil {
			msg := "input validation failed: " + llmErrText(err)
			log.Warn("tool validate failed before gate", zap.String("tool", tc.Name), zap.String("error", llmErrText(err)))
			return msg, msg, false, false, false
		}
	}
	if conflict := toolIntentConflict(tc.Name, tc.Summary); conflict != "" {
		log.Warn("tool intent conflict before gate", zap.String("tool", tc.Name), zap.String("summary", tc.Summary), zap.String("error", conflict))
		return conflict, conflict, false, false, false
	}
	outsideWorkDir := writesOutsideWorkDir(ctx, t, argsJSON)
	effectiveDanger := toolapp.EffectiveDanger(t, toolapp.DangerLevel(tc.Danger))
	staticDanger := toolapp.MinimumDanger(t)
	if b := humanloopapp.From(ctx); b != nil && (effectiveDanger == toolapp.DangerDangerous || outsideWorkDir) {
		convID, _ := reqctxpkg.GetConversationID(ctx)
		// An out-of-root write skips BOTH bypasses on purpose. approve_always is per (conversation, tool),
		// so honouring it would turn one "yes, edit that file over there" into a standing licence for every
		// later Write anywhere — the user answered about a PATH, not about the tool. The active skill's
		// allowed-tools are the same shape of promise ("this skill uses Write"), made before anyone knew
		// where it would write. Neither ever authorized leaving the residency.
		//
		// 越界写**刻意**跳过**两个**豁免。approve_always 是按 (对话, 工具) 记的,故照顾它会把一次「行,改
		// 那边那个文件」变成此后**任何**位置每次 Write 的长期许可——用户回答的是一个**路径**、不是一个工具。
		// active skill 的 allowed-tools 是同一形状的承诺（「本 skill 会用 Write」）,而它是在谁都还不知道
		// 它要写到哪里之前作出的。两者都从未授权「离开驻地」。
		if outsideWorkDir || staticDanger == toolapp.DangerDangerous || (!b.IsAllowed(convID, tc.Name) && !skillPreApproves(ctx, tc.Name)) {
			// The reason rides the prompt only when it IS the reason, so an ordinary danger confirmation's
			// payload stays byte-identical to what every existing client already parses. Without this key
			// the user would face an approval dialog for a write the model called `safe` and have no way to
			// learn why — a prompt that cannot explain itself gets clicked through.
			//
			// 理由**仅在它就是理由时**才上 prompt,故普通 danger 确认的载荷与每个既有客户端已在解析的形状
			// 逐字节相同。没有这个键,用户会为一次模型自称 `safe` 的写面对一个批准框、却无从知道为什么——
			// 一个无法自我解释的弹窗只会被闭眼点掉。
			// The model's summary is not an authority over the operation it selected. In particular,
			// a delete call must never be presented as a deactivate call just because the model wrote
			// "deactivate" in this field. Build the approval sentence from the resolved tool name;
			// keep the payload shape stable for existing clients.
			//
			// 模型自报 summary 不能决定它实际选中的动作。尤其不能因为模型在此字段写了
			// "deactivate"，就把 delete 调用展示成 deactivate。批准句由真实解析工具名生成，
			// 同时保持既有 payload 形状，兼容现有客户端。
			payload := map[string]any{"summary": canonicalGateSummary(t, tc, outsideWorkDir), "args": json.RawMessage(argsJSON)}
			if outsideWorkDir {
				payload["outsideWorkDir"] = true
			}
			prompt, _ := json.Marshal(payload)
			resp, err := b.Request(ctx, humanloopapp.Request{
				ToolCallID:     tc.ID,
				Kind:           humanloopapp.KindDanger,
				Tool:           resolvedToolName(t, tc),
				ConversationID: convID,
				Prompt:         prompt,
			})
			if err != nil { // ctx cancelled — the run is aborting
				return "The run was cancelled before this tool ran.", "", true, false, false
			}
			// Fail-safe: only an explicit approve runs the tool; deny / an unexpected action does NOT
			// (a malformed resolve must never execute a dangerous call).
			//
			// fail-safe：只有显式 approve 才跑工具；deny / 意外动作都不跑（畸形 resolve 绝不能执行危险调用）。
			if resp.Action != humanloopapp.DecisionApprove && resp.Action != humanloopapp.DecisionApproveAlways {
				return humanloopapp.DenyFeedback, "", true, false, false
			}
			humanApproved = true
			// approve / approve_always → fall through and execute
		}
	}
	output, errMsg, ok = executeTool(ctx, t, tc.Name, argsJSON, log)
	return output, errMsg, ok, true, humanApproved
}

// resolvedToolName is the name the executor actually resolved. It is kept separate from the
// model's prose so the human gate and audit trail cannot describe a different operation.
//
// resolvedToolName 返回执行器实际解析到的名字。它与模型 prose 分离，确保人闸与审计不会描述另一个动作。
func resolvedToolName(t toolapp.Tool, tc messagesdomain.ToolCallData) string {
	if t != nil && t.Name() != "" {
		return t.Name()
	}
	return tc.Name
}

// canonicalGateSummary is the user-facing action sentence for a dangerous gate. The LLM summary
// remains useful on the tool card, but it is deliberately not used here: approval must identify the
// operation that will actually execute. Lifecycle verbs get explicit copy because "deactivate",
// "kill", and "delete" have materially different consequences.
//
// canonicalGateSummary 是危险闸面向用户的动作句。LLM summary 仍可在工具卡使用，但刻意不用于这里：批准
// 必须指出将真实执行的动作。生命周期动词的后果不同，故 deactivate / kill / delete 使用明确文案。
func canonicalGateSummary(t toolapp.Tool, tc messagesdomain.ToolCallData, outsideWorkDir bool) string {
	name := resolvedToolName(t, tc)
	if outsideWorkDir {
		return fmt.Sprintf("Write outside the conversation work directory using `%s`. The exact target is shown below.", name)
	}
	switch name {
	case "delete_function":
		return "Remove this function from the active catalog. Its primary entity and actions are not restorable; sandbox environments are destroyed, version history is retained for audit, and dependent relations are purged."
	case "delete_handler":
		return "Remove this handler from the active product surface. Its resident instance stops, the handler and its actions are not restorable, immutable versions remain for audit, and relation edges are purged."
	case "delete_agent":
		return "Remove this agent from the active product surface. Its active configuration is not restorable; execution history is retained for audit and relation edges are purged."
	case "delete_control":
		return "Delete this control logic and all its versions. This is not reversible and has no restore operation; workflows that reference it may fail capability checks."
	case "delete_approval":
		return "Remove this approval form from normal reads. Its primary row is not restorable; immutable versions remain for audit, relation edges are purged, and referencing workflows may fail capability checks."
	case "delete_skill":
		return "Permanently delete this skill and its directory. This cannot be undone; agents equipped with it may fail after its relation is removed."
	case "delete_trigger":
		return "Remove this trigger from normal reads and stop its listener. The primary row is not restorable; activation and firing history remains for audit, relation edges are purged, and referencing workflows may stop receiving its signal."
	case "delete_workflow":
		return "Permanently delete this workflow from normal reads. It is not restorable; automation is stopped and history is retained for audit."
	case "forget_memory":
		return "Permanently delete this memory from the workspace. This cannot be undone and has no restore operation; it will no longer appear in future context."
	case "install_mcp_server":
		return "Install this MCP server into the workspace. This persists its configuration, may start a resident process or external connection, and can add new capabilities and encrypted credentials."
	case "uninstall_mcp_server":
		return "Uninstall this MCP server from the workspace. This stops its resident process, permanently deletes its persistent configuration, and makes its tools unavailable."
	case "deactivate_workflow":
		return "Take this workflow offline gracefully: stop accepting new triggers and let in-flight runs finish."
	case "kill_workflow":
		return "Hard-stop this workflow: stop accepting new triggers and cancel every in-flight run immediately."
	default:
		return fmt.Sprintf("Run the `%s` operation. The selected tool is `%s`.", name, name)
	}
}

// toolIntentConflict catches the high-consequence lifecycle mix-ups that can otherwise pass a
// human gate with a misleading model summary (for example delete_workflow + "deactivate"). The
// call is rejected before approval or side effect; the model receives a concrete correction and
// may select the intended tool on the next step.
//
// toolIntentConflict 拦截高后果生命周期动作的自相矛盾，避免错误调用带着误导 summary 通过人闸（例如
// delete_workflow + "deactivate"）。它在批准和副作用之前拒绝，模型收到明确纠正后可在下一步选择正确工具。
func toolIntentConflict(toolName, summary string) string {
	s := strings.ToLower(strings.TrimSpace(summary))
	if s == "" {
		return ""
	}
	has := func(parts ...string) bool {
		for _, part := range parts {
			if strings.Contains(s, part) {
				return true
			}
		}
		return false
	}
	var expected string
	switch toolName {
	case "delete_workflow":
		if has("deactivat", "graceful", "offline", "stop listening", "drain") {
			expected = "deactivate_workflow"
		}
	case "deactivate_workflow":
		if has("delete", "permanent", "remove", "irreversible") {
			expected = "delete_workflow"
		}
	case "kill_workflow":
		if has("deactivat", "graceful", "offline", "let.*finish", "drain") {
			expected = "deactivate_workflow"
		}
	case "activate_workflow":
		if has("deactivat", "offline", "stop listening") {
			expected = "deactivate_workflow"
		}
	}
	if expected == "" {
		return ""
	}
	return fmt.Sprintf("tool selection conflict: `%s` was selected, but its summary describes `%s`; no tool was executed. Select `%s` for the described operation.", toolName, expected, expected)
}

// writesOutsideWorkDir reports whether this call physically writes a file outside the conversation's
// residency — the one condition that forces the human gate regardless of the LLM's self-reported danger
// (WRK-077 WD1). False whenever there is no residency, which is the default, so an unmounted conversation
// behaves exactly as it did before WD1.
//
// Why this outranks the self-report: everywhere else the danger level is the model's honest opinion about
// its own action, and that is the design (S18: no central permission gate, pure trust + per-call
// confirmation). "Am I about to write outside the folder the user pointed at?" is not an opinion — it is
// a computable fact about the target path, and the user's whole instruction for the residency was that
// looking outside is free while WRITING outside is the thing to ask about. A model that resolves a path
// slightly wrong, or that judges an overwrite `safe` because the content looks harmless, must not be able
// to skip that question. Reads are never gated here: the residency is a zoom, not a jail.
//
// It reads the raw path through the SAME fspath.ExpandIn the tool itself will use, so the gate judges the
// exact file Execute will open — a second resolver would eventually disagree with the first, and the
// disagreement would silently be a hole. Inside() is fail-closed, so an unresolvable root or an escaping
// symlink gates rather than passes.
//
// writesOutsideWorkDir 报告本次调用是否会把文件写到对话驻地**之外**——那是**唯一**无视 LLM 自报 danger 而
// 强制人闸的条件（WRK-077 WD1）。无驻地时恒 false，而那是默认，故未挂对话的行为与 WD1 之前**完全**一致。
//
// 为何它盖过自报：其余一切地方，danger 等级都是模型对自己行为的诚实意见，而那正是设计（S18：无中央权限
// 门控，纯信任 + 逐次确认）。而「我是不是正要写到用户指的那个文件夹外面去?」**不是**意见——它是关于目标
// 路径的一个可计算的**事实**，而用户对驻地的全部指示就是：往外**看**随便，往外**写**才是要问的那件事。一个
// 把路径解析得稍有偏差、或因为内容看起来无害就判某次覆写 `safe` 的模型，绝不能有跳过这个问题的能力。
// 此处从不拦**读**：驻地是 zoom、不是牢。
//
// 它经**同一个** fspath.ExpandIn 读那个原始路径——正是工具自己将要用的那一个，故闸判的就是 Execute 将要打开
// 的那个文件；两个解析器终会互相不同意，而那份不同意会静默地成为一个洞。Inside() 是 fail-closed 的，故解不开
// 的根或逃逸的符号链接是**设闸**、不是放行。
func writesOutsideWorkDir(ctx context.Context, t toolapp.Tool, argsJSON []byte) bool {
	root := reqctxpkg.GetWorkDir(ctx)
	if root == "" {
		return false
	}
	fw, isWriter := t.(toolapp.FileWriteTool)
	if !isWriter {
		return false
	}
	raw := fw.WriteTarget(argsJSON)
	if strings.TrimSpace(raw) == "" {
		return false // no determinable target: Execute will refuse it anyway (see FileWriteTool)
	}
	target, err := fspathpkg.ExpandIn(root, raw)
	if err != nil {
		return false // an unresolvable path never reaches the filesystem; Execute reports the real reason
	}
	return !fspathpkg.Inside(root, target)
}

// skillPreApproves reports whether the run's active skill declared this tool in its allowed-tools.
// A skill's allowed-tools are a PRE-AUTHORIZATION, not a restriction: a dangerous call the
// active skill expects skips the per-call confirmation. No agent state / no active skill → false
// (the gate stands). It does NOT reach the residency write gate — see dispatchWithGate.
//
// skillPreApproves 报告本次运行的 active skill 是否在其 allowed-tools 里声明了该工具。skill 的 allowed-tools
// 是**预授权**、非限制：active skill 期待的危险调用跳过逐次确认。无 agent state / 无 active skill →
// false（门照常）。active skill 由 skill 激活记录（skill/activate.go）。
func skillPreApproves(ctx context.Context, toolName string) bool {
	st, ok := reqctxpkg.GetAgentState(ctx)
	return ok && st.IsToolPreApprovedBySkill(toolName)
}

// maxToolResultBytes() hard-caps any single tool_result. The result is persisted whole, rides a
// durable SSE open frame whole, and feeds the SAME turn's next LLM step whole (warm/cold
// projection only trims LATER turns) — so one unbounded result (a head_limit-less Grep over a
// big tree, a chatty MCP tool) would blow the provider request, the DB row, and the frontend
// frame all at once. 256 KiB matches the Bash tool's own cap.
//
// maxToolResultBytes() 硬限单个 tool_result。结果会整段落库、整段上 durable SSE open 帧、并整段进入
// **同一回合**下一步的 LLM 请求（warm/cold 投影只裁后续回合）——一个无界结果（不带 head_limit 的
// 大树 Grep、话痨 MCP 工具）会同时打爆 provider 请求、DB 行与前端帧。256 KiB 对齐 Bash 自身的 cap。

// maxToolResultBytes reads the live tool_result cap (limits.Tools.ToolResultCapKB).
//
// maxToolResultBytes 读活动 tool_result 上限（limits.Tools.ToolResultCapKB）。
func maxToolResultBytes() int { return limitspkg.Current().Tools.ToolResultCapKB << 10 }

// capToolResult truncates an oversized result (keeping the head — for search-style output the
// first matches are the useful ones) and tells the LLM how to narrow.
//
// capToolResult 截断超限结果（保头部——搜索类输出前面的命中才有用）并告诉 LLM 如何收窄。
func capToolResult(s string) string {
	if len(s) <= maxToolResultBytes() {
		return s
	}
	return s[:maxToolResultBytes()] + fmt.Sprintf(
		"\n...[tool result truncated: %d of %d bytes shown — narrow the query (filters / head_limit / pagination) to see the rest]",
		maxToolResultBytes(), len(s))
}

// executeTool runs ValidateInput then Execute and shapes the (output, errMsg, ok) tuple.
// There is no central permission gate or generic domain translation: a tool owns the quality of its
// error (clean text, any next-step hint), while the loop removes Go wrapper paths before the result
// becomes user-visible.
//
// executeTool 跑 ValidateInput 再 Execute，整形 (output, errMsg, ok) 三元组。无中央权限门控、
// 也无通用领域翻译：工具自负其 error 质量（干净文本、必要的 next-step 提示），loop 只在结果
// 面向用户之前去掉 Go 包装路径。
func executeTool(ctx context.Context, t toolapp.Tool, name string, argsJSON []byte, log *zap.Logger) (output, errMsg string, ok bool) {
	if t == nil {
		// The LLM named a tool not in this turn's set — a wiring bug or a stale catalog.
		// LLM 点了本回合工具集外的工具——接线 bug 或过期 catalog。
		log.Warn("executeTool: tool not in registry — likely wiring bug or stale catalog", zap.String("tool", name))
		msg := fmt.Sprintf("Tool %q is not available in this turn, so nothing was executed. Use a tool from the current catalog, or tell the user that the requested operation is unavailable.", name)
		if name == "search_memory" {
			msg += " Memory lookup uses a listed memory name with read_memory; there is no search_memory tool."
		}
		return msg, msg, false
	}

	// The args couldn't be parsed as JSON even after repair (parseToolArgs left the rawArgsKey
	// sentinel) — say THAT plainly, not the tool's downstream "field X required" which misdirects the
	// agent from the real problem (its JSON was malformed) (F-toolargs-opacity). Echo the raw text the
	// agent actually sent (truncated) so its retry isn't blind — it can see WHAT was malformed (F168-M9).
	// 即便修复也无法解析成 JSON（parseToolArgs 留下 rawArgsKey 哨兵）——直说，而非工具下游的 "field X
	// required"（把 agent 从真问题=JSON 畸形引开）。回显 agent 实际发的原文（截断），使 retry 不盲——它能
	// 看见**什么**畸形了（F168-M9）。
	if raw, ok := unparsedRaw(argsJSON); ok {
		const maxEcho = 512
		echo := raw
		if len(echo) > maxEcho {
			echo = echo[:maxEcho] + fmt.Sprintf("…(+%d bytes truncated)", len(raw)-maxEcho)
		}
		msg := "your tool arguments were not valid JSON and could not be auto-repaired — re-send the call as a single well-formed JSON object. The text received was: " + echo
		return msg, msg, false
	}

	// Both failure logs render the error through [llmErrText], NOT `zap.Error` — same key, richer value.
	// `zap.Error` calls `Error()`, which drops Details by construction, so the reason the domain already
	// computed (which op, which node, the real CEL error) survived only into the LLM's copy and was
	// thrown away in the operator's. That asymmetry is backwards: the model can retry, the human reading
	// the log at 3am cannot.
	// 两条失败日志都经 [llmErrText] 渲染错误、**不用** `zap.Error`——同一个键、更富的值。`zap.Error` 调
	// `Error()`,而它按构造丢 Details,于是 domain **已经算出来的**原因(哪个 op、哪个节点、真正的 CEL 错误)
	// 只活进了 LLM 那一份、在运维那一份里被扔掉。这个不对称是反的:模型还能重试,凌晨读日志的人不能。
	if err := t.ValidateInput(argsJSON); err != nil {
		log.Warn("tool validate failed", zap.String("tool", name), zap.String("error", llmErrText(err)))
		msg := "input validation failed: " + llmErrText(err)
		return msg, msg, false
	}

	output, err := t.Execute(ctx, string(argsJSON))
	output = capToolResult(output)
	if err != nil {
		msg := llmErrText(err)
		log.Warn("tool execute failed", zap.String("tool", name), zap.String("error", msg))
		if output != "" {
			return output + "\n\n" + msg, msg, false
		}
		return msg, msg, false
	}
	return output, "", true
}

// unparsedRaw reports whether argsJSON is the single-key rawArgsKey sentinel parseToolArgs leaves
// when the LLM's tool arguments could not be decoded as JSON even after repair, and if so returns
// the LLM's ORIGINAL malformed text. rawArgsKey is a reserved internal token no tool parameter can
// be named, so this shape is unambiguous (F165). Returning the raw lets executeTool echo back what
// the agent actually sent, so its retry is not blind (F168-M9).
//
// unparsedRaw 报告 argsJSON 是否是 parseToolArgs 在 LLM 工具参数即便修复也无法解析时留下的单键
// rawArgsKey 哨兵，是则返回 LLM 的原始畸形文本。rawArgsKey 是任何工具参数都不可能取的保留内部 token，
// 故此形状无歧义（F165）。返回原文让 executeTool 回显 agent 实际发的内容、使 retry 不盲（F168-M9）。
func unparsedRaw(argsJSON []byte) (string, bool) {
	var m map[string]any
	if json.Unmarshal(argsJSON, &m) != nil || len(m) != 1 {
		return "", false
	}
	raw, ok := m[rawArgsKey].(string)
	return raw, ok
}

// llmErrText renders an error for the LLM: the message PLUS any structured Details a tool/domain
// attached (e.g. a workflow validation's "reason" naming the offending node + the actual CEL error).
// Error() alone drops Details — they are computed for the N1 envelope yet are exactly the actionable
// part the agent needs to self-correct. Surfacing them here de-opaques tool errors for EVERY tool,
// not just the one that prompted it (an opaque "workflow graph is invalid" had the agent guessing
// CEL syntax blindly across ~8 attempts).
//
// llmErrText 把 error 渲给 LLM：message + 工具/domain 附的结构化 Details（如 workflow 校验的 "reason"
// 点名违例节点 + 真实 CEL 错）。Error() 本身丢 Details——它为 N1 envelope 算出、却正是 agent 自纠所需。
// 在此浮出，一处给**所有**工具去不透明化（不透明的 "workflow graph is invalid" 曾让 agent 盲猜 CEL ~8 次）。
// llmErrText surfaces the LLM-facing error text (clean Message + Details, no Go call-path) for a
// tool result — see errorspkg.Surface, the single source this and the scheduler's nodeErrText share
// (F89 established the behavior; extracted to the foundation when a third site needed it).
//
// llmErrText 给工具结果浮出 LLM 可见错误文本（干净 Message + Details、无 Go 调用路径）——见
// errorspkg.Surface（本函数与 scheduler 的 nodeErrText 共用的单一来源；F89 立此行为、第三处需用时下沉地基）。
func llmErrText(err error) string {
	return errorspkg.Surface(err)
}

type indexedCall struct {
	idx int
	tc  messagesdomain.ToolCallData
}

type handledCall struct {
	call           indexedCall
	haltOnRepeat   bool
	terminalRepeat bool
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

// partitionByExecutionGroup buckets calls by ExecutionGroup; ≤0 get sequential auto-groups
// (each its own batch) placed after the explicit ones. Same explicit group → one batch →
// concurrent; distinct groups → separate batches → ordered.
//
// partitionByExecutionGroup 按 ExecutionGroup 分桶；≤0 获顺序自动组（各自一批）排在显式组之后。
// 同一显式组 → 一批 → 并行；不同组 → 分批 → 有序。
func partitionByExecutionGroup(calls []messagesdomain.ToolCallData) []executionBatch {
	if len(calls) == 0 {
		return nil
	}

	maxExplicit := 0
	for _, tc := range calls {
		maxExplicit = max(maxExplicit, tc.ExecutionGroup)
	}
	nextAuto := max(maxExplicit+1, autoGroupBase)

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
