package workflow

import (
	"bytes"
	"encoding/json"
	"fmt"
)

// decodeWorkflowOps accepts the public array shape plus the two shape-preserving variants
// observed from hosted models: an exact JSON-encoded array string, and legacy add_node/add_edge
// objects whose body fields were emitted beside (rather than inside) node/edge. It deliberately
// does not repair arbitrary JSON or merge conflicting nested and top-level fields.
//
// decodeWorkflowOps 接受公开数组形状，以及托管模型实际发出的两种等价变体：精确 JSON 编码的
// 数组字符串，和把 add_node/add_edge 的 body 字段放在 node/edge 外的旧形状。不修任意 JSON，
// 也不合并互相冲突的内外字段。
func decodeWorkflowOps(raw json.RawMessage) (json.RawMessage, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, fmt.Errorf("ops must be a non-empty JSON array")
	}
	if raw[0] == '"' {
		var encoded string
		if err := json.Unmarshal(raw, &encoded); err != nil {
			return nil, fmt.Errorf("ops must be a JSON array or an exact JSON-encoded array: %w", err)
		}
		raw = bytes.TrimSpace([]byte(encoded))
		if len(raw) == 0 || raw[0] != '[' {
			return nil, fmt.Errorf("ops string must contain a JSON array")
		}
	}
	if raw[0] != '[' {
		return nil, fmt.Errorf("ops must be a JSON array or an exact JSON-encoded array")
	}

	var entries []json.RawMessage
	if err := json.Unmarshal(raw, &entries); err != nil {
		return nil, fmt.Errorf("ops must be a JSON array: %w", err)
	}
	normalized := make([]json.RawMessage, 0, len(entries))
	for i, entry := range entries {
		one, err := normalizeWorkflowOp(entry)
		if err != nil {
			return nil, fmt.Errorf("ops[%d]: %w", i, err)
		}
		normalized = append(normalized, one)
	}
	return json.Marshal(normalized)
}

// decodeWorkflowTags accepts the declared string-array shape plus the exact JSON-encoded
// array-string variant observed from hosted models. Missing tags remain nil for backwards
// compatibility with direct tool callers; malformed strings and non-string array items fail.
//
// decodeWorkflowTags 接受声明的字符串数组，以及托管模型实际发出的精确 JSON 数组字符串变体。
// 缺省 tags 为兼容既有直接调用保留 nil；畸形字符串和非字符串数组元素均拒绝。
func decodeWorkflowTags(raw json.RawMessage) ([]string, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}
	if raw[0] == '"' {
		var encoded string
		if err := json.Unmarshal(raw, &encoded); err != nil {
			return nil, fmt.Errorf("tags must be a JSON array or an exact JSON-encoded array: %w", err)
		}
		raw = bytes.TrimSpace([]byte(encoded))
		if len(raw) == 0 || raw[0] != '[' {
			return nil, fmt.Errorf("tags string must contain a JSON array")
		}
	}
	if raw[0] != '[' {
		return nil, fmt.Errorf("tags must be a JSON array or an exact JSON-encoded array")
	}
	var tags []string
	if err := json.Unmarshal(raw, &tags); err != nil {
		return nil, fmt.Errorf("tags must be a JSON array of strings: %w", err)
	}
	return tags, nil
}

