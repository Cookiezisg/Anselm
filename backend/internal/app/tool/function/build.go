package function

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	envfixapp "github.com/sunweilin/anselm/backend/internal/app/envfix"
	functionapp "github.com/sunweilin/anselm/backend/internal/app/function"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
)

// --- create_function -------------------------------------------------------

type CreateFunction struct{ svc *functionapp.Service }

func (t *CreateFunction) Name() string { return "create_function" }

func (t *CreateFunction) Description() string {
	return `Build a new Python function from ops; v1 takes effect immediately (no separate accept step). Required ops: set_meta, set_code. Optional: set_inputs, set_outputs, set_dependencies, set_python_version.

OP SHAPES (exact field names):
  {"op":"set_meta", "name":"snake_case_name", "description":"one line", "tags":["..."]}
  {"op":"set_code", "code":"def main(x: str) -> dict:\n    return {\"y\": x}"}
  {"op":"set_inputs", "inputs":[{"name":"x","type":"string","description":"..."}]}
  {"op":"set_outputs", "outputs":[{"name":"y","type":"string","description":"..."}]}
  {"op":"set_dependencies", "dependencies":["requests==2.31","pandas"]}
  {"op":"set_python_version", "version":"3.12"}

Field type is one of: string, number, boolean, object, array (a coarse hint; nested shapes are read with CEL at runtime, not declared here).

The schema declares ops as an array. A hosted provider that serializes the entire array as one JSON string is repaired only when that string decodes to a valid JSON array. The same narrow repair accepts an unambiguous field map or a top-level JSON-Schema object for set_inputs/set_outputs and projects it to the flat Field list used by Anselm. Do not send CSV, prose, or ambiguous shapes.

The function is stateless, run in a fresh isolated process per call. ENTRY POINT: the FIRST top-level (column-0) def in your code is the entry — its name is not significant (main is just a convention) and it is called with the inputs as keyword arguments (entry(**input)), returning a JSON-serialisable value. Define any helper defs AFTER the entry def or nest them inside it; a top-level helper placed BEFORE the entry would be called instead and fail. If the dependency install fails, the platform auto-revises the deps with an LLM and retries (≤3); the result reports envStatus + any envFixAttempts. Pass credentials via arguments, never hard-code them.`
}

func (t *CreateFunction) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["ops"],
		"properties": {
			"ops": {"type": "array", "description": "Build ops; each has an 'op' discriminator + op-specific fields.", "items": {"type": "object"}},
			"changeReason": {"type": "string", "description": "One-line reason for this creation."}
		}
	}`)
}

func (t *CreateFunction) ValidateInput(args json.RawMessage) error {
	var a struct {
		Ops json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_function: bad args: %w", err)
	}
	ops, _, err := canonicalOpsJSON(a.Ops)
	if err != nil {
		return fmt.Errorf("create_function: bad args: %w", err)
	}
	var items []json.RawMessage
	if err := json.Unmarshal(ops, &items); err != nil {
		return fmt.Errorf("create_function: bad args: ops must be an array: %w", err)
	}
	if items == nil {
		return fmt.Errorf("create_function: bad args: ops must be an array")
	}
	if len(items) == 0 {
		return ErrOpsRequired
	}
	return nil
}

// NormalizeArguments repairs the one observed hosted-model drift at the boundary: an array
// declared in the schema sometimes arrives as a JSON-encoded string. The repair is deliberately
// narrow and happens before validation so the durable tool card, gate decision, and execution all
// use the same native-array arguments.
//
// NormalizeArguments 在边界修复一次已观测的 hosted-model 漂移：schema 声明的数组偶尔以 JSON 字符串到达。
// 修复刻意收窄并发生在校验前，使耐久工具卡、人闸决议和执行都使用同一份原生数组参数。
func (t *CreateFunction) NormalizeArguments(args json.RawMessage) (json.RawMessage, bool) {
	return normalizeStringifiedOps(args)
}

func (t *CreateFunction) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_function: bad args: %w", err)
	}
	canonical, _, err := canonicalOpsJSON(args.Ops)
	if err != nil {
		return "", fmt.Errorf("create_function: bad args: %w", err)
	}
	ops, err := functionapp.ParseOps(canonical)
	if err != nil {
		return "", fmt.Errorf("create_function: %w", err)
	}
	sink := newBuildSink(ctx)
	defer sink.Close()
	f, v, err := t.svc.Create(ctx, functionapp.CreateInput{Ops: ops, ChangeReason: args.ChangeReason, Progress: sink})
	if err != nil {
		return "", fmt.Errorf("create_function: %w", err)
	}
	return toolapp.ToJSON(buildOutput(f.ID, v, len(ops), sink.attempts)), nil
}

// --- edit_function ---------------------------------------------------------

type EditFunction struct{ svc *functionapp.Service }

func (t *EditFunction) Name() string { return "edit_function" }

func (t *EditFunction) Description() string {
	return `Edit a function: apply ops on top of its active version, producing a new version that takes effect immediately. Same op shapes as create_function. Pass an empty ops array to just rebuild the active version's environment (retry a failed dependency install). A hosted provider may encode the whole ops array as a JSON string, or express set_inputs/set_outputs as an unambiguous field map / top-level JSON-Schema object; these exact shapes are normalized to Anselm's flat Field list. Do not send CSV, prose, or ambiguous shapes. Use revert_function to switch the active version to an older one.`
}

func (t *EditFunction) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["functionId", "ops"],
		"properties": {
			"functionId": {"type": "string"},
			"ops": {"type": "array", "description": "Build ops (empty array = rebuild env only).", "items": {"type": "object"}},
			"changeReason": {"type": "string", "description": "One-line reason for this edit."}
		}
	}`)
}

