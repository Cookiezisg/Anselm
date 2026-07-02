// The conversation-ledger tap on the loop's tool choke point: EVERY tool execution in the
// system flows through runOneTool, so this one call site observes "the AI touched item X"
// for the whole tool universe — no per-tool code. The recorder rides ctx (seeded by the chat
// runner; subagent/invoke ctxs inherit it), so conversation-less paths (workflow dispatch,
// REST) have nothing to find and skip at zero cost.
//
// 对话台账在 loop 工具咽喉上的水龙头:全系统每次工具执行都过 runOneTool,故这一个调用点就观测到
// 全工具宇宙的「AI 碰了物 X」——零逐工具代码。记账器随 ctx(chat runner 种入;subagent/invoke
// ctx 继承),无对话路径(workflow 派发、REST)找不到它、零成本跳过。
package loop

import (
	"context"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	touchpointapp "github.com/sunweilin/anselm/backend/internal/app/touchpoint"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// entityTool is the OPTIONAL self-report marker for tools bound to one entity (the agent
// mount universe: a mounted function/handler/mcp runs under the ENTITY'S OWN NAME, so the
// name-keyed catalog can't know it — and a user entity named like a catalog key would even
// mis-extract). A marker tool bypasses the catalog entirely: its touch is what it declares.
// Structural (no import): mount tools implement it where they live.
//
// entityTool 是绑定单一实体的工具的**可选自报标记**(agent 挂载宇宙:挂载的 function/handler/mcp
// 以**实体自己的名字**为工具名,按名字键的目录不可能认识它——用户实体若恰好叫某目录键名还会被
// 误提取)。带标记的工具完全绕过目录:它的触碰以自报为准。结构化接口(零 import):mount 工具就地实现。
type entityTool interface {
	TouchEntity() (kind, id, name string)
}

// recordTouches books an EXECUTED, successful tool call's touch targets into the conversation
// ledger. "Failed" here means TOOL-LEVEL failure (ok&&executed is false: denied/cancelled-before-run
// by the danger gate, or the tool returned a Go error — bad ref, malformed args) — those never record
// (a touch that didn't happen is not a touch). A tool that ran fine but whose underlying entity
// operation failed INTERNALLY (e.g. run_function on a real function that raised) is ok=true and DOES
// book "executed": the ledger is a factual footprint of what the conversation touched, and that entity
// really was executed — consistent with viewed/created booking regardless of downstream outcome.
// Extraction under-reports rather than errors; Record itself is best-effort — nothing here disturbs the turn.
//
// recordTouches 把一次**真执行且成功**的工具调用的触碰目标记入对话台账。这里的「失败」指**工具层**失败
// (ok&&executed 为假:被 danger 门拒/运行前取消,或工具返 Go error——坏 ref、畸形参数)——这些不记(没发生的
// 触碰不是触碰)。工具跑得好但底层实体操作**内部**失败(如 run_function 跑一个真函数而它 raise)是 ok=true、
// **会**记 executed:台账是「对话碰过什么」的事实足迹,该实体确被执行——与 viewed/created 无条件记一致。
// 提取宁少报不报错;Record 本身 best-effort——不扰动回合。
func recordTouches(ctx context.Context, t toolapp.Tool, tc messagesdomain.ToolCallData, output string, ok bool) {
	if !ok {
		return
	}
	rec, found := touchpointapp.From(ctx)
	if !found {
		return
	}
	conv, found := reqctxpkg.GetConversationID(ctx)
	if !found {
		return
	}
	var refs []touchpointapp.ItemRef
	if et, isEntity := t.(entityTool); isEntity {
		kind, id, name := et.TouchEntity()
		refs = []touchpointapp.ItemRef{{Kind: kind, ID: id, Name: name, Verb: touchpointdomain.VerbExecuted}}
	} else {
		refs = touchpointapp.ExtractTouches(tc.Name, tc.Arguments, output)
	}
	if len(refs) == 0 {
		return
	}
	actor := touchpointdomain.ActorAssistant
	if _, sub := reqctxpkg.GetSubagentID(ctx); sub {
		actor = touchpointdomain.ActorSubagent
	}
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	for _, r := range refs {
		rec.Record(ctx, touchpointdomain.Touch{
			ConversationID: conv,
			ItemKind:       r.Kind,
			ItemID:         r.ID,
			ItemName:       r.Name,
			Verb:           r.Verb,
			Actor:          actor,
			MessageID:      msgID,
		})
	}
}
