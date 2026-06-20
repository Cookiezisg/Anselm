// Tests for the MCP-client OAuth 2.1 flow. An httptest.Server plays BOTH the protected resource
// (401 WWW-Authenticate + RFC 9728 metadata) and the authorization server (RFC 8414 metadata + DCR
// + token). Every clock-dependent call takes a fixed `now` so assertions are deterministic.
//
// 本测试用一台 httptest.Server 同时扮演受保护资源与授权服务器；所有时钟相关调用传固定 now、断言确定。
package oauth_test

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	oauth "github.com/sunweilin/anselm/backend/internal/infra/mcp/oauth"
)

// fixedNow is the single deterministic clock used across all token-time assertions.
//
// fixedNow 是所有 token 时间断言共用的确定时钟。
var fixedNow = time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)

// fakeAS captures what a fake authorization+resource server saw, and lets each test tune responses.
//
// fakeAS 记录假授权/资源服务器看到了什么，并让每个测试调节响应。
type fakeAS struct {
	srv *httptest.Server

	// recorded request facts
	registerBody    map[string]any
	tokenForm       url.Values
	tokenAuthHeader string
	prmPaths        []string // every protected-resource-metadata path hit
	asPaths         []string // every authorization-server metadata path hit

	// knobs
	prmJSON        string // body served at the protected-resource-metadata endpoint (path-agnostic)
	registerStatus int
	registerResp   string
	tokenStatus    int
	tokenResp      string
	// asMetaFor maps a well-known request path -> (status, body). Missing path => 404.
	asMetaFor map[string]asMetaReply
}

type asMetaReply struct {
	status int
	body   string
}

func newFakeAS(t *testing.T) *fakeAS {
	t.Helper()
	f := &fakeAS{
		registerStatus: http.StatusCreated,
		tokenStatus:    http.StatusOK,
		asMetaFor:      map[string]asMetaReply{},
	}
	mux := http.NewServeMux()

	// Protected-resource-metadata (RFC 9728). We register the host-root well-known and let the
	// path-aware variant fall through to the same handler via a prefix match.
	prmHandler := func(w http.ResponseWriter, r *http.Request) {
		f.prmPaths = append(f.prmPaths, r.URL.Path)
		if f.prmJSON == "" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		io.WriteString(w, f.prmJSON)
	}
	mux.HandleFunc("/.well-known/oauth-protected-resource", prmHandler)
	mux.HandleFunc("/.well-known/oauth-protected-resource/", prmHandler)

	// Authorization-server metadata (RFC 8414 + OIDC fallback).
	asHandler := func(w http.ResponseWriter, r *http.Request) {
		f.asPaths = append(f.asPaths, r.URL.Path)
		reply, ok := f.asMetaFor[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(reply.status)
		io.WriteString(w, reply.body)
	}
	mux.HandleFunc("/.well-known/oauth-authorization-server", asHandler)
	mux.HandleFunc("/.well-known/oauth-authorization-server/", asHandler)
	mux.HandleFunc("/.well-known/openid-configuration", asHandler)
	mux.HandleFunc("/.well-known/openid-configuration/", asHandler)

	// DCR registration endpoint.
	mux.HandleFunc("/register", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		f.registerBody = map[string]any{}
		_ = json.Unmarshal(body, &f.registerBody)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(f.registerStatus)
		if f.registerResp != "" {
			io.WriteString(w, f.registerResp)
		}
	})

	// Token endpoint.
	mux.HandleFunc("/token", func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		f.tokenForm = r.PostForm
		f.tokenAuthHeader = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(f.tokenStatus)
		if f.tokenResp != "" {
			io.WriteString(w, f.tokenResp)
		}
	})

	f.srv = httptest.NewServer(mux)
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeAS) client() *http.Client { return f.srv.Client() }
func (f *fakeAS) url() string          { return f.srv.URL }

