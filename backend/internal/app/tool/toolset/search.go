// Package toolset provides the search_tools system tool — on-demand discovery of
// lazy tools' full definitions. The LLM knows the lazy inventory from the
// system-prompt overview (Toolset.Overview: name + one-line description each);
// when it needs a capability it calls search_tools with a description, gets back
// the full definitions (incl. the large Parameters schema) of the best matches,
// and the host includes those tools in the tool list on subsequent turns.
//
// Discovery is per-tool, not per-category: instead of loading a whole group's
// schemas for the rest of the conversation, search_tools surfaces only the few
// individually-relevant tools and lets the LLM re-search as the task evolves.
//
// Package toolset 提供 search_tools 系统工具——按需发现 lazy 工具的完整定义。LLM 从 system-prompt
// 概览（Toolset.Overview：每个 name + 一句话 description）知道 lazy 全集；需要某能力时用一段描述调
// search_tools，拿回最佳命中的完整定义（含大 Parameters schema），host 在后续回合把这些工具纳入
// 工具列表。
//
// 发现按工具粒度、非按类：不为整组的 schema 锁定整对话，search_tools 只浮出
// 少数逐个相关的工具，并让 LLM 随任务演进重搜。
package toolset

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	errorspkg "github.com/sunweilin/foryx/backend/internal/pkg/errors"

	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

const defaultSearchToolsLimit = 5

// ErrEmptyQuery: query missing or empty.
//
// ErrEmptyQuery：query 缺失或为空。
var ErrEmptyQuery = errorspkg.New(errorspkg.KindInvalid, "TOOLSET_EMPTY_QUERY", "query is required and must be non-empty")

var searchToolsSchema = json.RawMessage(`{
	"type": "object",
	"required": ["query"],
	"properties": {
		"query": {
			"type": "string",
			"description": "Describe the capability you need (keywords or a short phrase). Returns the full definitions of the best-matching tools so you can then call them."
		}
	}
}`)

// SearchTools surfaces lazy tools' full definitions on demand by keyword-matching
// a query against each lazy tool's name + description. It is itself a RESIDENT tool
// (always available so the LLM can discover others). On a hit it records each tool
// in AgentState so the host includes them in the tool list on subsequent turns.
//
// SearchTools 通过对每个 lazy 工具 name + description 做关键词匹配，按需浮出其完整定义。它自身是
// RESIDENT 工具（始终可用，使 LLM 能发现其它工具）。命中时把每个工具记入 AgentState，使 host 在
// 后续回合把它们纳入工具列表。
type SearchTools struct {
	lazy []toolapp.Tool
}

// NewSearchTools snapshots the lazy tools this search will surface. The host builds
// it from Toolset.Lazy and puts it in the resident set.
//
// NewSearchTools 快照本 search 将浮出的 lazy 工具。host 从 Toolset.Lazy 构造、放入 resident 集。
func NewSearchTools(lazy []toolapp.Tool) *SearchTools {
	return &SearchTools{lazy: lazy}
}

func (t *SearchTools) Name() string                { return "search_tools" }
func (t *SearchTools) Parameters() json.RawMessage { return searchToolsSchema }

func (t *SearchTools) Description() string {
	return "Find and load tools by capability. The system prompt lists available tools as one-liners; call this with a description of what you need to get a tool's full definition (parameters), then call that tool."
}

// ValidateInput rejects an empty query pre-Execute.
//
// ValidateInput 在 Execute 前拒绝空 query。
func (t *SearchTools) ValidateInput(args json.RawMessage) error {
	var a struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_tools.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Query) == "" {
		return ErrEmptyQuery
	}
	return nil
}

type toolView struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Parameters  json.RawMessage `json:"parameters"`
}

// Execute keyword-ranks lazy tools against the query, returns the top matches' full
// definitions as JSON (the same shape the LLM will see when the tool is loaded), and
// marks each discovered in AgentState. No match → an actionable string (not an error).
//
// Execute 按 query 对 lazy 工具关键词排序，返回 top 命中的完整定义 JSON（与该工具加载后 LLM 所见
// 同形），并把每个记入 AgentState。无命中 → 可操作字符串（非错误）。
func (t *SearchTools) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_tools.Execute: %w", err)
	}

	matches := rankLazy(t.lazy, args.Query, defaultSearchToolsLimit)
	if len(matches) == 0 {
		return fmt.Sprintf("No tools matched %q. The system prompt lists all available tools; try different keywords.", args.Query), nil
	}

	state, hasState := reqctxpkg.GetAgentState(ctx)
	views := make([]toolView, 0, len(matches))
	for _, m := range matches {
		if hasState {
			state.MarkToolDiscovered(m.Name())
		}
		d := toolapp.ToLLMDef(m)
		views = append(views, toolView{Name: d.Name, Description: d.Description, Parameters: d.Parameters})
	}
	body, err := json.MarshalIndent(map[string]any{"tools": views}, "", "  ")
	if err != nil {
		return "", fmt.Errorf("search_tools.Execute: marshal: %w", err)
	}
	return string(body), nil
}

// rankLazy scores lazy tools by case-insensitive overlap of query terms against
// name+description; returns up to limit, highest score first, ties broken by name.
// Pure keyword matching — no embeddings (the LLM authors the query from the overview,
// and the lazy inventory is small enough that lexical ranking suffices locally).
//
// rankLazy 按 query 词与 name+description 的大小写不敏感重叠给 lazy 工具打分；返回至多 limit 个，
// 高分在前，同分按名。纯关键词匹配——无 embedding（LLM 从概览自拟 query，本地 lazy 全集小到词法
// 排序即够）。
func rankLazy(lazy []toolapp.Tool, query string, limit int) []toolapp.Tool {
	terms := strings.Fields(strings.ToLower(query))
	type scored struct {
		tool  toolapp.Tool
		score int
	}
	var hits []scored
	for _, tl := range lazy {
		hay := strings.ToLower(tl.Name() + " " + tl.Description())
		score := 0
		for _, term := range terms {
			if strings.Contains(hay, term) {
				score++
			}
		}
		if score > 0 {
			hits = append(hits, scored{tool: tl, score: score})
		}
	}
	sort.SliceStable(hits, func(i, j int) bool {
		if hits[i].score != hits[j].score {
			return hits[i].score > hits[j].score
		}
		return hits[i].tool.Name() < hits[j].tool.Name()
	})
	n := min(len(hits), limit)
	out := make([]toolapp.Tool, 0, n)
	for i := range n {
		out = append(out, hits[i].tool)
	}
	return out
}

var _ toolapp.Tool = (*SearchTools)(nil)
