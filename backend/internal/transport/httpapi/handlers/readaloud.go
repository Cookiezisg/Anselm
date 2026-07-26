package handlers

import (
	"encoding/json"
	"net/http"

	"go.uber.org/zap"

	readaloudapp "github.com/sunweilin/anselm/backend/internal/app/readaloud"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// ReadAloudHandler serves the two read-aloud endpoints (WRK-082 批C, P10). It sits alongside
// `/api/v1/speech/asr` (transcription, the OTHER direction) under a distinct path segment so the
// two never share a URL: one turns a microphone into text, this one turns text into audio.
//
// ReadAloudHandler 提供朗读两端点(批C,P10)。它与 `/api/v1/speech/asr`(转写,**另一个**方向)并列
// 在不同路径段下,使两者永不共用 URL:一个把麦克风变成文字,这个把文字变成音频。
type ReadAloudHandler struct {
	svc *readaloudapp.Service
	log *zap.Logger
}

func NewReadAloudHandler(svc *readaloudapp.Service, log *zap.Logger) *ReadAloudHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &ReadAloudHandler{svc: svc, log: log.Named("handlers.readaloud")}
}

// Register wires the endpoints onto mux.
func (h *ReadAloudHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/read-aloud/availability", h.Availability)
	mux.HandleFunc("POST /api/v1/read-aloud:read", h.Read)
}

type readAloudRequest struct {
	Text  string `json:"text"`
	Voice string `json:"voice"`
}

// readAloudResponse hands back the ATTACHMENT, not bytes: playback already has a first-class path
// (the attachment playback lease), so returning an id reuses every player, cache and lifecycle
// rule that path already owns instead of inventing a second way to hear a file.
//
// readAloudResponse 交回**附件**而非字节:播放本就有一条一等路径(附件播放租约),故返回 id 即复用
// 那条路径已经拥有的全部播放器、缓存与生命周期规则,而不是再发明第二种听文件的方式。
type readAloudResponse struct {
	AttachmentID string `json:"attachmentId"`
	Filename     string `json:"filename"`
	MimeType     string `json:"mimeType"`
	SizeBytes    int64  `json:"sizeBytes"`
	Cached       bool   `json:"cached"`
}

type readAloudAvailability struct {
	Available bool `json:"available"`
}

// Availability answers whether the button should exist at all (honest absence: no key can speak →
// no read-aloud affordance, rather than a button that always fails).
//
// Availability 答按钮该不该存在(诚实缺席:没有 key 能说话就不给朗读入口,而不是一个按了必失败的钮)。
func (h *ReadAloudHandler) Availability(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, readAloudAvailability{Available: h.svc.Available(r.Context())})
}

// Read synthesizes (or serves from cache) and returns the artifact's attachment.
//
// Read 合成(或从缓存取)并返回产物附件。
func (h *ReadAloudHandler) Read(w http.ResponseWriter, r *http.Request) {
	var req readAloudRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, readaloudapp.ErrTextRequired)
		return
	}
	res, err := h.svc.Read(r.Context(), req.Text, req.Voice)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, readAloudResponse{
		AttachmentID: res.Attachment.ID,
		Filename:     res.Attachment.Filename,
		MimeType:     res.Attachment.MimeType,
		SizeBytes:    res.Attachment.SizeBytes,
		Cached:       res.Cached,
	})
}
