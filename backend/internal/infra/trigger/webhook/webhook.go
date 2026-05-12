// Package webhook is the HTTP-webhook trigger listener. Each registered
// trigger gets its own sub-path under /api/v1/webhooks/{wfId}/{path} +
// optional secret check (X-Webhook-Secret header or ?token=). Body
// 10MB cap; payload becomes the trigger input.
//
// Plan 05 §2.4 + §6.6.
//
// Package webhook 是 HTTP webhook trigger;每个 trigger 一个子路径
// /api/v1/webhooks/{wfId}/{path} + 可选 secret 校验 (header 或 ?token=)。
// body 10MB cap;payload 当 trigger input。
package webhook

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
)

// MaxBodyBytes caps webhook POST body. 10MB default per Plan 05 §2.4.
//
// MaxBodyBytes webhook POST body 上限,默认 10MB(§2.4)。
const MaxBodyBytes = 10 * 1024 * 1024

// OnFireFunc is called on each accepted webhook request. Caller wires to
// scheduler.StartRun.
//
// OnFireFunc 每次 accept 的 webhook 请求调;接 scheduler.StartRun。
type OnFireFunc func(workflowID, nodeID string, input map[string]any)

// Listener manages webhook registrations against a single http.ServeMux.
//
// Listener 管理 webhook 注册(共用一个 http.ServeMux)。
type Listener struct {
	mu       sync.Mutex
	mux      *http.ServeMux
	registry map[string]registration // path → reg
	keys     map[string]string       // (workflowID,nodeID) → path
	lastFire map[string]time.Time
	onFire   OnFireFunc
	log      *zap.Logger
}

type registration struct {
	WorkflowID string
	NodeID     string
	Method     string
	Secret     string
}

// New constructs a Listener bound to mux. The mux is shared with the
// main httpapi router (registers under /api/v1/webhooks/...).
//
// New 构造 Listener,绑给定 mux(跟主 httpapi router 共享)。
func New(mux *http.ServeMux, log *zap.Logger, onFire OnFireFunc) *Listener {
	return &Listener{
		mux:      mux,
		registry: make(map[string]registration),
		keys:     make(map[string]string),
		lastFire: make(map[string]time.Time),
		onFire:   onFire,
		log:      log.Named("trigger.webhook"),
	}
}

// Register adds a webhook at /api/v1/webhooks/{workflowID}/{path}.
// spec.Config["path"] is required and must be unique across all
// registered webhooks (ErrPathConflict). method defaults to POST.
//
// Register 加 webhook 路径;path 必填且全局唯一,撞返 ErrPathConflict;
// method 默认 POST。
func (l *Listener) Register(spec triggerdomain.Spec) error {
	subpath, _ := spec.Config["path"].(string)
	method, _ := spec.Config["method"].(string)
	secret, _ := spec.Config["secret"].(string)

	if subpath == "" {
		return fmt.Errorf("triggerwebhookinfra.Register: %w: empty path", triggerdomain.ErrPathConflict)
	}
	if method == "" {
		method = http.MethodPost
	}
	method = strings.ToUpper(method)

	full := webhookFullPath(spec.WorkflowID, subpath)
	key := spec.WorkflowID + "/" + spec.NodeID

	l.mu.Lock()
	defer l.mu.Unlock()

	if other, taken := l.registry[full]; taken && (other.WorkflowID != spec.WorkflowID || other.NodeID != spec.NodeID) {
		return fmt.Errorf("triggerwebhookinfra.Register: %w: %s already registered to %s/%s",
			triggerdomain.ErrPathConflict, full, other.WorkflowID, other.NodeID)
	}

	if oldPath, ok := l.keys[key]; ok && oldPath != full {
		delete(l.registry, oldPath)
		// stdlib http.ServeMux can't unregister handlers — leftover route
		// would 404 anyway since l.registry is the source-of-truth lookup
		// table (see ServeHTTP wrapper below). Document the limitation.
		// stdlib mux 不支持 unregister;留下的路由会落到 ServeHTTP 包装里
		// 由 l.registry 查不到时回 404,等价 unregister 效果。
	}

	method = strings.ToUpper(method)
	reg := registration{
		WorkflowID: spec.WorkflowID,
		NodeID:     spec.NodeID,
		Method:     method,
		Secret:     secret,
	}
	if _, alreadyMounted := l.registry[full]; !alreadyMounted {
		// Register mux handler once per full path.
		l.mux.HandleFunc(full, l.handleWebhook(full))
	}
	l.registry[full] = reg
	l.keys[key] = full
	return nil
}

