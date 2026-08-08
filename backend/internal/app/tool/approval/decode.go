package approval

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

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

// decodeApprovalTimeout preserves the public duration-string contract while accepting the exact
// integer-seconds shape emitted by some hosted models (for example, "7200" for 2h). The value is
// canonicalized before it reaches the domain so UI receipts and later timeout sweeps keep one readable
// duration instead of persisting a provider-specific number.
//
// decodeApprovalTimeout 保持公开 duration 字符串契约，同时兼容部分托管模型发出的精确整数秒形状
// (例如用 "7200" 表示 2h)。进入 domain 前先归一化，避免 UI 回执和后续超时扫描持久化 provider
// 专属数字而失去人类可读口径。
func decodeApprovalTimeout(raw json.RawMessage) (string, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return "", nil
	}

	var text string
	if raw[0] == '"' {
		if err := json.Unmarshal(raw, &text); err != nil {
			return "", fmt.Errorf("timeout must be a duration string or an exact integer number of seconds")
		}
	} else {
		var seconds int64
		if err := json.Unmarshal(raw, &seconds); err != nil {
			return "", fmt.Errorf("timeout must be a duration string or an exact integer number of seconds")
		}
		text = strconv.FormatInt(seconds, 10)
	}

	text = strings.TrimSpace(text)
	if text == "" {
		return "", nil
	}
	seconds, err := strconv.ParseInt(text, 10, 64)
	if err != nil {
		if isBareApprovalNumber(text) {
			return "", fmt.Errorf("timeout seconds must be an exact integer")
		}
		// Unit-bearing durations remain the public form and are validated by the domain.
		return text, nil
	}
	if seconds <= 0 || seconds > int64((time.Duration(1<<63-1))/time.Second) {
		return "", fmt.Errorf("timeout seconds must be a positive integer")
	}
	return compactApprovalDuration(time.Duration(seconds) * time.Second), nil
}

func isBareApprovalNumber(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if (r < '0' || r > '9') && r != '+' && r != '-' && r != '.' {
			return false
		}
	}
	return true
}

func compactApprovalDuration(d time.Duration) string {
	if d%(24*time.Hour) == 0 {
		return fmt.Sprintf("%dd", d/(24*time.Hour))
	}
	if d%time.Hour == 0 {
		return fmt.Sprintf("%dh", d/time.Hour)
	}
	if d%time.Minute == 0 {
		return fmt.Sprintf("%dm", d/time.Minute)
	}
	if d%time.Second == 0 {
		return fmt.Sprintf("%ds", d/time.Second)
	}
	return d.String()
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
