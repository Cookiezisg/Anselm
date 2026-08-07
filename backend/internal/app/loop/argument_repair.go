package loop

import (
	"encoding/json"
	"regexp"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

var authoritativeFlowrunIDPattern = regexp.MustCompile(`\bfr_[A-Za-z0-9]+\b`)
var authoritativeTriggerIDPattern = regexp.MustCompile(`\btrg_[A-Za-z0-9]+\b`)

// normalizeToolCallArguments applies a tool's conservative compatibility repair before the
// assistant blocks enter durable history. The provider wire remains independently observable in
// llmtap; the app-side card and execution describe the arguments that actually ran.
//
// normalizeToolCallArguments 在 assistant block 进入耐久历史前应用工具的保守兼容修复。provider 原始线缆
// 仍由 llmtap 独立观测；app 侧卡片与执行描述的是实际运行的参数。
func normalizeToolCallArguments(
	calls []messagesdomain.ToolCallData,
	blocks []messagesdomain.Block,
	byName map[string]toolapp.Tool,
	evidence []llminfra.LLMMessage,
) ([]messagesdomain.ToolCallData, []messagesdomain.Block, []string) {
	repairs := make(map[string]struct {
		content string
		reason  string
	})
	var repairedTools []string
	authoritativeFlowrunID := latestUnambiguousFlowrunID(evidence)
	authoritativeTriggerID := latestUnambiguousTriggerID(evidence)
	for i := range calls {
		raw, err := json.Marshal(calls[i].Arguments)
		if err != nil {
			continue
		}
		normalized, changed := toolapp.NormalizeArguments(byName[calls[i].Name], raw)
		reason := "provider arguments normalized by tool boundary"
		if calls[i].Name == "get_flowrun" {
			reason = "provider file_path alias normalized to flowrunId"
		}
		if calls[i].Name == "get_flowrun" && authoritativeFlowrunID != "" {
			var fields map[string]any
			if json.Unmarshal(normalized, &fields) == nil && fields != nil {
				if current, _ := fields["flowrunId"].(string); current != authoritativeFlowrunID {
					fields["flowrunId"] = authoritativeFlowrunID
					delete(fields, "file_path")
					if exact, marshalErr := json.Marshal(fields); marshalErr == nil {
						normalized = exact
						changed = true
						reason = "flowrunId restored from one unambiguous user/tool evidence value"
					}
				}
			}
		}
		if calls[i].Name == "get_trigger" && authoritativeTriggerID != "" {
			var fields map[string]any
			if json.Unmarshal(normalized, &fields) == nil && fields != nil {
				current, hasCurrent := fields["triggerId"].(string)
				_, hasAlias := fields["file_path"]
				if (!hasCurrent || current == "") && !hasAlias {
					fields["triggerId"] = authoritativeTriggerID
					if exact, marshalErr := json.Marshal(fields); marshalErr == nil {
						normalized = exact
						changed = true
						reason = "triggerId restored from one unambiguous user/tool evidence value"
					}
				}
			}
		}
		if !changed {
			continue
		}
		var args map[string]any
		if json.Unmarshal(normalized, &args) != nil || args == nil {
			continue
		}
		calls[i].Arguments = args
		repairs[calls[i].ID] = struct {
			content string
			reason  string
		}{content: string(normalized), reason: reason}
		repairedTools = append(repairedTools, calls[i].Name)
	}
	if len(repairs) == 0 {
		return calls, blocks, nil
	}
	for i := range blocks {
		if blocks[i].Type != messagesdomain.BlockTypeToolCall {
			continue
		}
		if repair, ok := repairs[blocks[i].ID]; ok {
			blocks[i].Content = repair.content
			if blocks[i].Attrs == nil {
				blocks[i].Attrs = make(map[string]any)
			}
			blocks[i].Attrs["argumentRepair"] = repair.reason
		}
	}
	return calls, blocks, repairedTools
}

// latestUnambiguousTriggerID returns one exact trigger id from the newest authoritative user/tool
// message. It only repairs an omitted target when the evidence contains exactly one candidate;
// a search result listing several triggers deliberately disables the repair.
//
// latestUnambiguousTriggerID 从最新的权威 user/tool message 取一个精确 trigger ID。只有证据中恰有一个候选
// 时才修复漏传目标；搜索结果列出多个 trigger 时刻意关闭修复。
func latestUnambiguousTriggerID(messages []llminfra.LLMMessage) string {
	for i := len(messages) - 1; i >= 0; i-- {
		message := messages[i]
		if message.Role != llminfra.RoleUser && message.Role != llminfra.RoleTool {
			continue
		}
		candidates := make(map[string]struct{})
		for _, match := range authoritativeTriggerIDPattern.FindAllString(message.Content, -1) {
			candidates[match] = struct{}{}
		}
		for _, part := range message.Parts {
			for _, match := range authoritativeTriggerIDPattern.FindAllString(part.Text, -1) {
				candidates[match] = struct{}{}
			}
		}
		if len(candidates) != 1 {
			if len(candidates) > 1 {
				return ""
			}
			continue
		}
		for id := range candidates {
			return id
		}
	}
	return ""
}

// latestUnambiguousFlowrunID returns one exact run id from the newest authoritative user/tool
// message. It deliberately does not use edit distance, prefixes, or a database lookup: those
// would turn a malformed provider argument into a guessed target. If the newest such message has
// multiple candidates, the repair is disabled for that call.
//
// latestUnambiguousFlowrunID 从最新的权威 user/tool message 取一个精确 run id。刻意不做编辑距离、前缀
// 或数据库查找，否则 malformed provider 参数会变成猜出来的目标；最新消息有多个候选则不修复。
func latestUnambiguousFlowrunID(messages []llminfra.LLMMessage) string {
	for i := len(messages) - 1; i >= 0; i-- {
		message := messages[i]
		if message.Role != llminfra.RoleUser && message.Role != llminfra.RoleTool {
			continue
		}
		candidates := make(map[string]struct{})
		for _, match := range authoritativeFlowrunIDPattern.FindAllString(message.Content, -1) {
			candidates[match] = struct{}{}
		}
		for _, part := range message.Parts {
			for _, match := range authoritativeFlowrunIDPattern.FindAllString(part.Text, -1) {
				candidates[match] = struct{}{}
			}
		}
		if len(candidates) != 1 {
			if len(candidates) > 1 {
				return ""
			}
			continue
		}
		for id := range candidates {
			return id
		}
	}
	return ""
}
