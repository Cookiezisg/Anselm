package golden

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestGolden_L1_ProviderBackedLongContext proves the full path accepts a large
// text prompt and that the provider reports the configured minimum actual input
// tokens. It deliberately has no local-estimator assertion: C1's contract is
// provider-authoritative admission. The sentinel check prevents a successful
// but ignored prompt from passing.
//
// Example (explicitly billable):
// EVALS=1 EVALS_LONG_CONTEXT=1 EVALS_LONG_CONTEXT_BYTES=2400000 \
// EVALS_LONG_CONTEXT_MIN_INPUT_TOKENS=950000 make -C backend evals
func TestGolden_L1_ProviderBackedLongContext(t *testing.T) {
	cfg := requireLongContext(t)
	wc := evalWS(t, "dialogue")
	conv := newConv(t, wc, "golden: provider-backed long context")

	raw := make([]byte, 12)
	if _, err := rand.Read(raw); err != nil {
		t.Fatal(err)
	}
	sentinel := "L1-" + strings.ToUpper(hex.EncodeToString(raw))
	prompt := longContextFixture(cfg.bytes, sentinel) +
		"\nReply with exactly the AUTHORITATIVE_SENTINEL value and nothing else."
	turn := sayLong(t, wc, conv, prompt, 10*time.Minute)
	if !strings.Contains(turn.answer, sentinel) {
		t.Fatalf("provider accepted the long prompt but did not preserve its sentinel: %q", turn.answer)
	}
	if got := observedPromptTokens(turn.assistant); got >= cfg.minInputTokens {
		t.Logf("long-context admitted: payload_bytes=%d observed_input_tokens=%d ttft=%s total=%s", len(prompt), got, turn.ttft, turn.total)
		return
	}
	t.Fatalf("provider never reported >= %d actual input tokens for %d-byte long-context prompt", cfg.minInputTokens, len(prompt))
}

// TestGolden_L2_ProviderBackedLongDialogueLearnsFromNaturalOverflow intentionally lets an unknown
// external route reach its real upstream wall once. The user must never see that recoverable
// rejection: the loop checkpoints and retries the same step, records the verified evidence, and
// the next small turn uses the learned soft budget to make the compaction durable. This is the
// product contract for arbitrary external model keys — no local static-window table is trusted.
// Keep it separately opt-in: it is intentionally a multi-million-token billable evaluation.
//
// Example (explicitly billable):
// EVALS=1 EVALS_NATURAL_OVERFLOW=1 make -C backend evals
func TestGolden_L2_ProviderBackedLongDialogueLearnsFromNaturalOverflow(t *testing.T) {
	cfg := requireLongDialogue(t)
	wc := evalWS(t, "dialogue", "utility")
	conv := newConv(t, wc, "golden: external-model natural overflow")

	anchors := make([]string, 0, cfg.turns)
	peakInput := 0
	naturalRecovery := false
	for i := range cfg.turns {
		anchor := randomLongSentinel(t, "L2")
		anchors = append(anchors, anchor)
		prompt := longDialogueFixture(cfg.bytesPerTurn, anchor, i) +
			"\nReply with exactly the MEMORY_ANCHOR value and nothing else."
		turn := sayLong(t, wc, conv, prompt, 10*time.Minute)
		if !strings.Contains(turn.answer, anchor) {
			t.Fatalf("turn %d lost its current anchor %s: %q", i+1, anchor, turn.answer)
		}
		if got := observedPromptTokens(turn.assistant); got > peakInput {
			peakInput = got
		}
		if recovered := observedContextRecoveries(turn.assistant); recovered > 0 {
			naturalRecovery = true
			t.Logf("natural provider wall recovered: turn=%d overflow_predicted_tokens=%d recoveries=%d", i+1, observedOverflowPrediction(turn.assistant), recovered)
		}
		if turn.assistant.Status == "error" || turn.assistant.ErrorCode != "" {
			t.Fatalf("turn %d exposed a recoverable provider failure: status=%s code=%s", i+1, turn.assistant.Status, turn.assistant.ErrorCode)
		}
		t.Logf("long-dialogue turn=%d payload_bytes=%d observed_input_tokens=%d ttft=%s total=%s", i+1, len(prompt), observedPromptTokens(turn.assistant), turn.ttft, turn.total)
	}
	if !naturalRecovery {
		t.Fatalf("the configured dialogue never reached a recoverable natural provider context wall; increase EVALS_NATURAL_OVERFLOW_BYTES_PER_TURN or _TURNS (peak=%d)", peakInput)
	}

	// This cheap follow-up is intentionally AFTER the recovered turn: it is the first request
	// that can consult the persisted learned profile and turn the in-memory checkpoint into a
	// durable conversation summary/watermark.
	final := sayLong(t, wc, conv,
		"What were the first and most recent MEMORY_ANCHOR values in this conversation? Return both exact values.",
		10*time.Minute)
	compactedSummary := waitForLongSummary(t, wc, conv, anchors[0])
	if !strings.Contains(final.answer, anchors[0]) || !strings.Contains(final.answer, anchors[len(anchors)-1]) {
		t.Fatalf("conversation failed across durable compaction: first=%s last=%s answer=%q summary=%q", anchors[0], anchors[len(anchors)-1], final.answer, compactedSummary)
	}
	t.Logf("long-dialogue compaction survived: peak_input_tokens=%d final_ttft=%s final_total=%s", peakInput, final.ttft, final.total)
}

type longDialogueConfig struct {
	turns              int
	bytesPerTurn       int
	minPeakInputTokens int
}

