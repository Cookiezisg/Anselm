package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// InvokeInput is the request shape for Service.InvokeAgent (mirrors functionapp.RunInput).
//
// InvokeInput 是 Service.InvokeAgent 的请求形状（对标 functionapp.RunInput）。
type InvokeInput struct {
	AgentID     string
	VersionID   string         // empty → active version
	Input       map[string]any // data fed to the agent (appended to its prompt)
	TriggeredBy string         // chat | workflow | http | test
	MaxTurns    int            // ReAct turn cap; 0 → default

	// Workflow-only (ADR-010 sub-step replay): a flowrun :replay prepends prior completed steps and
	// records new ones. Both nil for a standalone chat/http invoke. FlowrunID/NodeID tag the execution.
	FlowrunID     string
	FlowrunNodeID string
	ReplaySteps   []RecordedStep
	Recorder      StepRecorder
}

// RecordedStep is one completed ReAct step (assistant blocks + tool results) for replay reconstruction.
type RecordedStep struct {
	Assistant   []chatdomain.Block
	ToolResults []chatdomain.Block
}

// StepRecorder journals a completed step at its absolute turn index (workflow durable replay).
type StepRecorder func(ctx context.Context, step int, assistant, toolResults []chatdomain.Block)

// ExecutionResult is the terminal output of InvokeAgent (mirrors functiondomain.ExecutionResult + agent extras).
//
// ExecutionResult 是 InvokeAgent 的终态输出（对标 function.ExecutionResult）。
type ExecutionResult struct {
	ExecutionID string `json:"executionId"`
	OK          bool   `json:"ok"`
	Output      any    `json:"output"`
	Status      string `json:"status"`
	StopReason  string `json:"stopReason,omitempty"`
	Steps       int    `json:"steps"`
	TokensIn    int    `json:"tokensIn"`
	TokensOut   int    `json:"tokensOut"`
	ErrorMsg    string `json:"errorMsg,omitempty"`
	ElapsedMs   int64  `json:"elapsedMs"`
}

const defaultInvokeMaxTurns = 10

// InvokeAgent runs an agent's ReAct loop once and records one AgentExecution (mirrors function
// RunFunction: the single execution method every path — invoke_agent tool / HTTP :invoke / workflow
// agent node — funnels through, so every run lands in agent_executions).
//
// InvokeAgent 跑一次 agent ReAct loop 并记一条 AgentExecution（对标 function.RunFunction：所有触发路径
// 都经此方法，每次执行都落表）。
func (s *Service) InvokeAgent(ctx context.Context, in InvokeInput) (*ExecutionResult, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, fmt.Errorf("agentapp.InvokeAgent: %w", err)
	}
	if s.invoke.picker == nil || s.invoke.keys == nil || s.invoke.factory == nil {
		return nil, fmt.Errorf("agentapp.InvokeAgent: invoke deps not configured (call SetInvokeDeps)")
	}

	a, err := s.repo.Get(ctx, in.AgentID)
	if err != nil {
		return nil, fmt.Errorf("agentapp.InvokeAgent: %w", err)
	}
	versionID := in.VersionID
	if versionID == "" {
		if a.ActiveVersionID == "" {
			return nil, fmt.Errorf("agentapp.InvokeAgent: %w", agentdomain.ErrNoActiveVersion)
		}
		versionID = a.ActiveVersionID
	}
	v, err := s.repo.GetVersion(ctx, versionID)
	if err != nil {
		return nil, fmt.Errorf("agentapp.InvokeAgent: version: %w", err)
	}

	startedAt := time.Now().UTC()
	result, modelID, runErr := s.runLoop(ctx, a, v, in)
	endedAt := time.Now().UTC()

	res := &ExecutionResult{
		Status:    agentdomain.ExecutionStatusOK,
		ElapsedMs: endedAt.Sub(startedAt).Milliseconds(),
	}
	if runErr != nil {
		res.Status = agentdomain.ExecutionStatusFailed
		res.ErrorMsg = runErr.Error()
	} else {
		res.OK = result.Status != chatdomain.StatusError
		if !res.OK {
			res.Status = agentdomain.ExecutionStatusFailed
			res.ErrorMsg = "agent loop error"
		}
		res.Output = coerceEnumOutput(v.OutputSchema, result.LastMessage)
		res.StopReason = result.StopReason
		res.Steps = result.Steps
		res.TokensIn = result.TokensIn
		res.TokensOut = result.TokensOut
	}

	execID := s.recordExecution(ctx, uid, in, a, v, res, modelID, startedAt, endedAt)
	res.ExecutionID = execID
	return res, nil
}