// Unregister removes a webhook (entry stays mounted on mux but starts
// returning 404 since l.registry forgets it).
//
// Unregister 删 webhook;mux 路由保留但 ServeHTTP 在 registry 查不到 → 404。
func (l *Listener) Unregister(workflowID, nodeID string) {
	key := workflowID + "/" + nodeID
	l.mu.Lock()
	defer l.mu.Unlock()
	if path, ok := l.keys[key]; ok {
		delete(l.registry, path)
		delete(l.keys, key)
	}
}

// State returns runtime state for one trigger.
//
// State 返某 trigger 状态。
func (l *Listener) State(workflowID, nodeID string) triggerdomain.State {
	key := workflowID + "/" + nodeID
	l.mu.Lock()
	defer l.mu.Unlock()
	st := triggerdomain.State{
		WorkflowID: workflowID, NodeID: nodeID,
		Kind: triggerdomain.KindWebhook, Status: triggerdomain.StateIdle,
	}
	if _, ok := l.keys[key]; ok {
		st.Status = triggerdomain.StateActive
	}
	if last, ok := l.lastFire[key]; ok {
		t := last
		st.LastFiredAt = &t
	}
	return st
}

func (l *Listener) handleWebhook(fullPath string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
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

		if reg.Secret != "" {
			gotSecret := r.Header.Get("X-Webhook-Secret")
			if gotSecret == "" {
				gotSecret = r.URL.Query().Get("token")
			}
			if gotSecret != reg.Secret {
				http.Error(w, "secret mismatch", http.StatusUnauthorized)
				return
			}
		}

		// Body 10MB cap.
		body, err := io.ReadAll(io.LimitReader(r.Body, MaxBodyBytes+1))
		if err != nil {
			http.Error(w, "read body", http.StatusBadRequest)
			return
		}
		if len(body) > MaxBodyBytes {
			http.Error(w, "body too large", http.StatusRequestEntityTooLarge)
			return
		}

		input := map[string]any{
			"firedAt": time.Now(),
			"method":  r.Method,
			"path":    fullPath,
			"headers": flattenHeaders(r.Header),
		}
		if len(body) > 0 {
			var payload any
			if err := json.Unmarshal(body, &payload); err == nil {
				input["body"] = payload
			} else {
				input["bodyRaw"] = string(body)
			}
		}

		key := reg.WorkflowID + "/" + reg.NodeID
		l.mu.Lock()
		l.lastFire[key] = time.Now()
		l.mu.Unlock()

		// Fire async + recover to keep handler responsive even on slow
		// scheduler / onFire panic (§6.13 parity with cron/fsnotify).
		// 异步 fire + recover,保证 HTTP 响应不被 scheduler 慢或 panic 拖住。
		go func() {
			defer func() {
				if r := recover(); r != nil {
					l.log.Error("webhook onFire panic",
						zap.String("workflowID", reg.WorkflowID),
						zap.String("nodeID", reg.NodeID),
						zap.Any("recover", r))
				}
			}()
			l.onFire(reg.WorkflowID, reg.NodeID, input)
		}()
		w.WriteHeader(http.StatusAccepted)
		_, _ = w.Write([]byte(`{"accepted":true}`))
	}
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

// webhookFullPath builds the mux path for a workflow + subpath. Exported
// so tests + Service can both use it.
//
// webhookFullPath 拼 webhook mux 路径。
func webhookFullPath(workflowID, subpath string) string {
	subpath = strings.TrimPrefix(subpath, "/")
	return "/api/v1/webhooks/" + workflowID + "/" + subpath
}
