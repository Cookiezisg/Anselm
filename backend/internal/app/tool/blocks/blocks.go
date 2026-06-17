// Package blocks provides search_blocks — the LLM's workflow-palette search.
// Scope is a hard rule: only the six kinds that wire directly into a
// workflow graph (function / handler methods / mcp tools / agent / control /
// approval). Conversations, documents, skills, memories, workflows and
// triggers never appear here — cross-entity omni-search belongs to the human
// search box, and a smaller answer space is exactly what keeps the LLM's
// mental load low while building.
//
// Package blocks 提供 search_blocks——LLM 的工作流积木面板检索。范围是铁律：
// 只搜能直接接进 workflow 图的六类（function / handler 方法 / mcp 工具 / agent /
// control / approval）。对话、文档、skill、memory、workflow、trigger 永不出现——
// 跨实体综搜属于人的搜索框，更小的答案空间正是构建工作流时压低 LLM 心智负担的关键。
package blocks

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// BlocksTools returns the search_blocks tool group.
//
// BlocksTools 返回 search_blocks 工具组。
func BlocksTools(engine *searchapp.Service) []toolapp.Tool {
	return []toolapp.Tool{&SearchBlocks{engine: engine}}
}

// SearchBlocks is the palette tool over the unified search engine.
//
// SearchBlocks 是统一搜索引擎上的积木面板工具。
type SearchBlocks struct{ engine *searchapp.Service }

func (t *SearchBlocks) Name() string { return "search_blocks" }

func (t *SearchBlocks) Description() string {
	return "Find wireable workflow building blocks by describing the capability you need. Searches functions, handler METHODS, MCP TOOLS, agents, controls and approvals (names, descriptions AND code). Each hit carries a ref you can place directly into a workflow node (fn_<id> / hd_<id>.<method> / mcp:<server>/<tool> / agent, control, approval ids). Use get_* for full schemas."
}

func (t *SearchBlocks) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["query"],
		"properties": {
			"query": {"type": "string", "description": "Describe the capability you need (e.g. \"send an email\", \"parse weather data\")."},
			"kinds": {"type": "array", "items": {"type": "string", "enum": ["function","handler","mcp","agent","control","approval"]}, "description": "Restrict to these block kinds; omit for all six."},
			"limit": {"type": "number", "description": "Max hits (default 8, max 20)."}
		}
	}`)
}

type searchBlocksArgs struct {
	Query string   `json:"query"`
	Kinds []string `json:"kinds"`
	Limit int      `json:"limit"`
}

// ValidateInput rejects an empty query pre-Execute (S18).
//
// ValidateInput 在 Execute 前拒绝空 query（S18）。
func (t *SearchBlocks) ValidateInput(args json.RawMessage) error {
	var a searchBlocksArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_blocks.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Query) == "" {
		return searchdomain.ErrQueryRequired
	}
	for _, k := range a.Kinds {
		if !searchdomain.IsBlockEntityType(searchdomain.EntityType(k)) {
			return searchdomain.ErrTypeInvalid
		}
	}
	return nil
}

func (t *SearchBlocks) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a searchBlocksArgs
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("search_blocks: bad args: %w", err)
	}
	kinds := make([]searchdomain.EntityType, 0, len(a.Kinds))
	for _, k := range a.Kinds {
		kinds = append(kinds, searchdomain.EntityType(k))
	}
	hits, err := t.engine.SearchBlocks(ctx, a.Query, kinds, a.Limit)
	if err != nil {
		return "", fmt.Errorf("search_blocks: %w", err)
	}
	if len(hits) == 0 {
		return fmt.Sprintf("No blocks matched %q. Try different capability keywords, or create the block (create_function / create_handler / …).", a.Query), nil
	}
	return toolapp.ToJSON(map[string]any{"count": len(hits), "blocks": hits}), nil
}

var _ toolapp.Tool = (*SearchBlocks)(nil)
