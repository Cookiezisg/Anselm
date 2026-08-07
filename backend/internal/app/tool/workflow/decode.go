package workflow

import (
	"bytes"
	"encoding/json"
	"fmt"
)

// decodeWorkflowOps accepts the public array shape plus the narrow variants observed from hosted
// models: an exact JSON-encoded array string, legacy add_node/add_edge objects whose body fields
// were emitted beside (rather than inside) node/edge, and an exact nodes/edges graph snapshot. It
// deliberately does not repair arbitrary JSON or merge conflicting fields.
//
// decodeWorkflowOps 接受公开数组形状，以及托管模型实际发出的窄变体：精确 JSON 编码的数组
// 字符串、把 add_node/add_edge 的 body 字段放在 node/edge 外的旧形状，以及精确的 nodes/edges
// 图快照。不修任意 JSON，也不合并互相冲突的字段。
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
			if len(raw) == 0 || raw[0] != '{' {
				return nil, fmt.Errorf("ops string must contain a JSON array or an exact graph snapshot")
			}
		}
	}
	if raw[0] == '{' {
		graphOps, err := normalizeHostedGraphSnapshot(raw)
		if err != nil {
			return nil, fmt.Errorf("ops graph snapshot: %w", err)
		}
		raw = graphOps
	}
	if raw[0] != '[' {
		return nil, fmt.Errorf("ops must be a JSON array, an exact JSON-encoded array, or an exact graph snapshot")
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

// normalizeHostedGraphSnapshot converts one observed hosted-model graph snapshot into the public
// op list. The accepted vocabulary is intentionally finite: nodes/edges must both be arrays, node
// type is the alias for kind, and triggerId is the alias for ref only on trigger nodes.
//
// normalizeHostedGraphSnapshot 把一种已观察到的托管模型图快照转换为公开 op 列表。词汇表刻意
// 有限：nodes/edges 必须同时为数组，node.type 是 kind 别名，triggerId 只在 trigger 节点上
// 作为 ref 别名；其余形状不猜测。
func normalizeHostedGraphSnapshot(raw json.RawMessage) (json.RawMessage, error) {
	var graph map[string]json.RawMessage
	if err := json.Unmarshal(raw, &graph); err != nil || graph == nil {
		return nil, fmt.Errorf("must be an object with nodes and edges arrays")
	}
	for key := range graph {
		if key != "nodes" && key != "edges" {
			return nil, fmt.Errorf("unknown graph snapshot field %q", key)
		}
	}
	nodesRaw, hasNodes := graph["nodes"]
	edgesRaw, hasEdges := graph["edges"]
	if !hasNodes || !hasEdges {
		return nil, fmt.Errorf("nodes and edges arrays are required")
	}
	nodes, err := decodeSnapshotArray(nodesRaw, "nodes")
	if err != nil {
		return nil, err
	}
	edges, err := decodeSnapshotArray(edgesRaw, "edges")
	if err != nil {
		return nil, err
	}

	ops := make([]json.RawMessage, 0, len(nodes)+len(edges))
	for i, nodeRaw := range nodes {
		node, err := normalizeHostedSnapshotNode(nodeRaw)
		if err != nil {
			return nil, fmt.Errorf("nodes[%d]: %w", i, err)
		}
		ops = append(ops, node)
	}
	for i, edgeRaw := range edges {
		edge, err := normalizeHostedSnapshotEdge(edgeRaw)
		if err != nil {
			return nil, fmt.Errorf("edges[%d]: %w", i, err)
		}
		ops = append(ops, edge)
	}
	return json.Marshal(ops)
}

func decodeSnapshotArray(raw json.RawMessage, name string) ([]json.RawMessage, error) {
	if raw = bytes.TrimSpace(raw); len(raw) == 0 || raw[0] != '[' {
		return nil, fmt.Errorf("%s must be an array", name)
	}
	var entries []json.RawMessage
	if err := json.Unmarshal(raw, &entries); err != nil {
		return nil, fmt.Errorf("%s must be an array: %w", name, err)
	}
	return entries, nil
}

func normalizeHostedSnapshotNode(raw json.RawMessage) (json.RawMessage, error) {
	var source map[string]json.RawMessage
	if err := json.Unmarshal(raw, &source); err != nil || source == nil {
		return nil, fmt.Errorf("must be an object")
	}
	for key := range source {
		switch key {
		case "id", "kind", "type", "ref", "triggerId", "input", "retry", "pos", "notes":
		default:
			return nil, fmt.Errorf("unknown node field %q", key)
		}
	}
	id, err := requiredSnapshotString(source, "id")
	if err != nil {
		return nil, err
	}
	kind, kindRaw, err := snapshotAliasedString(source, "kind", "type")
	if err != nil {
		return nil, err
	}
	if kind == "" {
		return nil, fmt.Errorf("kind/type is required")
	}
	ref, refRaw, err := snapshotAliasedString(source, "ref", "triggerId")
	if err != nil {
		return nil, err
	}
	if triggerID, hasTriggerID := source["triggerId"]; hasTriggerID {
		if kind != "trigger" {
			return nil, fmt.Errorf("triggerId alias requires kind/type \"trigger\", got %q", kind)
		}
		refRaw = triggerID
	}
	if ref == "" {
		return nil, fmt.Errorf("ref/triggerId is required")
	}

	node := map[string]json.RawMessage{
		"id":   id,
		"kind": kindRaw,
		"ref":  refRaw,
	}
	for _, key := range []string{"input", "retry", "pos", "notes"} {
		if value, ok := source[key]; ok {
			node[key] = value
		}
	}
	nodeRaw, err := json.Marshal(node)
	if err != nil {
		return nil, fmt.Errorf("encode normalized node: %w", err)
	}
	return json.Marshal(map[string]json.RawMessage{
		"op":   json.RawMessage(`"add_node"`),
		"node": nodeRaw,
	})
}

func normalizeHostedSnapshotEdge(raw json.RawMessage) (json.RawMessage, error) {
	var source map[string]json.RawMessage
	if err := json.Unmarshal(raw, &source); err != nil || source == nil {
		return nil, fmt.Errorf("must be an object")
	}
	for key := range source {
		switch key {
		case "id", "from", "fromPort", "to":
		default:
			return nil, fmt.Errorf("unknown edge field %q", key)
		}
	}
	edge := make(map[string]json.RawMessage, 4)
	for _, key := range []string{"id", "from", "fromPort", "to"} {
		if value, ok := source[key]; ok {
			if key != "fromPort" {
				if _, err := requiredSnapshotString(source, key); err != nil {
					return nil, err
				}
			}
			edge[key] = value
		}
	}
	for _, key := range []string{"id", "from", "to"} {
		if _, ok := edge[key]; !ok {
			return nil, fmt.Errorf("%s is required", key)
		}
	}
	edgeRaw, err := json.Marshal(edge)
	if err != nil {
		return nil, fmt.Errorf("encode normalized edge: %w", err)
	}
	return json.Marshal(map[string]json.RawMessage{
		"op":   json.RawMessage(`"add_edge"`),
		"edge": edgeRaw,
	})
}

func requiredSnapshotString(source map[string]json.RawMessage, key string) (json.RawMessage, error) {
	raw, ok := source[key]
	if !ok {
		return nil, fmt.Errorf("%s is required", key)
	}
	var value string
	if err := json.Unmarshal(raw, &value); err != nil || value == "" {
		return nil, fmt.Errorf("%s must be a non-empty string", key)
	}
	return raw, nil
}

func snapshotAliasedString(source map[string]json.RawMessage, canonical, alias string) (string, json.RawMessage, error) {
	canonicalRaw, hasCanonical := source[canonical]
	aliasRaw, hasAlias := source[alias]
	if hasCanonical && hasAlias {
		return "", nil, fmt.Errorf("fields %q and %q conflict", canonical, alias)
	}
	raw := canonicalRaw
	if !hasCanonical {
		raw = aliasRaw
	}
	if !hasCanonical && !hasAlias {
		return "", nil, nil
	}
	var value string
	if err := json.Unmarshal(raw, &value); err != nil {
		return "", nil, fmt.Errorf("%s/%s must be strings", canonical, alias)
	}
	return value, raw, nil
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
		if alias, ok := top["type"]; ok {
			var typeOp string
			if err := json.Unmarshal(alias, &typeOp); err != nil {
				return nil, fmt.Errorf("'type' must be a string when paired with 'op'")
			}
			if typeOp != op {
				return nil, fmt.Errorf("fields \"op\" and \"type\" conflict")
			}
			delete(top, "type")
		}
	} else if value, ok := top["type"]; ok {
		var typeOp string
		if err := json.Unmarshal(value, &typeOp); err != nil {
			return nil, fmt.Errorf("'type' must be a string")
		}
		if !isWorkflowOpType(typeOp) {
			return nil, fmt.Errorf("unsupported operation discriminator %q", typeOp)
		}
		op = typeOp
		top["op"] = value
		delete(top, "type")
	}

	switch op {
	case "add_node":
		if err := normalizeHostedNodeAliases(top); err != nil {
			return nil, fmt.Errorf("add_node: %w", err)
		}
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

func isWorkflowOpType(value string) bool {
	switch value {
	case "set_meta", "add_node", "update_node", "delete_node", "add_edge", "update_edge", "delete_edge":
		return true
	default:
		return false
	}
}

// normalizeHostedNodeAliases handles one observed hosted-model shorthand without turning the
// decoder into a fuzzy repair layer. The aliases are only valid for a trigger node and any
// canonical/alias or nested/top-level mix is rejected rather than guessed.
//
// normalizeHostedNodeAliases 只处理一种已观察到的托管模型简写，不把 decoder 变成模糊修复层。
// 别名仅对 trigger 节点有效；规范字段与别名、嵌套与顶层混用时一律拒绝，不猜测。
func normalizeHostedNodeAliases(top map[string]json.RawMessage) error {
	if _, hasNode := top["node"]; hasNode {
		if _, hasNodeID := top["nodeId"]; hasNodeID {
			return fmt.Errorf("top-level field \"nodeId\" conflicts with the nested \"node\" object")
		}
		if _, hasTriggerID := top["triggerId"]; hasTriggerID {
			return fmt.Errorf("top-level field \"triggerId\" conflicts with the nested \"node\" object")
		}
		return nil
	}

	if nodeID, ok := top["nodeId"]; ok {
		if _, hasCanonicalID := top["id"]; hasCanonicalID {
			return fmt.Errorf("top-level fields \"nodeId\" and \"id\" conflict")
		}
		top["id"] = nodeID
		delete(top, "nodeId")
	}

	if triggerID, ok := top["triggerId"]; ok {
		if _, hasCanonicalRef := top["ref"]; hasCanonicalRef {
			return fmt.Errorf("top-level fields \"triggerId\" and \"ref\" conflict")
		}
		if kindRaw, hasKind := top["kind"]; hasKind {
			var kind string
			if err := json.Unmarshal(kindRaw, &kind); err != nil {
				return fmt.Errorf("'kind' must be a string when using \"triggerId\": %w", err)
			}
			if kind != "trigger" {
				return fmt.Errorf("\"triggerId\" alias requires kind \"trigger\", got %q", kind)
			}
		}
		top["ref"] = triggerID
		delete(top, "triggerId")
	}
	return nil
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
