package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Desktop-side video-generation dialects (WRK-082 批D). Unlike image and speech, EVERY provider is
// asynchronous: submit → poll a handle → fetch the artifact. The shape below is therefore three
// verbs, not one, and the poll loop is shared while the three verbs differ per provider.
//
// THREE dialects. `anselm` is the managed free tier through the gateway; `qwen` and `google` are
// direct connections. OpenAI's Videos API (Sora) is NOT implemented: it was announced for
// removal on 2026-09-24 (代拍 D2). A driver with eight weeks left would be built, reviewed, and
// deleted without ever earning its keep — and worse, its two unique traits (a real progress
// percentage, a separate `/content` sub-endpoint) would have shaped this abstraction around a
// provider that is leaving.
//
// 桌面侧视频生成方言(批D)。与图像、语音不同,**每一家都是异步的**:提交 → 轮询句柄 → 取回产物。
// 故下面是三个动词而非一个:轮询循环共用,三个动词各家不同。
//
// **三个方言**。`anselm` 是经网关的受管免费档;`qwen` 与 `google` 是直连。OpenAI 的 Videos API(Sora)**不实现**:它已公告 2026-09-24 下线(代拍 D2)。
// 一个只剩八周寿命的 driver 会被建、被复审、被删掉,却从没挣回自己的成本;更糟的是它那两个独有特性
// (真进度百分比、单独的 `/content` 子端点)会把这套抽象塑造成围绕一个正在离场的家。
//
// **没有真进度百分比**。两家都只给状态字(wan 六态 / Veo 一个 `done` 布尔)。刻意**不**用「已耗时
// ÷ 预估耗时」合成一个百分比:Veo 官方给的区间是 11 秒到 6 分钟,合成出来的进度条会长时间卡在 99%
// ——那比一个诚实的「仍在生成(已等 2 分 10 秒)」更糟,因为它在撒一个可被验证为假的谎。

// ErrVideoGenFailed is the neutral sentinel for a generation the upstream refused or broke on.
//
// ErrVideoGenFailed 是上游拒绝/失败的中立 sentinel。
var ErrVideoGenFailed = errorspkg.New(errorspkg.KindUnavailable, "VIDEO_GEN_FAILED", "video generation failed")

// videoMaxBytes caps a downloaded artifact. Video is the one modality where the cap is a real
// product limit rather than hostile-URL defence: a 20-second 1080p clip is tens of MB.
//
// videoMaxBytes 封顶下载产物。视频是唯一一处该上限是**真产品限制**而非防恶意 URL 的模态:
// 一段 20 秒 1080p 是几十 MB。
const videoMaxBytes = 512 << 20

// GeneratedVideo is one produced artifact, bytes in hand.
type GeneratedVideo struct {
	Bytes []byte
	Mime  string
}

// VideoJob is an accepted submission. Handle is OPAQUE — a DashScope task uuid, a Google operation
// name carrying its own `models/…/operations/…` path. Nothing outside the dialect may parse it.
//
// VideoJob 是一次已被受理的提交。Handle **不透明**——DashScope 的 task uuid、Google 自带
// `models/…/operations/…` 路径的 operation name。方言之外任何地方不得解析它。
type VideoJob struct {
	Provider string
	Handle   string
	Model    string
}

// VideoPhase is the closed set every provider's status vocabulary is normalized into.
type VideoPhase string

const (
	VideoQueued    VideoPhase = "queued"
	VideoRunning   VideoPhase = "running"
	VideoSucceeded VideoPhase = "succeeded"
	VideoFailed    VideoPhase = "failed"
)

// VideoStatus is one poll's answer. Artifact is set only on VideoSucceeded.
type VideoStatus struct {
	Phase    VideoPhase
	Artifact *VideoArtifact
	Reason   string // provider-supplied failure text (already bounded)
}

// VideoArtifact is a FETCHABLE reference, not a URL. The distinction is the single most
// error-prone thing in this family: DashScope hands back a bare pre-signed OSS URL that an
// Authorization header can make the object store REJECT, while Google's file URI requires the API
// key. "Got a URL, therefore I can download it" is false for both, in opposite directions.
//
// VideoArtifact 是一个**可取回的引用**、不是一个 URL。这个区别是本族里最容易写错的一处:DashScope
// 返回的是裸预签名 OSS URL,带上 Authorization 反而可能被对象存储**拒绝**;而 Google 的文件 URI
// **必须**带 API key。「拿到 URL 就能下」这句话对两家都不成立,且不成立的方向相反。
type VideoArtifact struct {
	URL     string
	Headers map[string]string
}