// defaultASMeta wires the standard AS metadata at the host-root oauth-authorization-server path.
//
// defaultASMeta 把标准 AS 元数据挂在 host 根的 oauth-authorization-server 路径。
func (f *fakeAS) defaultASMeta() {
	f.asMetaFor["/.well-known/oauth-authorization-server"] = asMetaReply{
		status: http.StatusOK,
		body: `{
			"issuer": "` + f.url() + `",
			"authorization_endpoint": "` + f.url() + `/authorize",
			"token_endpoint": "` + f.url() + `/token",
			"registration_endpoint": "` + f.url() + `/register",
			"scopes_supported": ["mcp:read", "mcp:write"],
			"code_challenge_methods_supported": ["S256"]
		}`,
	}
}

// defaultPRM advertises this same server as the authorization server.
//
// defaultPRM 把本服务器通告为授权服务器。
func (f *fakeAS) defaultPRM() {
	f.prmJSON = `{"resource": "` + f.url() + `", "authorization_servers": ["` + f.url() + `"]}`
}

// ---------------------------------------------------------------------------
// ResourceMetadataURL
// ---------------------------------------------------------------------------

func TestResourceMetadataURL(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"quoted", `Bearer resource_metadata="https://x/.well-known/oauth-protected-resource"`, "https://x/.well-known/oauth-protected-resource"},
		{"unquoted", `Bearer resource_metadata=https://x/.well-known/oauth-protected-resource`, "https://x/.well-known/oauth-protected-resource"},
		{"absent", `Bearer realm="x", error="invalid_token"`, ""},
		{"empty header", ``, ""},
		{"with other params before", `Bearer realm="mcp", resource_metadata="https://x/prm", error="invalid_token"`, "https://x/prm"},
		{"with other params after quoted", `Bearer resource_metadata="https://x/prm", scope="mcp:read"`, "https://x/prm"},
		// A query-string in the value: the regex stops at the closing quote, so '=' inside is fine.
		{"value with query string", `Bearer resource_metadata="https://x/prm?a=b&c=d"`, "https://x/prm?a=b&c=d"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := oauth.ResourceMetadataURL(tc.in); got != tc.want {
				t.Fatalf("ResourceMetadataURL(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Discover
// ---------------------------------------------------------------------------

func TestDiscover_HappyPath(t *testing.T) {
	f := newFakeAS(t)
	f.defaultPRM()
	f.defaultASMeta()

	meta, err := oauth.Discover(context.Background(), f.client(), f.url(), "")
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if meta.AuthorizationEndpoint != f.url()+"/authorize" {
		t.Errorf("AuthorizationEndpoint = %q", meta.AuthorizationEndpoint)
	}
	if meta.TokenEndpoint != f.url()+"/token" {
		t.Errorf("TokenEndpoint = %q", meta.TokenEndpoint)
	}
	if meta.RegistrationEndpoint != f.url()+"/register" {
		t.Errorf("RegistrationEndpoint = %q", meta.RegistrationEndpoint)
	}
	if meta.Resource != f.url() {
		t.Errorf("Resource = %q, want %q", meta.Resource, f.url())
	}
	if !meta.SupportsDCR() {
		t.Error("SupportsDCR() = false")
	}
	if !meta.SupportsS256() {
		t.Error("SupportsS256() = false")
	}
}

func TestDiscover_PathAwareWellKnown(t *testing.T) {
	f := newFakeAS(t)
	f.defaultPRM()
	f.defaultASMeta()

	// Server URL WITH a path must try /.well-known/oauth-protected-resource/v1/mcp first.
	serverURL := f.url() + "/v1/mcp"
	_, err := oauth.Discover(context.Background(), f.client(), serverURL, "")
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	wantPath := "/.well-known/oauth-protected-resource/v1/mcp"
	found := false
	for _, p := range f.prmPaths {
		if p == wantPath {
			found = true
		}
	}
	if !found {
		t.Errorf("expected a request to %q, saw %v", wantPath, f.prmPaths)
	}
	// And the path-aware form must be tried BEFORE the host-root form.
	if f.prmPaths[0] != wantPath {
		t.Errorf("path-aware form not tried first: %v", f.prmPaths)
	}
}

func TestDiscover_OpenIDConfigurationFallback(t *testing.T) {
	f := newFakeAS(t)
	f.defaultPRM()
	// oauth-authorization-server is NOT registered (404); only openid-configuration is.
	f.asMetaFor["/.well-known/openid-configuration"] = asMetaReply{
		status: http.StatusOK,
		body: `{
			"issuer": "` + f.url() + `",
			"authorization_endpoint": "` + f.url() + `/authorize",
			"token_endpoint": "` + f.url() + `/token",
			"registration_endpoint": "` + f.url() + `/register",
			"code_challenge_methods_supported": ["S256"]
		}`,
	}

	meta, err := oauth.Discover(context.Background(), f.client(), f.url(), "")
	if err != nil {
		t.Fatalf("Discover (openid fallback): %v", err)
	}
	if meta.TokenEndpoint != f.url()+"/token" {
		t.Errorf("TokenEndpoint = %q", meta.TokenEndpoint)
	}
	// oauth-authorization-server must have been tried (and 404'd) before openid-configuration.
	var sawOAuthAS, sawOIDC bool
	for _, p := range f.asPaths {
		if p == "/.well-known/oauth-authorization-server" {
			sawOAuthAS = true
		}
		if p == "/.well-known/openid-configuration" {
			sawOIDC = true
		}
	}
	if !sawOAuthAS || !sawOIDC {
		t.Errorf("expected both AS well-known paths tried, saw %v", f.asPaths)
	}
}

func TestDiscover_PrefersAdvertisedResourceMetaURL(t *testing.T) {
	f := newFakeAS(t)
	f.defaultPRM()
	f.defaultASMeta()

	// Advertise a specific PRM URL; it must be hit FIRST (before any well-known candidate).
	advertised := f.url() + "/.well-known/oauth-protected-resource/custom"
	_, err := oauth.Discover(context.Background(), f.client(), f.url(), advertised)
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if len(f.prmPaths) == 0 || f.prmPaths[0] != "/.well-known/oauth-protected-resource/custom" {
		t.Errorf("advertised PRM URL not preferred first: %v", f.prmPaths)
	}
}

func TestDiscover_ResourceFromPRMPreferredSameHost(t *testing.T) {
	f := newFakeAS(t)
	// A same-host PRM resource (canonicalized, e.g. trailing-slash normalized) IS honored.
	sameHostResource := f.url() + "/mcp"
	f.prmJSON = `{"resource": "` + sameHostResource + `", "authorization_servers": ["` + f.url() + `"]}`
	f.defaultASMeta()

	meta, err := oauth.Discover(context.Background(), f.client(), f.url(), "")
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if meta.Resource != sameHostResource {
		t.Errorf("Resource = %q, want same-host PRM value %q", meta.Resource, sameHostResource)
	}
}

func TestDiscover_CrossHostPRMResourceIgnored(t *testing.T) {
	f := newFakeAS(t)
	// A PRM that points the token audience at a DIFFERENT host must be ignored (audience-redirect
	// defense): Discover binds the resource to our own server URL instead.
	f.prmJSON = `{"resource": "https://evil.example/mcp", "authorization_servers": ["` + f.url() + `"]}`
	f.defaultASMeta()

	meta, err := oauth.Discover(context.Background(), f.client(), f.url(), "")
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if meta.Resource != f.url() {
		t.Errorf("Resource = %q, want canonical server URL %q (cross-host PRM must be ignored)", meta.Resource, f.url())
	}
}

func TestDiscover_ErrNoAuthorizationServers(t *testing.T) {
	f := newFakeAS(t)
	// PRM exists but lists no authorization_servers → fetchProtectedResourceMetadata never accepts it.
	f.prmJSON = `{"resource": "` + f.url() + `", "authorization_servers": []}`

	_, err := oauth.Discover(context.Background(), f.client(), f.url(), "")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, oauth.ErrDiscovery) {
		t.Errorf("error %v not ErrDiscovery", err)
	}
}

func TestDiscover_ErrNoUsableAuthServer(t *testing.T) {
	f := newFakeAS(t)
	// PRM lists an AS, but its metadata is missing/404 everywhere → no usable AS.
	f.prmJSON = `{"resource": "` + f.url() + `", "authorization_servers": ["` + f.url() + `"]}`
	// asMetaFor is empty → every well-known returns 404.

	_, err := oauth.Discover(context.Background(), f.client(), f.url(), "")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, oauth.ErrDiscovery) {
		t.Errorf("error %v not ErrDiscovery", err)
	}
}

func TestDiscover_ErrASMetaMissingEndpoints(t *testing.T) {
	f := newFakeAS(t)
	f.defaultPRM()
	// AS metadata present but missing token_endpoint → rejected, no usable AS.
	f.asMetaFor["/.well-known/oauth-authorization-server"] = asMetaReply{
		status: http.StatusOK,
		body:   `{"issuer": "` + f.url() + `", "authorization_endpoint": "` + f.url() + `/authorize"}`,
	}

	_, err := oauth.Discover(context.Background(), f.client(), f.url(), "")
	if !errors.Is(err, oauth.ErrDiscovery) {
		t.Errorf("error %v not ErrDiscovery", err)
	}
}

// ---------------------------------------------------------------------------
// Register (DCR)
// ---------------------------------------------------------------------------

func TestRegister_HappyPath_201(t *testing.T) {
	f := newFakeAS(t)
	f.registerStatus = http.StatusCreated
	f.registerResp = `{"client_id": "client-abc"}`

	reg, err := oauth.Register(context.Background(), f.client(), f.url()+"/register",
		"Anselm", "http://127.0.0.1:9999/callback", []string{"mcp:read", "mcp:write"})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	if reg.ClientID != "client-abc" {
		t.Errorf("ClientID = %q", reg.ClientID)
	}
	if reg.ClientSecret != "" {
		t.Errorf("ClientSecret = %q, want empty (public client)", reg.ClientSecret)
	}

	// Verify the posted body shape.
	b := f.registerBody
	if b["client_name"] != "Anselm" {
		t.Errorf("client_name = %v", b["client_name"])
	}
	if got := toStrings(b["redirect_uris"]); !equalStrings(got, []string{"http://127.0.0.1:9999/callback"}) {
		t.Errorf("redirect_uris = %v", got)
	}
	if got := toStrings(b["grant_types"]); !equalStrings(got, []string{"authorization_code", "refresh_token"}) {
		t.Errorf("grant_types = %v, want incl refresh_token", got)
	}
	if got := toStrings(b["response_types"]); !equalStrings(got, []string{"code"}) {
		t.Errorf("response_types = %v", got)
	}
	if b["token_endpoint_auth_method"] != "none" {
		t.Errorf("token_endpoint_auth_method = %v, want none", b["token_endpoint_auth_method"])
	}
	if b["scope"] != "mcp:read mcp:write" {
		t.Errorf("scope = %v, want space-joined", b["scope"])
	}
}

func TestRegister_HappyPath_200_WithSecret(t *testing.T) {
	f := newFakeAS(t)
	f.registerStatus = http.StatusOK // 200 also accepted
	f.registerResp = `{"client_id": "client-xyz", "client_secret": "s3cr3t"}`

	reg, err := oauth.Register(context.Background(), f.client(), f.url()+"/register",
		"Anselm", "http://127.0.0.1:9999/callback", nil)
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	if reg.ClientID != "client-xyz" || reg.ClientSecret != "s3cr3t" {
		t.Errorf("reg = %+v", reg)
	}
	// scope omitted when no scopes given.
	if _, ok := f.registerBody["scope"]; ok {
		t.Errorf("scope should be omitted when no scopes, got %v", f.registerBody["scope"])
	}
}

func TestRegister_ErrMissingClientID(t *testing.T) {
	f := newFakeAS(t)
	f.registerStatus = http.StatusCreated
	f.registerResp = `{"client_secret": "only-secret"}` // no client_id

	_, err := oauth.Register(context.Background(), f.client(), f.url()+"/register",
		"Anselm", "http://127.0.0.1:9999/callback", nil)
	if !errors.Is(err, oauth.ErrRegistration) {
		t.Errorf("error %v not ErrRegistration", err)
	}
}

func TestRegister_ErrNon2xx(t *testing.T) {
	f := newFakeAS(t)
	f.registerStatus = http.StatusBadRequest
	f.registerResp = `{"error": "invalid_redirect_uri"}`

	_, err := oauth.Register(context.Background(), f.client(), f.url()+"/register",
		"Anselm", "http://127.0.0.1:9999/callback", nil)
	if !errors.Is(err, oauth.ErrRegistration) {
		t.Errorf("error %v not ErrRegistration", err)
	}
}

// ---------------------------------------------------------------------------
// NewPKCE / NewState
// ---------------------------------------------------------------------------

func TestNewPKCE(t *testing.T) {
	p, err := oauth.NewPKCE()
	if err != nil {
		t.Fatalf("NewPKCE: %v", err)
	}
	if p.Method != "S256" {
		t.Errorf("Method = %q, want S256", p.Method)
	}
	// Challenge == base64url-no-pad(SHA256(Verifier)).
	sum := sha256.Sum256([]byte(p.Verifier))
	want := base64.RawURLEncoding.EncodeToString(sum[:])
	if p.Challenge != want {
		t.Errorf("Challenge = %q, want %q", p.Challenge, want)
	}
	// No base64 padding chars anywhere.
	if strings.ContainsRune(p.Challenge, '=') || strings.ContainsRune(p.Verifier, '=') {
		t.Error("PKCE contains '=' padding")
	}
	// High entropy: two calls differ.
	p2, _ := oauth.NewPKCE()
	if p.Verifier == p2.Verifier {
		t.Error("two NewPKCE Verifiers equal — not random")
	}
	if p.Challenge == p2.Challenge {
		t.Error("two NewPKCE Challenges equal — not random")
	}
	// Verifier must satisfy RFC 7636 length bounds (43..128 chars; 32 raw bytes → 43 chars).
	if len(p.Verifier) < 43 || len(p.Verifier) > 128 {
		t.Errorf("Verifier length %d out of [43,128]", len(p.Verifier))
	}
}

func TestNewState(t *testing.T) {
	s1, err := oauth.NewState()
	if err != nil {
		t.Fatalf("NewState: %v", err)
	}
	if s1 == "" {
		t.Fatal("NewState empty")
	}
	s2, _ := oauth.NewState()
	if s1 == s2 {
		t.Error("two NewState values equal — not random")
	}
	if strings.ContainsRune(s1, '=') {
		t.Error("state contains '=' padding")
	}
}

// ---------------------------------------------------------------------------
// AuthorizeURL
// ---------------------------------------------------------------------------

func TestAuthorizeURL(t *testing.T) {
	meta := &oauth.Metadata{
		AuthorizationEndpoint: "https://as.example/authorize",
		Resource:              "https://mcp.example/v1/mcp",
	}
	pkce := oauth.PKCE{Verifier: "ver", Challenge: "chal", Method: "S256"}
	raw := oauth.AuthorizeURL(meta, "client-1", "http://127.0.0.1:8080/cb", "state-xyz", pkce, []string{"mcp:read", "mcp:write"})

	u, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse AuthorizeURL: %v", err)
	}
	if u.Scheme+"://"+u.Host+u.Path != "https://as.example/authorize" {
		t.Errorf("base = %q", u.Scheme+"://"+u.Host+u.Path)
	}
	q := u.Query()
	checks := map[string]string{
		"response_type":         "code",
		"client_id":             "client-1",
		"redirect_uri":          "http://127.0.0.1:8080/cb",
		"state":                 "state-xyz",
		"code_challenge":        "chal",
		"code_challenge_method": "S256",
		"resource":              "https://mcp.example/v1/mcp",
		"scope":                 "mcp:read mcp:write",
	}
	for k, want := range checks {
		if got := q.Get(k); got != want {
			t.Errorf("query %q = %q, want %q", k, got, want)
		}
	}
}