func requireLongDialogue(t *testing.T) longDialogueConfig {
	t.Helper()
	if os.Getenv("EVALS_NATURAL_OVERFLOW") != "1" {
		t.Skip("set EVALS_NATURAL_OVERFLOW=1 to run the billable natural-overflow golden")
	}
	return longDialogueConfig{
		// Five non-repeating ~560KB turns calibrated to cross the real 1M DeepSeek
		// route. This is a deliberately explicit spend; callers can tune either
		// knob for another provider, but no default suite ever enables it.
		turns:              positiveEnvInt(t, "EVALS_NATURAL_OVERFLOW_TURNS", 5),
		bytesPerTurn:       positiveEnvInt(t, "EVALS_NATURAL_OVERFLOW_BYTES_PER_TURN", 560_000),
		minPeakInputTokens: 0,
	}
}

func observedContextRecoveries(m evalMsg) int { return contextUsageInt(m, "recoveries") }

func observedOverflowPrediction(m evalMsg) int { return contextUsageInt(m, "lastOverflowPredictedInputTokens") }

func contextUsageInt(m evalMsg, key string) int {
	if m.Attrs == nil {
		return 0
	}
	usage, ok := m.Attrs["contextUsage"].(map[string]any)
	if !ok {
		return 0
	}
	switch n := usage[key].(type) {
	case float64:
		return int(n)
	case int:
		return n
	default:
		return 0
	}
}

func waitForLongSummary(t *testing.T, wc *harness.Client, convID, anchor string) string {
	t.Helper()
	deadline := time.Now().Add(2 * time.Minute)
	for time.Now().Before(deadline) {
		var snapshot struct {
			Summary string `json:"summary"`
		}
		wc.GET("/api/v1/conversations/"+convID).OK(t, &snapshot)
		if strings.Contains(snapshot.Summary, anchor) {
			return snapshot.Summary
		}
		time.Sleep(2 * time.Second)
	}
	t.Fatalf("durable semantic compaction did not preserve anchor %s within two minutes", anchor)
	return "" // unreachable
}

func randomLongSentinel(t *testing.T, prefix string) string {
	t.Helper()
	raw := make([]byte, 12)
	if _, err := rand.Read(raw); err != nil {
		t.Fatal(err)
	}
	return prefix + "-" + strings.ToUpper(hex.EncodeToString(raw))
}

func longDialogueFixture(bytes int, anchor string, segment int) string {
	var b strings.Builder
	b.Grow(bytes + len(anchor) + 256)
	// The summary pipeline purposefully reads a bounded prefix of huge blocks. Put the exact
	// fact at the front so this probes semantic preservation rather than a suffix artifact.
	b.WriteString("MEMORY_ANCHOR=")
	b.WriteString(anchor)
	b.WriteString("\nThis is long dialogue evidence. Preserve the anchor exactly.\n")
	for i := 0; b.Len() < bytes; i++ {
		// Both record and segment vary, preventing provider-side repetition compression from
		// turning four nominally large turns into a deceptively small prompt.
		fmt.Fprintf(&b, "segment=%08x record=%08x category=%08x payload=anselm-dialogue-evidence-%08x\n", segment, i, (i+segment)*2654435761, i^segment^0x5a5a5a5a)
	}
	b.WriteString("\nMEMORY_ANCHOR=")
	b.WriteString(anchor)
	b.WriteByte('\n')
	return b.String()
}

// sayLong is deliberately slower than the normal golden polling helper. The messages endpoint
// returns the full durable content of every message; polling a multi-megabyte user turn every
// 100ms would turn one admission probe into hundreds of megabytes of test traffic. It preserves
// the same terminal-state and interaction behavior while making billable long-context runs
// representative and cheap to observe.
type longTurn struct {
	answer    string
	assistant evalMsg
	ttft      time.Duration
	total     time.Duration
}

func sayLong(t *testing.T, wc *harness.Client, convID, content string, timeout time.Duration) longTurn {
	t.Helper()
	stream := wc.Subscribe(t, "messages")
	started := time.Now()
	msgID := wc.POST("/api/v1/conversations/"+convID+"/messages", map[string]any{"content": content}).Field(t, "id")
	deadline := time.Now().Add(timeout)
	nextHistoryPoll := time.Time{}
	nextEvent := 0
	var firstDelta time.Duration
	for time.Now().Before(deadline) {
		terminalFrame := false
		events := stream.Snapshot()
		for ; nextEvent < len(events); nextEvent++ {
			raw := string(events[nextEvent].Data)
			if firstDelta == 0 && strings.Contains(raw, `"kind":"delta"`) {
				firstDelta = time.Since(started)
			}
			if strings.Contains(raw, `"id":"`+msgID+`"`) && strings.Contains(raw, `"kind":"close"`) {
				terminalFrame = true
			}
		}
		now := time.Now()
		if terminalFrame || !now.Before(nextHistoryPoll) {
			drainInteractions(wc, convID)
			var msgs []evalMsg
			wc.GET("/api/v1/conversations/"+convID+"/messages?limit=80").OK(t, &msgs)
			for _, m := range msgs {
				if m.ID != msgID {
					continue
				}
				if m.Status == "pending" || m.Status == "streaming" {
					break
				}
				var text strings.Builder
				for _, blk := range m.Blocks {
					if blk.Type == "text" {
						text.WriteString(blk.Content)
					}
				}
				if firstDelta == 0 {
					firstDelta = time.Since(started)
				}
				return longTurn{answer: text.String(), assistant: m, ttft: firstDelta, total: time.Since(started)}
			}
			nextHistoryPoll = now.Add(2 * time.Second)
		}
		time.Sleep(25 * time.Millisecond)
	}
	t.Fatalf("assistant long-context turn did not reach terminal state within %s", timeout)
	return longTurn{} // unreachable; keeps the compiler aware of Fatalf's control flow.
}
