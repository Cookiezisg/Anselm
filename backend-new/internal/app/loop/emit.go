package loop

import (
	"context"
	"encoding/json"

	"go.uber.org/zap"

	entitystreamapp "github.com/sunweilin/forgify/backend/internal/app/entitystream"
	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// bridgeKey carries the messages-stream Bridge through ctx so block lifecycle can be pushed
// from deep in the call stack (streamLLM, runOneTool) without threading it as a parameter —
// the same seam the old eventlog Emitter used.
//
// bridgeKey 经 ctx 携带 messages 流的 Bridge，使 block 生命周期能从深调用栈（streamLLM、
// runOneTool）推送而无需层层传参——与旧 eventlog Emitter 同一条缝。
type bridgeKey struct{}

// WithBridge seeds the messages-stream Bridge so the loop live-pushes block lifecycle as it
// runs. The host (chat / agent) injects the Bus's messages instance before Run. A run
// without it — or without a conversation id — still accumulates blocks in memory and
// finalizes; it just doesn't stream (e.g. a workflow agent step). nil = no-op so callers may
// pass unconditionally.
//
// WithBridge 埋 messages 流的 Bridge，使 loop 边跑边实时推 block 生命周期。host（chat / agent）
// 在 Run 前注入 Bus 的 messages 实例。无它——或无对话 id——的运行仍内存累加 block 并终态落盘，
// 只是不推流（如 workflow agent 步）。nil = no-op，caller 可无条件传。
func WithBridge(ctx context.Context, b streamdomain.Bridge) context.Context {
	if b == nil {
		return ctx
	}
	return context.WithValue(ctx, bridgeKey{}, b)
}

func bridgeFrom(ctx context.Context) streamdomain.Bridge {
	b, _ := ctx.Value(bridgeKey{}).(streamdomain.Bridge)
	return b
}

// emitter live-pushes one turn's block lifecycle to the messages stream, anchored at
// conversation:<id>. It is best-effort: with no Bridge or conversation id it disables
// itself, so the loop body calls open/delta/close unconditionally and a non-streaming run
// simply skips the push. A dropped push is recovered by SSE replay + the REST history.
//
// emitter 把一个回合的 block 生命周期实时推到 messages 流，锚在 conversation:<id>。它
// best-effort：无 Bridge 或对话 id 时自禁用，故循环体无条件调 open/delta/close，非流式运行直接
// 跳过推送。漏推由 SSE replay + REST 历史兜回。
type emitter struct {
	bridge streamdomain.Bridge
	scope  streamdomain.Scope
	// mirror (SSE-C, optional): when this loop run IS an entity's execution (WithRunScope), every
	// frame is ALSO published to the entities stream scoped to that entity — the agent panel shows
	// the run's ReAct trace live. Independent of the messages side (an off-chat agent run mirrors
	// even with no conversation).
	//
	// mirror（SSE-C，可选）：当本次 loop run 即某实体的执行（WithRunScope）时，每帧**也**发到该实体 scope 的
	// entities 流——agent 面板实时显示运行的 ReAct 轨迹。独立于 messages 侧（不在 chat 的 agent run 即使无
	// conversation 也镜像）。
	mirrorBridge streamdomain.Bridge
	mirrorScope  streamdomain.Scope
	log          *zap.Logger
}

// newEmitter assembles the emitter from ctx, independently wiring two destinations: the messages
// stream (WithBridge + a conversation anchor) and/or the entities mirror (entitystream.WithBridge +
// WithRunScope). Both absent → a no-op emitter.
//
// newEmitter 从 ctx 组装 emitter，独立接两个目的地：messages 流（WithBridge + 对话锚点）和/或 entities
// 镜像（entitystream.WithBridge + WithRunScope）。两者皆缺 → no-op emitter。
func newEmitter(ctx context.Context, log *zap.Logger) emitter {
	em := emitter{log: log}
	if b := bridgeFrom(ctx); b != nil {
		if conv, ok := reqctxpkg.GetConversationID(ctx); ok {
			em.bridge = b
			em.scope = streamdomain.Scope{Kind: streamdomain.KindConversation, ID: conv}
		}
	}
	if mb := entitystreamapp.BridgeFrom(ctx); mb != nil {
		if sc, ok := entitystreamapp.RunScopeFrom(ctx); ok {
			em.mirrorBridge = mb
			em.mirrorScope = sc
		}
	}
	return em
}

func (e emitter) publish(ctx context.Context, nodeID string, frame streamdomain.Frame) {
	if e.bridge != nil {
		if _, err := e.bridge.Publish(ctx, streamdomain.Event{Scope: e.scope, ID: nodeID, Frame: frame}); err != nil {
			e.log.Warn("messages stream push failed", zap.String("node_id", nodeID), zap.Error(err))
		}
	}
	if e.mirrorBridge != nil {
		_, _ = e.mirrorBridge.Publish(ctx, streamdomain.Event{Scope: e.mirrorScope, ID: nodeID, Frame: frame})
	}
}

// open starts a streaming block node. parentID empty → anchor under the turn's message;
// non-empty → nest (a tool_result under its tool_call).
//
// open 开一个流式 block 节点。parentID 空 → 挂回合 message 下；非空 → 嵌套（tool_result 挂其
// tool_call 下）。
func (e emitter) open(ctx context.Context, blockID, parentID, nodeType string, content json.RawMessage) {
	e.publish(ctx, blockID, streamdomain.Open{
		ParentID: parentID,
		Node:     streamdomain.Node{Type: nodeType, Content: content},
	})
}

// delta appends a streaming chunk to an open block (token text / tool args). Empty chunks
// are skipped so a signature-only reasoning event doesn't emit an empty frame.
//
// delta 给开着的 block 追加流式 chunk（token 文本 / tool args）。空 chunk 跳过，使只带签名的
// reasoning 事件不发空帧。
func (e emitter) delta(ctx context.Context, blockID, chunk string) {
	if chunk == "" {
		return
	}
	e.publish(ctx, blockID, streamdomain.Delta{Chunk: chunk})
}

// close terminates a block. result (non-nil) carries the final content snapshot — the
// reconnect source of truth, since deltas are lossy.
//
// close 结束一个 block。result（非 nil）携带最终内容快照——重连真相，因 delta 可丢。
func (e emitter) close(ctx context.Context, blockID, status string, result *streamdomain.Node, errMsg string) {
	e.publish(ctx, blockID, streamdomain.Close{Status: status, Result: result, Error: errMsg})
}