func TestAuthorizeURL_AppendsWithAmpWhenQueryPresent(t *testing.T) {
	meta := &oauth.Metadata{
		AuthorizationEndpoint: "https://as.example/authorize?foo=bar",
		Resource:              "https://mcp.example",
	}
	pkce := oauth.PKCE{Challenge: "chal", Method: "S256"}
	raw := oauth.AuthorizeURL(meta, "c", "http://cb", "st", pkce, nil)

	if !strings.HasPrefix(raw, "https://as.example/authorize?foo=bar&") {
		t.Errorf("expected '&' separator after existing query, got %q", raw)
	}
	u, _ := url.Parse(raw)
	if u.Query().Get("foo") != "bar" {
		t.Error("existing query param foo=bar lost")
	}
	if u.Query().Get("response_type") != "code" {
		t.Error("response_type not appended")
	}
	// No scope param when scopes empty.
	if _, ok := u.Query()["scope"]; ok {
		t.Error("scope present despite nil scopes")
	}
}

func TestAuthorizeURL_QuestionMarkWhenNoQuery(t *testing.T) {
	meta := &oauth.Metadata{AuthorizationEndpoint: "https://as.example/authorize"}
	pkce := oauth.PKCE{Challenge: "c", Method: "S256"}
	raw := oauth.AuthorizeURL(meta, "c", "http://cb", "st", pkce, nil)
	if !strings.Contains(raw, "/authorize?") || strings.Contains(raw, "/authorize&") {
		t.Errorf("expected '?' separator, got %q", raw)
	}
	// Empty resource → no resource param.
	u, _ := url.Parse(raw)
	if _, ok := u.Query()["resource"]; ok {
		t.Error("resource present despite empty Resource")
	}
}

