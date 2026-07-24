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
	// DescribeModels parses /models with openaiSpecs and would drop anselm-auto.
	if _, ok := providerRegistry["anselm"]; !ok {
		t.Fatal("anselm not registered in providerRegistry")
	}
}

func TestAnselmBuildRequestUsesDeviceIdentity(t *testing.T) {
	// The DeepSeek-compatible body still forwards tools, while auth is the public
	// install id for the proof transport rather than a reusable bearer.
	httpReq, err := newAnselmProvider().BuildRequest(context.Background(), Request{
		ModelID:  AnselmModelID,
		Key:      "ins_test",
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
	if got := httpReq.Header.Get("X-Anselm-Install-ID"); got != "ins_test" {
		t.Errorf("install id = %q, want ins_test", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "" {
		t.Errorf("Authorization must be absent, got %q", got)
	}
	raw, _ := io.ReadAll(httpReq.Body)
	if !strings.Contains(string(raw), `"get_weather"`) {
		t.Errorf("tools not forwarded in body: %s", raw)
	}
}

func TestAnselmBuildRequestCarriesGatewayMultimodalParts(t *testing.T) {
	httpReq, err := newAnselmProvider().BuildRequest(context.Background(), Request{
		ModelID: AnselmModelID, Key: "ins_test", BaseURL: AnselmBaseURL,
		Messages: []LLMMessage{{Role: RoleUser, Parts: []ContentPart{
			{Type: PartText, Text: "review these"},
			{Type: PartImageURL, ImageURL: "data:image/png;base64,IMG"},
			{Type: PartVideoURL, VideoURL: "data:video/mp4;base64,VIDEO"},
			{Type: PartInputAudio, MediaType: "audio/mpeg", Data: "AUDIO"},
		}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(httpReq.Body)
	body := string(raw)
	for _, want := range []string{`"image_url"`, `"video_url"`, `"input_audio"`, `"format":"mp3"`} {
		if !strings.Contains(body, want) {
			t.Errorf("gateway wire missing %q: %s", want, body)
		}
	}
}

func TestAnselmDescribeModels(t *testing.T) {
	// An old gateway body without the extension still gets the route-aware
	// production fallback. Unknown ids are dropped.
	raw := `{"object":"list","data":[{"id":"anselm-auto","object":"model"},{"id":"gpt-4o"}]}`
	models, err := DescribeModels("anselm", raw) // package-level → exercises registry lookup
	if err != nil {
		t.Fatal(err)
	}
	if len(models) != 1 {
		t.Fatalf("got %d models, want 1: %+v", len(models), models)
	}
	m := models[0]
	if m.ID != AnselmModelID {
		t.Errorf("id = %q", m.ID)
	}
	if len(m.Knobs) != 0 {
		t.Errorf("knobs = %+v, want none (gateway strips them)", m.Knobs)
	}
	if m.ContextWindow != 1_000_000 || m.MaxOutput != 16_384 {
		t.Errorf("window/output = %d/%d, want 1000000/16384", m.ContextWindow, m.MaxOutput)
	}
	if m.TextInputLimit != 1_000_000 || m.MultimodalInputLimit != 1_000_000 {
		t.Errorf("route input limits = %d/%d", m.TextInputLimit, m.MultimodalInputLimit)
	}
	if !m.Vision || !m.Video || m.Audio || m.NativeDocs {
		t.Errorf("capabilities = %+v, want image+video only", m)
	}
	if m.MaxMediaParts != 8 || m.MaxMediaBytes != 3*1024*1024 {
		t.Errorf("media envelope = %d/%d, want 8/%d", m.MaxMediaParts, m.MaxMediaBytes, 3*1024*1024)
	}
}

func TestAnselmDescribeModels_UsesLiveRouteProfiles(t *testing.T) {
	raw := `{"object":"list","data":[{"id":"anselm-auto","object":"model","anselm_capabilities":{"version":1,"routing":"content","text":{"input_limit":900000,"output_limit":12000,"available":true},"multimodal":{"input_limit":200000,"output_limit":8000,"available":false}}}]}`
	models, err := DescribeModels("anselm", raw)
	if err != nil || len(models) != 1 {
		t.Fatalf("DescribeModels: models=%+v err=%v", models, err)
	}
	m := models[0]
	if m.ContextWindow != 900_000 || m.MaxOutput != 12_000 ||
		m.TextInputLimit != 900_000 || m.MultimodalInputLimit != 200_000 {
		t.Fatalf("live route profile not applied: %+v", m)
	}
	if m.Vision || m.Video {
		t.Fatalf("unavailable multimodal route was advertised: %+v", m)
	}
}

func TestRequestActiveInputBudgetTracksPromptModality(t *testing.T) {
	req := Request{
		InputBudgetTokens:           100,
		TextInputBudgetTokens:       1_000_000,
		MultimodalInputBudgetTokens: 1_000_000,
		Messages:                    []LLMMessage{{Role: RoleUser, Content: "text only"}},
	}
	if got := req.ActiveInputBudgetTokens(); got != 1_000_000 {
		t.Fatalf("text budget=%d", got)
	}
	req.Messages[0].Parts = []ContentPart{{Type: PartImageURL, ImageURL: "data:image/png;base64,AA=="}}
	if got := req.ActiveInputBudgetTokens(); got != 1_000_000 {
		t.Fatalf("multimodal budget=%d", got)
	}
	req.Messages = []LLMMessage{{Role: RoleUser, Content: "<context_checkpoint>image already summarized</context_checkpoint>"}}
	if got := req.ActiveInputBudgetTokens(); got != 1_000_000 {
		t.Fatalf("post-compaction text budget=%d", got)
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
	// In-stream budget and generic failures retain their distinct taxonomy.
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

func TestAnselmInStreamContextRejectedIsRecoverable(t *testing.T) {
	sse := `data: {"error":{"code":"UPSTREAM_REJECTED","message":"input too large","details":{"reason":"context_length"}}}` + "\n\n"
	resp := &http.Response{Body: io.NopCloser(strings.NewReader(sse))}
	events := collect(newAnselmProvider().ParseStream(context.Background(), resp, Request{}))
	for _, ev := range events {
		if ev.Type == EventError {
			if !IsContextLengthError(ev.Err) {
				t.Fatalf("error=%v, want typed context-length rejection", ev.Err)
			}
			return
		}
	}
	t.Fatal("no error event")
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
		_, _ = io.WriteString(w, `{"installId":"ins_abc","monthlyQuota":5000,"resetAt":"2026-07-01T00:00:00+08:00"}`)
	}))
	defer srv.Close()

	res, err := NewInstallClient(http.DefaultClient, "public-key").Install(context.Background(), srv.URL, "hashed-fp", "anselm-test")
	if err != nil {
		t.Fatal(err)
	}
	if res.InstallID != "ins_abc" || res.MonthlyQuota != 5000 {
		t.Errorf("result = %+v", res)
	}

	// 402 → ErrQuotaExhausted (mapped through classifyHTTPError, wrapped twice but Is still matches).
	srv402 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusPaymentRequired)
		_, _ = io.WriteString(w, `{"error":{"code":"INSTALL_CAP_REACHED"}}`)
	}))
	defer srv402.Close()
	if _, err := NewInstallClient(http.DefaultClient, "public-key").Install(context.Background(), srv402.URL, "fp", "c"); !errors.Is(err, ErrQuotaExhausted) {
		t.Errorf("402 install → %v, want ErrQuotaExhausted", err)
	}

	// A 200 with an empty token is not a usable provision → error.
	srvEmpty := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"installId":""}`)
	}))
	defer srvEmpty.Close()
	if _, err := NewInstallClient(http.DefaultClient, "public-key").Install(context.Background(), srvEmpty.URL, "fp", "c"); err == nil {
		t.Error("empty token should error")
	}
}
