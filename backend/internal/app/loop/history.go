package loop

import (
	"fmt"

	messagesdomain "github.com/sunweilin/foryx/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/foryx/backend/internal/infra/llm"
)

// warmPreviewBytes caps a warm-projected tool_result's inline length before truncation.
//
// warmPreviewBytes 限定 warm 投影的 tool_result 内联长度上限，超出即截断。
const warmPreviewBytes = 200

// extendHistory appends one ReAct step (assistant blocks + tool results) to running history.
//
// extendHistory 把一个 ReAct 步骤（assistant + tool result）追加到运行历史。
func extendHistory(history []llminfra.LLMMessage, aBlocks, rBlocks []messagesdomain.Block) []llminfra.LLMMessage {
	return append(history, BlocksToAssistantLLM(append(aBlocks, rBlocks...))...)
}

// BlocksToAssistantLLM converts an assistant turn's blocks to [assistant + N×tool] LLM
// messages. A pure transform: archived + compaction blocks drop (their content already
// lives in conversation.summary), so it never fails — no error to return.
//
// BlocksToAssistantLLM 把 assistant 回合的 blocks 转为 [assistant + N×tool] LLM 消息。纯转换：
// archived + compaction 块丢弃（内容已在 conversation.summary），故永不失败——无 error 可返。
func BlocksToAssistantLLM(blocks []messagesdomain.Block) []llminfra.LLMMessage {
	assistant := llminfra.LLMMessage{Role: llminfra.RoleAssistant}
	var toolResults []llminfra.LLMMessage

	for _, b := range blocks {
		if b.ContextRole == messagesdomain.ContextRoleArchived || b.Type == messagesdomain.BlockTypeCompaction {
			continue
		}
		switch b.Type {
		case messagesdomain.BlockTypeReasoning:
			assistant.ReasoningContent = b.Content
			if b.Attrs != nil {
				if sig, ok := b.Attrs["signature"].(string); ok {
					assistant.ReasoningSignature = sig
				}
			}

		case messagesdomain.BlockTypeText:
			assistant.Content = b.Content

		case messagesdomain.BlockTypeToolCall:
			assistant.ToolCalls = append(assistant.ToolCalls, llminfra.LLMToolCall{
				ID: b.ID, Name: blockToolName(b), Arguments: b.Content,
			})

		case messagesdomain.BlockTypeToolResult:
			toolResults = append(toolResults, llminfra.LLMMessage{
				Role: llminfra.RoleTool, Content: projectToolResultContent(b), ToolCallID: b.ParentBlockID,
			})
		}
	}

	return append([]llminfra.LLMMessage{assistant}, toolResults...)
}

// projectToolResultContent renders tool_result per ContextRole (hot full / warm preview /
// cold omitted-with-marker). The stored Content is never rewritten — this only shapes how
// the block reaches LLM history.
//
// projectToolResultContent 按 ContextRole 渲染 tool_result（hot 全文 / warm 预览 / cold 省略
// 带标记）。落库 Content 永不改写——这里只塑形 block 如何进入 LLM 历史。
func projectToolResultContent(b messagesdomain.Block) string {
	content := b.Content
	if content == "" && b.Error != "" {
		content = b.Error
	}
	switch b.ContextRole {
	case messagesdomain.ContextRoleWarm:
		if len(content) > warmPreviewBytes {
			return content[:warmPreviewBytes] + fmt.Sprintf("\n...[truncated, %d total bytes]", len(content))
		}
		return content
	case messagesdomain.ContextRoleCold:
		if name := blockToolName(b); name != "" {
			return fmt.Sprintf("[%s output omitted to save context (%d bytes)]", name, len(b.Content))
		}
		return fmt.Sprintf("[tool_result omitted to save context (%d bytes)]", len(b.Content))
	default:
		return content
	}
}

// blockToolName reads the tool name a tool_call / tool_result block carries in Attrs["tool"].
//
// blockToolName 读 tool_call / tool_result 块在 Attrs["tool"] 里携带的工具名。
func blockToolName(b messagesdomain.Block) string {
	if b.Attrs != nil {
		if v, ok := b.Attrs["tool"].(string); ok {
			return v
		}
	}
	return ""
}

// ExtractTextContent returns the last text block's content (used by autoTitle / subagent
// tool_result, where an agent run's final answer is its last text block).
//
// ExtractTextContent 返回最后一个 text block 的内容（供 autoTitle / subagent tool_result 用，
// agent run 的最终答复即其最后一个 text block）。
func ExtractTextContent(blocks []messagesdomain.Block) string {
	var last string
	for _, b := range blocks {
		if b.Type == messagesdomain.BlockTypeText {
			last = b.Content
		}
	}
	return last
}