func TestAuthorizeURL_ValuesAreEncoded(t *testing.T) {
	meta := &oauth.Metadata{
		AuthorizationEndpoint: "https://as.example/authorize",
		Resource:              "https://mcp.example/v1/mcp",
	}
	pkce := oauth.PKCE{Challenge: "a+b/c=", Method: "S256"}
	raw := oauth.AuthorizeURL(meta, "c", "http://127.0.0.1:8080/cb", "st&ate", pkce, []string{"a b"})
	// Raw string must not contain the unencoded reserved chars verbatim in the query.
	if strings.Contains(raw, "st&ate") {
		t.Errorf("state not encoded: %q", raw)
	}
	// And round-trips back to the original values.
	u, _ := url.Parse(raw)
	if u.Query().Get("state") != "st&ate" {
		t.Errorf("state round-trip = %q", u.Query().Get("state"))
	}
	if u.Query().Get("code_challenge") != "a+b/c=" {
		t.Errorf("code_challenge round-trip = %q", u.Query().Get("code_challenge"))
	}
	if u.Query().Get("redirect_uri") != "http://127.0.0.1:8080/cb" {
		t.Errorf("redirect_uri round-trip = %q", u.Query().Get("redirect_uri"))
	}
}

// ---------------------------------------------------------------------------
// Exchange
// ---------------------------------------------------------------------------

