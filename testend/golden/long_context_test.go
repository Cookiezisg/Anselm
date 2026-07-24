package golden

import (
	"crypto/rand"
	"encoding/hex"
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
	answer, assistant := sayLong(t, wc, conv, prompt, 10*time.Minute)
	if !strings.Contains(answer, sentinel) {
		t.Fatalf("provider accepted the long prompt but did not preserve its sentinel: %q", answer)
	}
	if got := observedPromptTokens(assistant); got >= cfg.minInputTokens {
		t.Logf("long-context admitted: payload_bytes=%d observed_input_tokens=%d", len(prompt), got)
		return
	}
	t.Fatalf("provider never reported >= %d actual input tokens for %d-byte long-context prompt", cfg.minInputTokens, len(prompt))
}

// sayLong is deliberately slower than the normal golden polling helper. The messages endpoint
// returns the full durable content of every message; polling a multi-megabyte user turn every
// 100ms would turn one admission probe into hundreds of megabytes of test traffic. It preserves
// the same terminal-state and interaction behavior while making billable long-context runs
// representative and cheap to observe.
func sayLong(t *testing.T, wc *harness.Client, convID, content string, timeout time.Duration) (string, evalMsg) {
	t.Helper()
	msgID := wc.POST("/api/v1/conversations/"+convID+"/messages", map[string]any{"content": content}).Field(t, "id")
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
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
			return text.String(), m
		}
		time.Sleep(2 * time.Second)
	}
	t.Fatalf("assistant long-context turn did not reach terminal state within %s", timeout)
	return "", evalMsg{} // unreachable; keeps the compiler aware of Fatalf's control flow.
}
