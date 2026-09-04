// llmtap is the acceptance rig's standing LLM-wire witness (WRK-087 channel 5): the standalone
// process form of harness.Recorder. It sits between the backend and one real upstream (typically
// the Anselm free-tier gateway), forwards every byte, and journals every crossing to JSONL —
// request bodies land as per-call files so a multi-MB base64 image doesn't turn the journal into
// one unreadable line. "The model really saw the pixels" and "the cache really didn't pay twice"
// are only provable here, never in the model's own words.
//
// llmtap 是验收台架常驻的 LLM 线缆见证者(WRK-087 通道五):harness.Recorder 的独立进程形。它站在
// 后端与一个真上游(通常是 Anselm 免费档网关)之间,逐字节转发,并把每次穿越落进 JSONL——请求体落
// 成逐调用文件,几 MB 的 base64 图不会把 journal 压成一行读不了的东西。「模型真的看见了像素」与
// 「缓存真的没付第二次钱」只在这里可证,永远不在模型自己的话里。
package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/sunweilin/anselm/testend/harness/proxycore"
)

type record struct {
	TS           string `json:"ts"`
	Event        string `json:"event,omitempty"`
	Upstream     string `json:"upstream,omitempty"`
	Method       string `json:"method"`
	Path         string `json:"path"`
	Size         int    `json:"size"`
	BodyFile     string `json:"bodyFile,omitempty"`
	ResponseFile string `json:"responseFile,omitempty"`
	Status       int    `json:"status,omitempty"`
}

type failureBudget struct {
	mu        sync.Mutex
	path      string
	remaining int
}