func TestExchange_HappyPath(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	f.tokenResp = `{"access_token":"at-1","refresh_token":"rt-1","token_type":"Bearer","expires_in":3600,"scope":"mcp:read"}`

	meta := &oauth.Metadata{TokenEndpoint: f.url() + "/token", Resource: "https://mcp.example/v1/mcp"}
	tok, err := oauth.Exchange(context.Background(), f.client(), meta,
		"client-1", "" /*no secret*/, "auth-code", "http://127.0.0.1:8080/cb", "verifier-1", fixedNow)
	if err != nil {
		t.Fatalf("Exchange: %v", err)
	}
	if tok.AccessToken != "at-1" || tok.RefreshToken != "rt-1" || tok.TokenType != "Bearer" || tok.Scope != "mcp:read" {
		t.Errorf("token = %+v", tok)
	}
	// Absolute Expiry = now + expires_in.
	wantExpiry := fixedNow.Add(3600 * time.Second)
	if !tok.Expiry.Equal(wantExpiry) {
		t.Errorf("Expiry = %v, want %v", tok.Expiry, wantExpiry)
	}

	// Verify the posted form.
	form := f.tokenForm
	want := map[string]string{
		"grant_type":    "authorization_code",
		"code":          "auth-code",
		"redirect_uri":  "http://127.0.0.1:8080/cb",
		"client_id":     "client-1",
		"code_verifier": "verifier-1",
		"resource":      "https://mcp.example/v1/mcp",
	}
	for k, v := range want {
		if form.Get(k) != v {
			t.Errorf("form %q = %q, want %q", k, form.Get(k), v)
		}
	}
	// client_secret must be ABSENT when empty.
	if _, ok := form["client_secret"]; ok {
		t.Errorf("client_secret present despite empty secret: %q", form.Get("client_secret"))
	}
}

