package scheduler

import (
	"context"
	"encoding/json"
	"fmt"

	"go.uber.org/zap"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	limitspkg "github.com/sunweilin/forgify/backend/internal/pkg/limits"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
)

// AgentEntityResolver is the port AgentDispatcher uses to load an agent entity by agentRef.
// Implements doc 02 §"节点形态": agentRef makes the node reference a managed Agent entity.
//
// AgentEntityResolver 是 AgentDispatcher 按 agentRef 加载 Agent 实体的端口。
type AgentEntityResolver interface {
	GetAgentConfig(ctx context.Context, agentRef string) (prompt string, maxTurns int, enabledTools []string, modelOverride string, err error)
}

// AgentDispatcher runs the workflow `agent` node — an agentic ReAct loop
// (multi-turn, full system-tool registry) wrapped around app/loop.Run.
// When config.agentRef is set, loads config from the Agent entity (quadrinity pattern, doc 02).
// When config.prompt is set inline, uses it directly (backwards compat).
//
// AgentDispatcher 跑 workflow `agent` 节点;agentRef 时从 Agent 实体加载配置，否则用内联字段。
type AgentDispatcher struct {
	picker        modeldomain.ModelPicker
	keys          apikeydomain.KeyProvider
	factory       *llminfra.Factory
	documents     DocumentResolver
	toolsFn       func() []toolapp.Tool
	log           *zap.Logger
	agentResolver AgentEntityResolver // optional: resolves agentRef → entity config
}

// SetAgentResolver wires the agent entity resolver post-construction (avoids import cycle).
func (d *AgentDispatcher) SetAgentResolver(r AgentEntityResolver) { d.agentResolver = r }

// NewAgentDispatcher wires deps. nil picker/keys/factory → dispatch errs;
// nil documents simply skips attach prefix; toolsFn returns the tool slice
// at dispatch time (so registrations that append AFTER wire-up still take
// effect — common when D22 read-only tools are added later in main.go boot).
//
// NewAgentDispatcher 装配依赖。nil picker/keys/factory 时 dispatch 返错;
// nil documents 跳过 attach 前缀;toolsFn 在 dispatch 时读取(支持装配后
// append——main.go boot 末尾追加 D22 只读工具是常见情况)。
func NewAgentDispatcher(
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
	documents DocumentResolver,
	toolsFn func() []toolapp.Tool,
	log *zap.Logger,
) *AgentDispatcher {
	if log == nil {
		log = zap.NewNop()
	}
	return &AgentDispatcher{
		picker:    picker,
		keys:      keys,
		factory:   factory,
		documents: documents,
		toolsFn:   toolsFn,
		log:       log,
	}
}

