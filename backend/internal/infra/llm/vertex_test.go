package llm

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"strings"
	"testing"
)

// serviceAccountJSON builds a syntactically real service-account file — a real RSA key included,
// because `google.JWTConfigFromJSON` parses the PEM and a fake string would make these tests pass
// for the wrong reason (they would be asserting our error path, not our success path).
//
// serviceAccountJSON 造一份**语法上真实**的服务账号文件——含一把真 RSA key,因为
// `google.JWTConfigFromJSON` 会解析 PEM,而一个假字符串会让这些测试**因错误的理由通过**
// (那样断言的是我们的错误分支、不是成功分支)。
func serviceAccountJSON(t *testing.T, project string) string {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	pemKey := string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
	blob, _ := json.Marshal(map[string]string{
		"type":         "service_account",
		"project_id":   project,
		"private_key":  pemKey,
		"client_email": "anselm@" + project + ".iam.gserviceaccount.com",
		"token_uri":    "https://oauth2.googleapis.com/token",
	})
	return string(blob)
}

// TestVertex_ProjectAndRegionComeFromWhatTheUserAlreadyGaveUs: the project is INSIDE the
// service-account file and the region is INSIDE the host, so neither is a field to ask for. Asking
// again would be asking the user to repeat themselves and handing them a way to disagree with
// themselves.
//
// TestVertex_ProjectAndRegionComeFromWhatTheUserAlreadyGaveUs:project 在**服务账号文件里**、region
// 在**主机名里**,故两者都不是要问的字段。再问一遍等于让用户重复自己,并递给他一个与自己不一致的机会。
func TestVertex_ProjectAndRegionComeFromWhatTheUserAlreadyGaveUs(t *testing.T) {
	key := serviceAccountJSON(t, "my-proj")
	got := vertexChatURL(Request{
		ModelID: "gemini-2.5-pro",
		Key:     key,
		BaseURL: "https://us-central1-aiplatform.googleapis.com",
	})
	want := "https://us-central1-aiplatform.googleapis.com/v1/projects/my-proj/locations/us-central1/endpoints/openapi/chat/completions"
	if got != want {
		t.Errorf("url = %s\nwant %s", got, want)
	}
	// All three host shapes `@ai-sdk/google-vertex` can produce (read from its published bundle,
	// H12-f). The `.rep.` pair are Google's data-residency endpoints, and they are the ones a parser
	// that only knows `{region}-aiplatform.` gets SILENTLY wrong: it answers "global" and builds a URL
	// for the wrong location — a 404 that reads like「这个模型不存在」.
	// `@ai-sdk/google-vertex` 能产出的**三种**主机形状(H12-f 从它已发布的包里读出)。`.rep.` 那两个是
	// Google 的数据驻留端点,也正是只认识 `{region}-aiplatform.` 的解析器会**静默搞错**的那两个:
	// 它会答 "global"、去为错误的 location 拼 URL——换来一个读起来像「这个模型不存在」的 404。
	for host, want := range map[string]string{
		"https://aiplatform.googleapis.com":              "global",
		"https://aiplatform.eu.rep.googleapis.com":       "eu",
		"https://aiplatform.us.rep.googleapis.com":       "us",
		"https://us-central1-aiplatform.googleapis.com":  "us-central1",
		"https://europe-west4-aiplatform.googleapis.com": "europe-west4",
	} {
		if loc := vertexLocationFromBase(host); loc != want {
			t.Errorf("%s → %q, want %q", host, loc, want)
		}
	}
	// An explicit option still wins, for a user whose host and region genuinely differ.
	// 显式指定仍然优先,给那些主机名与区域确实不同的用户。
	got = vertexChatURL(Request{
		ModelID: "m", Key: key,
		BaseURL: "https://aiplatform.googleapis.com",
		Options: map[string]string{vertexLocationOption: "europe-west4"},
	})
	if !strings.Contains(got, "/locations/europe-west4/") {
		t.Errorf("explicit location ignored: %s", got)
	}
}

// TestVertex_APIKeyInsteadOfAFileSaysSo is the failure this provider will actually see. Vertex is
// the only credential in the app that is not a pasted string, so the overwhelmingly likely mistake
// is pasting one anyway — and a generic JSON parse error would send the user to inspect their Google
// project instead of the field they filled in.
//
// TestVertex_APIKeyInsteadOfAFileSaysSo 是这一家**真正会遇到**的失败。Vertex 是本 app 里唯一不是
// 「粘一个字符串」的凭证,故压倒性可能的错误就是**照粘一个**——而一句笼统的 JSON 解析错误会把用户送去
// 检查他的 Google 项目、而不是他刚填的那一栏。
func TestVertex_APIKeyInsteadOfAFileSaysSo(t *testing.T) {
	_, err := newVertexProvider().BuildRequest(context.Background(), Request{
		ModelID:  "gemini-2.5-pro",
		Key:      "AIzaSyLooksLikeAnApiKey",
		BaseURL:  "https://us-central1-aiplatform.googleapis.com",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
	})
	if err == nil {
		t.Fatal("an API key is not a service-account file; building a request with it must fail here")
	}
	if !strings.Contains(err.Error(), "service-account") {
		t.Errorf("the message must name the actual mistake, got %q", err)
	}
}

// TestVertex_TokenSourceIsCachedPerCredential: minting is an RSA signature plus a network round
// trip. Doing it per chat request would put a second HTTP call — and a second failure mode — in
// front of every message the user sends.
//
// TestVertex_TokenSourceIsCachedPerCredential:铸 token 是一次 RSA 签名加一次网络往返。逐 chat 请求
// 做它,等于在用户发的**每一条消息**前面加一次 HTTP 调用和一种新的失败方式。
func TestVertex_TokenSourceIsCachedPerCredential(t *testing.T) {
	key := serviceAccountJSON(t, "cache-proj")
	a, err := vertexTokenSource(context.Background(), key)
	if err != nil {
		t.Fatal(err)
	}
	b, err := vertexTokenSource(context.Background(), key)
	if err != nil {
		t.Fatal(err)
	}
	if a != b {
		t.Error("the same credential must reuse one token source (it owns the refresh bookkeeping)")
	}
	other, err := vertexTokenSource(context.Background(), serviceAccountJSON(t, "other-proj"))
	if err != nil {
		t.Fatal(err)
	}
	if a == other {
		t.Error("a different credential must not share a token source")
	}
}

// TestVertex_IsSpeakableAndCarriesTheOpenAIBody: the wire above the URL and the token is ordinary,
// which is the whole reason Vertex costs one file instead of a third dialect.
//
// TestVertex_IsSpeakableAndCarriesTheOpenAIBody:URL 与 token 之上的线缆是**普通的**,而那正是 Vertex
// 只花一个文件、而不是第三条方言的全部理由。
func TestVertex_IsSpeakableAndCarriesTheOpenAIBody(t *testing.T) {
	for _, npm := range []string{"@ai-sdk/google-vertex", "@ai-sdk/google-vertex/anthropic"} {
		d := DialectForNPM(npm)
		if d != DialectVertex || !d.Speakable() {
			t.Errorf("%s should resolve to a speakable vertex dialect, got %q", npm, d)
		}
	}
	p := newVertexProvider()
	if p.spec.auth == nil || p.spec.chatURL == nil {
		t.Fatal("vertex overrides exactly two things: the URL and the credential")
	}
	var h http.Header = http.Header{}
	if err := p.spec.auth(context.Background(), h, "not-a-file"); err == nil {
		t.Error("a non-file credential must fail loudly at auth time")
	}
}
