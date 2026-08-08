// Package control provides the LLM system tools for the control-logic library:
// search / get / create / edit / revert / delete. These are lazy tools (Toolset.Lazy)
// — surfaced via search_tools, not resident. There is NO run/executions tool: a control
// logic is evaluated by the workflow durable interpreter, never invoked
// standalone.
//
// Package control 提供操作 control 逻辑库的 LLM system tool：search/get/create/edit/revert/
// delete。懒加载工具（Toolset.Lazy）——经 search_tools 浮现，非常驻。**无 run/executions 工具**：
// control 逻辑由 workflow durable 解释器求值，绝不独立调用。
package control

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	controlapp "github.com/sunweilin/anselm/backend/internal/app/control"
	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	controldomain "github.com/sunweilin/anselm/backend/internal/domain/control"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// ControlTools constructs the control-logic system tools over the app service.
//
// ControlTools 基于 app service 构造 control 逻辑 system tool。
func ControlTools(svc *controlapp.Service, content *searchapp.Service, deps toolapp.DependentCounter) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchControl{svc: svc, content: content},
		&GetControl{svc: svc},
		&CreateControl{svc: svc},
		&EditControl{svc: svc},
		&RevertControl{svc: svc},
		&DeleteControl{svc: svc, deps: deps},
	}
}

// branchArg is the JSON shape of one routing branch in create/edit tool args.
//
// branchArg 是 create/edit 工具参数里一条路由分支的 JSON 形状。
type branchArg struct {
	Port string            `json:"port"`
	When string            `json:"when"`
	Emit map[string]string `json:"emit"`
}

// decodeControlBranches accepts the schema-correct array and the exact
// JSON-encoded array string emitted by some hosted models. It tolerates an
// encoding variant, not a different value: malformed strings, objects and
// non-array values remain invalid.
func decodeControlBranches(raw json.RawMessage) ([]branchArg, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}

	var branches []branchArg
	switch raw[0] {
	case '[':
		if err := json.Unmarshal(raw, &branches); err != nil {
			return nil, fmt.Errorf("branches must be a JSON array: %w", err)
		}
	case '"':
		var encoded string
		if err := json.Unmarshal(raw, &encoded); err != nil {
			return nil, fmt.Errorf("branches must be a JSON array or an exact JSON-encoded array: %w", err)
		}
		encodedBytes := bytes.TrimSpace([]byte(encoded))
		if len(encodedBytes) == 0 || encodedBytes[0] != '[' {
			return nil, fmt.Errorf("branches string must contain a JSON array")
		}
		if err := json.Unmarshal(encodedBytes, &branches); err != nil {
			return nil, fmt.Errorf("branches string must contain a valid JSON array: %w", err)
		}
	default:
		return nil, fmt.Errorf("branches must be a JSON array or an exact JSON-encoded array")
	}
	return branches, nil
}

// decodeControlInputs accepts the schema-correct array and the exact JSON-encoded array string
// emitted by some hosted models. It deliberately mirrors decodeControlBranches: only an encoding
// variant is tolerated, while objects, malformed strings, and non-array values remain invalid.
//
// decodeControlInputs 接受 schema 正确的数组，以及部分托管模型发出的完整 JSON 数组字符串。
// 与 decodeControlBranches 对称：只兼容编码形态，不放宽值形状；对象、坏字符串和非数组仍拒绝。
func decodeControlInputs(raw json.RawMessage) ([]schemapkg.Field, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}

	var inputs []schemapkg.Field
	switch raw[0] {
	case '[':
		if err := json.Unmarshal(raw, &inputs); err != nil {
			return nil, fmt.Errorf("inputs must be a JSON array: %w", err)
		}
	case '"':
		var encoded string
		if err := json.Unmarshal(raw, &encoded); err != nil {
			return nil, fmt.Errorf("inputs must be a JSON array or an exact JSON-encoded array: %w", err)
		}
		encodedBytes := bytes.TrimSpace([]byte(encoded))
		if len(encodedBytes) == 0 || encodedBytes[0] != '[' {
			return nil, fmt.Errorf("inputs string must contain a JSON array")
		}
		if err := json.Unmarshal(encodedBytes, &inputs); err != nil {
			return nil, fmt.Errorf("inputs string must contain a valid JSON array: %w", err)
		}
	default:
		return nil, fmt.Errorf("inputs must be a JSON array or an exact JSON-encoded array")
	}
	return inputs, nil
}

// decodeControlVersion accepts a native integer and the exact decimal string variant emitted by
// some hosted models. Other representations stay invalid so a malformed version cannot silently
// select an unintended snapshot.
func decodeControlVersion(raw json.RawMessage) (int, error) {
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

func toBranches(in []branchArg) []controldomain.Branch {
	out := make([]controldomain.Branch, len(in))
	for i, b := range in {
		out[i] = controldomain.Branch{Port: b.Port, When: b.When, Emit: b.Emit}
	}
	return out
}
