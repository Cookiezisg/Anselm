package handlers

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"
	"mime"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	mediaapp "github.com/sunweilin/anselm/backend/internal/app/media"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// AttachmentHandler serves the 4 /api/v1/attachments/* endpoints: multipart upload, metadata
// fetch, raw-bytes download, and soft-delete. Bytes are stored content-addressed (CAS) and
// reach the LLM via chat resolving attachment ids into provider content parts.
//
// AttachmentHandler 提供 /api/v1/attachments/* 的 4 端点：multipart 上传、元数据取、原始字节下载、
// 软删。字节内容寻址（CAS）存储，经 chat 把 id 解析成 provider content part 进 LLM。
type AttachmentHandler struct {
	svc   *attachmentapp.Service
	media AttachmentPreparation
	log   *zap.Logger

	playbackMu       sync.Mutex
	playbackLeases   map[string]attachmentPlaybackLease
	playbackLeaseTTL time.Duration
	now              func() time.Time
}

// AttachmentPreparation is the optional media-readiness sidecar attached to upload/get responses.
//
// AttachmentPreparation 是 upload/get 响应可附带的媒体准备状态侧车。
type AttachmentPreparation interface {
	Preparation(ctx context.Context, attachmentID string) (mediaapp.Preparation, error)
	CancelPreparation(ctx context.Context, attachmentID string) (mediaapp.Preparation, error)
	RetryPreparation(ctx context.Context, attachmentID string) (mediaapp.Preparation, error)
}

// NewAttachmentHandler constructs the handler.
//
// NewAttachmentHandler 构造 handler。
func NewAttachmentHandler(svc *attachmentapp.Service, media AttachmentPreparation, log *zap.Logger) *AttachmentHandler {
	if log == nil {
		log = zap.NewNop()
	}
	log = log.Named("handlers.attachment")
	return &AttachmentHandler{
		svc:              svc,
		media:            media,
		log:              log,
		playbackLeaseTTL: playbackLeaseTTLFromEnv(log),
	}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *AttachmentHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/attachments", h.Upload)
	mux.HandleFunc("GET /api/v1/attachments/{id}", h.Get)
	mux.HandleFunc("GET /api/v1/attachments/{id}/content", h.Content)
	mux.HandleFunc("POST /api/v1/attachments/{id}/playback-lease", h.CreatePlaybackLease)
	mux.HandleFunc("GET /api/v1/attachment-playback/{token}", h.PlaybackContent)
	mux.HandleFunc("POST /api/v1/attachments/{id}/preparation/cancel", h.CancelPreparation)
	mux.HandleFunc("POST /api/v1/attachments/{id}/preparation/retry", h.RetryPreparation)
	mux.HandleFunc("DELETE /api/v1/attachments/{id}", h.Delete)
}

// uploadHeadroom is the slack above MaxBytes the request body may use (multipart framing
// overhead); the file itself is re-checked against MaxBytes in the Service.
//
// uploadHeadroom 是请求体在 MaxBytes 之上的余量（multipart 封装开销）；文件本身在 Service 再按
// MaxBytes 复检。
const uploadHeadroom = 1 << 20

const rigPlaybackLeaseTTLEnv = "ANSELM_RIG_PLAYBACK_LEASE_TTL_MS"

// playbackLeaseTTLFromEnv is a testend-only seam. Production keeps the five-minute default;
// the acceptance rig may shorten it so a real native player can cross expiry without a five-minute
// idle. An invalid value is ignored rather than changing the production safety default.
func playbackLeaseTTLFromEnv(log *zap.Logger) time.Duration {
	raw := strings.TrimSpace(os.Getenv(rigPlaybackLeaseTTLEnv))
	if raw == "" {
		return 0
	}
	ms, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || ms <= 0 {
		log.Warn("invalid rig playback lease TTL; using production default", zap.String("value", raw))
		return 0
	}
	return time.Duration(ms) * time.Millisecond
}

