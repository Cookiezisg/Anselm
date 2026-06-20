package llm

import (
	"context"
	"errors"
	"fmt"
	"io"
	"iter"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestAnselmProviderIdentity(t *testing.T) {
	p := newAnselmProvider()
	if p.Name() != "anselm" {
		t.Errorf("Name = %q, want anselm", p.Name())
	}
	if p.DefaultBaseURL() != AnselmBaseURL {
		t.Errorf("DefaultBaseURL = %q, want %q", p.DefaultBaseURL(), AnselmBaseURL)
	}
	// Must be registered, else lookupProvider falls back to the openai dialect — whose
	// DescribeModels parses /models with openaiSpecs and would drop deepseek-v4-flash.
	if _, ok := providerRegistry["anselm"]; !ok {
		t.Fatal("anselm not registered in providerRegistry")
	}
}

func TestAnselmBuildRequestInheritsDeepSeek(t *testing.T) {
	// Embed inheritance: BuildRequest is deepseekProvider's, so the gwk_ token rides the Bearer
	// path unchanged and tools are forwarded — the free tier is agentic.
	httpReq, err := newAnselmProvider().BuildRequest(context.Background(), Request{
		ModelID:  "deepseek-v4-flash",
		Key:      "gwk_secret",
		BaseURL:  AnselmBaseURL,
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Tools:    []ToolDef{{Name: "get_weather", Description: "d", Parameters: []byte(`{"type":"object"}`)}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if got := httpReq.URL.String(); got != AnselmBaseURL+"/chat/completions" {
		t.Errorf("url = %s, want %s/chat/completions", got, AnselmBaseURL)
	}
	if got := httpReq.Header.Get("Authorization"); got != "Bearer gwk_secret" {
		t.Errorf("auth = %q, want Bearer gwk_secret", got)
	}
	raw, _ := io.ReadAll(httpReq.Body)
	if !strings.Contains(string(raw), `"get_weather"`) {
		t.Errorf("tools not forwarded in body: %s", raw)
	}
}

func TestAnselmDescribeModels(t *testing.T) {
	// Gateway /models returns ids only; anselmSpecs must yield exactly deepseek-v4-flash,
	// knob-free (the gateway strips thinking/reasoning_effort). Unknown ids are dropped.
	raw := `{"object":"list","data":[{"id":"deepseek-v4-flash","object":"model"},{"id":"gpt-4o"}]}`
	models, err := DescribeModels("anselm", raw) // package-level → exercises registry lookup
	if err != nil {
		t.Fatal(err)
	}
	if len(models) != 1 {
		t.Fatalf("got %d models, want 1: %+v", len(models), models)
	}
	m := models[0]
	if m.ID != "deepseek-v4-flash" {
		t.Errorf("id = %q", m.ID)
	}
	if len(m.Knobs) != 0 {
		t.Errorf("knobs = %+v, want none (gateway strips them)", m.Knobs)
	}
	if m.ContextWindow != 1_000_000 {
		t.Errorf("ctx = %d, want 1000000", m.ContextWindow)
	}
	if m.Vision || m.NativeDocs {
		t.Error("vision/docs should be false")
	}
}

func TestClassifyHTTPError402QuotaExhausted(t *testing.T) {
	err := classifyHTTPError(http.StatusPaymentRequired, []byte("out of budget"))
	if !errors.Is(err, ErrQuotaExhausted) {
		t.Errorf("402 → %v, want ErrQuotaExhausted", err)
	}
	// Distinct Code: must NOT be conflated with ErrRateLimited, or it'd become retryable.
	if errors.Is(err, ErrRateLimited) {
		t.Error("402 must not match ErrRateLimited (distinct Code)")
	}
}

func TestAnselmInStreamBudgetExhausted(t *testing.T) {
	// In-stream error.code BUDGET_EXHAUSTED → ErrQuotaExhausted; any other code → ErrProviderError.
	cases := []struct {
		code   string
		target error
	}{
		{"BUDGET_EXHAUSTED", ErrQuotaExhausted},
		{"UPSTREAM_BUSY", ErrProviderError},
	}
	for _, tc := range cases {
		sse := fmt.Sprintf("data: {\"error\":{\"code\":%q,\"message\":\"x\"}}\n\n", tc.code)
		resp := &http.Response{Body: io.NopCloser(strings.NewReader(sse))}
		events := collect(newAnselmProvider().ParseStream(context.Background(), resp, Request{}))
		var gotErr error
		for _, ev := range events {
			if ev.Type == EventError {
				gotErr = ev.Err
			}
		}
		if gotErr == nil {
			t.Fatalf("code %s: no error event", tc.code)
		}
		if !errors.Is(gotErr, tc.target) {
			t.Errorf("code %s → %v, want Is(%v)", tc.code, gotErr, tc.target)
		}
	}
}

// quotaOnceClient yields one ErrQuotaExhausted error and counts how many times Stream is invoked.
type quotaOnceClient struct{ calls int }

func (c *quotaOnceClient) Stream(ctx context.Context, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		c.calls++
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: depleted", ErrQuotaExhausted)})
	}
}

func TestQuotaExhaustedNotRetried(t *testing.T) {
	// The load-bearing guarantee (critic's concern): a depleted free tier must NOT be retried — a
	// retry just re-hits the same 402 and burns wall-clock. isRetryable is the gate; Generate must
	// call Stream exactly once.
	if isRetryable(fmt.Errorf("%w: x", ErrQuotaExhausted)) {
		t.Fatal("ErrQuotaExhausted must be non-retryable")
	}
	if !isRetryable(fmt.Errorf("%w: x", ErrRateLimited)) {
		t.Fatal("control: ErrRateLimited must stay retryable (else the test proves nothing)")
	}
	c := &quotaOnceClient{}
	_, err := Generate(context.Background(), c, Request{})
	if !errors.Is(err, ErrQuotaExhausted) {
		t.Errorf("err = %v, want ErrQuotaExhausted", err)
	}
	if c.calls != 1 {
		t.Errorf("Stream called %d times, want 1 (no retry on quota)", c.calls)
	}
}

func TestInstallClient(t *testing.T) {
	// Success: token + quota snapshot decoded; the request carries the HASHED fingerprint, the raw
	// machine serial must never leave the device.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/install" {
			t.Errorf("path = %s, want /install", r.URL.Path)
		}
		body, _ := io.ReadAll(r.Body)
		if !strings.Contains(string(body), `"fingerprint":"hashed-fp"`) {
			t.Errorf("request body = %s, want hashed fingerprint", body)
		}
		_, _ = io.WriteString(w, `{"token":"gwk_abc","monthlyQuota":5000,"resetAt":"2026-07-01T00:00:00+08:00"}`)
	}))
	defer srv.Close()

	res, err := NewInstallClient().Install(context.Background(), srv.URL, "hashed-fp", "anselm-test")
	if err != nil {
		t.Fatal(err)
	}
	if res.Token != "gwk_abc" || res.MonthlyQuota != 5000 {
		t.Errorf("result = %+v", res)
	}

	// 402 → ErrQuotaExhausted (mapped through classifyHTTPError, wrapped twice but Is still matches).
	srv402 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusPaymentRequired)
		_, _ = io.WriteString(w, `{"error":{"code":"INSTALL_CAP_REACHED"}}`)
	}))
	defer srv402.Close()
	if _, err := NewInstallClient().Install(context.Background(), srv402.URL, "fp", "c"); !errors.Is(err, ErrQuotaExhausted) {
		t.Errorf("402 install → %v, want ErrQuotaExhausted", err)
	}

	// A 200 with an empty token is not a usable provision → error.
	srvEmpty := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"token":""}`)
	}))
	defer srvEmpty.Close()
	if _, err := NewInstallClient().Install(context.Background(), srvEmpty.URL, "fp", "c"); err == nil {
		t.Error("empty token should error")
	}
}