func TestExchange_SendsClientSecretWhenSet(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	f.tokenResp = `{"access_token":"at","token_type":"Bearer"}`

	meta := &oauth.Metadata{TokenEndpoint: f.url() + "/token", Resource: "https://mcp.example"}
	_, err := oauth.Exchange(context.Background(), f.client(), meta,
		"client-1", "the-secret", "code", "http://cb", "ver", fixedNow)
	if err != nil {
		t.Fatalf("Exchange: %v", err)
	}
	if f.tokenForm.Get("client_secret") != "the-secret" {
		t.Errorf("client_secret = %q, want the-secret", f.tokenForm.Get("client_secret"))
	}
}

func TestExchange_NoExpiresInLeavesZeroExpiry(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	f.tokenResp = `{"access_token":"at","token_type":"Bearer"}` // no expires_in

	meta := &oauth.Metadata{TokenEndpoint: f.url() + "/token"}
	tok, err := oauth.Exchange(context.Background(), f.client(), meta, "c", "", "code", "http://cb", "ver", fixedNow)
	if err != nil {
		t.Fatalf("Exchange: %v", err)
	}
	if !tok.Expiry.IsZero() {
		t.Errorf("Expiry = %v, want zero when no expires_in", tok.Expiry)
	}
}

func TestExchange_ErrNon200(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusBadRequest
	f.tokenResp = `{"error":"invalid_grant"}`

	meta := &oauth.Metadata{TokenEndpoint: f.url() + "/token"}
	_, err := oauth.Exchange(context.Background(), f.client(), meta, "c", "", "code", "http://cb", "ver", fixedNow)
	if !errors.Is(err, oauth.ErrToken) {
		t.Errorf("error %v not ErrToken", err)
	}
}