// requireCreateWorkflowMetadata makes the LLM tool's required metadata contract executable.
// The fields must be present, while an empty string/array is the explicit representation of
// "the user supplied no value". This guard belongs before Execute so omission cannot silently
// create a workflow with lost user intent.
//
// requireCreateWorkflowMetadata 将 LLM 工具 schema 的 metadata 必填契约落到执行前：字段必须
// 出现，但空字符串/空数组是「用户没有提供值」的明确表达。守卫必须早于 Execute，避免漏字段
// 静默创建出丢失用户意图的 workflow。
func requireCreateWorkflowMetadata(raw json.RawMessage) error {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil {
		return fmt.Errorf("create_workflow: bad args: %w", err)
	}
	if _, ok := fields["description"]; !ok {
		return ErrDescriptionRequired
	}
	if _, ok := fields["tags"]; !ok {
		return ErrTagsRequired
	}
	if _, ok := fields["changeReason"]; !ok {
		return ErrChangeReasonRequired
	}

	if bytes.Equal(bytes.TrimSpace(fields["description"]), []byte("null")) {
		return fmt.Errorf("create_workflow: description must be a string (use an empty string when absent)")
	}
	var description string
	if err := json.Unmarshal(fields["description"], &description); err != nil {
		return fmt.Errorf("create_workflow: description must be a string: %w", err)
	}
	if bytes.Equal(bytes.TrimSpace(fields["tags"]), []byte("null")) {
		return fmt.Errorf("create_workflow: tags must be a JSON array (use [] when absent)")
	}
	if _, err := decodeWorkflowTags(fields["tags"]); err != nil {
		return fmt.Errorf("create_workflow: %w", err)
	}
	if bytes.Equal(bytes.TrimSpace(fields["changeReason"]), []byte("null")) {
		return fmt.Errorf("create_workflow: changeReason must be a string (use an empty string when absent)")
	}
	var changeReason string
	if err := json.Unmarshal(fields["changeReason"], &changeReason); err != nil {
		return fmt.Errorf("create_workflow: changeReason must be a string: %w", err)
	}
	return nil
}

func normalizeWorkflowOp(raw json.RawMessage) (json.RawMessage, error) {
	var top map[string]json.RawMessage
	if err := json.Unmarshal(raw, &top); err != nil || top == nil {
		return nil, fmt.Errorf("must be an object")
	}
	var op string
	if value, ok := top["op"]; ok {
		if err := json.Unmarshal(value, &op); err != nil {
			return nil, fmt.Errorf("'op' must be a string")
		}
	}

	switch op {
	case "add_node":
		if err := liftWorkflowBody(top, "node", workflowNodeFields); err != nil {
			return nil, fmt.Errorf("add_node: %w", err)
		}
	case "add_edge":
		if err := liftWorkflowBody(top, "edge", workflowEdgeFields); err != nil {
			return nil, fmt.Errorf("add_edge: %w", err)
		}
	}
	return json.Marshal(top)
}

var workflowNodeFields = []string{"id", "kind", "ref", "input", "retry", "pos", "notes"}
var workflowEdgeFields = []string{"id", "from", "fromPort", "to"}

func liftWorkflowBody(top map[string]json.RawMessage, bodyKey string, fields []string) error {
	_, hasBody := top[bodyKey]
	stray := make([]string, 0, len(fields))
	for _, field := range fields {
		if _, ok := top[field]; ok {
			stray = append(stray, field)
		}
	}
	if hasBody {
		if len(stray) != 0 {
			return fmt.Errorf("top-level fields %s conflict with the nested %q object", stringsJoinQuoted(stray), bodyKey)
		}
		return nil
	}
	if len(stray) == 0 {
		return nil
	}
	body := make(map[string]json.RawMessage, len(stray))
	for _, field := range stray {
		body[field] = top[field]
		delete(top, field)
	}
	encoded, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshal nested %q object: %w", bodyKey, err)
	}
	top[bodyKey] = encoded
	return nil
}

func stringsJoinQuoted(fields []string) string {
	quoted := make([]byte, 0, len(fields)*5)
	for i, field := range fields {
		if i > 0 {
			quoted = append(quoted, ',', ' ')
		}
		quoted = append(quoted, '"')
		quoted = append(quoted, field...)
		quoted = append(quoted, '"')
	}
	return string(quoted)
}

func hasWorkflowOps(raw json.RawMessage) bool {
	raw = bytes.TrimSpace(raw)
	return len(raw) > 0 && !bytes.Equal(raw, []byte("null"))
}