// runLoop builds the agent host + LLM bundle and runs app/loop.Run (the ReAct loop).
func (s *Service) runLoop(ctx context.Context, a *agentdomain.Agent, v *agentdomain.AgentVersion, in InvokeInput) (loopapp.Result, string, error) {
	// Knowledge prefix (agent's attached docs) prepended to the user message.
	prefix := ""
	if s.invoke.knowledge != nil && len(v.Knowledge) > 0 {
		p, kErr := s.invoke.knowledge.BuildKnowledgePrefix(ctx, v.Knowledge)
		if kErr != nil {
			return loopapp.Result{}, "", fmt.Errorf("resolve knowledge: %w", kErr)
		}
		prefix = p
	}

	userMsg := prefix + v.Prompt
	if len(in.Input) > 0 {
		b, _ := json.Marshal(in.Input)
		userMsg += "\n\nInput data:\n```json\n" + string(b) + "\n```"
	}

	// Filter the global tool registry to the agent's whitelisted callables.
	var allTools []toolapp.Tool
	if s.invoke.toolsFn != nil {
		allTools = s.invoke.toolsFn()
	}
	whitelist := make([]string, 0, len(v.Tools))
	for _, t := range v.Tools {
		whitelist = append(whitelist, t.Ref)
	}
	tools := filterToolsByWhitelist(allTools, whitelist)

	// Pass the version's ModelOverride (nil → default agent scenario model; set → that exact key+model).
	//
	// 传 version 的 ModelOverride（nil 走默认 agent scenario 模型；设了就用那把 key+model）。
	bundle, err := llmclientpkg.ResolveAgentWithOverride(ctx, v.ModelOverride, s.invoke.picker, s.invoke.keys, s.invoke.factory)
	if err != nil {
		return loopapp.Result{}, "", fmt.Errorf("resolve LLM: %w", err)
	}

	host := &agentHost{
		userPrompt: userMsg,
		tools:      tools,
		replay:     in.ReplaySteps,
		recorder:   in.Recorder,
		log:        s.log,
	}

	// System prompt: agent identity (name/description) + the worker discipline (doc 09/11 §S4).
	identity := "You are a workflow automation worker."
	if a.Name != "" {
		identity = "You are " + a.Name + ", a workflow automation worker."
		if a.Description != "" {
			identity += " Your role: " + a.Description
		}
	}
	systemPrompt := identity +
		" Use available tools as needed; respond concisely when finished." +
		" Only use the tools explicitly provided to you. Do not attempt capabilities you have no tool for." +
		outputSchemaInstruction(v.OutputSchema)

	maxTurns := in.MaxTurns
	if maxTurns <= 0 {
		maxTurns = defaultInvokeMaxTurns
	}
	remaining := maxTurns - len(in.ReplaySteps)
	if remaining < 1 {
		remaining = 1
	}

	baseReq := llminfra.Request{
		ModelID:  bundle.ModelID,
		Key:      bundle.Key,
		BaseURL:  bundle.BaseURL,
		System:   systemPrompt,
		Thinking: bundle.Thinking,
		Options:  bundle.Options,
	}
	result := loopapp.Run(ctx, host, bundle.Client, baseReq, remaining, s.log)
	return result, bundle.ModelID, nil
}

// recordExecution writes one terminal AgentExecution (mirrors functionapp.recordExecution).
//
// recordExecution 写一条终态 AgentExecution（对标 functionapp.recordExecution）。
func (s *Service) recordExecution(ctx context.Context, uid string, in InvokeInput, a *agentdomain.Agent, v *agentdomain.AgentVersion, res *ExecutionResult, modelID string, startedAt, endedAt time.Time) string {
	triggeredBy := in.TriggeredBy
	if triggeredBy == "" {
		triggeredBy = agentdomain.TriggeredByHTTP
	}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)

	exec := &agentdomain.AgentExecution{
		ID:             idgenpkg.New("agx"),
		UserID:         uid,
		Status:         res.Status,
		TriggeredBy:    triggeredBy,
		Input:          in.Input,
		Output:         res.Output,
		ErrorMessage:   res.ErrorMsg,
		ElapsedMs:      endedAt.Sub(startedAt).Milliseconds(),
		StartedAt:      startedAt,
		EndedAt:        endedAt,
		ConversationID: convID,
		MessageID:      msgID,
		ToolCallID:     toolCallID,
		FlowrunID:      in.FlowrunID,
		FlowrunNodeID:  in.FlowrunNodeID,
		AgentID:        a.ID,
		VersionID:      v.ID,
		ModelID:        modelID,
	}
	// Detached ctx (best-effort persist): a cancelled run ctx must not lose the execution record.
	detached := reqctxpkg.SetUserID(context.Background(), uid)
	if err := s.repo.SaveExecution(detached, exec); err != nil {
		s.log.Warn("agentapp.recordExecution: SaveExecution failed (best-effort)",
			zap.String("agentId", a.ID), zap.String("versionId", v.ID), zap.Error(err))
		return ""
	}
	return exec.ID
}

