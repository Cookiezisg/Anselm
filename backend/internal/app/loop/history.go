// history.go — In-loop history extension. extendHistory is called after each
// tool-calling step. BlocksToAssistantLLM is exported so callers building
// historical history (e.g. chat.buildHistory loading from DB) reuse the same
// converter — there's only one source of truth for blocks → LLM wire shape.
//
// history.go — 循环内历史扩展。extendHistory 在每个工具调用步骤后调用。
// BlocksToAssistantLLM 导出，让构建历史的调用方（如 chat.buildHistory 从 DB
// 加载）复用同一个转换器——blocks → LLM wire 形状只有一个事实源。
package loop

import (
	"encoding/json"
	"fmt"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// extendHistory appends one ReAct step's contribution (assistant blocks +
// tool result blocks) to the running history.
//
// extendHistory 把一个 ReAct 步骤的贡献（assistant blocks + tool result blocks）
// 追加到运行中的历史。
func extendHistory(history []llminfra.LLMMessage, aBlocks, rBlocks []chatdomain.Block) ([]llminfra.LLMMessage, error) {
	msgs, err := BlocksToAssistantLLM(append(aBlocks, rBlocks...))
	if err != nil {
		return nil, err
	}
	return append(history, msgs...), nil
}

// BlocksToAssistantLLM converts an assistant turn's blocks into LLM wire
// messages. A turn with tool calls expands to:
//
//	[assistant{text, reasoning, toolCalls}] + [N × role=tool messages]
//
// Used by both extendHistory (in-loop accumulation) and chat.buildHistory
// (DB-loaded historical messages) — single source of truth for the
// conversion.
//
// BlocksToAssistantLLM 把 assistant 回合的 blocks 转为 LLM 协议消息。
// 含工具调用的回合展开为：
//
//	[assistant{text, reasoning, toolCalls}] + [N 条 role=tool 消息]
//
// extendHistory（循环内累积）与 chat.buildHistory（从 DB 加载历史消息）共用
// ——转换器只有一个事实源。
func BlocksToAssistantLLM(blocks []chatdomain.Block) ([]llminfra.LLMMessage, error) {
	assistant := llminfra.LLMMessage{Role: llminfra.RoleAssistant}
	var toolResults []llminfra.LLMMessage

	for _, b := range blocks {
		switch b.Type {
		case chatdomain.BlockTypeReasoning:
			var d chatdomain.TextData
			if err := json.Unmarshal([]byte(b.Data), &d); err != nil {
				return nil, fmt.Errorf("loop.BlocksToAssistantLLM: reasoning block %q: %w", b.ID, err)
			}
			assistant.ReasoningContent = d.Text

		case chatdomain.BlockTypeText:
			var d chatdomain.TextData
			if err := json.Unmarshal([]byte(b.Data), &d); err != nil {
				return nil, fmt.Errorf("loop.BlocksToAssistantLLM: text block %q: %w", b.ID, err)
			}
			assistant.Content = d.Text

		case chatdomain.BlockTypeToolCall:
			var d chatdomain.ToolCallData
			if err := json.Unmarshal([]byte(b.Data), &d); err != nil {
				return nil, fmt.Errorf("loop.BlocksToAssistantLLM: tool_call block %q: %w", b.ID, err)
			}
			argsJSON, _ := json.Marshal(d.Arguments)
			assistant.ToolCalls = append(assistant.ToolCalls, llminfra.LLMToolCall{
				ID: d.ID, Name: d.Name, Arguments: string(argsJSON),
			})

		case chatdomain.BlockTypeToolResult:
			var d chatdomain.ToolResultData
			if err := json.Unmarshal([]byte(b.Data), &d); err != nil {
				return nil, fmt.Errorf("loop.BlocksToAssistantLLM: tool_result block %q: %w", b.ID, err)
			}
			toolResults = append(toolResults, llminfra.LLMMessage{
				Role: llminfra.RoleTool, Content: d.Result, ToolCallID: d.ToolCallID,
			})
		}
	}
	return append([]llminfra.LLMMessage{assistant}, toolResults...), nil
}

// ExtractTextContent returns the last text block's content from a block slice.
// Used by callers (chat for auto-titling; subagent as the tool_result string
// returned to the parent LLM).
//
// ExtractTextContent 从 block 列表返回最后一个 text block 的内容。供调用方
// 使用（chat 用作自动命名素材；subagent 用作返主 LLM 的 tool_result）。
func ExtractTextContent(blocks []chatdomain.Block) string {
	var last string
	for _, b := range blocks {
		if b.Type == chatdomain.BlockTypeText {
			var d chatdomain.TextData
			if json.Unmarshal([]byte(b.Data), &d) == nil {
				last = d.Text
			}
		}
	}
	return last
}
