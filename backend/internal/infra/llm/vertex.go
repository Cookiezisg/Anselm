package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// Vertex AI is the one provider in the catalog whose CREDENTIAL is a different kind of thing.
//
// Every other key in this app is a string a person pastes. Vertex takes a Google service-account
// JSON file and expects an OAuth2 access token minted from it — sign a JWT with the file's private
// key, exchange it for a token that lives one hour, refresh before it dies. models.dev says so
// plainly in its own `env`: PROJECT + LOCATION + `GOOGLE_APPLICATION_CREDENTIALS`, a FILE PATH.
//
// **The credential still fits one key row, and that is not a trick.** A service-account file IS a
// string — a JSON document. Storing it whole in the same encrypted column costs no schema change,
// and it carries `project_id` inside itself, so the project never has to be asked for twice.
//
// Vertex AI 是目录里**凭证根本不是同一种东西**的那一家。
//
// 本 app 里其余每一把 key 都是「人粘贴的一个字符串」。Vertex 收的是一个 Google **服务账号 JSON 文件**,
// 并要求用它铸出的 OAuth2 access token——用文件里的私钥签一个 JWT、换一个**只活一小时**的 token、
// 到期前续。models.dev 在自己的 `env` 里就直说了:PROJECT + LOCATION + `GOOGLE_APPLICATION_CREDENTIALS`,
// 一个**文件路径**。
//
// **凭证仍然装得进一行 key,而这不是取巧。** 服务账号文件**本身就是**一个字符串——一份 JSON 文档。
// 整份存进同一个加密列,零 schema 变更,而且它**自带 `project_id`**,故项目名永远不必问第二遍。
//
// **The wire is ordinary.** Vertex serves an OpenAI-compatible chat completions endpoint under
// `…/endpoints/openapi`, so everything above the URL and the token is [compatProvider] verbatim —
// which is why this file is 150 lines instead of a third dialect.
//
// **线缆是普通的。** Vertex 在 `…/endpoints/openapi` 下提供 OpenAI 兼容的 chat completions,故 URL 与
// token 之上的一切都是 [compatProvider] 逐字复用——这也正是本文件是 150 行、而不是第三条方言的原因。
//
// Sources / 出处:
//   - OpenAI-compatible endpoint shape:
//     https://cloud.google.com/vertex-ai/generative-ai/docs/reference/rest/v1/projects.locations.endpoints.chat/completions
//   - Service-account JWT flow: golang.org/x/oauth2/google (we do NOT hand-roll the signing — 原则 #8)
const vertexScope = "https://www.googleapis.com/auth/cloud-platform"

// vertexLocationOption lets a caller name the region explicitly. Normally it is READ OFF the base
// URL host (`us-central1-aiplatform.googleapis.com`), because that host is the one thing the user
// must supply anyway and repeating the region in a second field is a way to have them disagree.
//
// vertexLocationOption 让调用方显式指定区域。通常它是**从 base URL 主机名读出来的**
// (`us-central1-aiplatform.googleapis.com`)——那个主机名本来就是用户必须填的东西,而把区域再要一遍
// 只会制造两处不一致的机会。
const vertexLocationOption = "location"

func newVertexProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name: "google-vertex",
		// Empty: the host carries the user's region. 为空:主机名里带着用户的区域。
		baseURL: func() string { return "" },
		wire:    partMask{image: true, file: true},
		parts:   openaiParts,
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxTokens = req.MaxTokens
			}
			if v := req.Options["reasoning_effort"]; v != "" {
				body.ReasoningEffort = v
			}
		},
		chatURL: vertexChatURL,
		auth:    vertexAuth,
		// The probe body is ignored on purpose: Vertex has no OpenAI-shaped /models listing to
		// intersect with, so the catalog is the only inventory that exists for it.
		// 探测体**刻意忽略**:Vertex 没有 OpenAI 形的 /models 列举可以求交,故目录是它**唯一存在**的清单。
		describe: func(string) ([]ModelInfo, error) {
			return describeAllFromCatalog(catalogSpecs("google-vertex", compatKnobs), partMask{image: true, file: true}), nil
		},
	}}
}

// vertexChatURL builds `{base}/v1/projects/{project}/locations/{location}/endpoints/openapi/chat/completions`.
//
// The project comes out of the service-account JSON — the user already handed it to us, so asking
// for it again would be asking them to repeat themselves and giving them a way to get it wrong.
//
// vertexChatURL 构造 `{base}/v1/projects/{project}/locations/{location}/endpoints/openapi/chat/completions`。
//
// project 从**服务账号 JSON 里**取——用户已经把它交给我们了,再问一遍等于让他重复自己,并给他一个填错的机会。
func vertexChatURL(req Request) string {
	base := strings.TrimRight(req.BaseURL, "/")
	project := vertexProjectFromKey(req.Key)
	location := strings.TrimSpace(req.Options[vertexLocationOption])
	if location == "" {
		location = vertexLocationFromBase(base)
	}
	return base + "/v1/projects/" + url.PathEscape(project) +
		"/locations/" + url.PathEscape(location) + "/endpoints/openapi/chat/completions"
}

