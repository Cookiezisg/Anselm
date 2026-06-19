// Package webhook is the HTTP-webhook source listener (path + optional secret/HMAC + 10MB
// body cap), keyed by triggerID and mounted at /api/v1/webhooks/{triggerID}/{path}. It fires
// once per accepted request; the dedupKey is sha256(body)[:8] + a minute bucket so a
// network-level retry of the same request collapses while a later identical payload fires again.
//
// Package webhook 是 HTTP webhook source listener（路径 + 可选 secret/HMAC + 10MB body 上限），
// 按 triggerID 键、挂在 /api/v1/webhooks/{triggerID}/{path}。每次 accept 的请求触发一次；dedupKey =
// sha256(body)[:8] + 分钟桶，使同一请求的网络级重试折叠、之后相同 payload 照常触发。
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"

	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// Signature algorithms. Only hmac-sha256-hex is implemented (GitHub's X-Hub-Signature-256).
//
// 签名算法。当前只实现 hmac-sha256-hex（GitHub `X-Hub-Signature-256`）。
const (
	SignatureAlgoHMACSHA256Hex = "hmac-sha256-hex"
	DefaultHMACSignatureHeader = "X-Hub-Signature-256"
	HMACSignaturePrefix        = "sha256="
)

// webhookPrefix is the single mux pattern the listener mounts ONCE; every per-trigger path
// dispatches off l.registry under it. Mounting one catch-all (not HandleFunc-per-trigger) means
// the mux never grows and re-registering a previously-unregistered path can't panic the stdlib
// ServeMux on a duplicate pattern.
//
// webhookPrefix 是 listener 只挂一次的 mux pattern；每个 per-trigger 路径在其下经 l.registry 派发。
// 挂一个 catch-all（而非 per-trigger HandleFunc）使 mux 永不增长，且重注册一个已注销路径不会因
// 重复 pattern 把 stdlib ServeMux panic 掉。
const webhookPrefix = "/api/v1/webhooks/"

// Listener manages webhook registrations against one shared http.ServeMux.
//
// Listener 管理 webhook 注册，与外部共享一个 http.ServeMux。
type Listener struct {
	mu       sync.Mutex
	registry map[string]registration // key: full mux path
	paths    map[string]string       // key: triggerID → full mux path
	report   triggerinfra.ReportFunc
	log      *zap.Logger
}

type registration struct {
	TriggerID       string
	Method          string
	Secret          string
	SignatureAlgo   string // empty = plain X-Webhook-Secret eq-check; hmac-sha256-hex = HMAC verify
	SignatureHeader string // header to read the signature from; empty + algo set → DefaultHMACSignatureHeader
}

// New constructs a Listener bound to the given mux and mounts its single catch-all route once.
// No other handler may claim the /api/v1/webhooks/ prefix (the 28 resource handlers live under
// their own paths) — a duplicate-pattern panic here would be a wiring bug, not runtime input.
//
// New 构造 Listener 并绑定给定 mux、只挂一次其 catch-all 路由。/api/v1/webhooks/ 前缀不得被其他
// handler 占用（28 个资源 handler 各居己路径）——此处重复 pattern panic 是装配 bug、非运行时输入。
func New(mux *http.ServeMux, log *zap.Logger, report triggerinfra.ReportFunc) *Listener {
	l := &Listener{
		registry: make(map[string]registration),
		paths:    make(map[string]string),
		report:   report,
		log:      log.Named("trigger.webhook"),
	}
	mux.HandleFunc(webhookPrefix, l.handleWebhook)
	return l
}

