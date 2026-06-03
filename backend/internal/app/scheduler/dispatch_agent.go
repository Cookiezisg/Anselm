package scheduler

import (
	"context"
	"encoding/json"
	"fmt"

	"go.uber.org/zap"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	limitspkg "github.com/sunweilin/forgify/backend/internal/pkg/limits"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
)

// AgentEntityResolver is the port AgentDispatcher uses to run an agentRef node through the agent
// service's InvokeAgent — the single execution method (mirrors dispatch_function → functionapp.RunFunction)
// that loads the entity config, runs the ReAct loop, and records one AgentExecution. Implemented by
// agentapp.Service. The legacy inline-config path (no agentRef) does NOT use this.
//
// AgentEntityResolver 是 AgentDispatcher 把 agentRef 节点交给 agent service 的 InvokeAgent 执行的端口。
type AgentEntityResolver interface {
	InvokeAgent(ctx context.Context, in agentapp.InvokeInput) (*agentapp.ExecutionResult, error)
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
	cfg := in.Node.Config

	// agentRef path (canonical, doc 02): route the run through the agent service's InvokeAgent — the
	// SINGLE execution method (mirrors dispatch_function → RunFunction) that loads the entity config,
	// runs the ReAct loop, and records one AgentExecution (triggeredBy=workflow). Sub-step replay
	// (ADR-010) is threaded through. Checked FIRST: this path uses the agent service's own LLM deps,
	// not the dispatcher's (picker/keys/factory below are only for the legacy inline path).
	if agentRef, ok := cfg["agentRef"].(string); ok && agentRef != "" && d.agentResolver != nil {
		return d.invokeViaEntity(ctx, in, agentRef)
	}

	// Legacy inline-config path: config.prompt directly on the node (no entity → no execution record).
	if d.picker == nil || d.keys == nil || d.factory == nil {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: missing picker/keys/factory", in.Node.ID)}
	}
	prompt, _ := cfg["prompt"].(string)
	if prompt == "" {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: prompt required (set config.prompt or config.agentRef)", in.Node.ID)}
	}

	maxTurns := workflowMaxTurns(cfg)

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

// invokeViaEntity runs an agentRef node through the agent service's InvokeAgent (the single execution
// method, mirrors dispatch_function → RunFunction): it loads the entity config, runs the ReAct loop,
// and records one AgentExecution. The flowrun sub-step journal (ADR-010 replay) is threaded via
// InvokeInput.ReplaySteps + Recorder so crash-replay still skips already-completed steps.
//
// invokeViaEntity 把 agentRef 节点交给 agent service 的 InvokeAgent（单一执行方法，对标 RunFunction）：
// 加载实体配置、跑 ReAct、记一条执行；ADR-010 子步重放经 ReplaySteps/Recorder 透传。
func (d *AgentDispatcher) invokeViaEntity(ctx context.Context, in DispatchInput, agentRef string) DispatchOutput {
	var replay []agentapp.RecordedStep
	var recorder agentapp.StepRecorder
	if in.AgentSubSteps != nil {
		for _, s := range in.AgentSubSteps.LoadSteps(ctx) {
			replay = append(replay, agentapp.RecordedStep{Assistant: s.Assistant, ToolResults: s.ToolResults})
		}
		journal := in.AgentSubSteps
		recorder = func(rctx context.Context, step int, assistant, toolResults []chatdomain.Block) {
			journal.RecordStep(rctx, step, assistant, toolResults)
		}
	}
	flowrunID := ""
	if in.ExecCtx != nil && in.ExecCtx.Run != nil {
		flowrunID = in.ExecCtx.Run.ID
	}
	res, err := d.agentResolver.InvokeAgent(ctx, agentapp.InvokeInput{
		AgentID:       agentRef,
		Input:         in.NodeIn,
		TriggeredBy:   agentdomain.TriggeredByWorkflow,
		MaxTurns:      workflowMaxTurns(in.Node.Config),
		FlowrunID:     flowrunID,
		FlowrunNodeID: in.Node.ID,
		ReplaySteps:   replay,
		Recorder:      recorder,
	})
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: %w", in.Node.ID, err)}
	}
	if !res.OK {
		return DispatchOutput{Error: fmt.Errorf("agent node %q: %s", in.Node.ID, res.ErrorMsg)}
	}
	return DispatchOutput{Outputs: map[string]any{
		"out":         res.Output,
		"status":      res.Status,
		"stopReason":  res.StopReason,
		"steps":       res.Steps,
		"tokensIn":    res.TokensIn,
		"tokensOut":   res.TokensOut,
		"executionId": res.ExecutionID,
	}}
}

// workflowMaxTurns is the unattended agent-node turn cap: limits.Workflow default, overridable by
// config.maxTurns, clamped to the hard cap. The ONE place a turn cap stays load-bearing — a triggered
// workflow runs with no human to stop a runaway agent (decision #2 exception).
//
// workflowMaxTurns 是无人值守 agent 节点的 turn cap：limits 默认 + config.maxTurns 覆盖 + 硬上限夹取。
func workflowMaxTurns(cfg map[string]any) int {
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
	if maxTurns < 1 {
		maxTurns = 1
	}
	if maxTurns > hardTurns {
		maxTurns = hardTurns
	}
	return maxTurns
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