func (b *failureBudget) take(r *http.Request) bool {
	if b.path == "" || r.URL.Path != b.path {
		return false
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.remaining <= 0 {
		return false
	}
	b.remaining--
	return true
}

func (b *failureBudget) takeVideoPoll(r *http.Request) bool {
	if r.Method != http.MethodGet || !strings.HasPrefix(r.URL.Path, "/v1/videos/") {
		return false
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.remaining <= 0 {
		return false
	}
	b.remaining--
	return true
}

func main() {
	listen := flag.String("listen", "127.0.0.1:8788", "listen address")
	upstream := flag.String("upstream", "", "real upstream origin, e.g. https://api.anselm.website (required)")
	out := flag.String("out", "", "journal JSONL path (required)")
	failPath := flag.String("fail-path", "", "test-only path to fail before forwarding (default: disabled)")
	failCount := flag.Int("fail-count", 0, "test-only number of matching requests to fail")
	failStatus := flag.Int("fail-status", http.StatusServiceUnavailable, "test-only injected HTTP status")
	failKind := flag.String("fail-kind", "generic", "test-only fault payload: generic, quota-http, quota-stream, speech-handshake, speech-upstream-closed, speech-frame-invalid, or video-poll-timeout")
	injectMetadata := flag.Bool("inject-wav-metadata", false, "test-only: insert LIST and fact chunks into successful /v1/audio/speech WAV responses")
	flag.Parse()
	if *upstream == "" || *out == "" {
		fmt.Fprintln(os.Stderr, "llmtap: -upstream and -out are required")
		os.Exit(2)
	}
	u, err := url.Parse(strings.TrimRight(*upstream, "/"))
	if err != nil || u.Host == "" {
		fmt.Fprintf(os.Stderr, "llmtap: bad upstream %q\n", *upstream)
		os.Exit(2)
	}
	if *failCount < 0 || *failStatus < 400 || *failStatus > 599 {
		fmt.Fprintln(os.Stderr, "llmtap: fail-count must be non-negative and fail-status must be 400..599")
		os.Exit(2)
	}
	if *failKind != "generic" && *failKind != "quota-http" && *failKind != "quota-stream" && *failKind != "speech-handshake" && *failKind != "speech-upstream-closed" && *failKind != "speech-frame-invalid" && *failKind != "video-poll-timeout" {
		fmt.Fprintf(os.Stderr, "llmtap: unsupported fail-kind %q\n", *failKind)
		os.Exit(2)
	}
	if *failKind == "quota-http" && *failStatus != http.StatusPaymentRequired && *failStatus != http.StatusTooManyRequests {
		fmt.Fprintln(os.Stderr, "llmtap: quota-http fail-status must be 402 or 429")
		os.Exit(2)
	}
	if *failKind == "speech-handshake" && *failStatus != http.StatusUnauthorized {
		fmt.Fprintln(os.Stderr, "llmtap: speech-handshake fail-status must be 401")
		os.Exit(2)
	}
	journal, err := os.OpenFile(*out, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: open journal: %v\n", err)
		os.Exit(1)
	}
	bodies := filepath.Join(filepath.Dir(*out), "llm-bodies")
	if err := os.MkdirAll(bodies, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: mkdir bodies: %v\n", err)
		os.Exit(1)
	}
	responses := filepath.Join(filepath.Dir(*out), "llm-responses")
	if err := os.MkdirAll(responses, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: mkdir responses: %v\n", err)
		os.Exit(1)
	}

	var mu sync.Mutex
	n, responseN := 0, 0
	writeRec := func(r record) {
		r.TS = time.Now().Format(time.RFC3339Nano)
		b, err := json.Marshal(r)
		if err != nil {
			return
		}
		mu.Lock()
		_, _ = journal.Write(append(b, '\n'))
		mu.Unlock()
	}
	// A deterministic journey may legitimately make no model request (for example an inline
	// metadata PATCH). Keep channel 5 observable without fabricating a request/response pair.
	// 纯确定性旅程可能合法地不调模型(如就地 PATCH 元数据);保留通道五可见,但不伪造请求/响应对。
	writeRec(record{Event: "ready", Upstream: u.String()})

	// Request and response are journaled as two lines sharing method+path order rather than one
	// merged record: ModifyResponse fires on a different goroutine schedule than the request hook,
	// and pretending to pair them would fabricate an ordering the wire does not guarantee.
	// 请求与响应各落一行(共 method+path 的先后序)而非并成一条:ModifyResponse 与请求钩子的调度
	// 不同,假装配对等于伪造一个线缆并不保证的顺序。
	recordRequest := func(r *http.Request, body []byte) {
		mu.Lock()
		n++
		seq := n
		mu.Unlock()
		bf := ""
		if len(body) > 0 {
			bf = filepath.Join(bodies, fmt.Sprintf("%05d%s.bin", seq, strings.ReplaceAll(r.URL.Path, "/", "_")))
			_ = os.WriteFile(bf, body, 0o644)
		}
		writeRec(record{Method: r.Method, Path: r.URL.Path, Size: len(body), BodyFile: bf})
	}
	recordResponse := func(resp *http.Response) {
		writeRec(record{Method: resp.Request.Method, Path: resp.Request.URL.Path, Status: resp.StatusCode})
	}
	recordResponseBody := func(resp *http.Response, body []byte) {
		mu.Lock()
		responseN++
		seq := responseN
		mu.Unlock()
		file := filepath.Join(responses, fmt.Sprintf("%05d%s.bin", seq, strings.ReplaceAll(resp.Request.URL.Path, "/", "_")))
		if err := os.WriteFile(file, body, 0o644); err != nil {
			return
		}
		writeRec(record{Method: resp.Request.Method, Path: resp.Request.URL.Path, Size: len(body), ResponseFile: file, Status: resp.StatusCode})
	}
	decorate := func(resp *http.Response, body io.ReadCloser) io.ReadCloser {
		if !*injectMetadata || resp.StatusCode != http.StatusOK || resp.Request == nil || resp.Request.URL.Path != "/v1/audio/speech" {
			return body
		}
		raw, err := io.ReadAll(body)
		_ = body.Close()
		if err != nil {
			writeRec(record{Event: "wav_metadata_injection_failed", Upstream: u.String(), Method: resp.Request.Method, Path: resp.Request.URL.Path})
			return io.NopCloser(bytes.NewReader(raw))
		}
		mutated, added, err := injectWAVMetadata(raw)
		if err != nil {
			// Non-WAV successful responses are valid for some providers. Do not turn a
			// diagnostic perturbation into a product failure; leave those bytes untouched.
			// 某些供应商的成功响应可能不是 WAV。诊断扰动不能反过来制造产品失败，原样透传。
			return io.NopCloser(bytes.NewReader(raw))
		}
		if resp.Header == nil {
			resp.Header = make(http.Header)
		}
		resp.ContentLength = int64(len(mutated))
		resp.Header.Set("Content-Length", fmt.Sprintf("%d", len(mutated)))
		writeRec(record{Event: "wav_metadata_injected", Upstream: u.String(), Method: resp.Request.Method, Path: resp.Request.URL.Path, Size: added, Status: resp.StatusCode})
		return io.NopCloser(bytes.NewReader(mutated))
	}
	passThrough := proxycore.HandlerWithResponseBodyPolicy(u, recordRequest, recordResponse, recordResponseBody, decorate)
	budget := &failureBudget{path: strings.TrimSpace(*failPath), remaining: *failCount}
	handler := http.Handler(passThrough)
	if (budget.path != "" || *failKind == "video-poll-timeout") && budget.remaining > 0 {
		handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if (*failKind == "speech-upstream-closed" || *failKind == "speech-frame-invalid") && isWebSocketUpgrade(r) {
				if budget.take(r) {
					var upstreamError []byte
					if *failKind == "speech-frame-invalid" {
						upstreamError = []byte(`{"type":"error","code":"SPEECH_AUDIO_FRAME_INVALID"}`)
					}
					proxySpeechAndCloseUpstream(w, r, u, 100*time.Millisecond, upstreamError, recordRequest, recordResponse, func(event record) {
						writeRec(event)
					})
					return
				}
				passThrough.ServeHTTP(w, r)
				return
			}
			// A speech handshake is an HTTP refusal before the WebSocket upgrade. Only intercept the
			// upgrade request; ordinary probes to the same path remain transparent and cannot consume
			// the one-shot budget.
			// 语音握手拒绝发生在 WebSocket upgrade 之前。只拦 upgrade 请求；同路径普通探针继续透明，
			// 不能误消费一次性预算。
			if *failKind == "speech-handshake" && !isWebSocketUpgrade(r) {
				passThrough.ServeHTTP(w, r)
				return
			}
			injected := false
			if *failKind == "video-poll-timeout" {
				injected = budget.takeVideoPoll(r)
			} else {
				injected = budget.take(r)
			}
			if !injected {
				passThrough.ServeHTTP(w, r)
				return
			}
			body, _ := io.ReadAll(r.Body)
			r.Body = io.NopCloser(bytes.NewReader(body))
			recordRequest(r, body)
			status, contentType, payload := injectedFailure(*failKind, *failStatus)
			resp := &http.Response{Request: r, StatusCode: status}
			recordResponse(resp)
			w.Header().Set("Content-Type", contentType)
			w.WriteHeader(status)
			_, _ = w.Write(payload)
			recordResponseBody(resp, payload)
			writeRec(record{Event: "fault_injected", Upstream: u.String(), Method: r.Method, Path: r.URL.Path, Size: len(payload), Status: status})
		})
	}

	fmt.Printf("llmtap: %s → %s (journal %s)\n", *listen, u.String(), *out)
	if err := http.ListenAndServe(*listen, handler); err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: %v\n", err)
		os.Exit(1)
	}
}