func TestExchange_ErrNoAccessToken(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	f.tokenResp = `{"token_type":"Bearer","expires_in":3600}` // no access_token

	meta := &oauth.Metadata{TokenEndpoint: f.url() + "/token"}
	_, err := oauth.Exchange(context.Background(), f.client(), meta, "c", "", "code", "http://cb", "ver", fixedNow)
	if !errors.Is(err, oauth.ErrToken) {
		t.Errorf("error %v not ErrToken", err)
	}
}

func TestExchange_ContentTypeIsFormEncoded(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	f.tokenResp = `{"access_token":"at"}`
	// r.PostForm is only populated by ParseForm for application/x-www-form-urlencoded bodies, so a
	// non-empty PostForm proves the request used the correct Content-Type.
	meta := &oauth.Metadata{TokenEndpoint: f.url() + "/token"}
	_, err := oauth.Exchange(context.Background(), f.client(), meta, "c", "", "code", "http://cb", "ver", fixedNow)
	if err != nil {
		t.Fatalf("Exchange: %v", err)
	}
	if len(f.tokenForm) == 0 {
		t.Error("PostForm empty — body was not application/x-www-form-urlencoded")
	}
}

// ---------------------------------------------------------------------------
// Refresh
// ---------------------------------------------------------------------------

func TestRefresh_KeepsOldRefreshTokenWhenAbsent(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	// No refresh_token in response → keep the old one (no rotation).
	f.tokenResp = `{"access_token":"at-2","token_type":"Bearer","expires_in":1800}`

	tok, err := oauth.Refresh(context.Background(), f.client(), f.url()+"/token",
		"client-1", "" /*no secret*/, "old-rt", "https://mcp.example/v1/mcp", fixedNow)
	if err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if tok.RefreshToken != "old-rt" {
		t.Errorf("RefreshToken = %q, want old-rt (kept)", tok.RefreshToken)
	}
	if tok.AccessToken != "at-2" {
		t.Errorf("AccessToken = %q", tok.AccessToken)
	}
	if !tok.Expiry.Equal(fixedNow.Add(1800 * time.Second)) {
		t.Errorf("Expiry = %v, want recomputed", tok.Expiry)
	}
	// grant_type + resource re-asserted.
	if f.tokenForm.Get("grant_type") != "refresh_token" {
		t.Errorf("grant_type = %q", f.tokenForm.Get("grant_type"))
	}
	if f.tokenForm.Get("refresh_token") != "old-rt" {
		t.Errorf("refresh_token form = %q", f.tokenForm.Get("refresh_token"))
	}
	if f.tokenForm.Get("resource") != "https://mcp.example/v1/mcp" {
		t.Errorf("resource = %q, want re-asserted", f.tokenForm.Get("resource"))
	}
	if _, ok := f.tokenForm["client_secret"]; ok {
		t.Error("client_secret present despite empty secret")
	}
}