func (d *AgentDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	if d.picker == nil || d.keys == nil || d.factory == nil {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: missing picker/keys/factory", in.Node.ID)}
	}

	cfg := in.Node.Config

	// agentRef support (doc 02 §"节点形态"): if config.agentRef is set, load prompt/maxTurns/tools
	// from the Agent entity's active version. Falls back to inline config for backwards compat.
	var entityMaxTurns int
	var entityEnabledTools []string
	var entityModelOverride string
	if agentRef, ok := cfg["agentRef"].(string); ok && agentRef != "" && d.agentResolver != nil {
		// Use the run ctx (carries userID) — NOT Background(): the agent store scopes Get by
		// user_id, so Background() would fail RequireUserID and agentRef resolution would always error.
		p, mt, et, mo, rErr := d.agentResolver.GetAgentConfig(ctx, agentRef)
		if rErr != nil {
			return DispatchOutput{Error: fmt.Errorf("agent node %q: resolve agentRef %q: %w", in.Node.ID, agentRef, rErr)}
		}
		// Override inline config with entity values.
		cfg = make(map[string]any, len(cfg))
		for k, v := range in.Node.Config {
			cfg[k] = v
		}
		if p != "" {
			cfg["prompt"] = p
		}
		entityMaxTurns = mt
		entityEnabledTools = et
		entityModelOverride = mo
	}

	prompt, _ := cfg["prompt"].(string)
	if prompt == "" {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: prompt required (set config.prompt or config.agentRef)", in.Node.ID)}
	}
	_ = entityModelOverride // used below in model override logic when entity sets it

	// Workflow agent nodes are the ONE place a turn cap stays load-bearing: a
	// triggered workflow runs unattended, so no human can stop a runaway agent.
	// Configurable via limits.Workflow; 0 falls back to the default — we never let
	// an unattended agent node go unbounded (decision #2 exception).
	//
	// workflow agent 节点是唯一保留 turn cap 的地方：触发型 workflow 无人值守，
	// 没人能停失控 agent。经 limits.Workflow 可配；0 回落默认——绝不让无人值守
	// agent 节点无限。
	wf := limitspkg.Current().Workflow
	defTurns := wf.AgentNodeMaxTurns
	if defTurns <= 0 {
		defTurns = 10
	}
	hardTurns := wf.AgentNodeMaxTurnsHard
	if hardTurns <= 0 {
		hardTurns = 50
	}
	maxTurns := defTurns
	if v, ok := cfg["maxTurns"]; ok {
		switch n := v.(type) {
		case int:
			maxTurns = n
		case float64:
			maxTurns = int(n)
		}
	}
	// Entity maxTurns overrides node config if set via agentRef.
	if entityMaxTurns > 0 {
		maxTurns = entityMaxTurns
	}
	if maxTurns < 1 {
		maxTurns = 1
	}
	if maxTurns > hardTurns {
		maxTurns = hardTurns
	}

	atts, err := parseAttachedDocuments(cfg)
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: %w", in.Node.ID, err)}
	}
	docPrefix := ""
	if d.documents != nil && len(atts) > 0 {
		docs, err := d.documents.ResolveAttached(ctx, atts)
		if err != nil {
			return DispatchOutput{Error: fmt.Errorf("agent node %q: resolve attached: %w", in.Node.ID, err)}
		}
		docPrefix = documentapp.RenderAttachedAsXML(docs)
	}

	enabled, _ := parseEnabledTools(cfg)
	// Entity tools override inline config when loaded via agentRef.
	if len(entityEnabledTools) > 0 {
		enabled = entityEnabledTools
	}
	var allTools []toolapp.Tool
	if d.toolsFn != nil {
		allTools = d.toolsFn()
	}
	tools := filterToolsByWhitelist(allTools, enabled)

	// Per-node override; nil = ResolveAgentWithOverride falls back to picker default.
	//
	// 每节点 override;nil = ResolveAgentWithOverride 走 picker 默认。
	bundle, err := llmclientpkg.ResolveAgentWithOverride(ctx, in.Node.ModelOverride, d.picker, d.keys, d.factory)
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: resolve LLM: %w", in.Node.ID, err)}
	}

	// Sub-step replay (ADR-010): on a flowrun :replay, load the prior run's completed steps once.
	// They prepend to history (LoadHistory) and consume their share of the turn budget so the total
	// LLM turns across runs stays bounded by maxTurns.
	var replaySteps []RecordedStep
	if in.AgentSubSteps != nil {
		replaySteps = in.AgentSubSteps.LoadSteps(ctx)
	}
	host := &agentHost{
		userPrompt: docPrefix + prompt,
		tools:      tools,
		captured:   &agentResult{},
		replay:     replaySteps,
		recorder:   in.AgentSubSteps,
		log:        d.log,
	}
	// Build agent system prompt (doc 09 / doc 11 §S4 agent system prompt chain):
	// [identity] describes the agent's role from its config name/description.
	// [prompt]   is the user-provided task prompt (already in userPrompt).
	// [output]   describes the expected output schema if set.
	// This replaces the old hardcoded "You are a workflow agent" system prompt.
	agentName, _ := cfg["agentName"].(string)
	agentDesc, _ := cfg["agentDescription"].(string)
	var systemParts []string
	if agentName != "" {
		identity := "You are " + agentName + ", a workflow automation worker."
		if agentDesc != "" {
			identity += " Your role: " + agentDesc
		}
		systemParts = append(systemParts, identity)
	} else {
		systemParts = append(systemParts, "You are a workflow automation worker.")
	}
	systemParts = append(systemParts, "Use available tools as needed; respond concisely when finished.")
	// Tool restriction: do NOT include any meta-tools (fs/shell/web/memory/ask) — only the
	// pre-filtered tools from the whitelist are available. (doc 00 §"员工思维")
	systemParts = append(systemParts, "Only use the tools explicitly provided to you. Do not attempt capabilities you have no tool for.")
	systemPrompt := ""
	for i, p := range systemParts {
		if i > 0 {
			systemPrompt += " "
		}
		systemPrompt += p
	}

	baseReq := llminfra.Request{
		ModelID:  bundle.ModelID,
		Key:      bundle.Key,
		BaseURL:  bundle.BaseURL,
		System:   systemPrompt,
		Thinking: bundle.Thinking,
		Options:  bundle.Options,
	}
	remainingTurns := maxTurns - len(replaySteps)
	if remainingTurns < 1 {
		remainingTurns = 1
	}
	result := loopapp.Run(ctx, host, bundle.Client, baseReq, remainingTurns, d.log)

	if result.Status == chatdomain.StatusError {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: agent loop error", in.Node.ID)}
	}

	return DispatchOutput{Outputs: map[string]any{
		"out":        result.LastMessage,
		"status":     result.Status,
		"stopReason": result.StopReason,
		"steps":      result.Steps,
		"tokensIn":   result.TokensIn,
		"tokensOut":  result.TokensOut,
	}}
}