// VideoRequest is the neutral ask. Each dialect translates it and validates LOCALLY before
// spending anything — asking Veo for 15 seconds must fail here, not after an upstream charge.
//
// VideoRequest 是中立请求。各方言翻译它,并在花钱**之前**本地校验——向 Veo 要 15 秒必须在这里失败,
// 而不是在上游收了一次钱之后。
type VideoRequest struct {
	Prompt      string
	DurationSec int
	Aspect      string // "landscape" | "portrait" | "square" — the tool's enum
	Resolution  string // "720p" | "1080p"
	// FirstFrame turns text-to-video into IMAGE-to-video (WRK-082 H9). Nil = text-to-video, the
	// original shape. It is a data URL rather than a link for the same reason the image editor's
	// source is: an attachment has no address upstream can fetch, and minting one would be a
	// hosting responsibility plus an SSRF surface bought for nothing.
	//
	// **Aspect and resolution stop being ours to choose when this is set** — the clip inherits the
	// frame's geometry, so passing our enum alongside would be asking the upstream to letterbox or
	// crop the very image the user handed us.
	//
	// FirstFrame 把「文生视频」变成**图生视频**(H9)。nil = 文生视频、原本那一形。它是 data URL 而非
	// 链接,理由与改图的源图相同:附件没有上游取得到的地址,而凭空造一个是白买托管责任加 SSRF 面。
	//
	// **它一旦设定,aspect 与 resolution 就不再由我们决定**——片子继承首帧的几何,此时还把我们的枚举
	// 递过去,等于要求上游对用户刚递来的那张图做信箱边或裁切。
	FirstFrame *DataURL
}

// VideoPollInterval is each provider's documented polling cadence. DashScope's 15s is an explicit
// documentation recommendation (polling harder risks rate limiting); Google's 10s comes from its
// own examples. Using one number for both would be picking a cadence neither vendor described.
//
// VideoPollInterval 是各家文档给的轮询节奏。DashScope 的 15s 是文档**明写**的建议(压更紧有被限流
// 风险);Google 的 10s 出自它自己的示例。给两家用同一个数,等于选一个两家都没描述过的节奏。
func VideoPollInterval(provider string) time.Duration {
	switch provider {
	case "qwen":
		return 15 * time.Second
	case "google":
		return 10 * time.Second
	case "anselm":
		// The gateway forwards to wan, so wan's cadence is the real one — polling the
		// gateway harder only makes the gateway poll DashScope harder.
		// 网关转发给 wan,故真正的节奏是 wan 的——把网关轮询得更紧,只会让网关把 DashScope 轮询得更紧。
		return 15 * time.Second
	default:
		return 15 * time.Second
	}
}

// VideoMaxDuration is each provider's hard ceiling in seconds.
func VideoMaxDuration(provider string) int {
	// One route, one cap (WRK-085): the managed gateway forwards to wan, whose ceiling is 15s. The
	// parameter stays because the CLAMP is what matters — a caller asking for 30 seconds must get a
	// receipt reporting what was actually made, not what was asked.
	// 一条路一个上限(WRK-085):受管网关转发给 wan,顶棚 15 秒。参数保留是因为**钳制**才是要点——一个
	// 要 30 秒的调用方,拿到的 receipt 必须报**真做出来的**那个数,不是他要的那个。
	if provider == "anselm" {
		return 15
	}
	return 0
}

// ── Anselm gateway (managed free tier) ───────────────────────────────────────

// SubmitVideoAnselm submits through the managed gateway. Two things differ from every direct
// dialect and both matter:
//
//  1. The answer is **202**, not 200 — nothing has been generated yet, and the gateway says so in
//     the status line rather than making the client read a field.
//  2. The returned id is a **signed handle**, not the upstream task id. It only verifies for the
//     install that paid for it, so it is opaque here in the strongest sense: this code could not
//     take it apart even if it wanted to.
//
// SubmitVideoAnselm 经受管网关提交。有两处与所有直连方言不同,且两处都重要:
//
//  1. 答案是 **202** 而非 200——此刻什么都还没生成,网关在状态行里就说了,不必让客户端去读字段。
//  2. 返回的 id 是**签名句柄**、不是上游 task id。它只对付过钱的那个 install 验得过,故它在这里是
//     最强意义上的不透明:本段代码**就算想**也拆不开它。
func SubmitVideoAnselm(ctx context.Context, httpc *http.Client, baseURL, installID string, req VideoRequest) (VideoJob, error) {
	if req.DurationSec < 2 || req.DurationSec > VideoMaxDuration("anselm") {
		return VideoJob{}, fmt.Errorf("%w: duration must be 2-%d seconds", ErrVideoGenFailed, VideoMaxDuration("anselm"))
	}
	payload := map[string]any{
		"prompt":     req.Prompt,
		"seconds":    req.DurationSec,
		"aspect":     anselmAspect(req.Aspect),
		"resolution": anselmResolution(req.Resolution),
	}
	endpoint := "/videos/generations"
	if req.FirstFrame != nil {
		// H9 has a distinct managed route and request shape. Sending the first frame to the text
		// route silently discards the user's source and makes animate_image look like a successful
		// text-to-video call until the provider rejects the incomplete intent.
		// H9 的受管路由与请求形状是独立的。把首帧送到文生视频路由会静默丢掉用户源图，让
		// animate_image 看起来像一次成功的文生视频，直到上游因意图不完整而拒绝。
		payload["image"] = req.FirstFrame.String()
		endpoint = "/videos/animations"
	}
	body, _ := json.Marshal(payload)
	httpReq, err := newVideoRequest(ctx, strings.TrimRight(baseURL, "/")+endpoint, body)
	if err != nil {
		return VideoJob{}, err
	}
	httpReq.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	raw, err := doVideoRequestAccepting(httpc, httpReq, "anselm", http.StatusAccepted)
	if err != nil {
		return VideoJob{}, err
	}
	var wire struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || strings.TrimSpace(wire.ID) == "" {
		return VideoJob{}, fmt.Errorf("%w: gateway accepted nothing (no handle)", ErrVideoGenFailed)
	}
	return VideoJob{Provider: "anselm", Handle: wire.ID}, nil
}

