package llm

import (
	"context"
	"encoding/json"
	"io"
	"testing"
)

// Azure is the one member of this dialect whose REQUEST LINE differs, and both differences fail in
// the same nasty way: a 401 or a 404 that reads like the user's fault. These pin the wire.
//
// Azure 是本方言里**请求行**不同的那一个,而两处不同都以同一种讨厌的方式失败:一个读起来**像是用户
// 的错**的 401 或 404。这里把线缆钉死。
func TestAzure_DeploymentInThePathAndApiKeyHeader(t *testing.T) {
	httpReq, err := newAzureProvider().BuildRequest(context.Background(), Request{
		ModelID:  "gpt-4o-prod",
		Key:      "az-secret",
		BaseURL:  "https://myres.openai.azure.com",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := "https://myres.openai.azure.com/openai/deployments/gpt-4o-prod/chat/completions?api-version=" + azureAPIVersion
	if got := httpReq.URL.String(); got != want {
		t.Errorf("url = %s\nwant %s", got, want)
	}
	// The credential is `api-key`. As a bearer it would 401 exactly like a wrong key, and the user
	// would go re-copy a key that was never wrong.
	// 凭证是 `api-key`。当 bearer 发会 401 得和「key 填错了」一模一样,而用户会跑去重抄一把从没错过的 key。
	if got := httpReq.Header.Get("api-key"); got != "az-secret" {
		t.Errorf("api-key header = %q", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "" {
		t.Errorf("Authorization must be absent on Azure, got %q", got)
	}
	// The body is OpenAI's, verbatim — that is the whole reason Azure rides this dialect at all.
	// body 是 OpenAI 的、逐字相同——那正是 Azure 能搭上本方言的全部理由。
	raw, _ := io.ReadAll(httpReq.Body)
	var body map[string]any
	if err := json.Unmarshal(raw, &body); err != nil {
		t.Fatal(err)
	}
	if body["model"] != "gpt-4o-prod" || body["stream"] != true {
		t.Errorf("body = %v, want the ordinary OpenAI shape", body)
	}
}

// A deployment name is USER-CHOSEN, so it can contain anything a person might type. Unescaped, a
// space produces a request line the server rejects with a message about nothing in particular.
//
// deployment 名是**用户自己取的**,故里面可能出现人会打的任何东西。不转义的话,一个空格会产出一行
// 服务器会拒、且拒得不知所云的请求行。
func TestAzure_EscapesTheUserChosenDeploymentAndHonoursTheVersionOverride(t *testing.T) {
	httpReq, err := newAzureProvider().BuildRequest(context.Background(), Request{
		ModelID:  "gpt-4o prod/eu",
		Key:      "k",
		BaseURL:  "https://myres.openai.azure.com/",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Options:  map[string]string{azureAPIVersionOption: "2025-01-01-preview"},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := "https://myres.openai.azure.com/openai/deployments/gpt-4o%20prod%2Feu/chat/completions?api-version=2025-01-01-preview"
	if got := httpReq.URL.String(); got != want {
		t.Errorf("url = %s\nwant %s", got, want)
	}
}

// TestDialect_SpeakableIsAboutTheWireNotThePackage pins the two directions the `npm` hint can
// mislead in, both of which cost something real:
//
//   - `@ai-sdk/amazon-bedrock` speaks Converse over SigV4, so the package name says「third full
//     dialect」— but Bedrock ALSO serves OpenAI-compatible chat completions with a bearer token, and
//     reading the package as the protocol would have cost 116 models for nothing.
//   - `@ai-sdk/google-vertex` looks like Gemini's cousin, but Vertex authenticates with a
//     service-account file. Routing it to the Gemini provider would 401 forever with a message that
//     blames the user's key.
//
// TestDialect_SpeakableIsAboutTheWireNotThePackage 钉住 `npm` 线索**两个方向**的误导,而两边都有真实代价:
//
//   - `@ai-sdk/amazon-bedrock` 讲 Converse + SigV4,故包名说的是「第三条完整方言」——但 Bedrock **同时**
//     用 bearer 提供 OpenAI 兼容的 chat completions,把包名当协议读会**白白**丢掉 116 个模型。
//   - `@ai-sdk/google-vertex` 看着像 Gemini 的表亲,但 Vertex 用**服务账号文件**鉴权。路由到 Gemini
//     provider 会永远 401,而消息去怪用户的 key。
func TestDialect_SpeakableIsAboutTheWireNotThePackage(t *testing.T) {
	if !DialectForNPM("@ai-sdk/azure").Speakable() {
		t.Error("azure is implemented (deployment in the path + api-key header)")
	}
	if d := DialectForNPM("@ai-sdk/amazon-bedrock"); d != DialectOpenAICompat || !d.Speakable() {
		t.Errorf("bedrock serves an OpenAI-compatible endpoint with a bearer token, got %q", d)
	}
	for _, npm := range []string{"@ai-sdk/google-vertex", "@ai-sdk/google-vertex/anthropic"} {
		if d := DialectForNPM(npm); d != DialectVertex || d.Speakable() {
			t.Errorf("%s takes a service-account file, not a key — it must stay honestly absent, got %q", npm, d)
		}
	}
}
