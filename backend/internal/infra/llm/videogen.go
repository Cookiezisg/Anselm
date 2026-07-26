package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Desktop-side video-generation dialects (WRK-082 批D). Unlike image and speech, EVERY provider is
// asynchronous: submit → poll a handle → fetch the artifact. The shape below is therefore three
// verbs, not one, and the poll loop is shared while the three verbs differ per provider.
//
// Two dialects, not three. OpenAI's Videos API (Sora) is NOT implemented: it was announced for
// removal on 2026-09-24 (代拍 D2). A driver with eight weeks left would be built, reviewed, and
// deleted without ever earning its keep — and worse, its two unique traits (a real progress
// percentage, a separate `/content` sub-endpoint) would have shaped this abstraction around a
// provider that is leaving.
//
// 桌面侧视频生成方言(批D)。与图像、语音不同,**每一家都是异步的**:提交 → 轮询句柄 → 取回产物。
// 故下面是三个动词而非一个:轮询循环共用,三个动词各家不同。
//
// **两个方言、不是三个**。OpenAI 的 Videos API(Sora)**不实现**:它已公告 2026-09-24 下线(代拍 D2)。
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
	default:
		return 15 * time.Second
	}
}

// VideoMaxDuration is each provider's hard ceiling in seconds.
func VideoMaxDuration(provider string) int {
	switch provider {
	case "qwen":
		return 15
	case "google":
		return 8
	default:
		return 8
	}
}

// ── DashScope (wan) ──────────────────────────────────────────────────────────