// Register mounts a webhook at /api/v1/webhooks/{triggerID}/{path}; a path owned by another
// trigger returns a conflict error.
//
// Register 在 /api/v1/webhooks/{triggerID}/{path} 挂载 webhook；路径被另一 trigger 占用则返冲突。
func (l *Listener) Register(triggerID string, _ string, config map[string]any) error {
	subpath, _ := config["path"].(string)
	method, _ := config["method"].(string)
	secret, _ := config["secret"].(string)
	sigAlgo, _ := config["signatureAlgo"].(string)
	sigHeader, _ := config["signatureHeader"].(string)

	if subpath == "" {
		return fmt.Errorf("webhook.Register %s: empty path", triggerID)
	}
	if sigAlgo != "" && sigAlgo != SignatureAlgoHMACSHA256Hex {
		return fmt.Errorf("webhook.Register %s: unsupported signatureAlgo %q (only %q)", triggerID, sigAlgo, SignatureAlgoHMACSHA256Hex)
	}
	if sigAlgo != "" && secret == "" {
		return fmt.Errorf("webhook.Register %s: signatureAlgo requires secret", triggerID)
	}
	if method == "" {
		method = http.MethodPost
	}
	method = strings.ToUpper(method)
	if sigAlgo != "" && sigHeader == "" {
		sigHeader = DefaultHMACSignatureHeader
	}

	full := webhookFullPath(triggerID, subpath)

	l.mu.Lock()
	defer l.mu.Unlock()
	if other, taken := l.registry[full]; taken && other.TriggerID != triggerID {
		return fmt.Errorf("webhook.Register %s: %s already registered to %s", triggerID, full, other.TriggerID)
	}
	// A path change (Edit hot-reload) frees the old registry key; the single catch-all route stays
	// mounted, so the stale path now 404s via registry miss with no mux mutation.
	// 路径变更（Edit 热更）释放旧 registry 键；唯一 catch-all 路由仍挂着，故旧路径经 registry miss 返 404、不动 mux。
	if oldPath, ok := l.paths[triggerID]; ok && oldPath != full {
		delete(l.registry, oldPath)
	}
	l.registry[full] = registration{TriggerID: triggerID, Method: method, Secret: secret, SignatureAlgo: sigAlgo, SignatureHeader: sigHeader}
	l.paths[triggerID] = full
	return nil
}

// Unregister removes a webhook from the registry (the shared catch-all route stays; the freed
// path now 404s via registry miss).
//
// Unregister 把 webhook 从 registry 删（共享 catch-all 路由保留；释放的路径经 registry miss 返 404）。
func (l *Listener) Unregister(triggerID string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if path, ok := l.paths[triggerID]; ok {
		delete(l.registry, path)
		delete(l.paths, triggerID)
	}
}

// Start is a no-op — the single catch-all route mounts in New against the shared mux.
//
// Start 是 no-op——唯一 catch-all 路由在 New 时挂到共享 mux。
func (l *Listener) Start() {}

// Stop is a no-op — the mux lifecycle is owned by the HTTP server, not this listener.
//
// Stop 是 no-op——mux 生命周期归 HTTP server，不归此 listener。
func (l *Listener) Stop() {}

