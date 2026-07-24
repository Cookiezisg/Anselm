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
	speechMaxFrameBytes    = 256 * 1024
	speechSessionMaxAge    = 2 * time.Minute
	speechDefaultPongWait  = 30 * time.Second
	speechDefaultPingEvery = 10 * time.Second
	speechWriteWait        = 10 * time.Second
)

type ProofHeaders interface {
	ProofHeaders(ctx context.Context, method, rawURL, kid string, body []byte, refresh bool) (http.Header, error)
}

// SpeechHandler proxies the desktop microphone WebSocket to the managed Anselm
// gateway. The gateway owns Qwen ASR config and credentials; the sidecar owns
// the device-proof private key; the Flutter client only sees transcript events.
type SpeechHandler struct {
	svc       *speechapp.Service
	proof     ProofHeaders
	dialer    *websocket.Dialer
	pongWait  time.Duration
	pingEvery time.Duration
	log       *zap.Logger
}

func NewSpeechHandler(svc *speechapp.Service, proof ProofHeaders, log *zap.Logger) *SpeechHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &SpeechHandler{
		svc:       svc,
		proof:     proof,
		dialer:    websocket.DefaultDialer,
		pongWait:  speechDefaultPongWait,
		pingEvery: speechDefaultPingEvery,
		log:       log.Named("handlers.speech"),
	}
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
		// A refusal that arrives BEFORE the upgrade carries the gateway's structured code. Keep the
		// actionable ones distinct: "your monthly allowance is gone" and "slow down for a moment"
		// need opposite user behaviour, and flattening both into "speech is unavailable" invites
		// endless retrying. Unknown codes stay ErrUnavailable — never invent a meaning.
		// 升级**之前**到达的拒绝带着网关的结构化码。可行动的那几种必须分开:「本月额度用完了」与「稍等
		// 一下」要求相反的用户行为,把两者压成「语音不可用」等于邀请无限重试。未知码保持 ErrUnavailable
		// ——绝不臆造含义。
		if classified := speechapp.ClassifyHandshakeCode(handshakeRefusalCode(err)); classified != nil {
			responsehttpapi.FromDomainError(w, h.log, classified)
			return
		}
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
	_ = downConn.SetReadDeadline(speechReadDeadline(deadline, h.pongWait))
	_ = upConn.SetReadDeadline(speechReadDeadline(deadline, h.pongWait))
	downConn.SetPongHandler(func(string) error {
		return downConn.SetReadDeadline(speechReadDeadline(deadline, h.pongWait))
	})
	upConn.SetPongHandler(func(string) error {
		return upConn.SetReadDeadline(speechReadDeadline(deadline, h.pongWait))
	})
	client := &speechClientWriter{conn: downConn}
	stopHeartbeat := make(chan struct{})
	defer close(stopHeartbeat)
	go speechHeartbeat(stopHeartbeat, downConn, deadline, h.pingEvery)
	go speechHeartbeat(stopHeartbeat, upConn, deadline, h.pingEvery)

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
			_ = upConn.SetReadDeadline(speechReadDeadline(deadline, h.pongWait))
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
		_ = downConn.SetReadDeadline(speechReadDeadline(deadline, h.pongWait))
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
		code, nonceInvalid := handshakeEnvelope(resp)
		if resp == nil || resp.StatusCode != http.StatusUnauthorized || !nonceInvalid {
			if resp != nil && resp.Body != nil {
				_ = resp.Body.Close()
			}
			if code != "" {
				// Carry ONLY the closed-set code forward, never the provider's prose: the transport
				// must stay unable to leak upstream text into a user-facing error.
				// 只携带闭集里的 code,绝不携带上游散文:传输层必须**没有能力**把上游文本泄进用户面错误。
				last = &handshakeRefusal{code: code, cause: err}
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

// handshakeRefusal carries a gateway refusal code observed during the WebSocket handshake. It holds
// the CODE only — the upstream's message never travels with it.
// handshakeRefusal 携带握手期观察到的网关拒绝码。**只**存 code——上游的 message 绝不随行。
type handshakeRefusal struct {
	code  string
	cause error
}

func (e *handshakeRefusal) Error() string { return "speech: gateway refused the handshake" }
func (e *handshakeRefusal) Unwrap() error { return e.cause }

// handshakeRefusalCode extracts the code from a dial error, or "" when the failure carried none.
// handshakeRefusalCode 从拨号错误里取出 code;失败未带码时返回 ""。
func handshakeRefusalCode(err error) string {
	var refusal *handshakeRefusal
	if errors.As(err, &refusal) {
		return refusal.code
	}
	return ""
}

// handshakeEnvelope reads the gateway's structured error envelope from a failed handshake response.
// It returns the code and whether that code is the nonce-refresh signal.
// handshakeEnvelope 从失败的握手响应里读网关的结构化错误信封,返回 code 及它是否为 nonce 刷新信号。
func handshakeEnvelope(resp *http.Response) (code string, nonceInvalid bool) {
	if resp == nil || resp.Body == nil {
		return "", false
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if err != nil {
		return "", false
	}
	var envelope struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if json.Unmarshal(raw, &envelope) != nil {
		return "", false
	}
	return envelope.Error.Code, envelope.Error.Code == "DEVICE_PROOF_NONCE_INVALID"
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

func speechReadDeadline(max time.Time, wait time.Duration) time.Time {
	deadline := time.Now().Add(wait)
	if deadline.After(max) {
		return max
	}
	return deadline
}

func speechHeartbeat(stop <-chan struct{}, conn *websocket.Conn, max time.Time, every time.Duration) {
	ticker := time.NewTicker(every)
	defer ticker.Stop()
	for {
		select {
		case <-stop:
			return
		case <-ticker.C:
			if time.Now().After(max) {
				_ = conn.SetReadDeadline(time.Now())
				return
			}
			if err := conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(speechWriteWait)); err != nil {
				_ = conn.SetReadDeadline(time.Now())
				return
			}
		}
	}
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