// Upload handles POST /api/v1/attachments — a multipart form with a single "file" field.
//
// Upload 处理 POST /api/v1/attachments —— 单 "file" 字段的 multipart 表单。
func (h *AttachmentHandler) Upload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, int64(limitspkg.Current().Guards.AttachmentMaxMB)<<20+uploadHeadroom)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrTooLarge)
		} else {
			responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrBadUpload)
		}
		return
	}
	// Files above maxMemory are backed by temporary multipart files; remove them after this request.
	// 超过 maxMemory 的文件会落到 multipart 临时文件；请求结束后必须清掉。
	defer r.MultipartForm.RemoveAll()
	file, header, err := r.FormFile("file")
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrBadUpload)
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrBadUpload)
		return
	}

	// Trust the declared part type; sniff when absent or generic so kind classification works.
	// 信任声明的 part 类型；缺失或泛型时嗅探，使 kind 分类生效。
	mime := header.Header.Get("Content-Type")
	if mime == "" || mime == "application/octet-stream" {
		mime = http.DetectContentType(data)
	}

	a, err := h.svc.Upload(r.Context(), header.Filename, mime, data)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, h.response(r.Context(), a))
}

func (h *AttachmentHandler) Get(w http.ResponseWriter, r *http.Request) {
	a, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, h.response(r.Context(), a))
}

