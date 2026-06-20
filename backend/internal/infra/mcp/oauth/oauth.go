// Package oauth implements the MCP client side of OAuth 2.1 for remote MCP servers: the full
// discovery → dynamic client registration → PKCE authorization-code → token exchange/refresh
// chain, with NO vendor pre-registration (DCR registers the client at runtime) and NO client
// secret (public client + PKCE). It is pure protocol — net/http + crypto only, no app/domain
// deps — so each RFC step is unit-testable against an httptest fake authorization server.
//
// Package oauth 实现 remote MCP server 的客户端侧 OAuth 2.1：发现 → 动态客户端注册 → PKCE 授权码 →
// token 交换/刷新 全链，**无厂商预注册**（DCR 运行时注册客户端）、**无 client secret**（公共客户端 + PKCE）。
// 纯协议——只用 net/http + crypto、无 app/domain 依赖——故每个 RFC 步骤都能对 httptest 假授权服务器单测。
package oauth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
)

// Protocol sentinels reuse the centralized mcp domain dictionary (S20) so the app layer surfaces a
// stable wire code; the oauth package adds no codes of its own.
//
// 协议 sentinel 复用集中的 mcp domain 字典（S20），使 app 层透出稳定 wire code；oauth 包不自造码。
var (
	ErrDiscovery    = mcpdomain.ErrOAuthDiscovery
	ErrRegistration = mcpdomain.ErrOAuthRegistration
	ErrToken        = mcpdomain.ErrOAuthToken
)

// httpDo is the minimal HTTP surface the flow needs — an *http.Client satisfies it; tests inject
// a client pointed at an httptest server.
//
// httpDo 是流程需要的最小 HTTP 面——*http.Client 满足之；测试注入指向 httptest server 的 client。
type httpDo interface {
	Do(*http.Request) (*http.Response, error)
}

// Metadata is the resolved discovery result: where to register, authorize, and exchange tokens
// for one protected MCP server.
//
// Metadata 是发现链解析结果：某个受保护 MCP server 去哪注册、授权、换 token。
type Metadata struct {
	Issuer                string
	AuthorizationEndpoint string
	TokenEndpoint         string
	RegistrationEndpoint  string // empty → server's AS does not support DCR
	ScopesSupported       []string
	CodeChallengeMethods  []string
	Resource              string // the protected resource (the MCP server canonical URL) for RFC 8707
}

// SupportsDCR reports whether the authorization server advertises a registration endpoint —
// the precondition for our no-vendor-step flow.
//
// SupportsDCR 报告授权服务器是否通告注册端点——我们无厂商步骤流程的前提。
func (m *Metadata) SupportsDCR() bool { return m.RegistrationEndpoint != "" }

// SupportsS256 reports whether the AS accepts PKCE S256 (OAuth 2.1 requires it; absence of the
// field is treated as supported per RFC 8414 since plain is forbidden in 2.1).
//
// SupportsS256 报告 AS 是否接受 PKCE S256（OAuth 2.1 要求之；字段缺失按支持处理，因 2.1 禁 plain）。
func (m *Metadata) SupportsS256() bool {
	if len(m.CodeChallengeMethods) == 0 {
		return true
	}
	for _, c := range m.CodeChallengeMethods {
		if c == "S256" {
			return true
		}
	}
	return false
}

var resourceMetadataRe = regexp.MustCompile(`resource_metadata="?([^",\s]+)`)

// ResourceMetadataURL extracts the protected-resource-metadata URL a server advertises in its
// 401 WWW-Authenticate header (RFC 9728 §5.1). Empty if absent.
//
// ResourceMetadataURL 从 server 401 的 WWW-Authenticate 头（RFC 9728 §5.1）提取受保护资源元数据 URL。
func ResourceMetadataURL(wwwAuthenticate string) string {
	m := resourceMetadataRe.FindStringSubmatch(wwwAuthenticate)
	if len(m) == 2 {
		return m[1]
	}
	return ""
}