// vertexLocationFromBase reads the region out of `{region}-aiplatform.googleapis.com`, and answers
// "global" for the region-less host — Google's own name for that endpoint, not an invention.
//
// vertexLocationFromBase 从 `{region}-aiplatform.googleapis.com` 里读区域;对**没有区域**的那个主机名
// 答 "global"——那是 Google 自己给那个端点起的名字、不是我们编的。
func vertexLocationFromBase(base string) string {
	u, err := url.Parse(base)
	if err != nil || u.Host == "" {
		return "global"
	}
	host, _, _ := strings.Cut(u.Host, ":")
	region, rest, found := strings.Cut(host, "-aiplatform.")
	if !found || rest == "" || region == "" {
		return "global"
	}
	return region
}

func vertexProjectFromKey(key string) string {
	var sa struct {
		ProjectID string `json:"project_id"`
	}
	_ = json.Unmarshal([]byte(key), &sa)
	return sa.ProjectID
}

// vertexTokens caches one token source per service account, keyed by the credential itself.
//
// The cache is not an optimisation. `google.JWTConfigFromJSON` parses and RSA-signs on every call,
// and the token exchange is a network round trip — doing that per chat request would put a second
// HTTP call, and a second failure mode, in front of every message the user sends. The oauth2
// TokenSource returned here does the refresh-before-expiry bookkeeping itself, which is exactly the
// part worth not writing by hand (原则 #8).
//
// vertexTokens 按**凭证本身**为键,逐服务账号缓存一个 token source。
//
// 这个缓存不是优化。`google.JWTConfigFromJSON` 每次调用都要解析并做 RSA 签名,而换 token 是一次网络
// 往返——逐 chat 请求做这件事,等于在用户发的**每一条消息**前面加一次 HTTP 调用和一种新的失败方式。
// 这里拿到的 oauth2 TokenSource 自己管「到期前续」的账,而那正是最不值得手写的一段(原则 #8)。
var vertexTokens sync.Map // service-account JSON -> oauth2.TokenSource

func vertexTokenSource(ctx context.Context, key string) (oauth2.TokenSource, error) {
	if ts, ok := vertexTokens.Load(key); ok {
		return ts.(oauth2.TokenSource), nil
	}
	cfg, err := google.JWTConfigFromJSON([]byte(key), vertexScope)
	if err != nil {
		// The most likely cause by far is a user who pasted an API key into a field that wants a
		// service-account file. Say which one it is; the generic parse error would send them looking
		// at their Google project.
		// 最可能的原因远远地是:用户把一把 API key 粘进了一个要**服务账号文件**的字段。**说清楚是哪一种**
		// ——一句笼统的解析错误会把他送去翻自己的 Google 项目。
		return nil, fmt.Errorf("%w: vertex needs a service-account JSON file, not an API key (%v)", ErrAuthFailed, err)
	}
	ts := cfg.TokenSource(ctx)
	actual, _ := vertexTokens.LoadOrStore(key, ts)
	return actual.(oauth2.TokenSource), nil
}

func vertexAuth(ctx context.Context, h http.Header, key string) error {
	ts, err := vertexTokenSource(ctx, key)
	if err != nil {
		return err
	}
	tok, err := ts.Token()
	if err != nil {
		return fmt.Errorf("%w: vertex token exchange: %v", ErrAuthFailed, err)
	}
	h.Set("Authorization", "Bearer "+tok.AccessToken)
	return nil
}

// VerifyServiceAccount proves a credential end to end: parse the file, sign the JWT, exchange it
// for a token. Exported for the apikey probe, which has nothing better to check.
//
// VerifyServiceAccount 端到端地验一份凭证:解析文件、签 JWT、换 token。导出给 apikey 探针——它没有
// 更好的东西可查。
func VerifyServiceAccount(ctx context.Context, key string) error {
	ts, err := vertexTokenSource(ctx, key)
	if err != nil {
		return err
	}
	if _, err := ts.Token(); err != nil {
		return fmt.Errorf("%w: vertex token exchange: %v", ErrAuthFailed, err)
	}
	return nil
}

// ProbeMessage renders an error for the key-test surface without leaking a private key: oauth2
// errors can quote the request, and a service-account file IS the secret.
//
// ProbeMessage 为 key 测试面渲染错误,且**不泄漏私钥**:oauth2 的错误可能引用请求内容,而服务账号文件
// **本身就是**那个秘密。
func ProbeMessage(err error) string {
	if err == nil {
		return ""
	}
	msg := err.Error()
	if i := strings.Index(msg, "-----BEGIN"); i >= 0 {
		return strings.TrimSpace(msg[:i]) + " (credential redacted)"
	}
	return msg
}
