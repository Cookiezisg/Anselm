package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	speechapp "github.com/sunweilin/anselm/backend/internal/app/speech"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

const (
	speechMaxFrameBytes = 256 * 1024
	speechSessionMaxAge = 2 * time.Minute
	speechWriteWait     = 10 * time.Second
)

type ProofHeaders interface {
	ProofHeaders(ctx context.Context, method, rawURL, kid string, body []byte, refresh bool) (http.Header, error)
}

// SpeechHandler proxies the desktop microphone WebSocket to the managed Anselm
// gateway. The gateway owns Qwen ASR config and credentials; the sidecar owns
// the device-proof private key; the Flutter client only sees transcript events.
type SpeechHandler struct {
	svc    *speechapp.Service
	proof  ProofHeaders
	dialer *websocket.Dialer
	log    *zap.Logger
}

func NewSpeechHandler(svc *speechapp.Service, proof ProofHeaders, log *zap.Logger) *SpeechHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &SpeechHandler{svc: svc, proof: proof, dialer: websocket.DefaultDialer, log: log.Named("handlers.speech")}
}

func (h *SpeechHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/speech/asr", h.ASR)
}

func (h *SpeechHandler) ASR(w http.ResponseWriter, r *http.Request) {
	if h.svc == nil || h.proof == nil {
		responsehttpapi.FromDomainError(w, h.log, speechapp.ErrUnavailable)
		return
	}
	gw, err := h.svc.ManagedGateway(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	upURL, err := speechURL(gw.BaseURL, r.URL.Query().Get("language"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, speechapp.ErrUnavailable.WithCause(err))
		return
	}
	upConn, err := h.dialUpstream(r.Context(), upURL, gw.InstallID)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, speechapp.ErrUnavailable.WithCause(err))
		return
	}
	defer func() { _ = upConn.Close() }()

	upgrader := websocket.Upgrader{
		ReadBufferSize:  speechMaxFrameBytes,
		WriteBufferSize: speechMaxFrameBytes,
		CheckOrigin:     func(*http.Request) bool { return true },
	}
	downConn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer func() { _ = downConn.Close() }()
	downConn.SetReadLimit(speechMaxFrameBytes)
	deadline := time.Now().Add(speechSessionMaxAge)
	_ = downConn.SetReadDeadline(deadline)
	_ = upConn.SetReadDeadline(deadline.Add(speechWriteWait))
	client := &speechClientWriter{conn: downConn}

	upDone := make(chan struct{})
	go func() {
		defer close(upDone)
		for {
			mt, payload, err := upConn.ReadMessage()
			if err != nil {
				_ = client.writeJSON(map[string]string{"type": "error", "code": "SPEECH_UPSTREAM_CLOSED"})
				_ = downConn.SetReadDeadline(time.Now())
				return
			}
			if mt != websocket.TextMessage && mt != websocket.BinaryMessage {
				continue
			}
			if err := client.writeRaw(websocket.TextMessage, payload); err != nil {
				return
			}
			var evt struct {
				Type string `json:"type"`
			}
			if json.Unmarshal(payload, &evt) == nil && evt.Type == "session.finished" {
				_ = downConn.SetReadDeadline(time.Now())
				return
			}
		}
	}()

	for {
		select {
		case <-upDone:
			return
		default:
		}
		mt, payload, err := downConn.ReadMessage()
		if err != nil {
			return
		}
		switch mt {
		case websocket.BinaryMessage:
			if len(payload) == 0 || len(payload) > speechMaxFrameBytes {
				_ = client.writeJSON(map[string]string{"type": "error", "code": "SPEECH_AUDIO_FRAME_INVALID"})
				return
			}
			if err := writeSpeechRaw(upConn, websocket.BinaryMessage, payload); err != nil {
				return
			}
		case websocket.TextMessage:
			if !validSpeechControl(payload) {
				_ = client.writeJSON(map[string]string{"type": "error", "code": "SPEECH_CONTROL_INVALID"})
				return
			}
			if err := writeSpeechRaw(upConn, websocket.TextMessage, payload); err != nil {
				return
			}
		}
	}
}

func (h *SpeechHandler) dialUpstream(ctx context.Context, rawURL, installID string) (*websocket.Conn, error) {
	var last error
	for attempt := 0; attempt < 2; attempt++ {
		headers, err := h.proof.ProofHeaders(ctx, http.MethodGet, rawURL, installID, nil, attempt > 0)
		if err != nil {
			return nil, err
		}
		conn, resp, err := h.dialer.DialContext(ctx, rawURL, headers)
		if err == nil {
			return conn, nil
		}
		last = err
		if resp == nil || resp.StatusCode != http.StatusUnauthorized || !responseIsNonceInvalid(resp.Body) {
			if resp != nil && resp.Body != nil {
				_ = resp.Body.Close()
			}
			break
		}
		_ = resp.Body.Close()
	}
	return nil, last
}

func speechURL(baseURL, language string) (string, error) {
	u, err := url.Parse(strings.TrimSpace(baseURL))
	if err != nil || u.Host == "" {
		if err == nil {
			err = errors.New("missing host")
		}
		return "", err
	}
	switch u.Scheme {
	case "https":
		u.Scheme = "wss"
	case "http":
		u.Scheme = "ws"
	case "wss", "ws":
	default:
		u.Scheme = "wss"
	}
	u.Path = strings.TrimRight(u.Path, "/") + "/speech/asr"
	q := url.Values{}
	if strings.TrimSpace(language) != "" {
		q.Set("language", strings.TrimSpace(language))
	}
	u.RawQuery = q.Encode()
	u.Fragment = ""
	u.User = nil
	return u.String(), nil
}

func responseIsNonceInvalid(body io.Reader) bool {
	if body == nil {
		return false
	}
	raw, err := io.ReadAll(io.LimitReader(body, 64<<10))
	if err != nil {
		return false
	}
	var envelope struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	return json.Unmarshal(raw, &envelope) == nil && envelope.Error.Code == "DEVICE_PROOF_NONCE_INVALID"
}

func validSpeechControl(payload []byte) bool {
	var in struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(payload, &in); err != nil {
		return false
	}
	return in.Type == "commit" || in.Type == "finish" || in.Type == "cancel"
}

func writeSpeechRaw(conn *websocket.Conn, mt int, payload []byte) error {
	_ = conn.SetWriteDeadline(time.Now().Add(speechWriteWait))
	return conn.WriteMessage(mt, payload)
}

type speechClientWriter struct {
	mu   sync.Mutex
	conn *websocket.Conn
}

func (w *speechClientWriter) writeJSON(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	return w.writeRaw(websocket.TextMessage, b)
}

func (w *speechClientWriter) writeRaw(mt int, payload []byte) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	_ = w.conn.SetWriteDeadline(time.Now().Add(speechWriteWait))
	return w.conn.WriteMessage(mt, payload)
}
