// Package relation gives the LLM the relationship graph's read surface — "who uses this
// entity, what does it use" — so an edit or delete can check its impact surface first
// (the HTTP neighborhood endpoint's tool twin).
//
// Package relation 给 LLM 关系图读取面——「谁在用它、它在用谁」——编辑/删除前先查影响面
// （HTTP neighborhood 端点的工具孪生）。
package relation

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"

	relationapp "github.com/sunweilin/anselm/backend/internal/app/relation"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// RelationTools constructs the relation tool group (lazy).
//
// RelationTools 构造 relation 工具组（懒加载）。
func RelationTools(svc *relationapp.Service) []toolapp.Tool {
	return []toolapp.Tool{&GetRelations{svc: svc}}
}

type GetRelations struct{ svc *relationapp.Service }

func (t *GetRelations) Name() string { return "get_relations" }

func (t *GetRelations) Description() string {
	return "Look up an entity's relationship neighborhood: every edge in and out (uses / used-by, with entity names and relation kind). Check this BEFORE deleting or reworking an entity to see what depends on it. depth 1-3 expands transitively (default 1); hosted callers may send an exact decimal integer string such as \"2\", but arbitrary strings and floats are invalid."
}

func (t *GetRelations) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["kind", "id"],
		"properties": {
			"kind": {"type": "string", "description": "Entity kind, e.g. function | handler | agent | workflow | trigger | control | approval | mcp | document | skill."},
			"id": {"type": "string", "description": "The entity id (fn_… / hd_… / wf_… …)."},
			"depth": {"type": "integer", "description": "Hops to expand (1-3, default 1). Exact decimal integer strings such as \"2\" are accepted for hosted-model compatibility; arbitrary strings and floats are invalid."}
		}
	}`)
}

type getRelationsArgs struct {
	Kind     string
	ID       string
	Depth    int
	depthSet bool
}

// UnmarshalJSON accepts the exact integer-string shape emitted by some hosted models while
// keeping arbitrary strings/floats invalid. This is a wire compatibility shim, not a guesser.
// UnmarshalJSON 兼容部分托管模型发出的精确整数字符串，同时保持任意字符串/浮点数非法；这是线缆兼容层，不是猜值。
func (a *getRelationsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		Kind  string          `json:"kind"`
		ID    string          `json:"id"`
		Depth json.RawMessage `json:"depth"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	a.Kind, a.ID = raw.Kind, raw.ID
	if len(raw.Depth) == 0 || bytes.Equal(bytes.TrimSpace(raw.Depth), []byte("null")) {
		return nil
	}
	a.depthSet = true
	var n int
	if err := json.Unmarshal(raw.Depth, &n); err == nil {
		a.Depth = n
		return nil
	}
	var s string
	if err := json.Unmarshal(raw.Depth, &s); err != nil {
		return fmt.Errorf("depth must be an integer or an exact decimal integer string")
	}
	if s == "" {
		return fmt.Errorf("depth must be an integer or an exact decimal integer string")
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return fmt.Errorf("depth must be an integer or an exact decimal integer string")
		}
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return fmt.Errorf("depth must be an integer or an exact decimal integer string")
	}
	a.Depth = n
	return nil
}

func (t *GetRelations) ValidateInput(args json.RawMessage) error {
	var a getRelationsArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_relations: bad args: %w", err)
	}
	if a.Kind == "" || a.ID == "" {
		return relationdomain.ErrInvalidRef
	}
	if a.depthSet && (a.Depth < relationdomain.MinNeighborhoodDepth || a.Depth > relationdomain.MaxNeighborhoodDepth) {
		return relationdomain.ErrDepthOutOfRange
	}
	return nil
}

func (t *GetRelations) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args getRelationsArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_relations: bad args: %w", err)
	}
	depth := args.Depth
	if !args.depthSet {
		depth = relationdomain.MinNeighborhoodDepth
	}
	edges, err := t.svc.Neighborhood(ctx, args.Kind, args.ID, depth)
	if err != nil {
		return "", fmt.Errorf("get_relations: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"edges": edges, "count": len(edges)}), nil
}