func injectedFailure(kind string, status int) (int, string, []byte) {
	switch kind {
	case "speech-handshake":
		return http.StatusUnauthorized, "application/json", []byte(`{"error":{"code":"QUOTA_EXHAUSTED","message":"fixture upstream prose: monthly speech allowance exhausted"}}`)
	case "quota-http":
		if status == http.StatusTooManyRequests {
			return status, "application/json", []byte(`{"error":{"code":"RATE_LIMITED","message":"temporarily rate limited; please retry"}}`)
		}
		return status, "application/json", []byte(`{"error":{"code":"QUOTA_EXHAUSTED","message":"monthly gateway budget exhausted"}}`)
	case "quota-stream":
		return http.StatusOK, "text/event-stream", []byte("data: {\"error\":{\"code\":\"BUDGET_EXHAUSTED\",\"message\":\"monthly gateway budget exhausted\"}}\n\n")
	case "video-poll-timeout":
		// Keep the accepted job in a valid non-terminal state. The real backend owns the
		// wall-clock cutoff and must produce VIDEO_GEN_FAILED with its honest continuation hint.
		return http.StatusOK, "application/json", []byte(`{"status":"pending"}`)
	default:
		return status, "application/json", []byte(`{"error":{"code":"RIG_INJECTED_STAGING_FAILURE","message":"rig injected media staging failure","details":{"reason":"media_staging"}}}`)
	}
}

