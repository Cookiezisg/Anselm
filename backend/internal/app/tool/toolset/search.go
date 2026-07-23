// Package toolset provides the search_tools system tool — on-demand activation
// of lazy tools. The LLM knows the lazy inventory from the
// system-prompt overview (Toolset.Overview: name + one-line description each);
// when it needs a capability it calls search_tools with a description, gets a
// compact list of activated matches, and the host includes those tools' full
// schemas in the next request's tools field.
//
// Discovery is per-tool, not per-category: instead of loading a whole group's
// schemas for the rest of the conversation, search_tools surfaces only the few
// individually-relevant tools and lets the LLM re-search as the task evolves.
//
// Package toolset 提供 search_tools 系统工具——按需激活 lazy 工具。LLM 从 system-prompt
// 概览（Toolset.Overview：每个 name + 一句话 description）知道 lazy 全集；需要某能力时用一段描述调
// search_tools，拿回最佳命中的紧凑激活清单，host 在下一请求 tools 字段放入这些工具的完整 schema。
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

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
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
			"description": "Describe the capability you need (keywords or a short phrase). Activates the best-matching tools; their full parameter schemas appear in the next request."
		}
	}
}`)

// SearchTools activates lazy tools on demand by keyword-matching
// a query against each lazy tool's name + description. It is itself a RESIDENT tool
// (always available so the LLM can discover others). On a hit it records each tool
// in AgentState so the host includes them in the tool list on subsequent turns.
//
// SearchTools 通过对每个 lazy 工具 name + description 做关键词匹配，按需激活工具。它自身是
// RESIDENT 工具（始终可用，使 LLM 能发现其它工具）。命中时把每个工具记入 AgentState，使 host 在
// 后续回合把它们纳入工具列表。
type SearchTools struct {
	lazy []toolapp.Tool
	// dynamic returns extra per-request lazy tools to also rank over — the ctx workspace's connected
	// MCP server tools (DynamicTools). nil → none. These aren't in the static lazy snapshot or the
	// system-prompt Overview, so search_tools is the LLM's only discovery path for them (F52).
	// dynamic 返回本请求要一并排序的额外 lazy 工具——ctx workspace 已连 MCP server 的工具。nil → 无。
	dynamic func(context.Context) []toolapp.Tool
}

// NewSearchTools snapshots the static lazy tools this search surfaces, plus an optional dynamic
// provider for per-request tools (the ctx workspace's MCP server tools). The host builds it from
// Toolset.Lazy and puts it in the resident set.
//
// NewSearchTools 快照静态 lazy 工具 + 可选动态 provider（ctx workspace 的 MCP 工具）。host 从 Toolset.Lazy
// 构造、放入 resident 集。
func NewSearchTools(lazy []toolapp.Tool, dynamic func(context.Context) []toolapp.Tool) *SearchTools {
	return &SearchTools{lazy: lazy, dynamic: dynamic}
}

// pool returns the full ranking pool for this request: the static lazy tools plus any per-request
// dynamic tools (MCP). Allocates a fresh slice so the static snapshot is never mutated.
//
// pool 返回本请求的完整排序池：静态 lazy + per-request 动态工具（MCP）。新分配切片、绝不改静态快照。
func (t *SearchTools) pool(ctx context.Context) []toolapp.Tool {
	if t.dynamic == nil {
		return t.lazy
	}
	dyn := t.dynamic(ctx)
	if len(dyn) == 0 {
		return t.lazy
	}
	out := make([]toolapp.Tool, 0, len(t.lazy)+len(dyn))
	out = append(out, t.lazy...)
	return append(out, dyn...)
}

func (t *SearchTools) Name() string                { return "search_tools" }
func (t *SearchTools) Parameters() json.RawMessage { return searchToolsSchema }

func (t *SearchTools) Description() string {
	return "Find and activate tools by capability. The system prompt lists available tools as one-liners; call this with what you need, then use the activated tools whose full schemas appear in the next request."
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
	Name    string `json:"name"`
	Purpose string `json:"purpose"`
}

// Execute keyword-ranks lazy tools, activates the top matches, and returns a compact
// acknowledgement. Full schemas appear exactly once — in the next model request's
// tools field — instead of being duplicated in both this durable tool_result and
// that field. No match → an actionable string (not an error).
//
// Execute 按 query 排序并激活 top 工具，返回紧凑确认。完整 schema 只在下一次模型请求的 tools
// 字段出现一次，不再同时复制进这条持久 tool_result。无命中 → 可操作字符串（非错误）。
func (t *SearchTools) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_tools.Execute: %w", err)
	}

	matches := rankLazy(t.pool(ctx), args.Query, defaultSearchToolsLimit)
	if len(matches) == 0 {
		return fmt.Sprintf("No tools matched %q. The system prompt lists all available tools; try different keywords.", args.Query), nil
	}

	state, hasState := reqctxpkg.GetAgentState(ctx)
	views := make([]toolView, 0, len(matches))
	for _, m := range matches {
		if hasState {
			state.MarkToolDiscovered(m.Name())
		}
		views = append(views, toolView{Name: m.Name(), Purpose: toolapp.BriefDescription(m.Description(), 180)})
	}
	body, err := json.Marshal(map[string]any{
		"loaded_tools": views,
		"status":       "Full parameter schemas are active in the next model request.",
	})
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