// Content streams the raw blob bytes with the stored mime type — for the frontend to preview /
// download the file.
//
// Content 以存储的 mime 类型流出原始 blob 字节——供前端预览/下载。
func (h *AttachmentHandler) Content(w http.ResponseWriter, r *http.Request) {
	a, data, err := h.svc.Download(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	mime := a.MimeType
	if mime == "" {
		mime = "application/octet-stream"
	}
	w.Header().Set("Content-Type", mime)
	// Inline preview; the standard MIME serializer safely encodes user-controlled filenames.
	// 内联预览；标准 MIME 序列化器安全编码用户可控文件名。
	w.Header().Set("Content-Disposition", attachmentContentDisposition(a.Filename))
	// http.ServeContent, NOT a hand-written Write: it answers RANGE requests (206 + Content-Range),
	// which is not a nicety — Apple's AVFoundation opens every media URL with `Range: bytes=0-1` and
	// refuses a server that cannot answer it (CoreMediaErrorDomain -12939, observed on a real run).
	// Seeking is the same mechanism: without ranges a player can only ever stream from byte zero.
	//
	// The previous hand-rolled version worked only because libmpv happens to download linearly. That
	// is exactly the kind of assumption that does not survive a backend swap, and it did not
	// (WRK-082 H5.5R). ServeContent also brings conditional requests and correct 416 handling for
	// free — all of it standard library, none of it ours to maintain (原则 #8).
	//
	// 用 http.ServeContent、**不是**手写 Write:它应答 **Range** 请求(206 + Content-Range),而这不是
	// 锦上添花——Apple 的 AVFoundation 打开每个媒体 URL 时都先发 `Range: bytes=0-1`,答不上来就拒绝
	// (CoreMediaErrorDomain -12939,真机实测)。**拖进度条是同一套机制**:没有 range,播放器永远只能从
	// 第 0 字节顺流。
	//
	// 之前那版手搓的能用,只是因为 libmpv 恰好线性下载。那正是**换底座就活不过来**的那类假设,而它确实
	// 没活过来(H5.5R)。ServeContent 还顺带带来条件请求与正确的 416 —— 全是标准库的,没有一行归我们
	// 维护(原则 #8)。
	http.ServeContent(w, r, a.Filename, a.CreatedAt, bytes.NewReader(data))
}

// CreatePlaybackLease mints a short-lived loopback URL for audio playback. The mint endpoint is still
// protected by the normal bearer + workspace middleware; only the returned fetch URL is bearerless so
// platform audio players that cannot attach headers can stream it. The opaque token is bound to the
// current workspace and attachment id, lives only in memory, and expires quickly.
//
// CreatePlaybackLease 签发短期本机音频播放 URL。签发端点仍受常规 bearer + workspace 中间件保护；只有返回
// 的 fetch URL 无 bearer，以便无法加 header 的平台播放器流式读取。opaque token 绑定当前 workspace 与
// attachment id，仅驻内存，短期过期。
func (h *AttachmentHandler) CreatePlaybackLease(w http.ResponseWriter, r *http.Request) {
	wsID, err := reqctxpkg.RequireWorkspaceID(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	a, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if a.Kind != attachmentdomain.KindAudio {
		responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrPlaybackUnsupported)
		return
	}

	token, err := randomPlaybackToken()
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	expiresAt := h.clock().Add(h.leaseTTL())
	h.playbackMu.Lock()
	if h.playbackLeases == nil {
		h.playbackLeases = make(map[string]attachmentPlaybackLease)
	}
	h.sweepExpiredPlaybackLeasesLocked(h.clock())
	h.playbackLeases[token] = attachmentPlaybackLease{
		AttachmentID: a.ID,
		WorkspaceID:  wsID,
		ExpiresAt:    expiresAt,
	}
	h.playbackMu.Unlock()

	responsehttpapi.Success(w, http.StatusOK, attachmentPlaybackLeaseResponse{
		URL:       "http://" + r.Host + "/api/v1/attachment-playback/" + token,
		ExpiresAt: expiresAt,
	})
}

// PlaybackContent serves a previously minted audio playback lease. This route is deliberately exempt
// from bearer/workspace middleware; all authorization comes from the high-entropy short-lived token and
// the still-global loopback Host gate. It uses http.ServeContent so Range requests from native audio
// stacks get correct 206/Content-Range semantics without the handler slicing them by hand.
//
// HONEST LIMIT: svc.Download still materialises the WHOLE blob, so every request — including every
// Range request a seeking player makes — re-reads the entire object into memory. That is acceptable
// for a local single-user desktop app with modest audio, but this is NOT streaming: real streaming
// needs an io.ReadSeeker seam over the CAS file. Do not describe this path as a memory optimisation.
//
// PlaybackContent 输出已签发的音频播放租约。该路由刻意豁免 bearer/workspace 中间件；授权来自高熵短期 token
// 和仍全局生效的 loopback Host 门。用 http.ServeContent 让原生音频栈的 Range 拿到正确 206/Content-Range，
// 而非手工切片。**诚实边界**：svc.Download 仍会把整份 blob 读进内存，故每个请求（包括播放器 seek 时发的
// 每个 Range 请求）都重读整个对象。本地单用户桌面端的中等音频可接受，但这**不是流式**——真流式需要在 CAS
// 上开一道 io.ReadSeeker 缝。不要把这条路径描述成省内存的优化。
func (h *AttachmentHandler) PlaybackContent(w http.ResponseWriter, r *http.Request) {
	lease, ok := h.takePlaybackLease(r.PathValue("token"))
	if !ok {
		responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrNotFound)
		return
	}
	ctx := reqctxpkg.SetWorkspaceID(r.Context(), lease.WorkspaceID)
	a, data, err := h.svc.Download(ctx, lease.AttachmentID)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if a.Kind != attachmentdomain.KindAudio {
		responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrPlaybackUnsupported)
		return
	}
	mime := a.MimeType
	if mime == "" {
		mime = "application/octet-stream"
	}
	w.Header().Set("Content-Type", mime)
	w.Header().Set("Content-Disposition", attachmentContentDisposition(a.Filename))
	http.ServeContent(w, r, a.Filename, a.CreatedAt, bytes.NewReader(data))
}

