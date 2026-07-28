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

// TestAzure_IsSpeakableAndBedrockIsNot: the honest-absence law applied to dialects. Azure now has an
// implementation, so a key may be created for it; Bedrock is still a NAME, so the refusal must land
// at key creation with its own reason instead of at the last hop.
//
// TestAzure_IsSpeakableAndBedrockIsNot:诚实缺席律用在方言上。Azure 现在有实现,故可以为它建 key;
// Bedrock 仍只是个名字,故拒绝必须落在**建 key 时**、带着自己的理由,而不是落在最后一跳。
func TestAzure_IsSpeakableAndBedrockIsNot(t *testing.T) {
	if !DialectForNPM("@ai-sdk/azure").Speakable() {
		t.Error("azure is implemented now")
	}
	if DialectForNPM("@ai-sdk/amazon-bedrock").Speakable() {
		t.Error("bedrock has no implementation; claiming it would move the failure to the last hop")
	}
}