// SubmitVideoDashScope submits one generation. The `X-DashScope-Async: enable` header is MANDATORY
// — without it the API answers "current user api does not support synchronous calls", because the
// video family has no synchronous form at all.
//
// SubmitVideoDashScope 提交一次生成。`X-DashScope-Async: enable` 头是**强制**的——缺了它 API 会答
// 「current user api does not support synchronous calls」,因为视频族**根本没有**同步形态。
func SubmitVideoDashScope(ctx context.Context, httpc *http.Client, nativeBase, key, model string, req VideoRequest) (VideoJob, error) {
	if req.DurationSec < 2 || req.DurationSec > VideoMaxDuration("qwen") {
		return VideoJob{}, fmt.Errorf("%w: duration must be 2-%d seconds for %s", ErrVideoGenFailed, VideoMaxDuration("qwen"), model)
	}
	params := map[string]any{
		"duration":  req.DurationSec,
		"watermark": false,
	}
	// wan2.7 replaced the single `size` with resolution + ratio; 2.6 and earlier still take `size`.
	// Same provider, two shapes — branch on the model, do not guess.
	// wan2.7 把单一 `size` 换成了 resolution + ratio;2.6 及更早仍吃 `size`。同一家两种形,按模型分支、不猜。
	if strings.HasPrefix(model, "wan2.7") || strings.HasPrefix(model, "happyhorse") {
		params["resolution"] = dashScopeResolution(req.Resolution)
		params["ratio"] = dashScopeRatio(req.Aspect)
	} else {
		params["size"] = dashScopeSize(req.Resolution, req.Aspect)
	}
	body, _ := json.Marshal(map[string]any{
		"model":      model,
		"input":      map[string]any{"prompt": req.Prompt},
		"parameters": params,
	})
	httpReq, err := newVideoRequest(ctx, strings.TrimRight(nativeBase, "/")+"/api/v1/services/aigc/video-generation/video-synthesis", body)
	if err != nil {
		return VideoJob{}, err
	}
	httpReq.Header.Set("Authorization", "Bearer "+key)
	httpReq.Header.Set("X-DashScope-Async", "enable")
	raw, err := doVideoRequest(httpc, httpReq, "qwen")
	if err != nil {
		return VideoJob{}, err
	}
	var wire struct {
		Output struct {
			TaskID string `json:"task_id"`
		} `json:"output"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || wire.Output.TaskID == "" {
		return VideoJob{}, fmt.Errorf("%w: dashscope accepted nothing (no task id)", ErrVideoGenFailed)
	}
	return VideoJob{Provider: "qwen", Handle: wire.Output.TaskID, Model: model}, nil
}

// PollVideoDashScope reads one task's state. The poll request deliberately does NOT carry the
// async header — that header belongs to submission only.
//
// PollVideoDashScope 读一次任务状态。轮询请求刻意**不带**异步头——那个头只属于提交。
func PollVideoDashScope(ctx context.Context, httpc *http.Client, nativeBase, key, taskID string) (VideoStatus, error) {
	u := strings.TrimRight(nativeBase, "/") + "/api/v1/tasks/" + taskID
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return VideoStatus{}, fmt.Errorf("%w: %v", ErrVideoGenFailed, err)
	}
	httpReq.Header.Set("Authorization", "Bearer "+key)
	raw, err := doVideoRequest(httpc, httpReq, "qwen")
	if err != nil {
		return VideoStatus{}, err
	}
	var wire struct {
		Output struct {
			TaskStatus string `json:"task_status"`
			VideoURL   string `json:"video_url"`
			Code       string `json:"code"`
			Message    string `json:"message"`
		} `json:"output"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil {
		return VideoStatus{}, fmt.Errorf("%w: dashscope status unreadable", ErrVideoGenFailed)
	}
	switch wire.Output.TaskStatus {
	case "PENDING":
		return VideoStatus{Phase: VideoQueued}, nil
	case "RUNNING":
		return VideoStatus{Phase: VideoRunning}, nil
	case "SUCCEEDED":
		if wire.Output.VideoURL == "" {
			return VideoStatus{}, fmt.Errorf("%w: dashscope succeeded with no artifact url", ErrVideoGenFailed)
		}
		// A bare pre-signed OSS URL: NO headers. Sending Authorization here can make the object
		// store reject the request. 裸预签名 OSS URL:**不带**头。这里送 Authorization 可能被对象存储拒。
		return VideoStatus{Phase: VideoSucceeded, Artifact: &VideoArtifact{URL: wire.Output.VideoURL}}, nil
	case "FAILED", "CANCELED", "UNKNOWN":
		return VideoStatus{Phase: VideoFailed, Reason: boundedReason(wire.Output.Code, wire.Output.Message)}, nil
	default:
		// An unrecognized status is treated as still running rather than as a failure: the closed
		// set is the VENDOR's, and a new member appearing must not turn a healthy job into an error.
		// 无法识别的状态按**仍在跑**处理、不按失败:封闭集是**厂商**的,新成员出现不该把一个健康任务变成错误。
		return VideoStatus{Phase: VideoRunning}, nil
	}
}

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

// SubmitVideoGemini submits one generation as a long-running operation. `durationSeconds` is a
// STRING on this wire, and 1080p forces exactly 8 seconds — both are validated here so an
// impossible combination fails before it costs anything.
//
// SubmitVideoGemini 以 long-running operation 提交一次生成。`durationSeconds` 在这条线缆上是**字符串**,
// 且 1080p **强制**恰好 8 秒——两者都在此校验,使不可能的组合在花钱之前就失败。
func SubmitVideoGemini(ctx context.Context, httpc *http.Client, baseURL, key, model string, req VideoRequest) (VideoJob, error) {
	dur := req.DurationSec
	if req.Resolution == "1080p" && dur != 8 {
		return VideoJob{}, fmt.Errorf("%w: %s requires exactly 8 seconds at 1080p", ErrVideoGenFailed, model)
	}
	if dur != 4 && dur != 6 && dur != 8 {
		return VideoJob{}, fmt.Errorf("%w: %s supports 4, 6 or 8 seconds (asked for %d)", ErrVideoGenFailed, model, dur)
	}
	params := map[string]any{
		"aspectRatio":      geminiAspect(req.Aspect),
		"durationSeconds":  strconv.Itoa(dur),
		"personGeneration": "allow_all",
	}
	if req.Resolution != "" {
		params["resolution"] = req.Resolution
	}
	body, _ := json.Marshal(map[string]any{
		"instances":  []any{map[string]any{"prompt": req.Prompt}},
		"parameters": params,
	})
	httpReq, err := newVideoRequest(ctx, strings.TrimRight(baseURL, "/")+"/models/"+model+":predictLongRunning", body)
	if err != nil {
		return VideoJob{}, err
	}
	httpReq.Header.Set("x-goog-api-key", key)
	raw, err := doVideoRequest(httpc, httpReq, "google")
	if err != nil {
		return VideoJob{}, err
	}
	var wire struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || wire.Name == "" {
		return VideoJob{}, fmt.Errorf("%w: gemini accepted nothing (no operation name)", ErrVideoGenFailed)
	}
	return VideoJob{Provider: "google", Handle: wire.Name, Model: model}, nil
}

// PollVideoGemini reads one operation. The handle ALREADY carries its `models/…/operations/…`
// path, so it is appended to `/v1beta/` directly — treating it as a bare id builds a 404.
//
// PollVideoGemini 读一次 operation。句柄**自带** `models/…/operations/…` 路径,故直接拼在 `/v1beta/`
// 之后——把它当裸 id 处理会拼出一个 404。
func PollVideoGemini(ctx context.Context, httpc *http.Client, baseURL, key, opName string) (VideoStatus, error) {
	u := strings.TrimRight(baseURL, "/") + "/" + strings.TrimPrefix(opName, "/")
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return VideoStatus{}, fmt.Errorf("%w: %v", ErrVideoGenFailed, err)
	}
	httpReq.Header.Set("x-goog-api-key", key)
	raw, err := doVideoRequest(httpc, httpReq, "google")
	if err != nil {
		return VideoStatus{}, err
	}
	var wire struct {
		Done  bool `json:"done"`
		Error *struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
		Response struct {
			GenerateVideoResponse struct {
				GeneratedSamples []struct {
					Video struct {
						URI string `json:"uri"`
					} `json:"video"`
				} `json:"generatedSamples"`
			} `json:"generateVideoResponse"`
		} `json:"response"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil {
		return VideoStatus{}, fmt.Errorf("%w: gemini operation unreadable", ErrVideoGenFailed)
	}
	if !wire.Done {
		return VideoStatus{Phase: VideoRunning}, nil
	}
	if wire.Error != nil {
		return VideoStatus{Phase: VideoFailed, Reason: boundedReason(strconv.Itoa(wire.Error.Code), wire.Error.Message)}, nil
	}
	for _, s := range wire.Response.GenerateVideoResponse.GeneratedSamples {
		if uri := strings.TrimSpace(s.Video.URI); uri != "" {
			// The file URI REQUIRES the API key on fetch — unlike DashScope's bare OSS link.
			// 该文件 URI 取回时**必须**带 API key——与 DashScope 的裸 OSS 链接相反。
			return VideoStatus{Phase: VideoSucceeded, Artifact: &VideoArtifact{
				URL: uri, Headers: map[string]string{"x-goog-api-key": key},
			}}, nil
		}
	}
	return VideoStatus{Phase: VideoFailed, Reason: "operation finished with no video"}, nil
}

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
	resp, err := httpc.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %s: %v", ErrVideoGenFailed, provider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, fmt.Errorf("%w: %s: read: %v", ErrVideoGenFailed, provider, err)
	}
	if resp.StatusCode != http.StatusOK {
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