// PollVideoAnselm reads one handle's state. The gateway already normalized the vendor's six-word
// vocabulary into four, so this reads its OWN contract rather than re-deriving DashScope's — that
// is the entire reason the gateway publishes a closed set instead of forwarding the vendor's.
//
// PollVideoAnselm 读一个句柄的状态。网关已经把厂商的六字词表归一成四个,故这里读的是**它自己的**
// 契约、而不是再推一遍 DashScope 的——网关发布一个封闭集而非转发厂商的,理由**就是**这个。
func PollVideoAnselm(ctx context.Context, httpc *http.Client, baseURL, installID, handle string) (VideoStatus, error) {
	u := strings.TrimRight(baseURL, "/") + "/videos/" + url.PathEscape(handle)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return VideoStatus{}, fmt.Errorf("%w: %v", ErrVideoGenFailed, err)
	}
	httpReq.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	raw, err := doVideoRequest(httpc, httpReq, "anselm")
	if err != nil {
		return VideoStatus{}, err
	}
	var wire struct {
		Status string `json:"status"`
		URL    string `json:"url"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil {
		return VideoStatus{}, fmt.Errorf("%w: gateway status unreadable", ErrVideoGenFailed)
	}
	switch wire.Status {
	case "pending":
		return VideoStatus{Phase: VideoQueued}, nil
	case "succeeded":
		if wire.URL == "" {
			return VideoStatus{}, fmt.Errorf("%w: gateway succeeded with no artifact url", ErrVideoGenFailed)
		}
		// A bare pre-signed OSS URL relayed by the gateway: NO headers, and in particular NOT the
		// install id — sending it to the object store would be both useless and a leak.
		// 由网关直通的裸预签名 OSS URL:**不带**任何头,尤其**不带** install id——把它送给对象存储
		// 既没用、又是一次泄漏。
		return VideoStatus{Phase: VideoSucceeded, Artifact: &VideoArtifact{URL: wire.URL}}, nil
	case "failed":
		// The gateway deliberately does not relay the upstream failure text (its own redaction
		// rule), so there is no reason to invent one here.
		// 网关刻意不转发上游失败文本(它自己的脱敏律),故这里没有理由编一个出来。
		return VideoStatus{Phase: VideoFailed, Reason: "the managed gateway reported a failed generation"}, nil
	default:
		return VideoStatus{Phase: VideoRunning}, nil
	}
}

// anselmAspect / anselmResolution translate the tool's enum into the gateway's wire vocabulary.
// The gateway takes shape WORDS rather than ratios precisely so this stays a rename and never a
// ratio computation.
//
// anselmAspect / anselmResolution 把工具的 enum 译成网关的线缆词表。网关收**形状词**而非比例,正是
// 为了让这里永远只是改名、而不是算比例。
func anselmAspect(aspect string) string {
	switch aspect {
	case "portrait", "square":
		return aspect
	default:
		return "landscape"
	}
}

func anselmResolution(res string) string {
	if res == "1080p" {
		return "1080p"
	}
	return "720p"
}

// ── DashScope (wan) ──────────────────────────────────────────────────────────

func dashScopeResolution(res string) string {
	if res == "1080p" {
		return "1080P"
	}
	return "720P"
}

func dashScopeRatio(aspect string) string {
	switch aspect {
	case "portrait":
		return "9:16"
	case "square":
		return "1:1"
	default:
		return "16:9"
	}
}

func dashScopeSize(res, aspect string) string {
	if res == "1080p" {
		switch aspect {
		case "portrait":
			return "1080*1920"
		case "square":
			return "1440*1440"
		default:
			return "1920*1080"
		}
	}
	switch aspect {
	case "portrait":
		return "720*1280"
	case "square":
		return "960*960"
	default:
		return "1280*720"
	}
}

// ── Gemini (Veo) ─────────────────────────────────────────────────────────────

func geminiAspect(aspect string) string {
	if aspect == "portrait" {
		return "9:16"
	}
	return "16:9" // Veo has no square form; landscape is the honest fallback / Veo 无方形,横向是诚实兜底
}

// ── shared ───────────────────────────────────────────────────────────────────

// FetchVideoArtifact downloads a finished artifact with the reference's OWN headers. It is https
// only, capped, and sniffs the mime — the same iron rules the image downloader follows.
//
// FetchVideoArtifact 用引用**自带**的头下载已完成产物。仅 https、有上限、嗅 mime——与图像下载器同一套铁律。
func FetchVideoArtifact(ctx context.Context, httpc *http.Client, ref *VideoArtifact) (GeneratedVideo, error) {
	if ref == nil || ref.URL == "" {
		return GeneratedVideo{}, fmt.Errorf("%w: no artifact to fetch", ErrVideoGenFailed)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, ref.URL, nil)
	if err != nil {
		return GeneratedVideo{}, fmt.Errorf("%w: %v", ErrVideoGenFailed, err)
	}
	if !strings.EqualFold(req.URL.Scheme, "https") || req.URL.Host == "" {
		return GeneratedVideo{}, fmt.Errorf("%w: artifact url malformed", ErrVideoGenFailed)
	}
	for k, v := range ref.Headers {
		req.Header.Set(k, v)
	}
	resp, err := httpc.Do(req)
	if err != nil {
		return GeneratedVideo{}, fmt.Errorf("%w: artifact download: %v", ErrVideoGenFailed, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return GeneratedVideo{}, fmt.Errorf("%w: artifact download: HTTP %d", ErrVideoGenFailed, resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, videoMaxBytes+1))
	if err != nil || len(data) == 0 {
		return GeneratedVideo{}, fmt.Errorf("%w: artifact download: %v", ErrVideoGenFailed, err)
	}
	if len(data) > videoMaxBytes {
		return GeneratedVideo{}, fmt.Errorf("%w: artifact exceeds the size cap", ErrVideoGenFailed)
	}
	mime := resp.Header.Get("Content-Type")
	if mime == "" || strings.HasPrefix(mime, "application/octet-stream") {
		mime = http.DetectContentType(data)
	}
	if i := strings.IndexByte(mime, ';'); i > 0 {
		mime = strings.TrimSpace(mime[:i])
	}
	return GeneratedVideo{Bytes: data, Mime: mime}, nil
}

func newVideoRequest(ctx context.Context, u string, body []byte) (*http.Request, error) {
	req, err := newImageRequest(ctx, u, body)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrVideoGenFailed, err)
	}
	return req, nil
}

func doVideoRequest(httpc *http.Client, req *http.Request, provider string) ([]byte, error) {
	return doVideoRequestAccepting(httpc, req, provider, http.StatusOK)
}

// doVideoRequestAccepting is doVideoRequest with an explicit success code. The managed submit
// answers 202 — "accepted, nothing generated yet" — and treating that as a failure would turn the
// single most correct thing the gateway does into an error.
//
// doVideoRequestAccepting 是带显式成功码的 doVideoRequest。受管提交答 **202**——「已受理,尚未生成」
// ——把它当失败,等于把网关做得最对的那一件事变成一个错误。
func doVideoRequestAccepting(httpc *http.Client, req *http.Request, provider string, wantStatus int) ([]byte, error) {
	resp, err := httpc.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %s: %v", ErrVideoGenFailed, provider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, fmt.Errorf("%w: %s: read: %v", ErrVideoGenFailed, provider, err)
	}
	if resp.StatusCode != wantStatus {
		excerpt := strings.TrimSpace(string(raw))
		if len(excerpt) > 300 {
			excerpt = excerpt[:300] + "…"
		}
		return nil, fmt.Errorf("%w: %s: HTTP %d: %s", ErrVideoGenFailed, provider, resp.StatusCode, excerpt)
	}
	return raw, nil
}

// boundedReason joins a provider's failure code + message into one bounded human-facing line.
//
// boundedReason 把上游失败码 + 文本拼成一行有界的人话。
func boundedReason(code, message string) string {
	r := strings.TrimSpace(strings.TrimSpace(code) + " " + strings.TrimSpace(message))
	if r == "" {
		return "upstream reported a failure without a reason"
	}
	if len(r) > 300 {
		r = r[:300] + "…"
	}
	return r
}
