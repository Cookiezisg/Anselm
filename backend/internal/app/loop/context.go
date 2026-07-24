package loop

import (
	"context"
	"fmt"
	"strings"
	"unicode/utf8"

	checkpointapp "github.com/sunweilin/anselm/backend/internal/app/contextcheckpoint"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const (
	// Context editing starts before quality degrades near the hard window, then
	// targets a materially smaller prompt so compaction is not repeated every
	// step. The upstream remains the hard-limit authority.
	contextEditRatio   = 0.80
	contextTargetRatio = 0.55

	// Keep the newest complete tool-call groups verbatim during routine edits.
	// Earlier tool outputs are durable/refetchable and become compact markers in
	// the prompt view only.
	hotToolGroups = 3

	// Request-weight deltas are converted to tokens with a deliberately cautious
	// three bytes/token heuristic. This estimate is a compaction trigger only;
	// it never rejects a request.
	estimateBytesPerToken = 3

	// At most two recovery attempts for one provider-confirmed context rejection:
	// semantic checkpoint first, deterministic emergency checkpoint second.
	maxContextRecoveryAttempts = 2
)

// PromptCompactor is an optional Host capability. It turns a long prompt
// history into a structured continuation checkpoint while retaining a recent
// protocol-valid suffix. The full durable block trace is never passed back for
// mutation.
type PromptCompactor interface {
	CompactPrompt(ctx context.Context, history []llminfra.LLMMessage, targetTokens int) ([]llminfra.LLMMessage, error)
}

// ContextObservation is safe operational metadata for one sampling request.
// It contains sizes and decisions, never prompt content.
type ContextObservation struct {
	Step             int
	Attempt          int
	Route            string
	InputBudget      int
	PredictedInput   int
	ActualInput      int
	RequestBytes     int
	SystemBytes      int
	ToolSchemaBytes  int
	HistoryBytes     int
	ClearedToolBytes int
	Compacted        bool
	CompactionMode   string
	Recovery         bool
	Succeeded        bool
	ContextOverflow  bool
}

// ContextObserver is an optional Host capability used by chat to persist the
// last per-request context size separately from the run's aggregate token cost.
type ContextObserver interface {
	ObserveContext(ctx context.Context, observation ContextObservation)
}

// RuntimeBudgetResolver optionally supplies a learned soft budget for this
// concrete outbound route. It is consulted only after the rendered prompt is
// known (text vs multimodal), never used to reject locally, and may return zero
// while an external model is still being learned.
type RuntimeBudgetResolver interface {
	RuntimeInputBudget(ctx context.Context, route string) int
}

type contextTracker struct {
	lastInput  int
	lastWeight int
}

func (t contextTracker) predict(weight int) int {
	if t.lastInput <= 0 || t.lastWeight <= 0 {
		return ceilDiv(weight, estimateBytesPerToken)
	}
	delta := weight - t.lastWeight
	adjustment := delta / estimateBytesPerToken
	if delta > 0 && delta%estimateBytesPerToken != 0 {
		adjustment++
	}
	predicted := t.lastInput + adjustment
	if predicted < 0 {
		return 0
	}
	return predicted
}

func (t *contextTracker) anchor(actual, weight int) {
	if actual > 0 {
		t.lastInput = actual
		t.lastWeight = weight
	}
}

type requestFootprint struct {
	total, system, tools, history int
}

func measureRequest(req llminfra.Request) requestFootprint {
	fp := requestFootprint{system: len(req.System)}
	for _, t := range req.Tools {
		fp.tools += len(t.Name) + len(t.Description) + len(t.Parameters) + 32
	}
	for _, m := range req.Messages {
		fp.history += len(m.Role) + len(m.Content) + len(m.ReasoningContent) + len(m.ReasoningSignature) + 32
		for _, tc := range m.ToolCalls {
			fp.history += len(tc.ID) + len(tc.Name) + len(tc.Arguments) + 24
		}
		for _, p := range m.Parts {
			switch p.Type {
			case llminfra.PartText:
				fp.history += len(p.Text)
			case llminfra.PartImageURL:
				// Transport base64 is not prompt text. A stable modal allowance
				// makes route changes visible to the predictor without pretending
				// to reproduce provider image tokenization.
				fp.history += 2_048 * estimateBytesPerToken
			case llminfra.PartVideoURL:
				fp.history += 16_384 * estimateBytesPerToken
			case llminfra.PartInputAudio, llminfra.PartFile:
				fp.history += 8_192 * estimateBytesPerToken
			}
		}
	}
	fp.total = fp.system + fp.tools + fp.history + 64
	return fp
}

func routeName(req llminfra.Request) string {
	if req.HasNativeMedia() {
		return "multimodal"
	}
	return "text"
}

// clearOldToolResults returns a prompt-only copy where refetchable old tool
// outputs are markers. It preserves every assistant tool-call message and all
// reasoning content, so provider tool protocol remains paired and valid.
func clearOldToolResults(history []llminfra.LLMMessage, keepGroups int, capNewestBytes int) ([]llminfra.LLMMessage, int) {
	protected := make(map[string]struct{})
	groups := 0
	for i := len(history) - 1; i >= 0; i-- {
		m := history[i]
		if m.Role != llminfra.RoleAssistant || len(m.ToolCalls) == 0 {
			continue
		}
		if groups < keepGroups {
			for _, tc := range m.ToolCalls {
				protected[tc.ID] = struct{}{}
			}
		}
		groups++
	}

	var out []llminfra.LLMMessage
	cleared := 0
	for i, m := range history {
		if m.Role != llminfra.RoleTool {
			continue
		}
		_, keep := protected[m.ToolCallID]
		replacement := ""
		switch {
		case !keep && len(m.Content) > 0:
			replacement = fmt.Sprintf("[tool output omitted from prompt view; call_id=%s; %d bytes remain in durable history and can be fetched again]", m.ToolCallID, len(m.Content))
		case keep && capNewestBytes > 0 && len(m.Content) > capNewestBytes:
			replacement = truncateUTF8(m.Content, capNewestBytes) + fmt.Sprintf("\n...[tool output truncated in emergency prompt view; %d total bytes]", len(m.Content))
		}
		if replacement == "" || replacement == m.Content {
			continue
		}
		if out == nil {
			out = append([]llminfra.LLMMessage(nil), history...)
		}
		cleared += len(m.Content) - len(replacement)
		out[i].Content = replacement
	}
	if out == nil {
		return history, 0
	}
	return out, cleared
}

// deterministicCheckpoint is the no-LLM safety net. It is deliberately
// explicit about being lossy and retains concrete tool names/ids/argument
// excerpts so the agent can re-fetch facts instead of fabricating them.
func deterministicCheckpoint(history []llminfra.LLMMessage, targetTokens, keepGroups int) ([]llminfra.LLMMessage, bool) {
	if len(history) < 3 {
		return history, false
	}
	suffixFrom := checkpointSuffixStart(history, keepGroups)
	if suffixFrom <= 0 {
		return history, false
	}

	maxBytes := targetTokens * estimateBytesPerToken / 3
	if maxBytes < 8_000 {
		maxBytes = 8_000
	}
	if maxBytes > 64_000 {
		maxBytes = 64_000
	}

	var b strings.Builder
	b.WriteString("<context_checkpoint kind=\"deterministic-emergency\">\n")
	b.WriteString("Earlier prompt content was compacted to keep the agent running. Re-fetch durable tool results when exact detail is needed; do not invent omitted facts.\n")
	for i := 0; i < suffixFrom && b.Len() < maxBytes; i++ {
		writeMessageExcerpt(&b, history[i], maxBytes-b.Len())
	}
	b.WriteString("</context_checkpoint>")

	out := make([]llminfra.LLMMessage, 0, 1+len(history)-suffixFrom)
	out = append(out, llminfra.LLMMessage{Role: llminfra.RoleUser, Content: b.String()})
	out = append(out, history[suffixFrom:]...)
	return out, true
}

func checkpointSuffixStart(history []llminfra.LLMMessage, keepGroups int) int {
	groups := 0
	for i := len(history) - 1; i >= 0; i-- {
		if history[i].Role == llminfra.RoleAssistant && len(history[i].ToolCalls) > 0 {
			groups++
			if groups == keepGroups {
				return i
			}
		}
	}
	// No long tool chain: retain a small recent conversational suffix.
	if len(history) > 4 {
		start := len(history) - 4
		for start > 0 && history[start].Role == llminfra.RoleTool {
			start--
		}
		return start
	}
	return 0
}

func writeMessageExcerpt(b *strings.Builder, m llminfra.LLMMessage, remaining int) {
	if remaining <= 64 {
		return
	}
	var line strings.Builder
	fmt.Fprintf(&line, "\n[%s]", m.Role)
	if c := strings.TrimSpace(m.Content); c != "" {
		line.WriteByte(' ')
		line.WriteString(c)
	}
	if r := strings.TrimSpace(m.ReasoningContent); r != "" {
		line.WriteString("\nreasoning outcome: ")
		line.WriteString(r)
	}
	for _, tc := range m.ToolCalls {
		fmt.Fprintf(&line, "\ntool_call %s id=%s args=%s", tc.Name, tc.ID, tc.Arguments)
	}
	s := line.String()
	const perMessageCap = 2_000
	if len(s) > perMessageCap {
		s = truncateUTF8(s, perMessageCap) + "…[excerpt truncated]"
	}
	if len(s) > remaining {
		s = truncateUTF8(s, remaining)
	}
	b.WriteString(s)
}

// truncateUTF8 returns a byte-bounded prefix without manufacturing an invalid
// UTF-8 string. Prompt projections eventually cross a JSON boundary; cutting a
// rune would silently replace content there and can corrupt an exact reference.
func truncateUTF8(s string, maxBytes int) string {
	if maxBytes <= 0 {
		return ""
	}
	if len(s) <= maxBytes {
		return s
	}
	end := maxBytes
	for end > 0 && !utf8.RuneStart(s[end]) {
		end--
	}
	return s[:end]
}

func compactPrompt(
	ctx context.Context,
	host Host,
	client llminfra.Client,
	baseReq llminfra.Request,
	history []llminfra.LLMMessage,
	targetTokens int,
	emergency bool,
) ([]llminfra.LLMMessage, bool, string) {
	before := measureHistory(history)
	if compactor, ok := host.(PromptCompactor); ok {
		if compacted, err := compactor.CompactPrompt(ctx, history, targetTokens); err == nil && measureHistory(compacted) < before {
			return compacted, true, "utility_semantic"
		}
	}
	keep := hotToolGroups
	if emergency {
		keep = 1
	}
	if compacted, err := checkpointapp.Compact(ctx, client, baseReq, history, targetTokens, keep); err == nil && measureHistory(compacted) < before {
		return compacted, true, "primary_semantic"
	}
	compacted, changed := deterministicCheckpoint(history, targetTokens, keep)
	if changed {
		return compacted, true, "deterministic_emergency"
	}
	return history, false, ""
}

func measureHistory(history []llminfra.LLMMessage) int {
	return measureRequest(llminfra.Request{Messages: history}).history
}

func ceilDiv(n, d int) int {
	if n <= 0 {
		return 0
	}
	return (n + d - 1) / d
}
