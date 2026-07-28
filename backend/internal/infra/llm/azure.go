package llm

import (
	"net/http"
	"net/url"
	"strings"
)

// Azure OpenAI speaks OpenAI's request BODY verbatim and almost nothing else about it.
//
// The two differences are exactly the two things no catalog can express, which is why models.dev
// hands us `@ai-sdk/azure` and stops there:
//
//   - **The deployment is in the PATH, not the body.** Azure does not address models by name; you
//     deploy a model under a deployment name of your choosing and call
//     `/openai/deployments/{deployment}/chat/completions`. Our `ModelID` IS that deployment name —
//     which is also why an Azure key needs no extra credential field: the resource name rides in
//     the base URL the user supplies (`https://{resource}.openai.azure.com`), so one key row still
//     holds everything. (models.dev's `env` splits it into AZURE_RESOURCE_NAME + AZURE_API_KEY
//     because the SDK builds the URL from parts; we take the whole URL and subsume both.)
//   - **The credential is an `api-key` header, not a bearer token.** Sending it as a bearer gets a
//     401 that reads exactly like a wrong key — the worst possible failure, because the user will
//     go and re-copy a key that was right all along.
//
// Azure OpenAI 逐字讲 OpenAI 的请求**体**,除此之外几乎处处不同。
//
// 那两处不同,恰是**任何目录都表达不了**的那两样——所以 models.dev 只递给我们一个 `@ai-sdk/azure`
// 就到此为止:
//
//   - **deployment 在路径里、不在 body 里。** Azure 不按名字寻址模型;你把一个模型部署成一个**自己
//     取名**的 deployment,然后调 `/openai/deployments/{deployment}/chat/completions`。我们的
//     `ModelID` **就是**那个 deployment 名——这也正是 Azure key **不需要**额外凭证字段的原因:
//     resource 名骑在用户填的 base URL 里(`https://{resource}.openai.azure.com`),一行 key 仍然装得
//     下全部。(models.dev 的 `env` 把它拆成 AZURE_RESOURCE_NAME + AZURE_API_KEY,是因为 SDK 要**拼**
//     URL;我们收整个 URL,把两者一并吞下。)
//   - **凭证是 `api-key` 头、不是 bearer。** 当 bearer 发会换来一个**读起来和「key 填错了」一模一样**
//     的 401——最糟的一种失败,因为用户会跑去重抄一把**本来就没错**的 key。
//
// The api-version query is a THIRD fact, and the honest thing about it is that it will age: Azure
// versions its data plane by date and expects callers to name one. It is a constant here with a
// user-editable override on the key row — the same shape as a prefilled base URL, for the same
// reason (we supply a value that works today; the user owns it the moment it does not).
//
// api-version 这个 query 是**第三个**事实,而关于它最诚实的一句话是**它会过期**:Azure 用日期给数据面
// 版本化、要求调用方指名一个。这里是一个常量 + key 行上可覆盖——与预填 base URL 同一形状、同一理由
// (我们给一个今天能用的值;它哪天不能用了,那一刻起归用户)。
const azureAPIVersion = "2024-10-21"

// azureAPIVersionOption is the per-key override key. A user on a preview API sets it and nothing in
// this build has to ship a new constant.
// azureAPIVersionOption 是逐 key 的覆盖键。用户在 preview API 上设一下即可,本构建不必为此发新常量。
const azureAPIVersionOption = "api_version"

func newAzureProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name: "azure",
		// Empty: the base URL carries the user's own resource name, so there is nothing to prefill.
		// 为空:base URL 里带着用户自己的 resource 名,没有可预填的东西。
		baseURL: func() string { return "" },
		wire:    partMask{image: true, file: true},
		parts:   openaiParts,
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxCompletionTokens = req.MaxTokens
			}
			if v := req.Options["reasoning_effort"]; v != "" {
				body.ReasoningEffort = v
			}
		},
		chatURL: azureChatURL,
		auth:    func(h http.Header, key string) { h.Set("api-key", key) },
		describe: func(raw string) ([]ModelInfo, error) {
			return describeFromSpecs(catalogSpecs("azure", openaiKnobs), raw, partMask{image: true, file: true}), nil
		},
	}}
}

// azureChatURL builds `{base}/openai/deployments/{deployment}/chat/completions?api-version=…`.
//
// The deployment segment is path-escaped because a deployment name is USER-CHOSEN: nothing stops
// someone from naming one `gpt-4o prod`, and an unescaped space would produce a request line the
// server rejects with a message about nothing in particular.
//
// azureChatURL 构造 `{base}/openai/deployments/{deployment}/chat/completions?api-version=…`。
//
// deployment 段做路径转义,因为 deployment 名是**用户自己取的**:没有任何东西阻止谁把它叫作
// `gpt-4o prod`,而一个未转义的空格会产出一行服务器会拒、且拒得不知所云的请求行。
func azureChatURL(req Request) string {
	base := strings.TrimRight(req.BaseURL, "/")
	version := req.Options[azureAPIVersionOption]
	if strings.TrimSpace(version) == "" {
		version = azureAPIVersion
	}
	return base + "/openai/deployments/" + url.PathEscape(req.ModelID) +
		"/chat/completions?api-version=" + url.QueryEscape(version)
}
