// Package agent (app layer) orchestrates the agent domain: forging config versions, running
// the ReAct loop (invoke), the execution-log surface, and the relation / catalog adapters.
//
// The version model is linear append-only with a free-moving ActiveVersionID pointer — no
// pending/accept. Create/edit write a new version (max+1) and take effect immediately; revert
// just moves the pointer. An agent writes no code, so there is NO sandbox dependency; instead
// invoke needs three injected ports (DIP): an LLM resolver, the global tool provider, and a
// knowledge renderer — none of which the agent owns.
//
// Package agent（app 层）编排 agent domain：锻造配置版本、跑 ReAct loop（invoke）、execution-log
// 面、relation / catalog 适配器。版本模型线性只增 + 可移动 ActiveVersionID 指针——无 pending/accept。
// create/edit 写新版本（max+1）立即生效；revert 只移指针。agent 不写代码，故**无 sandbox 依赖**；
// invoke 需三个注入端口（DIP）：LLM resolver、全局工具 provider、knowledge renderer——agent 自己都不拥有。
package agent

import (
	"context"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	notificationdomain "github.com/sunweilin/forgify/backend/internal/domain/notification"
	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// LLMBundle is a ready-to-run LLM client + a pre-filled base Request (ModelID/Key/BaseURL/
// Thinking/Options). InvokeAgent fills System + lets loop.Run compose Messages from the host.
//
// LLMBundle 是即用的 LLM client + 预填的 base Request（ModelID/Key/BaseURL/Thinking/Options）。
// InvokeAgent 填 System，Messages 由 loop.Run 从 host 组装。
type LLMBundle struct {
	Client  llminfra.Client
	Request llminfra.Request
}

// LLMResolver turns a (nil = default agent scenario) model override into a runnable bundle.
// Implemented at boot over model-picker + apikey + llm-factory — the agent owns none of that.
//
// LLMResolver 把（nil = 默认 agent 场景）model 覆盖解析为可运行 bundle。boot 时基于 model-picker +
// apikey + llm-factory 实现——agent 自己都不拥有。
type LLMResolver interface {
	ResolveAgent(ctx context.Context, override *modeldomain.ModelRef) (LLMBundle, error)
}

// KnowledgeProvider renders the agent's attached document IDs into a prompt-prefix string.
//
// KnowledgeProvider 把 agent 挂的文档 ID 渲染成 prompt 前缀字符串。
type KnowledgeProvider interface {
	BuildKnowledgePrefix(ctx context.Context, docIDs []string) (string, error)
}

// InvokeDeps are the LLM-side dependencies InvokeAgent needs, injected post-construction (DIP).
// Tools returns the full global tool registry; invoke filters it to the agent's whitelist.
//
// InvokeDeps 是 InvokeAgent 需要的 LLM 侧依赖，构造后注入（DIP）。Tools 返回全局工具表；invoke 按
// agent 白名单过滤。
type InvokeDeps struct {
	Resolver  LLMResolver
	Tools     func() []toolapp.Tool
	Knowledge KnowledgeProvider

	// EntitiesBridge (SSE-C, nil-tolerant): the agent run mirrors its ReAct trace (every block)
	// onto the entities stream scoped to the agent, so the agent panel shows the run live —
	// regardless of caller (chat / REST / workflow node). A stream, not the messages-table coupling
	// B5 deliberately avoided.
	//
	// EntitiesBridge（SSE-C，允许 nil）：agent run 把 ReAct 轨迹（每个 block）镜像到 agent scope 的 entities
	// 流，使 agent 面板实时显示运行——与谁触发无关（chat / REST / workflow 节点）。是流、非 B5 刻意回避的
	// messages 表耦合。
	EntitiesBridge streamdomain.Bridge
}

// RelationSyncer is the slice of relationapp.Service the agent consumes (nil-tolerant). Agents
// have both outgoing edges (the mounted skill/doc/fn/hd/mcp) and incoming edges (the
// conversation that forged/edited a version).
//
// RelationSyncer 是 agent 消费的 relationapp.Service 切片（允许 nil）。agent 有出边（挂载的
// skill/doc/fn/hd/mcp）也有入边（锻造/编辑某版本的对话）。
type RelationSyncer interface {
	SyncOutgoing(ctx context.Context, fromKind, fromID string, kindScope []string, edges []relationdomain.SyncEdge) error
	SyncIncoming(ctx context.Context, toKind, toID string, kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// Service orchestrates the agent domain.
//
// Service 编排 agent domain。
type Service struct {
	repo      agentdomain.Repository
	invoke    InvokeDeps
	relations RelationSyncer             // nil disables relation hooks
	notif     notificationdomain.Emitter // nil-tolerant
	log       *zap.Logger
}

// NewService wires the service; nil repo / log is a wiring bug. invoke deps + relations are
// injected later (SetInvokeDeps / SetRelationSyncer) to avoid init cycles.
//
// NewService 装配 service；nil repo / log 是装配 bug。invoke deps + relations 后注入（避 init 环）。
func NewService(repo agentdomain.Repository, notif notificationdomain.Emitter, log *zap.Logger) *Service {
	if repo == nil {
		panic("agentapp.NewService: repo is nil")
	}
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{repo: repo, notif: notif, log: log}
}

// SetRelationSyncer installs the relation Service post-construction (avoids an init cycle).
//
// SetRelationSyncer 装配后注入 relation Service（避 init 环）。
func (s *Service) SetRelationSyncer(r RelationSyncer) { s.relations = r }

// SetInvokeDeps installs the LLM-side invoke dependencies (resolver / tools / knowledge).
// Until called, InvokeAgent returns an error — CRUD works without them.
//
// SetInvokeDeps 注入 LLM 侧 invoke 依赖。未注入前 InvokeAgent 报错——CRUD 不依赖它们。
func (s *Service) SetInvokeDeps(deps InvokeDeps) { s.invoke = deps }

// publish emits an agent lifecycle notification; nil emitter is a no-op.
//
// publish 发一条 agent 生命周期通知；nil emitter 为 no-op。
func (s *Service) publish(ctx context.Context, action, agentID string, extra map[string]any) {
	if s.notif == nil {
		return
	}
	payload := map[string]any{"agentId": agentID}
	for k, v := range extra {
		payload[k] = v
	}
	if err := s.notif.Emit(ctx, "agent."+action, payload); err != nil {
		s.log.Warn("agentapp.publish: emit failed", zap.String("action", action), zap.Error(err))
	}
}

// loopHostType pins the loop.Host interface so a compile error fires if agentHost drifts.
var _ loopapp.Host = (*agentHost)(nil)
