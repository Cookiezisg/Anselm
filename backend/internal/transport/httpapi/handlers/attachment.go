package handlers

import (
	"context"
	"io"
	"net/http"
	"strconv"
	"strings"

	"go.uber.org/zap"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	mediaapp "github.com/sunweilin/anselm/backend/internal/app/media"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
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
	return &AttachmentHandler{svc: svc, media: media, log: log.Named("handlers.attachment")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *AttachmentHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/attachments", h.Upload)
	mux.HandleFunc("GET /api/v1/attachments/{id}", h.Get)
	mux.HandleFunc("GET /api/v1/attachments/{id}/content", h.Content)
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

// Upload handles POST /api/v1/attachments — a multipart form with a single "file" field.
//
// Upload 处理 POST /api/v1/attachments —— 单 "file" 字段的 multipart 表单。
func (h *AttachmentHandler) Upload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, int64(limitspkg.Current().Guards.AttachmentMaxMB)<<20+uploadHeadroom)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		responsehttpapi.FromDomainError(w, h.log, attachmentdomain.ErrTooLarge)
		return
	}
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
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	// inline preview; strip quotes from the filename so the header can't be broken.
	// 内联预览；从文件名剥引号，避免破坏 header。
	w.Header().Set("Content-Disposition", `inline; filename="`+strings.ReplaceAll(a.Filename, `"`, "")+`"`)
	_, _ = w.Write(data)
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