func (t *EditFunction) ValidateInput(args json.RawMessage) error {
	var a struct {
		FunctionID string          `json:"functionId"`
		Ops        json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("edit_function: bad args: %w", err)
	}
	if a.FunctionID == "" {
		return ErrFunctionIDRequired
	}
	ops, _, err := canonicalOpsJSON(a.Ops)
	if err != nil {
		return fmt.Errorf("edit_function: bad args: %w", err)
	}
	var items []json.RawMessage
	if err := json.Unmarshal(ops, &items); err != nil {
		return fmt.Errorf("edit_function: bad args: ops must be an array: %w", err)
	}
	if items == nil {
		return fmt.Errorf("edit_function: bad args: ops must be an array")
	}
	return nil
}

// NormalizeArguments applies the same narrow array-string repair as create_function.
func (t *EditFunction) NormalizeArguments(args json.RawMessage) (json.RawMessage, bool) {
	return normalizeStringifiedOps(args)
}

func (t *EditFunction) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		FunctionID   string          `json:"functionId"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_function: bad args: %w", err)
	}
	var ops []functionapp.Op
	if len(args.Ops) > 0 {
		canonical, _, perr := canonicalOpsJSON(args.Ops)
		if perr != nil {
			return "", fmt.Errorf("edit_function: bad args: %w", perr)
		}
		parsed, perr := functionapp.ParseOps(canonical)
		if perr != nil {
			return "", fmt.Errorf("edit_function: %w", perr)
		}
		ops = parsed
	}
	sink := newBuildSink(ctx)
	defer sink.Close()
	v, err := t.svc.Edit(ctx, functionapp.EditInput{ID: args.FunctionID, Ops: ops, ChangeReason: args.ChangeReason, Progress: sink})
	if err != nil {
		return "", fmt.Errorf("edit_function: %w", err)
	}
	return toolapp.ToJSON(buildOutput(args.FunctionID, v, len(ops), sink.attempts)), nil
}

// canonicalOpsJSON returns an array-shaped JSON value. The second result records whether the
// hosted-model string form was repaired so callers can rewrite the durable arguments only then.
func canonicalOpsJSON(raw json.RawMessage) (json.RawMessage, bool, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 {
		return nil, false, nil
	}
	if trimmed[0] == '"' {
		var encoded string
		if err := json.Unmarshal(trimmed, &encoded); err != nil {
			return nil, false, fmt.Errorf("ops must be an array or a JSON-encoded array: %w", err)
		}
		trimmed = bytes.TrimSpace([]byte(encoded))
		if len(trimmed) == 0 {
			return nil, false, fmt.Errorf("ops JSON string must contain an array")
		}
		var items []json.RawMessage
		if err := json.Unmarshal(trimmed, &items); err != nil {
			return nil, false, fmt.Errorf("ops JSON string must contain an array: %w", err)
		}
		if items == nil {
			return nil, false, fmt.Errorf("ops JSON string must contain an array")
		}
		normalized, _, err := normalizeFieldShapeOps(trimmed)
		if err != nil {
			return nil, false, err
		}
		return normalized, true, nil
	}
	var items []json.RawMessage
	if err := json.Unmarshal(trimmed, &items); err != nil {
		return nil, false, fmt.Errorf("ops must be an array: %w", err)
	}
	if items == nil {
		return nil, false, fmt.Errorf("ops must be an array")
	}
	normalized, changed, err := normalizeFieldShapeOps(trimmed)
	if err != nil {
		return nil, false, err
	}
	return normalized, changed, nil
}

// normalizeFieldShapeOps projects the two unambiguous provider representations observed for
// set_inputs/set_outputs onto Anselm's flat []schema.Field contract. It deliberately does not
// interpret arbitrary JSON Schema features: a wrapper is accepted only when every property is
// represented and required (if present) names exactly those properties.
//
// normalizeFieldShapeOps 将已观测的两种 provider 形状投影到 Anselm 的扁平 []schema.Field 契约：
// set_inputs/set_outputs 可传字段 map 或顶层 JSON Schema。刻意不解释任意 JSON Schema 特性：只有所有
// property 都在、且 required（若存在）恰好覆盖全部 property 时才接受 wrapper，避免静默改变语义。
func normalizeFieldShapeOps(raw json.RawMessage) (json.RawMessage, bool, error) {
	var ops []json.RawMessage
	if err := json.Unmarshal(raw, &ops); err != nil {
		return nil, false, fmt.Errorf("ops must be an array: %w", err)
	}
	changed := false
	for i, opRaw := range ops {
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(opRaw, &fields); err != nil || fields == nil {
			continue
		}
		opRawType, ok := fields["op"]
		if !ok {
			continue
		}
		var opType string
		if err := json.Unmarshal(opRawType, &opType); err != nil {
			continue
		}
		if opType != "set_inputs" && opType != "set_outputs" {
			continue
		}
		key := strings.TrimPrefix(opType, "set_")
		value, ok := fields[key]
		if !ok {
			continue
		}
		canonical, didChange, err := normalizeFieldShape(value, opType)
		if err != nil {
			return nil, false, err
		}
		if !didChange {
			continue
		}
		fields[key] = canonical
		encoded, err := json.Marshal(fields)
		if err != nil {
			return nil, false, fmt.Errorf("%s: normalize args: %w", opType, err)
		}
		ops[i] = encoded
		changed = true
	}
	if !changed {
		return raw, false, nil
	}
	encoded, err := json.Marshal(ops)
	if err != nil {
		return nil, false, fmt.Errorf("normalize ops: %w", err)
	}
	return encoded, true, nil
}

func normalizeFieldShape(raw json.RawMessage, opType string) (json.RawMessage, bool, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || trimmed[0] != '{' {
		return raw, false, nil
	}
	var object map[string]json.RawMessage
	if err := json.Unmarshal(trimmed, &object); err != nil || object == nil {
		return raw, false, nil
	}
	if properties, ok := object["properties"]; ok {
		fields, err := fieldsFromJSONSchema(properties, object["required"], opType)
		if err != nil {
			return nil, false, err
		}
		encoded, err := json.Marshal(fields)
		if err != nil {
			return nil, false, fmt.Errorf("%s: normalize schema: %w", opType, err)
		}
		return encoded, true, nil
	}

	keys := make([]string, 0, len(object))
	for name := range object {
		keys = append(keys, name)
	}
	sort.Strings(keys)
	fields := make([]map[string]json.RawMessage, 0, len(keys))
	for _, name := range keys {
		var field map[string]json.RawMessage
		if err := json.Unmarshal(object[name], &field); err != nil || field == nil {
			return nil, false, fmt.Errorf("%s: field %q must be an object", opType, name)
		}
		if existing, ok := field["name"]; ok {
			var existingName string
			if err := json.Unmarshal(existing, &existingName); err != nil || existingName != name {
				return nil, false, fmt.Errorf("%s: field map key %q conflicts with name", opType, name)
			}
		} else {
			encodedName, err := json.Marshal(name)
			if err != nil {
				return nil, false, fmt.Errorf("%s: field %q name: %w", opType, name, err)
			}
			field["name"] = encodedName
		}
		fields = append(fields, field)
	}
	encoded, err := json.Marshal(fields)
	if err != nil {
		return nil, false, fmt.Errorf("%s: normalize field map: %w", opType, err)
	}
	return encoded, true, nil
}

func fieldsFromJSONSchema(properties json.RawMessage, required json.RawMessage, opType string) ([]map[string]json.RawMessage, error) {
	var propertyMap map[string]json.RawMessage
	if err := json.Unmarshal(properties, &propertyMap); err != nil || propertyMap == nil {
		return nil, fmt.Errorf("%s: schema properties must be an object", opType)
	}
	if len(required) > 0 && string(bytes.TrimSpace(required)) != "null" {
		var requiredNames []string
		if err := json.Unmarshal(required, &requiredNames); err != nil {
			return nil, fmt.Errorf("%s: schema required must be an array", opType)
		}
		requiredSet := make(map[string]bool, len(requiredNames))
		for _, name := range requiredNames {
			requiredSet[name] = true
		}
		if len(requiredNames) != len(propertyMap) || len(requiredSet) != len(propertyMap) {
			return nil, fmt.Errorf("%s: schema required must cover every property", opType)
		}
		for name := range propertyMap {
			if !requiredSet[name] {
				return nil, fmt.Errorf("%s: schema property %q is not required", opType, name)
			}
		}
	}
	keys := make([]string, 0, len(propertyMap))
	for name := range propertyMap {
		keys = append(keys, name)
	}
	sort.Strings(keys)
	fields := make([]map[string]json.RawMessage, 0, len(keys))
	for _, name := range keys {
		var field map[string]json.RawMessage
		if err := json.Unmarshal(propertyMap[name], &field); err != nil || field == nil {
			return nil, fmt.Errorf("%s: schema property %q must be an object", opType, name)
		}
		encodedName, err := json.Marshal(name)
		if err != nil {
			return nil, fmt.Errorf("%s: schema property %q name: %w", opType, name, err)
		}
		field["name"] = encodedName
		fields = append(fields, field)
	}
	return fields, nil
}

func normalizeStringifiedOps(args json.RawMessage) (json.RawMessage, bool) {
	var fields map[string]json.RawMessage
	if json.Unmarshal(args, &fields) != nil || fields == nil {
		return nil, false
	}
	raw, ok := fields["ops"]
	if !ok {
		return nil, false
	}
	canonical, changed, err := canonicalOpsJSON(raw)
	if err != nil || !changed {
		return nil, false
	}
	fields["ops"] = canonical
	normalized, err := json.Marshal(fields)
	if err != nil {
		return nil, false
	}
	return normalized, true
}

// buildOutput is the shared create/edit result envelope: identity + env outcome +
// (when the fix loop ran more than once) the attempt history.
//
// buildOutput 是 create/edit 共享的结果信封：身份 + env 结果 +（修复循环跑过一次以上时）尝试历史。
func buildOutput(functionID string, v *functiondomain.Version, opsApplied int, attempts []envfixapp.Attempt) map[string]any {
	out := map[string]any{
		"id":         functionID,
		"versionId":  v.ID,
		"version":    v.Version,
		"envStatus":  v.EnvStatus,
		"opsApplied": opsApplied,
	}
	if v.EnvError != "" {
		out["envError"] = v.EnvError
	}
	if len(attempts) > 1 {
		out["envFixAttempts"] = attempts
	}
	return out
}