func TestRefresh_RotatesRefreshTokenWhenPresent(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	f.tokenResp = `{"access_token":"at-3","refresh_token":"new-rt","token_type":"Bearer","expires_in":900}`

	tok, err := oauth.Refresh(context.Background(), f.client(), f.url()+"/token",
		"client-1", "", "old-rt", "https://mcp.example", fixedNow)
	if err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if tok.RefreshToken != "new-rt" {
		t.Errorf("RefreshToken = %q, want new-rt (rotated)", tok.RefreshToken)
	}
}

func TestRefresh_ErrNon200(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusUnauthorized
	f.tokenResp = `{"error":"invalid_grant"}`

	_, err := oauth.Refresh(context.Background(), f.client(), f.url()+"/token",
		"c", "", "rt", "https://mcp.example", fixedNow)
	if !errors.Is(err, oauth.ErrToken) {
		t.Errorf("error %v not ErrToken", err)
	}
}

func TestRefresh_SendsClientSecretWhenSet(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusOK
	f.tokenResp = `{"access_token":"at"}`

	_, err := oauth.Refresh(context.Background(), f.client(), f.url()+"/token",
		"c", "the-secret", "rt", "https://mcp.example", fixedNow)
	if err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if f.tokenForm.Get("client_secret") != "the-secret" {
		t.Errorf("client_secret = %q", f.tokenForm.Get("client_secret"))
	}
}

// ---------------------------------------------------------------------------
// Token.Expired
// ---------------------------------------------------------------------------

func TestTokenExpired(t *testing.T) {
	skew := 30 * time.Second
	cases := []struct {
		name   string
		expiry time.Time
		want   bool
	}{
		{"zero expiry is never expired", time.Time{}, false},
		{"far future beyond skew", fixedNow.Add(10 * time.Minute), false},
		{"within skew window", fixedNow.Add(15 * time.Second), true},
		{"exactly at skew boundary", fixedNow.Add(30 * time.Second), true}, // !now+skew < expiry → equal counts as expired
		{"already past", fixedNow.Add(-1 * time.Second), true},
		{"just beyond skew", fixedNow.Add(31 * time.Second), false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			tok := &oauth.Token{Expiry: tc.expiry}
			if got := tok.Expired(fixedNow, skew); got != tc.want {
				t.Errorf("Expired(now, %v) with expiry %v = %v, want %v", skew, tc.expiry, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Security: error strings must not echo secrets verbatim beyond the truncated body.
// (Sanity check that postToken's truncation can't leak a long secret in full.)
// ---------------------------------------------------------------------------

func TestPostToken_ErrorTruncatesBody(t *testing.T) {
	f := newFakeAS(t)
	f.tokenStatus = http.StatusBadRequest
	long := strings.Repeat("S", 1000) // a long body simulating a verbose error
	f.tokenResp = `{"error":"` + long + `"}`

	meta := &oauth.Metadata{TokenEndpoint: f.url() + "/token"}
	_, err := oauth.Exchange(context.Background(), f.client(), meta, "c", "", "code", "http://cb", "ver", fixedNow)
	if err == nil {
		t.Fatal("expected error")
	}
	// The error must be truncated (it appends '…' and caps at ~300 chars of body).
	if !strings.Contains(err.Error(), "…") {
		t.Errorf("expected truncated body marker in error, got len %d", len(err.Error()))
	}
	if strings.Count(err.Error(), "S") >= 1000 {
		t.Error("full 1000-char body leaked into error string")
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

func toStrings(v any) []string {
	arr, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(arr))
	for _, e := range arr {
		s, _ := e.(string)
		out = append(out, s)
	}
	return out
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