// Discover resolves a server URL to its OAuth Metadata: it reads the protected-resource-metadata
// (RFC 9728) — preferring the URL the server advertised in its 401, else the well-known path — to
// find the authorization server(s), then reads the AS metadata (RFC 8414, openid fallback) for the
// endpoints. resourceMetaURL may be "" (use the well-known path).
//
// Discover 把 server URL 解析成 OAuth Metadata：读受保护资源元数据（RFC 9728）——优先 server 在 401
// 通告的 URL、否则 well-known 路径——找到授权服务器，再读 AS 元数据（RFC 8414，openid 兜底）拿端点。
func Discover(ctx context.Context, hc httpDo, serverURL, resourceMetaURL string) (*Metadata, error) {
	prm, err := fetchProtectedResourceMetadata(ctx, hc, serverURL, resourceMetaURL)
	if err != nil {
		return nil, err
	}
	if len(prm.AuthorizationServers) == 0 {
		return nil, fmt.Errorf("oauth.Discover: %w: protected-resource-metadata lists no authorization_servers", ErrDiscovery)
	}
	// Bind the RFC 8707 token audience to OUR server's host. The protected-resource-metadata is fetched
	// FROM the server, but we only honor its `resource` if it names the same host — a PRM that points the
	// audience elsewhere is ignored in favor of the canonical server URL (defense against a redirected
	// audience), per the oauth review.
	//
	// 把 RFC 8707 token 受众绑死到 OUR server 的 host。受保护资源元数据虽取自 server，但仅当其 `resource`
	// 指向同一 host 才采纳——指向别处的 PRM 被忽略、退回 canonical server URL（防受众被改向）。
	resource := canonicalResource(serverURL)
	if prm.Resource != "" && sameHost(prm.Resource, serverURL) {
		resource = prm.Resource
	}
	var lastErr error
	for _, as := range prm.AuthorizationServers {
		meta, err := fetchAuthServerMetadata(ctx, hc, as)
		if err != nil {
			lastErr = err
			continue
		}
		meta.Resource = resource
		return meta, nil
	}
	return nil, fmt.Errorf("oauth.Discover: %w: no usable authorization server (%v)", ErrDiscovery, lastErr)
}

type protectedResourceMetadata struct {
	Resource             string   `json:"resource"`
	AuthorizationServers []string `json:"authorization_servers"`
}

func fetchProtectedResourceMetadata(ctx context.Context, hc httpDo, serverURL, advertised string) (*protectedResourceMetadata, error) {
	candidates := wellKnownResourceURLs(serverURL)
	if advertised != "" {
		candidates = append([]string{advertised}, candidates...)
	}
	var lastErr error
	for _, u := range candidates {
		var prm protectedResourceMetadata
		if err := getJSON(ctx, hc, u, &prm); err != nil {
			lastErr = err
			continue
		}
		if len(prm.AuthorizationServers) > 0 {
			return &prm, nil
		}
	}
	return nil, fmt.Errorf("oauth.Discover: %w: no protected-resource-metadata (%v)", ErrDiscovery, lastErr)
}

// wellKnownResourceURLs builds the RFC 9728 candidate metadata URLs for a resource: the path-aware
// form (well-known inserted after the host, path appended) and the host-root form.
//
// wellKnownResourceURLs 为资源构造 RFC 9728 候选元数据 URL：路径感知形（well-known 插在 host 后、路径接尾）+ host 根形。
func wellKnownResourceURLs(serverURL string) []string {
	u, err := url.Parse(serverURL)
	if err != nil {
		return nil
	}
	origin := u.Scheme + "://" + u.Host
	path := strings.TrimSuffix(u.Path, "/")
	out := []string{}
	if path != "" {
		out = append(out, origin+"/.well-known/oauth-protected-resource"+path)
	}
	out = append(out, origin+"/.well-known/oauth-protected-resource")
	return out
}