// agentHost is the per-invoke loop.Host (mirrors scheduler.agentHost): history is the prompt (+ replay),
// Tools is the pre-filtered whitelist, RecordStep journals new steps when a recorder is wired.
type agentHost struct {
	userPrompt string
	tools      []toolapp.Tool
	replay     []RecordedStep
	recorder   StepRecorder
	log        *zap.Logger
}

func (h *agentHost) LoadHistory(_ context.Context) ([]llminfra.LLMMessage, error) {
	history := []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: h.userPrompt}}
	for _, step := range h.replay {
		msgs, err := loopapp.BlocksToAssistantLLM(h.log, append(append([]chatdomain.Block{}, step.Assistant...), step.ToolResults...))
		if err != nil {
			return nil, fmt.Errorf("agent replay reconstruct: %w", err)
		}
		history = append(history, msgs...)
	}
	return history, nil
}

func (h *agentHost) RecordStep(ctx context.Context, step int, assistant, toolResults []chatdomain.Block) {
	if h.recorder != nil {
		h.recorder(ctx, len(h.replay)+step, assistant, toolResults)
	}
}

func (h *agentHost) Tools(_ context.Context) []toolapp.Tool { return h.tools }

func (h *agentHost) WriteFinalize(_ context.Context, _ []chatdomain.Block, _, _, _, _ string, _, _ int) {
}

// filterToolsByWhitelist keeps only tools whose Name() is in the whitelist; empty whitelist = all.
//
// filterToolsByWhitelist 仅保留 Name() 在白名单内的工具；空白名单 = 全部。
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

// outputSchemaInstruction renders the agent's OutputSchema as a hard instruction appended to the
// system prompt, so a configured enum/json_schema actually shapes the LLM's final answer
// (fixes the "configured but ignored" gap).
//
// outputSchemaInstruction 把 OutputSchema 渲染成追加到 system prompt 的硬约束，
// 让配置的 enum/json_schema 真正约束 LLM 最终输出（修复"配了不生效"）。
func outputSchemaInstruction(os *agentdomain.OutputSchema) string {
	if os == nil {
		return ""
	}
	switch os.Kind {
	case agentdomain.OutputSchemaEnum:
		if len(os.Enums) > 0 {
			return "\n\nYour FINAL answer must be exactly one of these values verbatim — no extra words, quotes, or punctuation: " +
				strings.Join(os.Enums, " | ") + "."
		}
	case agentdomain.OutputSchemaJSONSchema:
		if len(os.Schema) > 0 {
			b, _ := json.Marshal(os.Schema)
			return "\n\nYour FINAL answer must be a single JSON value conforming to this JSON Schema. Output only the JSON, no prose:\n" + string(b)
		}
	}
	return ""
}

// coerceEnumOutput best-effort snaps a free-form enum answer onto an allowed value (exact match after
// trim, else the first enum the answer contains) so downstream workflow case nodes match reliably.
//
// coerceEnumOutput 把 enum 输出尽力规整到允许值（trim 精确匹配，否则取输出包含的第一个 enum），方便下游 case 命中。
func coerceEnumOutput(os *agentdomain.OutputSchema, out any) any {
	if os == nil || os.Kind != agentdomain.OutputSchemaEnum || len(os.Enums) == 0 {
		return out
	}
	s, ok := out.(string)
	if !ok {
		return out
	}
	trimmed := strings.TrimSpace(s)
	for _, e := range os.Enums {
		if strings.EqualFold(trimmed, e) {
			return e
		}
	}
	for _, e := range os.Enums {
		if strings.Contains(trimmed, e) {
			return e
		}
	}
	return out
}
