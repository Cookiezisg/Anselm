// Package contextcheckpoint builds protocol-safe continuation checkpoints for
// every ReAct host. It is deliberately independent of chat persistence so chat,
// workflow agents, and subagents can share the same semantic compaction path.
package contextcheckpoint

import (
	"context"
	"fmt"
	"strings"
	"unicode/utf8"

	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const (
	defaultChunkBytes = 80 * 1024
	outputTokens      = 2_000
)

const systemPrompt = `Create a continuation checkpoint for an autonomous agent whose earlier prompt messages will be removed.

Preserve operational truth, not prose. Keep:
- the user's current goal, explicit constraints, success criteria, and preferences;
- completed work and decisions;
- exact file paths, ids, names, commands, numbers, errors, and observed results;
- unresolved questions, todo items, and the immediate next action;
- which large/raw artifacts or tool outputs were omitted and how to re-fetch them.

Never claim omitted detail remains available. Do not invent facts. Preserve an existing checkpoint's facts unless newer evidence supersedes them.
Use compact sections: Goal & constraints; Completed/decisions; Exact references; Errors/observations; Open work/next action.
Output only the full updated checkpoint, under about 1500 tokens.`

// Compact semantically folds a protocol-complete old prefix into one
// continuation checkpoint and retains the newest complete assistant/tool-call
// groups verbatim. It changes only the in-memory prompt projection.
func Compact(
	ctx context.Context,
	client llminfra.Client,
	baseReq llminfra.Request,
	history []llminfra.LLMMessage,
	targetTokens int,
	keepGroups int,
) ([]llminfra.LLMMessage, error) {
	suffixFrom := suffixStart(history, keepGroups)
	if suffixFrom <= 0 {
		return history, nil
	}

	source := renderPrefix(history[:suffixFrom])
	if strings.TrimSpace(source) == "" {
		return history, nil
	}

	// The checkpoint request must itself fit small-window models. At most two
	// bytes of source per target input token leaves room for the running
	// checkpoint and system instruction; large models retain an 80 KiB ceiling
	// so an individual call stays cheap and predictable.
	chunkBytes := defaultChunkBytes
	if targetTokens > 0 && targetTokens*2 < chunkBytes {
		chunkBytes = targetTokens * 2
	}
	if chunkBytes < 8*1024 {
		chunkBytes = 8 * 1024
	}

	chunks := splitUTF8(source, chunkBytes)
	running := ""
	for i, chunk := range chunks {
		req := baseReq
		req.System = systemPrompt
		req.Tools = nil
		req.Messages = []llminfra.LLMMessage{{
			Role: llminfra.RoleUser,
			Content: fmt.Sprintf(
				"CHECKPOINT CHUNK %d/%d\n\nPREVIOUS CHECKPOINT:\n%s\n\nNEW EARLIER TRACE:\n%s",
				i+1, len(chunks), running, chunk,
			),
		}}
		if req.MaxTokens <= 0 || req.MaxTokens > outputTokens {
			req.MaxTokens = outputTokens
		}
		var err error
		running, err = llminfra.Generate(ctx, client, req)
		if err != nil {
			return history, err
		}
		running = clean(running)
		if running == "" {
			return history, nil
		}
	}

	checkpoint := llminfra.LLMMessage{
		Role: llminfra.RoleUser,
		Content: "<context_checkpoint>\n" + running +
			"\n</context_checkpoint>\nContinue the active task from this checkpoint and the recent exact tool trace below.",
	}
	out := make([]llminfra.LLMMessage, 0, 1+len(history)-suffixFrom)
	out = append(out, checkpoint)
	out = append(out, history[suffixFrom:]...)
	return out, nil
}

func suffixStart(history []llminfra.LLMMessage, keepGroups int) int {
	groups := 0
	for i := len(history) - 1; i >= 0; i-- {
		if history[i].Role == llminfra.RoleAssistant && len(history[i].ToolCalls) > 0 {
			groups++
			if groups == keepGroups {
				return i
			}
		}
	}
	if len(history) > 4 {
		start := len(history) - 4
		for start > 0 && history[start].Role == llminfra.RoleTool {
			start--
		}
		return start
	}
	return 0
}

func renderPrefix(history []llminfra.LLMMessage) string {
	var b strings.Builder
	for _, m := range history {
		fmt.Fprintf(&b, "\n[%s]\n", m.Role)
		if m.Content != "" {
			b.WriteString(m.Content)
			b.WriteByte('\n')
		}
		for _, p := range m.Parts {
			switch p.Type {
			case llminfra.PartText:
				b.WriteString(p.Text)
				b.WriteByte('\n')
			default:
				fmt.Fprintf(&b, "[native media %s consumed earlier; raw payload omitted from checkpoint input]\n", p.Type)
			}
		}
		if m.ReasoningContent != "" {
			b.WriteString("reasoning:\n")
			b.WriteString(m.ReasoningContent)
			b.WriteByte('\n')
		}
		for _, tc := range m.ToolCalls {
			fmt.Fprintf(&b, "tool_call name=%s id=%s args=%s\n", tc.Name, tc.ID, tc.Arguments)
		}
		if m.ToolCallID != "" {
			fmt.Fprintf(&b, "tool_call_id=%s\n", m.ToolCallID)
		}
	}
	return b.String()
}

func splitUTF8(s string, maxBytes int) []string {
	if len(s) <= maxBytes {
		return []string{s}
	}
	var out []string
	for len(s) > maxBytes {
		end := maxBytes
		for end > 0 && !utf8.RuneStart(s[end]) {
			end--
		}
		if end == 0 {
			end = maxBytes
		}
		out = append(out, s[:end])
		s = s[end:]
	}
	if s != "" {
		out = append(out, s)
	}
	return out
}

func clean(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "```") {
		if newline := strings.IndexByte(s, '\n'); newline >= 0 {
			s = s[newline+1:]
		} else {
			s = strings.TrimPrefix(s, "```")
		}
	}
	s = strings.TrimSuffix(strings.TrimSpace(s), "```")
	return strings.TrimSpace(s)
}