func isWebSocketUpgrade(r *http.Request) bool {
	if !strings.EqualFold(strings.TrimSpace(r.Header.Get("Upgrade")), "websocket") {
		return false
	}
	for _, value := range r.Header.Values("Connection") {
		for _, token := range strings.Split(value, ",") {
			if strings.EqualFold(strings.TrimSpace(token), "upgrade") {
				return true
			}
		}
	}
	return false
}

// proxySpeechAndCloseUpstream performs a real WebSocket handshake to the configured upstream,
// forwards frames in both directions, and closes only the upstream leg after the first audio frame.
// The backend therefore has to observe a genuine mid-stream upstream loss and produce its own
// SPEECH_UPSTREAM_CLOSED event; the rig never fabricates that product event.
//
// proxySpeechAndCloseUpstream 对真实上游完成 WebSocket 握手,双向转发帧,在首个音频帧后只关闭上游腿。
// 后端必须观察真正的中途上游断线并自己产生 SPEECH_UPSTREAM_CLOSED;台架绝不伪造产品事件。
func proxySpeechAndCloseUpstream(
	w http.ResponseWriter,
	r *http.Request,
	base *url.URL,
	closeAfter time.Duration,
	upstreamError []byte,
	onRequest func(*http.Request, []byte),
	onResponse func(*http.Response),
	onEvent func(record),
) {
	target := speechUpstreamURL(base, r.URL)
	headers := make(http.Header)
	for key, values := range r.Header {
		switch strings.ToLower(key) {
		case "connection", "upgrade", "sec-websocket-key", "sec-websocket-version", "sec-websocket-extensions", "sec-websocket-protocol":
			continue
		}
		headers[key] = append([]string(nil), values...)
	}
	upConn, resp, err := websocket.DefaultDialer.DialContext(r.Context(), target.String(), headers)
	if err != nil {
		if resp != nil && resp.Body != nil {
			_ = resp.Body.Close()
		}
		http.Error(w, "llmtap upstream speech dial failed", http.StatusBadGateway)
		return
	}
	defer func() { _ = upConn.Close() }()

	upgrader := websocket.Upgrader{
		ReadBufferSize:  256 * 1024,
		WriteBufferSize: 256 * 1024,
		CheckOrigin:     func(*http.Request) bool { return true },
	}
	downConn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer func() { _ = downConn.Close() }()
	onRequest(r, nil)
	onResponse(&http.Response{Request: r, StatusCode: http.StatusSwitchingProtocols})

	upClosed := make(chan struct{})
	downClosed := make(chan struct{})
	var closeOnce sync.Once
	closeBoth := func() {
		closeOnce.Do(func() {
			_ = downConn.Close()
			_ = upConn.Close()
		})
	}

	go func() {
		defer close(upClosed)
		for {
			messageType, payload, err := upConn.ReadMessage()
			if err != nil {
				return
			}
			if err := downConn.WriteMessage(messageType, payload); err != nil {
				return
			}
		}
	}()

	go func() {
		defer close(downClosed)
		var closeScheduled bool
		for {
			messageType, payload, err := downConn.ReadMessage()
			if err != nil {
				return
			}
			if err := upConn.WriteMessage(messageType, payload); err != nil {
				return
			}
			if messageType == websocket.BinaryMessage && !closeScheduled {
				closeScheduled = true
				onEvent(record{Event: "speech_audio_forwarded", Upstream: base.String(), Method: r.Method, Path: r.URL.Path, Size: len(payload)})
				if len(upstreamError) > 0 {
					if err := upConn.WriteMessage(websocket.TextMessage, upstreamError); err != nil {
						return
					}
					onEvent(record{Event: "speech_error_forwarded", Upstream: base.String(), Method: r.Method, Path: r.URL.Path, Size: len(upstreamError)})
				}
				time.AfterFunc(closeAfter, func() {
					onEvent(record{Event: "fault_injected", Upstream: base.String(), Method: r.Method, Path: r.URL.Path})
					_ = upConn.Close()
				})
			}
		}
	}()

	select {
	case <-upClosed:
		// Leave the downstream leg alive long enough for the real backend to send its typed
		// SPEECH_UPSTREAM_CLOSED event before it closes the session.
		select {
		case <-downClosed:
		case <-time.After(3 * time.Second):
			closeBoth()
		}
	case <-downClosed:
		closeBoth()
	}
}