// handleWebhook is the single catch-all under /api/v1/webhooks/: it reconstructs the registry key
// from the exact request path and dispatches, preserving 404-on-miss for unregistered / freed paths.
//
// handleWebhook 是 /api/v1/webhooks/ 下唯一的 catch-all：用确切请求路径重建 registry 键并派发，
// 未注册 / 已释放路径维持 miss-即-404。
func (l *Listener) handleWebhook(w http.ResponseWriter, r *http.Request) {
	fullPath := r.URL.Path
	l.mu.Lock()
	reg, ok := l.registry[fullPath]
	l.mu.Unlock()
	if !ok {
		http.NotFound(w, r)
		return
	}
	if !strings.EqualFold(r.Method, reg.Method) {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxBodyBytes()+1))
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	if int64(len(body)) > maxBodyBytes() {
		http.Error(w, "body too large", http.StatusRequestEntityTooLarge)
		return
	}
	// HMAC mode verifies the signature header against hmac_sha256(body, secret); plain mode
	// compares X-Webhook-Secret / ?token= to the configured secret.
	// HMAC 模式按 hmac_sha256(body, secret) 验签；明文模式按 secret 直比。
	if reg.Secret != "" {
		switch reg.SignatureAlgo {
		case SignatureAlgoHMACSHA256Hex:
			if !verifyHMACSHA256Hex(body, []byte(reg.Secret), r.Header.Get(reg.SignatureHeader)) {
				http.Error(w, "signature mismatch", http.StatusUnauthorized)
				return
			}
		default:
			got := r.Header.Get("X-Webhook-Secret")
			if got == "" {
				got = r.URL.Query().Get("token")
			}
			if got != reg.Secret {
				http.Error(w, "secret mismatch", http.StatusUnauthorized)
				return
			}
		}
	}

	payload := map[string]any{
		"firedAt": time.Now(),
		"method":  r.Method,
		"path":    fullPath,
		"headers": flattenHeaders(r.Header),
	}
	if len(body) > 0 {
		var parsed any
		if err := json.Unmarshal(body, &parsed); err == nil {
			payload["body"] = parsed
		} else {
			payload["bodyRaw"] = string(body)
		}
	}

	// Dedup key: body hash + a minute bucket. A network-level retry of the SAME request
	// (seconds apart) collapses onto one Firing per workflow (idx_trf_dedup), while a
	// legitimately repeated identical payload later (next minute on) fires again — the
	// UNIQUE is forever, so the key must not be the bare hash.
	// 去重键：body 哈希 + 分钟桶。同一请求的网络级重试（秒级间隔）按 workflow 折叠成一条
	// Firing（idx_trf_dedup）；之后（下一分钟起）合法重复的相同 payload 照常触发——UNIQUE
	// 是永久的，键不能只是裸哈希。
	sum := sha256.Sum256(body)
	dedup := hex.EncodeToString(sum[:8]) + "|" + time.Now().UTC().Format("200601021504")

	// Fire async + recover so the handler stays responsive on a slow/panicking onFire.
	// 异步 fire + recover，handler 不被慢/panic 拖累。
	triggerID := reg.TriggerID
	go func() {
		defer func() {
			if rec := recover(); rec != nil {
				l.log.Error("webhook report panic", zap.String("triggerID", triggerID), zap.Any("recover", rec))
			}
		}()
		l.report(triggerID, triggerinfra.Activity{Fired: true, Payload: payload, DedupKey: dedup})
	}()
	w.WriteHeader(http.StatusAccepted)
	_, _ = w.Write([]byte(`{"accepted":true}`))
}

func flattenHeaders(h http.Header) map[string]string {
	out := make(map[string]string, len(h))
	for k, v := range h {
		if len(v) > 0 {
			out[k] = v[0]
		}
	}
	return out
}

func webhookFullPath(triggerID, subpath string) string {
	return "/api/v1/webhooks/" + triggerID + "/" + strings.TrimPrefix(subpath, "/")
}

// verifyHMACSHA256Hex constant-time compares the GitHub-style `sha256=<hex>` (or bare hex)
// signature against hmac_sha256(body, secret). Empty header → false; auto-strips the prefix.
//
// verifyHMACSHA256Hex 常量时间对比 `sha256=<hex>` 签名与 hmac_sha256(body, secret)；空 header → false。
func verifyHMACSHA256Hex(body, secret []byte, headerVal string) bool {
	if headerVal == "" {
		return false
	}
	gotBytes, err := hex.DecodeString(strings.TrimPrefix(headerVal, HMACSignaturePrefix))
	if err != nil {
		return false
	}
	mac := hmac.New(sha256.New, secret)
	mac.Write(body)
	return hmac.Equal(gotBytes, mac.Sum(nil))
}

var _ triggerinfra.Listener = (*Listener)(nil)

// maxBodyBytes reads the live webhook body cap (limits.Guards.WebhookBodyMaxMB).
//
// maxBodyBytes 读活动 webhook body 上限（limits.Guards.WebhookBodyMaxMB）。
func maxBodyBytes() int64 { return int64(limitspkg.Current().Guards.WebhookBodyMaxMB) << 20 }
