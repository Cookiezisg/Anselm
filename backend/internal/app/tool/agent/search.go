package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"go.uber.org/zap"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	limitspkg "github.com/sunweilin/forgify/backend/internal/pkg/limits"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	llmparsepkg "github.com/sunweilin/forgify/backend/internal/pkg/llmparse"
)

// SearchAgents implements search_agents: LLM-ranked relevance search over the user's agents
// (mirrors search_function).
//
// SearchAgents 实现 search_agents：对用户 agents 做 LLM 相关性排序搜索（对标 search_function）。
type SearchAgents struct {
	svc     *agentapp.Service
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
	log     *zap.Logger
}

func (t *SearchAgents) Name() string { return "search_agents" }
func (t *SearchAgents) Description() string {
	return "Find agents in the user's library by query, ranked by relevance; get_agent to inspect config before editing or referencing in a workflow."
}
func (t *SearchAgents) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"query": {"type": "string", "description": "Natural language description of what you're looking for"},
			"limit": {"type": "integer", "description": "Maximum results to return (default 10, max 50)"}
		},
		"required": ["query"]
	}`)
}
func (t *SearchAgents) IsReadOnly() bool                    { return true }
func (t *SearchAgents) NeedsReadFirst() bool                { return false }
func (t *SearchAgents) RequiresWorkspace() bool             { return false }
func (t *SearchAgents) ValidateInput(json.RawMessage) error { return nil }
func (t *SearchAgents) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *SearchAgents) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
		Limit int    `json:"limit"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_agents: bad args: %w", err)
	}
	if args.Limit <= 0 || args.Limit > limitspkg.MaxSearchTopN {
		args.Limit = 10
	}

	agents, err := t.svc.ListAll(ctx)
	if err != nil {
		return "", fmt.Errorf("search_agents: list: %w", err)
	}
	if len(agents) == 0 {
		b, _ := json.Marshal([]any{})
		return string(b), nil
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "Query: %s\n\nAgents:\n", args.Query)
	for _, a := range agents {
		fmt.Fprintf(&sb, "- id: %s, name: %s, description: %s\n", a.ID, a.Name, a.Description)
	}
	fmt.Fprintf(&sb, "\nReturn the %d most relevant agent IDs as JSON: "+
		`[{"id":"ag_xxx","score":0.95},...]`+
		"\nRespond with valid JSON only.", args.Limit)

	bc, err := llmclientpkg.ResolveUtility(ctx, t.picker, t.keys, t.factory)
	if err != nil {
		return "", fmt.Errorf("search_agents: %w", err)
	}
	resp, err := llminfra.Generate(ctx, bc.Client, llminfra.Request{
		ModelID:  bc.ModelID,
		Key:      bc.Key,
		BaseURL:  bc.BaseURL,
		Thinking: bc.Thinking,
		Options:  bc.Options,
		Messages: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: sb.String()}},
	})
	if err != nil {
		return "", fmt.Errorf("search_agents: llm: %w", err)
	}

	var ranked []struct {
		ID    string  `json:"id"`
		Score float32 `json:"score"`
	}
	jsonStr, ok := llmparsepkg.ExtractJSON(resp)
	if !ok {
		return "", fmt.Errorf("search_agents: LLM response contained no JSON: %w: %q", llminfra.ErrProviderError, resp)
	}
	if err = json.Unmarshal([]byte(jsonStr), &ranked); err != nil {
		return "", fmt.Errorf("search_agents: parse ranking: %w", err)
	}

	byID := make(map[string]int, len(agents))
	for i, a := range agents {
		byID[a.ID] = i
	}
	type result struct {
		ID              string   `json:"id"`
		Name            string   `json:"name"`
		Description     string   `json:"description"`
		Tags            []string `json:"tags"`
		ActiveVersionID string   `json:"activeVersionId,omitempty"`
		Score           float32  `json:"score"`
	}
	out := make([]result, 0, len(ranked))
	for _, r := range ranked {
		idx, ok := byID[r.ID]
		if !ok {
			t.log.Warn("agenttool.SearchAgents: LLM returned unknown agent id", zap.String("id", r.ID))
			continue
		}
		a := agents[idx]
		out = append(out, result{
			ID: a.ID, Name: a.Name, Description: a.Description,
			Tags: a.Tags, ActiveVersionID: a.ActiveVersionID, Score: r.Score,
		})
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