func speechUpstreamURL(base, request *url.URL) *url.URL {
	target := *base
	if target.Scheme == "https" {
		target.Scheme = "wss"
	} else if target.Scheme == "http" {
		target.Scheme = "ws"
	}
	target.Path = strings.TrimRight(target.Path, "/") + "/" + strings.TrimLeft(request.Path, "/")
	target.RawPath = ""
	target.RawQuery = request.RawQuery
	target.Fragment = ""
	return &target
}

// injectWAVMetadata adds legal, word-aligned metadata chunks before the data chunk. It returns
// the exact number of inserted bytes so the wire journal can prove which bytes were test-rig
// perturbation. The audio payload is copied byte-for-byte.
//
// injectWAVMetadata 在 data chunk 前加入合法、字对齐的元数据 chunk，并返回插入字节数，使线缆
// journal 能明确证明哪些字节来自台架扰动；音频 payload 逐字节保留。
func injectWAVMetadata(raw []byte) ([]byte, int, error) {
	if len(raw) < 12 || string(raw[:4]) != "RIFF" || string(raw[8:12]) != "WAVE" {
		return nil, 0, fmt.Errorf("not a RIFF/WAVE stream")
	}
	const chunkBytes = 24 // LIST(8+4) + fact(8+4), both even-sized
	dataOffset := -1
	for off := 12; off+8 <= len(raw); {
		id := string(raw[off : off+4])
		size := int(binary.LittleEndian.Uint32(raw[off+4 : off+8]))
		body := off + 8
		if id == "data" {
			// Some real speech gateways use an unknown-length sentinel in the data
			// size and terminate the HTTP body at EOF. ParseWAV intentionally accepts
			// that shape, so the rig must be able to perturb it too.
			// 某些真实语音网关会在 data size 写未知长度哨兵、以 HTTP EOF 结束；ParseWAV
			// 有意兼容该形态，台架也必须能对它做扰动。
			dataOffset = off
			break
		}
		if size < 0 || body > len(raw) || size > len(raw)-body {
			return nil, 0, fmt.Errorf("truncated %q chunk", id)
		}
		next := body + size
		if size%2 == 1 {
			next++
		}
		if next > len(raw) {
			return nil, 0, fmt.Errorf("truncated %q padding", id)
		}
		off = next
	}
	if dataOffset < 0 {
		return nil, 0, fmt.Errorf("wav missing data chunk")
	}

	metadata := make([]byte, 0, chunkBytes)
	metadata = appendWAVChunk(metadata, "LIST", []byte("INFO"))
	metadata = appendWAVChunk(metadata, "fact", []byte("TEST"))
	out := make([]byte, 0, len(raw)+len(metadata))
	out = append(out, raw[:dataOffset]...)
	out = append(out, metadata...)
	out = append(out, raw[dataOffset:]...)
	if len(out)-8 > int(^uint32(0)) {
		return nil, 0, fmt.Errorf("wav exceeds RIFF size")
	}
	binary.LittleEndian.PutUint32(out[4:8], uint32(len(out)-8))
	return out, len(metadata), nil
}

func appendWAVChunk(dst []byte, id string, body []byte) []byte {
	dst = append(dst, id...)
	var size [4]byte
	binary.LittleEndian.PutUint32(size[:], uint32(len(body)))
	dst = append(dst, size[:]...)
	dst = append(dst, body...)
	if len(body)%2 == 1 {
		dst = append(dst, 0)
	}
	return dst
}
