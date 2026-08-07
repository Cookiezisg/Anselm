package workflow

import (
	"encoding/json"
	"fmt"
	"strings"
)

// workflowTargetArgs is the read-side address contract shared by get_workflow and
// capability_check_workflow. Exactly one canonical address is accepted: the opaque entity ID
// or the exact user-facing name.
//
// workflowTargetArgs 是 get_workflow 与 capability_check_workflow 共用的读地址契约。恰接收一个规范地址：
// opaque entity ID 或用户可见的精确名称。
type workflowTargetArgs struct {
	WorkflowID   string `json:"workflowId"`
	WorkflowName string `json:"workflowName"`
}

// normalizeWorkflowTargetArguments repairs one observed hosted-provider drift: a filesystem-shaped
// file_path was emitted for a workflow name. Only a single path segment is eligible, never an
// absolute/relative path. An explicit canonical field wins, and conflicting aliases are left alone
// so validation rejects them instead of guessing.
//
// normalizeWorkflowTargetArguments 修复一次已观测的 hosted provider 漂移：provider 把 workflow 名放进
// filesystem 形状的 file_path。只有单路径段可修复，绝不接受绝对/相对路径。显式规范字段优先；别名冲突时
// 原样交给校验拒绝，绝不猜。
func normalizeWorkflowTargetArguments(args []byte) ([]byte, bool) {
	var fields map[string]any
	if json.Unmarshal(args, &fields) != nil || fields == nil {
		return args, false
	}
	id, _ := fields["workflowId"].(string)
	name, _ := fields["workflowName"].(string)
	alias, hasAlias := fields["file_path"].(string)
	if !hasAlias || strings.TrimSpace(alias) == "" {
		return args, false
	}
	if strings.TrimSpace(id) != "" || strings.TrimSpace(name) != "" {
		if (strings.TrimSpace(name) != "" && strings.TrimSpace(name) == strings.TrimSpace(alias)) ||
			(strings.TrimSpace(id) != "" && strings.TrimSpace(id) == strings.TrimSpace(alias)) {
			delete(fields, "file_path")
			return marshalWorkflowTarget(fields, args)
		}
		return args, false
	}
	alias = strings.TrimSpace(alias)
	if strings.HasPrefix(alias, "wf_") && isOpaqueWorkflowID(alias) {
		fields["workflowId"] = alias
	} else if isSingleWorkflowName(alias) {
		fields["workflowName"] = alias
	} else {
		return args, false
	}
	delete(fields, "file_path")
	return marshalWorkflowTarget(fields, args)
}

func marshalWorkflowTarget(fields map[string]any, original []byte) ([]byte, bool) {
	normalized, err := json.Marshal(fields)
	if err != nil {
		return original, false
	}
	return normalized, true
}

func isOpaqueWorkflowID(value string) bool {
	if len(value) <= len("wf_") {
		return false
	}
	for _, r := range value[len("wf_"):] {
		if !(r >= 'A' && r <= 'Z') && !(r >= 'a' && r <= 'z') && !(r >= '0' && r <= '9') {
			return false
		}
	}
	return true
}

func isSingleWorkflowName(value string) bool {
	return value != "" && value != "." && value != ".." &&
		!strings.HasPrefix(value, "~") && !strings.ContainsAny(value, `/\\`)
}

func decodeWorkflowTarget(args []byte, toolName string) (workflowTargetArgs, error) {
	var fields struct {
		WorkflowID   string `json:"workflowId"`
		WorkflowName string `json:"workflowName"`
		FilePath     string `json:"file_path"`
	}
	if err := json.Unmarshal(args, &fields); err != nil {
		return workflowTargetArgs{}, fmt.Errorf("%s: bad args: %w", toolName, err)
	}
	fields.WorkflowID = strings.TrimSpace(fields.WorkflowID)
	fields.WorkflowName = strings.TrimSpace(fields.WorkflowName)
	if strings.TrimSpace(fields.FilePath) != "" {
		return workflowTargetArgs{}, fmt.Errorf("%s: file_path is not accepted; provide workflowId or workflowName", toolName)
	}
	if fields.WorkflowID == "" && fields.WorkflowName == "" {
		return workflowTargetArgs{}, ErrWorkflowIDRequired
	}
	if fields.WorkflowID != "" && fields.WorkflowName != "" {
		return workflowTargetArgs{}, fmt.Errorf("%s: provide exactly one of workflowId or workflowName", toolName)
	}
	return workflowTargetArgs{WorkflowID: fields.WorkflowID, WorkflowName: fields.WorkflowName}, nil
}
