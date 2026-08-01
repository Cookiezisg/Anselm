package approval

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"

	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// decodeApprovalBool accepts the schema-correct boolean and the exact string form emitted by
// some hosted models. It does not accept numbers or arbitrary truthy values.
//
// decodeApprovalBool 接受 schema 正确的布尔值，以及部分托管模型发出的精确字符串形式；不接受数字或
// 任意 truthy 值，避免把模型的形状错误静默扩大成业务语义。
func decodeApprovalBool(raw json.RawMessage) (bool, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return false, nil
	}
	var value bool
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return false, fmt.Errorf("must be boolean or an exact boolean string, got %s", string(raw))
	}
	value, err := strconv.ParseBool(strings.TrimSpace(text))
	if err != nil {
		return false, fmt.Errorf("must be boolean or an exact boolean string, got %q", text)
	}
	return value, nil
}

// decodeApprovalVersion accepts a native integer and the exact decimal string variant emitted by
// some hosted models. Other representations stay invalid so a malformed version cannot silently
// select an unintended snapshot.
func decodeApprovalVersion(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	var version int
	if err := json.Unmarshal(raw, &version); err == nil {
		return version, nil
	}
	var encoded string
	if err := json.Unmarshal(raw, &encoded); err != nil {
		return 0, fmt.Errorf("version must be a positive integer or an exact integer string, got %s", string(raw))
	}
	version, err := strconv.Atoi(strings.TrimSpace(encoded))
	if err != nil {
		return 0, fmt.Errorf("version must be a positive integer or an exact integer string, got %q", encoded)
	}
	return version, nil
}

// decodeApprovalInputs accepts the public Field array plus two shape-preserving hosted-model
// variants: an exact JSON-encoded array string, or a JSON object keyed by field name. Object keys
// are sorted because JSON objects have no order; this keeps the resulting UI and database stable.
//
// decodeApprovalInputs 接受公开的 Field 数组，以及两种不改变字段含义的托管模型形状：精确 JSON 编码的
// 数组字符串，或以字段名为 key 的 JSON 对象。JSON 对象无顺序，故排序 key 让 UI 和数据库稳定。
func decodeApprovalInputs(raw json.RawMessage) ([]schemapkg.Field, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}
	if raw[0] == '"' {
		var encoded string
		if err := json.Unmarshal(raw, &encoded); err != nil {
			return nil, fmt.Errorf("inputs must be a Field array or an exact JSON-encoded value: %w", err)
		}
		return decodeApprovalInputs([]byte(encoded))
	}

	switch raw[0] {
	case '[':
		var fields []schemapkg.Field
		if err := json.Unmarshal(raw, &fields); err != nil {
			return nil, fmt.Errorf("inputs must be a Field array: %w", err)
		}
		return fields, nil
	case '{':
		var byName map[string]json.RawMessage
		if err := json.Unmarshal(raw, &byName); err != nil {
			return nil, fmt.Errorf("inputs object must be keyed by field name: %w", err)
		}
		keys := make([]string, 0, len(byName))
		for name := range byName {
			if strings.TrimSpace(name) == "" {
				return nil, fmt.Errorf("inputs object contains an empty field name")
			}
			keys = append(keys, name)
		}
		sort.Strings(keys)
		fields := make([]schemapkg.Field, 0, len(keys))
		for _, name := range keys {
			var shape struct {
				Name        string `json:"name"`
				Type        string `json:"type"`
				Description string `json:"description"`
			}
			if err := json.Unmarshal(byName[name], &shape); err != nil {
				return nil, fmt.Errorf("inputs.%s must be a field object: %w", name, err)
			}
			if shape.Name != "" && shape.Name != name {
				return nil, fmt.Errorf("inputs.%s has conflicting name %q", name, shape.Name)
			}
			fields = append(fields, schemapkg.Field{Name: name, Type: shape.Type, Description: shape.Description})
		}
		return fields, nil
	default:
		return nil, fmt.Errorf("inputs must be a Field array, an exact JSON-encoded array, or a field-name object")
	}
}

// requireCompleteEditApprovalArgs keeps a full-version edit from silently turning omitted
// fields into zero values. The public schema advertises these fields as required, but the
// execution boundary must enforce the same contract for direct callers and malformed model JSON.
func requireCompleteEditApprovalArgs(raw json.RawMessage) error {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil {
		return fmt.Errorf("edit_approval: bad args: %w", err)
	}
	for _, name := range []string{"approvalId", "inputs", "template", "allowReason", "timeout", "timeoutBehavior", "changeReason"} {
		value, ok := fields[name]
		if !ok || bytes.Equal(bytes.TrimSpace(value), []byte("null")) {
			return fmt.Errorf("edit_approval: %s is required for a complete replacement", name)
		}
	}
	return nil
}