// attachmentContentDisposition uses the standard MIME serializer so user filenames cannot inject
// header delimiters and Unicode names remain representable to native preview/download clients.
// attachmentContentDisposition 使用标准 MIME 序列化器，防止用户文件名注入 header 分隔符，并让 Unicode
// 文件名仍能被原生预览/下载客户端表示。
func attachmentContentDisposition(filename string) string {
	return mime.FormatMediaType("inline", map[string]string{"filename": filename})
}

func (h *AttachmentHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

func (h *AttachmentHandler) CancelPreparation(w http.ResponseWriter, r *http.Request) {
	h.mutatePreparation(w, r, "cancel")
}

func (h *AttachmentHandler) RetryPreparation(w http.ResponseWriter, r *http.Request) {
	h.mutatePreparation(w, r, "retry")
}

func (h *AttachmentHandler) mutatePreparation(w http.ResponseWriter, r *http.Request, op string) {
	if h.media == nil {
		responsehttpapi.Success(w, http.StatusServiceUnavailable, mediaapp.Preparation{
			Status:    mediaapp.PreparationStatusUnavailable,
			Phase:     "unavailable",
			ErrorCode: "MEDIA_PREPARATION_UNAVAILABLE",
		})
		return
	}
	var (
		prep mediaapp.Preparation
		err  error
	)
	switch op {
	case "cancel":
		prep, err = h.media.CancelPreparation(r.Context(), r.PathValue("id"))
	case "retry":
		prep, err = h.media.RetryPreparation(r.Context(), r.PathValue("id"))
	default:
		responsehttpapi.FromDomainError(w, h.log, mediadomain.ErrInvalidRequest)
		return
	}
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, prep)
}

type attachmentResponse struct {
	*attachmentdomain.Attachment
	Preparation *mediaapp.Preparation `json:"preparation,omitempty"`
}

func (h *AttachmentHandler) response(ctx context.Context, a *attachmentdomain.Attachment) attachmentResponse {
	out := attachmentResponse{Attachment: a}
	if h.media == nil || a == nil {
		return out
	}
	prep, err := h.media.Preparation(ctx, a.ID)
	if err != nil {
		h.log.Warn("attachment: media preparation unavailable", zap.String("attachment_id", a.ID), zap.Error(err))
		prep = mediaapp.Preparation{Status: mediaapp.PreparationStatusUnavailable, Phase: "unavailable", ErrorCode: "MEDIA_PREPARATION_UNAVAILABLE"}
	}
	out.Preparation = &prep
	return out
}

type attachmentPlaybackLease struct {
	AttachmentID string
	WorkspaceID  string
	ExpiresAt    time.Time
}

type attachmentPlaybackLeaseResponse struct {
	URL       string    `json:"url"`
	ExpiresAt time.Time `json:"expiresAt"`
}

const defaultAttachmentPlaybackLeaseTTL = 5 * time.Minute

func (h *AttachmentHandler) leaseTTL() time.Duration {
	if h.playbackLeaseTTL > 0 {
		return h.playbackLeaseTTL
	}
	return defaultAttachmentPlaybackLeaseTTL
}

func (h *AttachmentHandler) clock() time.Time {
	if h.now != nil {
		return h.now()
	}
	return time.Now()
}

func (h *AttachmentHandler) takePlaybackLease(token string) (attachmentPlaybackLease, bool) {
	now := h.clock()
	h.playbackMu.Lock()
	defer h.playbackMu.Unlock()
	if h.playbackLeases == nil {
		return attachmentPlaybackLease{}, false
	}
	h.sweepExpiredPlaybackLeasesLocked(now)
	lease, ok := h.playbackLeases[token]
	return lease, ok
}

func (h *AttachmentHandler) sweepExpiredPlaybackLeasesLocked(now time.Time) {
	for token, lease := range h.playbackLeases {
		if !lease.ExpiresAt.After(now) {
			delete(h.playbackLeases, token)
		}
	}
}

func randomPlaybackToken() (string, error) {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b[:]), nil
}
