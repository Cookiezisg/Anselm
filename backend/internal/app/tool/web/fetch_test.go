package web

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	workspacedomain "github.com/sunweilin/anselm/backend/internal/domain/workspace"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// fakePicker implements modeldomain.ModelPicker.
type fakePicker struct {
	ref modeldomain.ModelRef
	err error
}

func (f *fakePicker) Pick(_ context.Context, _ string) (modeldomain.ModelRef, error) {
	return f.ref, f.err
}

// fixedMode implements FetchModePicker with a constant mode.
type fixedMode string

func (m fixedMode) WebFetchMode(context.Context) string { return string(m) }

func TestWebFetch_ValidateInput(t *testing.T) {
	wf := &WebFetch{}
	cases := []struct {
		json string
		want error
	}{
		{`{"url":"","prompt":"p"}`, ErrEmptyURL},
		{`{"url":"http://x","prompt":""}`, ErrEmptyPrompt},
		{`{"url":"ftp://x","prompt":"p"}`, ErrUnsupportedScheme},
		{`{"url":"http://x","prompt":"p"}`, nil},
	}
	for _, c := range cases {
		if got := wf.ValidateInput([]byte(c.json)); !errors.Is(got, c.want) {
			t.Fatalf("ValidateInput(%s) = %v, want %v", c.json, got, c.want)
		}
	}
}

func TestGuardHostname(t *testing.T) {
	reject := []string{"", "localhost", "127.0.0.1", "192.168.0.1", "10.0.0.1", "169.254.1.1"}
	for _, h := range reject {
		if guardHostname(h) == "" {
			t.Fatalf("guardHostname(%q) should reject", h)
		}
	}
	if r := guardHostname("8.8.8.8"); r != "" {
		t.Fatalf("guardHostname(8.8.8.8) public should pass, got %q", r)
	}
}

func TestClassifyIP(t *testing.T) {
	cases := map[string]bool{ // ip → should reject
		"127.0.0.1":     true,
		"192.168.1.1":   true,
		"10.0.0.1":      true,
		"169.254.1.1":   true,
		"0.0.0.0":       true,
		"224.0.0.1":     true,
		"8.8.8.8":       false,
		"93.184.216.34": false,
	}
	for ipStr, want := range cases {
		got := classifyIP(net.ParseIP(ipStr)) != ""
		if got != want {
			t.Fatalf("classifyIP(%s) reject=%v, want %v", ipStr, got, want)
		}
	}
}

func TestWebFetch_Execute_SSRFBlocked(t *testing.T) {
	wf := &WebFetch{} // SSRF guard fires before any fetch/LLM, so deps can be nil
	for _, u := range []string{"http://localhost/", "http://127.0.0.1/", "http://192.168.1.1/", "http://169.254.1.1/"} {
		out, err := wf.Execute(context.Background(), `{"url":"`+u+`","prompt":"x"}`)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(out, "Refusing") && !strings.Contains(out, "loopback") {
			t.Fatalf("%s not SSRF-blocked: %q", u, out)
		}
	}
}

func TestWebFetch_Execute_Summarises(t *testing.T) {
	// Mock Jina reader; any path returns canned page content.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("the page content"))
	}))
	defer srv.Close()
	old := jinaEndpoint
	jinaEndpoint = srv.URL + "/"
	defer func() { jinaEndpoint = old }()

	// provider "mock" → factory.Build short-circuits to the MockClient.
	factory := llminfra.NewFactory()
	factory.Mock().PushScript(llminfra.MockScript{
		Events: []llminfra.StreamEvent{{Type: llminfra.EventText, Delta: "SUMMARY"}},
	})

	wf := &WebFetch{
		picker:  &fakePicker{ref: modeldomain.ModelRef{APIKeyID: "ak", ModelID: "m"}},
		keys:    &fakeKeys{creds: apikeydomain.Credentials{Provider: "mock"}},
		factory: factory,
		mode:    fixedMode(workspacedomain.WebFetchModeJina),
	}
	// Public IP host → SSRF guard passes without DNS; fetch routes through the mock Jina.
	out, err := wf.Execute(context.Background(), `{"url":"http://93.184.216.34/","prompt":"what"}`)
	if err != nil {
		t.Fatal(err)
	}
	if out != "SUMMARY" {
		t.Fatalf("Execute = %q, want SUMMARY", out)
	}
}

