package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func bearerNext() (http.Handler, *bool) {
	called := false
	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	})
	return h, &called
}

func TestRequireBearerToken_emptyIsNoop(t *testing.T) {
	next, called := bearerNext()
	h := RequireBearerToken("")(next)
	r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil) // no Authorization
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if !*called || w.Code != http.StatusOK {
		t.Fatalf("empty token must be a no-op (dev/testend); called=%v code=%d", *called, w.Code)
	}
}

func TestRequireBearerToken_correctPasses(t *testing.T) {
	next, called := bearerNext()
	h := RequireBearerToken("s3cret")(next)
	r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil)
	r.Header.Set("Authorization", "Bearer s3cret")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if !*called {
		t.Fatal("correct bearer token must pass")
	}
}

func TestRequireBearerToken_missingOrWrongRejected(t *testing.T) {
	for _, auth := range []string{"", "Bearer wrong", "s3cret", "Basic s3cret", "Bearer s3cret "} {
		next, called := bearerNext()
		h := RequireBearerToken("s3cret")(next)
		r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil)
		if auth != "" {
			r.Header.Set("Authorization", auth)
		}
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if *called {
			t.Fatalf("auth %q must be rejected", auth)
		}
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("auth %q: want 401, got %d", auth, w.Code)
		}
		if !strings.Contains(w.Body.String(), "UNAUTH_BAD_TOKEN") {
			t.Fatalf("auth %q: want UNAUTH_BAD_TOKEN envelope, got %s", auth, w.Body.String())
		}
	}
}

func TestRequireBearerToken_healthNotExempt(t *testing.T) {
	next, called := bearerNext()
	h := RequireBearerToken("s3cret")(next)
	r := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil) // no token
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if *called || w.Code != http.StatusUnauthorized {
		t.Fatalf("health must require the token; called=%v code=%d", *called, w.Code)
	}
}

func TestRequireBearerToken_optionsExempt(t *testing.T) {
	next, called := bearerNext()
	h := RequireBearerToken("s3cret")(next)
	r := httptest.NewRequest(http.MethodOptions, "/api/v1/functions", nil) // CORS preflight, no auth
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if !*called {
		t.Fatal("OPTIONS preflight must be exempt")
	}
}

func TestRequireBearerToken_webhooksExempt(t *testing.T) {
	next, called := bearerNext()
	h := RequireBearerToken("s3cret")(next)
	r := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/gh/abc123", nil) // external caller, HMAC self-auth
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if !*called {
		t.Fatal("/api/v1/webhooks/ must be exempt (external callers can't know the token)")
	}
}

func TestRequireBearerToken_attachmentPlaybackExempt(t *testing.T) {
	next, called := bearerNext()
	h := RequireBearerToken("s3cret")(next)
	r := httptest.NewRequest(http.MethodGet, "/api/v1/attachment-playback/tok", nil) // native audio stack cannot attach headers
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if !*called {
		t.Fatal("/api/v1/attachment-playback/ must be exempt; the opaque lease token is the credential")
	}
}

// A traversal attempt through the bearerless playback prefix must never reach a protected handler.
// The prefix check sees the RAW path, so the middleware DOES exempt it — the guard is one layer down:
// net/http's ServeMux cleans the path and answers with a redirect instead of routing to the protected
// route, and the clean path the client then re-requests no longer matches the exemption (so it needs
// the bearer). This test pins that chain, because it is the whole reason a PREFIX exemption is safe.
//
// 经 bearerless playback 前缀做路径穿越,绝不能摸到受保护 handler。前缀检查看的是**原始**路径,故中间件
// 确实豁免它——真正的闸在下一层:ServeMux 清理路径后只回重定向、不路由到受保护路由,而客户端改请求的
// 干净路径已不再命中豁免、必须带 bearer。本测试钉死这条链——前缀豁免之所以安全,全靠它。
func TestRequireBearerToken_playbackPrefixTraversalCannotReachProtected(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/attachments/{id}/content", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("SECRET-CONTENT"))
	})
	h := RequireBearerToken("s3cret")(mux)

	r := httptest.NewRequest(http.MethodGet, "/api/v1/attachment-playback/../attachments/att_1/content", nil)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)

	if strings.Contains(w.Body.String(), "SECRET-CONTENT") {
		t.Fatalf("traversal through the playback exemption reached protected content: code=%d body=%q", w.Code, w.Body.String())
	}
}
