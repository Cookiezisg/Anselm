package llm

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFactoryBuildMockShortCircuits(t *testing.T) {
	f := NewFactory()
	c, _, err := f.Build(Config{Provider: "mock", BaseURL: "x"})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := c.(*MockClient); !ok {
		t.Errorf("mock provider should build a *MockClient, got %T", c)
	}
}

func TestFactoryResolvesDefaultBaseURL(t *testing.T) {
	_, baseURL, err := NewFactory().Build(Config{Provider: "openai"})
	if err != nil {
		t.Fatal(err)
	}
	if baseURL != "https://api.openai.com/v1" {
		t.Errorf("baseURL = %s, want openai default", baseURL)
	}
}

func TestFactoryUnknownProviderFallsBackToOpenAI(t *testing.T) {
	_, baseURL, err := NewFactory().Build(Config{Provider: "totally-unknown"})
	if err != nil {
		t.Fatal(err)
	}
	if baseURL != "https://api.openai.com/v1" {
		t.Errorf("unknown provider fallback baseURL = %s, want openai default", baseURL)
	}
}

func TestFactoryExplicitBaseURLWins(t *testing.T) {
	_, baseURL, _ := NewFactory().Build(Config{Provider: "openai", BaseURL: "https://proxy.local/v1"})
	if baseURL != "https://proxy.local/v1" {
		t.Errorf("baseURL = %s, want explicit", baseURL)
	}
}

// TestProviderClientEndToEnd exercises the full iron-law (build → do → parse) against a
// live httptest SSE server through the openai provider.
//
// TestProviderClientEndToEnd 经 openai provider 对 httptest SSE 服务跑完整铁律（build→do→parse）。
func TestProviderClientEndToEnd(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		io.WriteString(w,
			"data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n"+
				"data: {\"choices\":[{\"finish_reason\":\"stop\"}]}\n\n"+
				"data: [DONE]\n\n")
	}))
	defer srv.Close()

	c, _, _ := NewFactory().Build(Config{Provider: "openai"})
	events := collect(c.Stream(context.Background(), Request{
		BaseURL:  srv.URL,
		Key:      "k",
		ModelID:  "m",
		Messages: []LLMMessage{{Role: RoleUser, Content: "q"}},
	}))
	var text string
	for _, ev := range events {
		if ev.Type == EventError {
			t.Fatalf("unexpected error: %v", ev.Err)
		}
		if ev.Type == EventText {
			text += ev.Delta
		}
	}
	if text != "hi" {
		t.Errorf("text = %q, want hi", text)
	}
}

// TestProviderClientHTTPErrorMapped confirms a non-200 status maps to the sentinel
// (and thus the right HTTP status at transport) end-to-end.
//
// TestProviderClientHTTPErrorMapped 确认非 200 状态端到端映射到 sentinel。
func TestProviderClientHTTPErrorMapped(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		io.WriteString(w, "invalid api key")
	}))
	defer srv.Close()

	c, _, _ := NewFactory().Build(Config{Provider: "openai"})
	events := collect(c.Stream(context.Background(), Request{
		BaseURL:  srv.URL,
		Key:      "bad",
		ModelID:  "m",
		Messages: []LLMMessage{{Role: RoleUser, Content: "q"}},
	}))
	if len(events) != 1 || events[0].Type != EventError || !errors.Is(events[0].Err, ErrAuthFailed) {
		t.Errorf("401 should map to ErrAuthFailed end-to-end: %+v", events)
	}
}
