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
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
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

const searchBlocksScopeGuard = " Triggers are not workflow blocks: search triggers with search_triggers, and do not send trigger or notification as a kinds value here. Notification behavior belongs to the underlying function, handler, or MCP tool that provides it."
const searchBlocksExactIDGuard = " When a hit is found, use its exact entityId with get_function/get_handler or the matching detail tool; never use the displayed name where an Id field is required. Keep exact refs in the adjacent result card rather than repeating them in assistant prose."

func (t *SearchBlocks) legacyDescription() string {
	return "Find wireable workflow building blocks by describing the capability you need. Searches functions, handler METHODS, MCP TOOLS, agents, controls and approvals (names, descriptions AND code). Each hit carries a ref you can place directly into a workflow node (fn_<id> / hd_<id>.<method> / mcp:<server>/<tool> / agent, control, approval ids). This is workflow-palette discovery only: do not use search_blocks to decide that a capability cannot run in the current conversation. For an existing capability the user wants to run now, use search_tools to activate its callable tool, including a connected MCP tool, and then call it directly. IMPORTANT: honor every user-supplied filter exactly; if the user names kinds or a limit, include it in THIS call and do not make an unfiltered preliminary call. Use get_* for full schemas."
}

func (t *SearchBlocks) Description() string {
	return t.legacyDescription() + searchBlocksScopeGuard + searchBlocksExactIDGuard
}

func (t *SearchBlocks) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["query"],
		"properties": {
			"query": {"type": "string", "description": "Describe the capability you need (e.g. \"send an email\", \"parse weather data\")."},
		"kinds": {"type": "array", "items": {"type": "string", "enum": ["function","handler","mcp","agent","control","approval"]}, "description": "Restrict to these block kinds; omit for all six. Hosted models may send the same JSON array as a string; exact array contents are accepted, arbitrary strings are not."},
			"limit": {"type": "integer", "description": "Max hits (default 8, max 20). Hosted models may send an exact decimal string; floats and arbitrary strings remain invalid."}
		}
	}`)
}

type searchBlocksArgs struct {
	Query string   `json:"query"`
	Kinds []string `json:"kinds"`
	Limit int      `json:"limit"`
}

// UnmarshalJSON accepts the native schema shape and the exact stringified scalar/container
// encodings emitted by some hosted models. It does not guess arbitrary strings into tool values.
// UnmarshalJSON 接受 schema 原生形状，以及部分托管模型发出的同值字符串编码；不把任意字符串猜成工具参数。
func (a *searchBlocksArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		Query string          `json:"query"`
		Kinds json.RawMessage `json:"kinds"`
		Limit json.RawMessage `json:"limit"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	kinds, err := decodeSearchBlocksKinds(raw.Kinds)
	if err != nil {
		return fmt.Errorf("kinds: %w", err)
	}
	limit, err := decodeSearchBlocksInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = searchBlocksArgs{Query: raw.Query, Kinds: kinds, Limit: limit}
	return nil
}

func decodeSearchBlocksKinds(raw json.RawMessage) ([]string, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}
	var kinds []string
	if err := json.Unmarshal(raw, &kinds); err == nil {
		return kinds, nil
	}
	var encoded string
	if err := json.Unmarshal(raw, &encoded); err != nil {
		return nil, fmt.Errorf("must be an array or a JSON string holding one, got %s", string(raw))
	}
	if err := json.Unmarshal([]byte(encoded), &kinds); err != nil {
		return nil, fmt.Errorf("must be an array or a JSON string holding one, got %q", encoded)
	}
	return kinds, nil
}

func decodeSearchBlocksInt(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var encoded string
	if err := json.Unmarshal(raw, &encoded); err != nil {
		return 0, fmt.Errorf("must be an integer or an exact decimal integer string, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(encoded))
	if err != nil {
		return 0, fmt.Errorf("must be an integer or an exact decimal integer string, got %q", encoded)
	}
	return value, nil
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