func fetchAuthServerMetadata(ctx context.Context, hc httpDo, issuer string) (*Metadata, error) {
	type asMeta struct {
		Issuer                string   `json:"issuer"`
		AuthorizationEndpoint string   `json:"authorization_endpoint"`
		TokenEndpoint         string   `json:"token_endpoint"`
		RegistrationEndpoint  string   `json:"registration_endpoint"`
		ScopesSupported       []string `json:"scopes_supported"`
		CodeChallengeMethods  []string `json:"code_challenge_methods_supported"`
	}
	var lastErr error
	for _, u := range wellKnownAuthServerURLs(issuer) {
		var m asMeta
		if err := getJSON(ctx, hc, u, &m); err != nil {
			lastErr = err
			continue
		}
		if m.AuthorizationEndpoint == "" || m.TokenEndpoint == "" {
			lastErr = fmt.Errorf("metadata at %s missing authorization/token endpoint", u)
			continue
		}
		return &Metadata{
			Issuer:                m.Issuer,
			AuthorizationEndpoint: m.AuthorizationEndpoint,
			TokenEndpoint:         m.TokenEndpoint,
			RegistrationEndpoint:  m.RegistrationEndpoint,
			ScopesSupported:       m.ScopesSupported,
			CodeChallengeMethods:  m.CodeChallengeMethods,
		}, nil
	}
	return nil, fmt.Errorf("oauth: %w: authorization-server metadata (%v)", ErrDiscovery, lastErr)
}

// wellKnownAuthServerURLs builds the RFC 8414 §3.1 + OIDC candidate metadata URLs for an issuer,
// honoring an issuer path (well-known inserted after the host) and the host-root form.
//
// wellKnownAuthServerURLs 为 issuer 构造 RFC 8414 §3.1 + OIDC 候选元数据 URL，处理 issuer 路径与 host 根形。
func wellKnownAuthServerURLs(issuer string) []string {
	u, err := url.Parse(issuer)
	if err != nil {
		return nil
	}
	origin := u.Scheme + "://" + u.Host
	path := strings.TrimSuffix(u.Path, "/")
	var out []string
	for _, wk := range []string{"/.well-known/oauth-authorization-server", "/.well-known/openid-configuration"} {
		if path != "" {
			out = append(out, origin+wk+path)
		}
		out = append(out, origin+wk)
	}
	return out
}

// ClientRegistration is the result of DCR. ClientSecret is empty for a public client (the common
// PKCE case); when present the AS issued a confidential client and we must send the secret.
//
// ClientRegistration 是 DCR 结果。ClientSecret 对公共客户端为空（常见 PKCE 情形）；非空则 AS 发了机密
// 客户端、我们须带上 secret。
type ClientRegistration struct {
	ClientID     string
	ClientSecret string
}