func TestWebFetch_Execute_SummariseFailDegrades(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("raw page body here"))
	}))
	defer srv.Close()
	old := jinaEndpoint
	jinaEndpoint = srv.URL + "/"
	defer func() { jinaEndpoint = old }()

	// picker errors (e.g. utility model not configured) → summarise fails → degrade to raw content.
	wf := &WebFetch{
		picker:  &fakePicker{err: modeldomain.ErrNotConfigured},
		keys:    &fakeKeys{},
		factory: llminfra.NewFactory(),
		mode:    fixedMode(workspacedomain.WebFetchModeJina),
	}
	out, err := wf.Execute(context.Background(), `{"url":"http://93.184.216.34/","prompt":"what"}`)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "raw page body") || !strings.Contains(out, "Summarisation unavailable") {
		t.Fatalf("expected degraded raw content, got %q", out)
	}
}

// Local mode must never touch the Jina endpoint — the URL stays on this machine.
//
// local 模式绝不能碰 Jina 端点——URL 不出本机。
func TestWebFetch_FetchMode_LocalSkipsJina(t *testing.T) {
	jinaHits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		jinaHits++
		_, _ = w.Write([]byte("jina content"))
	}))
	defer srv.Close()
	old := jinaEndpoint
	jinaEndpoint = srv.URL + "/"
	defer func() { jinaEndpoint = old }()

	oldDirect := fetchDirectFn
	fetchDirectFn = func(context.Context, string) (string, error) { return "direct content", nil }
	defer func() { fetchDirectFn = oldDirect }()

	wf := &WebFetch{
		picker:  &fakePicker{err: modeldomain.ErrNotConfigured}, // summarise degrades → raw content visible
		keys:    &fakeKeys{},
		factory: llminfra.NewFactory(),
		mode:    fixedMode(workspacedomain.WebFetchModeLocal),
	}
	out, err := wf.Execute(context.Background(), `{"url":"http://93.184.216.34/","prompt":"what"}`)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "direct content") {
		t.Fatalf("local mode must use direct GET, got %q", out)
	}
	if jinaHits != 0 {
		t.Fatalf("local mode leaked the URL to Jina (%d hit(s))", jinaHits)
	}
}

// nil picker (no workspace service wired) fails closed to local.
//
// picker 为 nil（未接 workspace 服务）时收敛到 local。
func TestWebFetch_FetchMode_NilPickerDefaultsLocal(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		t.Error("nil mode picker must not reach Jina")
	}))
	defer srv.Close()
	old := jinaEndpoint
	jinaEndpoint = srv.URL + "/"
	defer func() { jinaEndpoint = old }()

	oldDirect := fetchDirectFn
	fetchDirectFn = func(context.Context, string) (string, error) { return "direct content", nil }
	defer func() { fetchDirectFn = oldDirect }()

	wf := &WebFetch{picker: &fakePicker{err: modeldomain.ErrNotConfigured}, keys: &fakeKeys{}, factory: llminfra.NewFactory()}
	out, err := wf.Execute(context.Background(), `{"url":"http://93.184.216.34/","prompt":"what"}`)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "direct content") {
		t.Fatalf("nil picker must default to direct GET, got %q", out)
	}
}

// jina mode falls back to direct GET when the reader fails.
//
// jina 模式在 reader 失败时回退直 GET。
func TestWebFetch_FetchMode_JinaFallsBackToDirect(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer srv.Close()
	old := jinaEndpoint
	jinaEndpoint = srv.URL + "/"
	defer func() { jinaEndpoint = old }()

	oldDirect := fetchDirectFn
	fetchDirectFn = func(context.Context, string) (string, error) { return "direct content", nil }
	defer func() { fetchDirectFn = oldDirect }()

	wf := &WebFetch{
		picker:  &fakePicker{err: modeldomain.ErrNotConfigured},
		keys:    &fakeKeys{},
		factory: llminfra.NewFactory(),
		mode:    fixedMode(workspacedomain.WebFetchModeJina),
	}
	out, err := wf.Execute(context.Background(), `{"url":"http://93.184.216.34/","prompt":"what"}`)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "direct content") {
		t.Fatalf("jina mode must fall back to direct GET, got %q", out)
	}
}
