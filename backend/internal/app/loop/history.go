package loop

import (
	"encoding/json"
	"fmt"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	mediarefpkg "github.com/sunweilin/anselm/backend/internal/pkg/mediaref"
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

// toolResultMediaIDs collects MediaRef attachment ids from a step's tool_result blocks (JSON
// receipts only — a plain-text result cannot carry the grammar).
//
// toolResultMediaIDs 从一步的 tool_result 块收集 MediaRef 附件 id(仅 JSON receipt——纯文本结果
// 载不动该文法)。
// toolMediaGroup pairs one tool_result's media ids with the tool_call that produced them. Grouping
// is not a nicety: the expansion chokepoint only expands what THIS call minted, so a step with two
// tool calls must ask twice — one flat id list would make each call's provenance check reject the
// other's artifacts.
//
// toolMediaGroup 把一个 tool_result 的媒体 id 与**产出它的那个 tool_call** 配对。分组不是锦上添花:
// 展开咽喉只展开**本次调用自己铸出**的东西,故一步里有两个工具调用时必须问两次——一个拉平的 id 列表会
// 让每个调用的归属检查把**另一个**的产物拒掉。
type toolMediaGroup struct {
	toolCallID string
	ids        []string
}

func toolResultMediaIDs(rBlocks []messagesdomain.Block) []toolMediaGroup {
	var groups []toolMediaGroup
	seen := map[string]bool{}
	for _, b := range rBlocks {
		if b.Type != messagesdomain.BlockTypeToolResult || b.Content == "" {
			continue
		}
		var ids []string
		// A tool_result is NOT necessarily JSON. MCP's is `[image: image/png]\n{"attachmentId":…}`:
		// a placeholder line the SDK renders, a newline, then the receipt the media inlet appended.
		// Gating on "the whole body parses as JSON" dropped that entire family on the floor — the
		// attachment was minted, the receipt was written, and the model still got only the
		// placeholder, which is precisely what 终点验收 ③ forbids. Falling through to the string form
		// lets the collector find receipts embedded in text (the same tolerance prose-written agent
		// answers needed).
		// tool_result **不一定**是 JSON。MCP 的形状是 `[image: image/png]\n{"attachmentId":…}`:SDK 渲的
		// 占位行 + 换行 + 媒体入口追加的 receipt。以「整段能解析成 JSON」为闸,把这一整族直接丢在地上
		// ——附件铸了、receipt 写了,而模型拿到的仍然只有占位符,那正是终点验收 ③ 禁止的东西。落到字符串
		// 形态,收集器就能找到**嵌在文本里**的 receipt(与散文体 agent 终答所需的是同一份容忍)。
		var v any
		if json.Unmarshal([]byte(b.Content), &v) != nil {
			v = b.Content
		}
		// The generation family is EXCLUDED here and only here: this is the tool_result of the step
		// the model just took, so a picture/clip/utterance it ordered was described by its own prompt
		// — re-inlining the bytes buys nothing and costs a multimodal request. Everything else
		// (function artifacts, MCP binaries) is evidence the model has not seen, and still expands.
		// A model that genuinely wants to look at what it made calls `inspect_media` — pull, not push.
		// 生成族**只在这里**被排除:这是模型**刚走那一步**的 tool_result,它点的图/片子/语音,描述就是它
		// 自己写的——把字节再内联回去买不到任何东西,却要付一次多模态请求的钱。其余产地(function 产物、
		// MCP 二进制)是模型**没见过**的证据,照常展开。真想看自己造的东西的模型去调 `inspect_media`
		// ——**拉,不是推**。
		for _, id := range mediarefpkg.CollectExcept(v, mediarefpkg.SelfAuthored) {
			if !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
			if len(ids) >= mediarefpkg.MaxRefs {
				break
			}
		}
		if len(ids) > 0 {
			// ParentBlockID IS the tool_call id (tools.go sets it when it builds the result block).
			// ParentBlockID **就是** tool_call id(tools.go 建结果块时设的)。
			groups = append(groups, toolMediaGroup{toolCallID: b.ParentBlockID, ids: ids})
		}
	}
	return groups
}