// agentHost is the per-dispatch loop.Host: history is a single user message
// (the prompt), Tools come from the dispatcher's pre-filtered slice,
// WriteFinalize is no-op (workflow doesn't persist agent chat history).
//
// agentHost 是单次 dispatch 的 loop.Host:history 仅含一条 user message(prompt),
// Tools 取自 dispatcher 预过滤切片,WriteFinalize no-op(workflow 不持久化 agent 历史)。
type agentHost struct {
	userPrompt string
	tools      []toolapp.Tool
	captured   *agentResult

	// Sub-step replay (ADR-010): replay = a prior run's completed steps, prepended to history so the
	// loop resumes past them without re-running their LLM + tool calls; recorder journals each new step.
	//
	// 子步 replay(ADR-010):replay 是上一 run 已完成步,前置进历史使 loop 越过它们续跑;recorder 记新步。
	replay   []RecordedStep
	recorder AgentSubStepJournal
	log      *zap.Logger
}

type agentResult struct {
	blocks []chatdomain.Block
	status string
}

func (h *agentHost) LoadHistory(_ context.Context) ([]llminfra.LLMMessage, error) {
	history := []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: h.userPrompt}}
	// Replay (ADR-010): reconstruct prior completed steps as history so the loop continues from the
	// crash point — their tool side-effects are NOT re-run (they're history, not re-dispatched).
	for _, step := range h.replay {
		msgs, err := loopapp.BlocksToAssistantLLM(h.log, append(append([]chatdomain.Block{}, step.Assistant...), step.ToolResults...))
		if err != nil {
			return nil, fmt.Errorf("agent replay reconstruct: %w", err)
		}
		history = append(history, msgs...)
	}
	return history, nil
}

// RecordStep (loop.StepRecorder) journals each completed step at its ABSOLUTE turn (prior replayed
// steps occupy the lower turn indices), so a later :replay reconstructs the full step history.
//
// RecordStep 按绝对 turn 记账每个完成步(已 replay 的步占据低位 turn)。
func (h *agentHost) RecordStep(ctx context.Context, step int, assistant, toolResults []chatdomain.Block) {
	if h.recorder != nil {
		h.recorder.RecordStep(ctx, len(h.replay)+step, assistant, toolResults)
	}
}

// Tools ignores ctx: workflow agent dispatch uses a fixed pre-filtered slice
// (no lazy groups / activate_tools).
//
// Tools 忽略 ctx：workflow agent dispatch 用固定预过滤切片（无 lazy 组 / activate_tools）。
func (h *agentHost) Tools(_ context.Context) []toolapp.Tool {
	return h.tools
}

func (h *agentHost) WriteFinalize(_ context.Context, blocks []chatdomain.Block, status, _, _, _ string, _, _ int) {
	h.captured.blocks = blocks
	h.captured.status = status
}

// parseEnabledTools accepts a string slice naming whitelisted tool names.
// Empty / missing → no filter (all tools available).
//
// parseEnabledTools 解析白名单(string 切片)。空/缺失 → 不过滤(全部可用)。
func parseEnabledTools(cfg map[string]any) ([]string, error) {
	raw, ok := cfg["enabledTools"]
	if !ok || raw == nil {
		return nil, nil
	}
	if typed, ok := raw.([]string); ok {
		return typed, nil
	}
	buf, err := json.Marshal(raw)
	if err != nil {
		return nil, err
	}
	var out []string
	if err := json.Unmarshal(buf, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func filterToolsByWhitelist(all []toolapp.Tool, whitelist []string) []toolapp.Tool {
	if len(whitelist) == 0 {
		return all
	}
	allowed := make(map[string]bool, len(whitelist))
	for _, n := range whitelist {
		allowed[n] = true
	}
	out := make([]toolapp.Tool, 0, len(whitelist))
	for _, t := range all {
		if allowed[t.Name()] {
			out = append(out, t)
		}
	}
	return out
}