// Register performs Dynamic Client Registration (RFC 7591): POST the registration endpoint with our
// loopback redirect URI and the authorization-code + refresh grants, requesting a public client
// (token_endpoint_auth_method=none) so no secret has to be stored.
//
// Register 走动态客户端注册（RFC 7591）：POST 注册端点，带 loopback redirect URI 与授权码+刷新 grant，
// 请求公共客户端（token_endpoint_auth_method=none）以免存 secret。
func Register(ctx context.Context, hc httpDo, registrationEndpoint, clientName, redirectURI string, scopes []string) (*ClientRegistration, error) {
	body := map[string]any{
		"client_name":                clientName,
		"redirect_uris":              []string{redirectURI},
		"grant_types":                []string{"authorization_code", "refresh_token"},
		"response_types":             []string{"code"},
		"token_endpoint_auth_method": "none",
	}
	if len(scopes) > 0 {
		body["scope"] = strings.Join(scopes, " ")
	}
	raw, _ := json.Marshal(body)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, registrationEndpoint, strings.NewReader(string(raw)))
	if err != nil {
		return nil, fmt.Errorf("oauth.Register: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := hc.Do(req)
	if err != nil {
		return nil, fmt.Errorf("oauth.Register: %w: %v", ErrRegistration, err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("oauth.Register: %w: status %d: %s", ErrRegistration, resp.StatusCode, truncate(string(data), 300))
	}
	var out struct {
		ClientID     string `json:"client_id"`
		ClientSecret string `json:"client_secret"`
	}
	if err := json.Unmarshal(data, &out); err != nil || out.ClientID == "" {
		return nil, fmt.Errorf("oauth.Register: %w: response has no client_id", ErrRegistration)
	}
	return &ClientRegistration{ClientID: out.ClientID, ClientSecret: out.ClientSecret}, nil
}

// PKCE is one authorization request's proof-key (RFC 7636, S256). Verifier is the high-entropy
// secret kept client-side; Challenge is its SHA-256 sent in the authorize URL.
//
// PKCE 是一次授权请求的证明密钥（RFC 7636，S256）。Verifier 是留在客户端的高熵秘密；Challenge 是其
// SHA-256、随 authorize URL 发出。
type PKCE struct {
	Verifier  string
	Challenge string
	Method    string
}

// NewPKCE mints a fresh S256 pair from 32 bytes of crypto/rand entropy.
//
// NewPKCE 从 32 字节 crypto/rand 熵铸一对新 S256。
func NewPKCE() (PKCE, error) {
	verifier, err := randomURLSafe(32)
	if err != nil {
		return PKCE{}, fmt.Errorf("oauth.NewPKCE: %w", err)
	}
	sum := sha256.Sum256([]byte(verifier))
	return PKCE{
		Verifier:  verifier,
		Challenge: base64.RawURLEncoding.EncodeToString(sum[:]),
		Method:    "S256",
	}, nil
}

// NewState mints an opaque anti-CSRF state value bound to one authorization request.
//
// NewState 铸一个绑定单次授权请求的不透明 anti-CSRF state。
func NewState() (string, error) { return randomURLSafe(24) }

// AuthorizeURL builds the OAuth 2.1 authorization-code request URL: response_type=code with PKCE
// S256, the loopback redirect, the resource indicator (RFC 8707, binds the token to this MCP
// server), state, and the requested scopes.
//
// AuthorizeURL 构造 OAuth 2.1 授权码请求 URL：response_type=code + PKCE S256 + loopback redirect +
// 资源指示符（RFC 8707，把 token 绑死本 MCP server）+ state + 请求的 scope。
func AuthorizeURL(meta *Metadata, clientID, redirectURI, state string, pkce PKCE, scopes []string) string {
	q := url.Values{}
	q.Set("response_type", "code")
	q.Set("client_id", clientID)
	q.Set("redirect_uri", redirectURI)
	q.Set("state", state)
	q.Set("code_challenge", pkce.Challenge)
	q.Set("code_challenge_method", pkce.Method)
	if meta.Resource != "" {
		q.Set("resource", meta.Resource)
	}
	if len(scopes) > 0 {
		q.Set("scope", strings.Join(scopes, " "))
	}
	sep := "?"
	if strings.Contains(meta.AuthorizationEndpoint, "?") {
		sep = "&"
	}
	return meta.AuthorizationEndpoint + sep + q.Encode()
}

// Token is an issued credential set. Expiry is absolute (computed from expires_in at receipt).
//
// Token 是一组签发凭据。Expiry 是绝对时刻（收到时由 expires_in 算出）。
type Token struct {
	AccessToken  string
	RefreshToken string
	TokenType    string
	Expiry       time.Time
	Scope        string
}

// Expired reports whether the access token is at/within skew of expiry (skew gives refresh
// headroom). A zero Expiry means "unknown" → treated as not expired.
//
// Expired 报告 access token 是否到/进入 skew 内（skew 给刷新留余量）。零 Expiry = 未知 → 视为未过期。
func (t *Token) Expired(now time.Time, skew time.Duration) bool {
	if t.Expiry.IsZero() {
		return false
	}
	return !now.Add(skew).Before(t.Expiry)
}

// Exchange swaps an authorization code for tokens (grant_type=authorization_code) with the PKCE
// verifier, the loopback redirect, and the resource indicator. clientSecret is sent only if the
// AS issued a confidential client.
//
// Exchange 用 PKCE verifier + loopback redirect + 资源指示符把授权码换成 token（grant_type=authorization_code）。
// clientSecret 仅在 AS 发了机密客户端时带上。
func Exchange(ctx context.Context, hc httpDo, meta *Metadata, clientID, clientSecret, code, redirectURI, codeVerifier string, now time.Time) (*Token, error) {
	form := url.Values{}
	form.Set("grant_type", "authorization_code")
	form.Set("code", code)
	form.Set("redirect_uri", redirectURI)
	form.Set("client_id", clientID)
	form.Set("code_verifier", codeVerifier)
	if meta.Resource != "" {
		form.Set("resource", meta.Resource)
	}
	if clientSecret != "" {
		form.Set("client_secret", clientSecret)
	}
	return postToken(ctx, hc, meta.TokenEndpoint, form, now)
}

// Refresh trades a refresh token for a new access token (grant_type=refresh_token), re-asserting
// the resource indicator. A rotated refresh token in the response replaces the old one.
//
// Refresh 用 refresh token 换新 access token（grant_type=refresh_token），重申资源指示符。响应里轮换的
// refresh token 替换旧的。
func Refresh(ctx context.Context, hc httpDo, tokenEndpoint, clientID, clientSecret, refreshToken, resource string, now time.Time) (*Token, error) {
	form := url.Values{}
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", refreshToken)
	form.Set("client_id", clientID)
	if resource != "" {
		form.Set("resource", resource)
	}
	if clientSecret != "" {
		form.Set("client_secret", clientSecret)
	}
	tok, err := postToken(ctx, hc, tokenEndpoint, form, now)
	if err != nil {
		return nil, err
	}
	// A refresh response may omit the refresh token, meaning "keep the old one" (no rotation).
	// 刷新响应可能省略 refresh token，意为「沿用旧的」（无轮换）。
	if tok.RefreshToken == "" {
		tok.RefreshToken = refreshToken
	}
	return tok, nil
}

func postToken(ctx context.Context, hc httpDo, tokenEndpoint string, form url.Values, now time.Time) (*Token, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, tokenEndpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("oauth: token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")
	resp, err := hc.Do(req)
	if err != nil {
		return nil, fmt.Errorf("oauth: %w: %v", ErrToken, err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("oauth: %w: status %d: %s", ErrToken, resp.StatusCode, truncate(string(data), 300))
	}
	var out struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		TokenType    string `json:"token_type"`
		ExpiresIn    int64  `json:"expires_in"`
		Scope        string `json:"scope"`
	}
	if err := json.Unmarshal(data, &out); err != nil || out.AccessToken == "" {
		return nil, fmt.Errorf("oauth: %w: response has no access_token", ErrToken)
	}
	tok := &Token{
		AccessToken:  out.AccessToken,
		RefreshToken: out.RefreshToken,
		TokenType:    out.TokenType,
		Scope:        out.Scope,
	}
	if out.ExpiresIn > 0 {
		tok.Expiry = now.Add(time.Duration(out.ExpiresIn) * time.Second)
	}
	return tok, nil
}

// --- helpers ---

func getJSON(ctx context.Context, hc httpDo, u string, dst any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("MCP-Protocol-Version", "2025-06-18")
	resp, err := hc.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET %s: status %d", u, resp.StatusCode)
	}
	return json.Unmarshal(data, dst)
}

// canonicalResource is the RFC 8707 resource identifier for an MCP server: scheme://host[:port]
// with the path preserved but no query/fragment (the audience the token is bound to).
//
// canonicalResource 是 MCP server 的 RFC 8707 资源标识：scheme://host[:port] 保留路径、无 query/fragment。
func canonicalResource(serverURL string) string {
	u, err := url.Parse(serverURL)
	if err != nil {
		return serverURL
	}
	u.RawQuery = ""
	u.Fragment = ""
	return u.String()
}

// sameHost reports whether two URLs share a scheme+host (the token-audience binding check).
//
// sameHost 报告两个 URL 是否同 scheme+host（token 受众绑定检查）。
func sameHost(a, b string) bool {
	ua, err1 := url.Parse(a)
	ub, err2 := url.Parse(b)
	if err1 != nil || err2 != nil {
		return false
	}
	return ua.Host == ub.Host
}

func randomURLSafe(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
