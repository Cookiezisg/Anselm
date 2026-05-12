// Package trigger is the workflow-trigger domain — listener types,
// per-trigger spec/state representations, and sentinel errors. No
// persistence (trigger config lives inside workflow Graph.Nodes; runtime
// state is in-memory per-listener and exposed via the HTTP /triggers
// endpoint).
//
// Plan 05 §2 details the four V1 listener kinds: cron / fsnotify /
// webhook / manual.
//
// Package trigger 是 workflow 触发器域 — listener 类型 + per-trigger
// spec/state 表示 + sentinel。无持久化(trigger config 在 workflow Graph.
// Nodes 内,runtime state 是 per-listener in-memory,经 HTTP /triggers 端
// 点暴露)。
package trigger

import (
	"errors"
	"time"
)

// Listener kinds (closed enum — Plan 05 V1 has these 4 only).
//
// Listener 种类(封闭枚举 — Plan 05 V1 只 4 种)。
const (
	KindCron     = "cron"
	KindFsnotify = "fsnotify"
	KindWebhook  = "webhook"
	KindManual   = "manual"
)

// Listener states (3 values).
// - active: registered + firing normally (cron entry live, fsnotify
//   watch live, webhook path live)
// - idle:   manual trigger — no listener registered (StartRun called
//   on-demand by HTTP/LLM)
// - error:  listener registration failed; needs user attention (e.g.
//   fsnotify path missing per §6.11)
//
// Listener 状态(3 值)。
const (
	StateActive = "active"
	StateIdle   = "idle"
	StateError  = "error"
)

// Spec is the normalized trigger configuration extracted from a workflow
// trigger node. The Service layer turns workflow Graph.Nodes of type
// "trigger" into Spec values at register time.
//
// Spec 是从 workflow trigger 节点解出的规范化触发器配置;Service 层在
// register 时把 Graph.Nodes 中 type=trigger 的节点转 Spec。
type Spec struct {
	WorkflowID string         `json:"workflowId"`
	NodeID     string         `json:"nodeId"`
	Kind       string         `json:"kind"`
	Config     map[string]any `json:"config"`
}

// State is the runtime state of one registered trigger. Returned by
// Service.State (powers GET /api/v1/workflows/{id}/triggers per §6.12).
//
// State 是已注册触发器的 runtime 状态。Service.State 返;为
// GET /api/v1/workflows/{id}/triggers 端点供数据(§6.12)。
type State struct {
	WorkflowID  string     `json:"workflowId"`
	NodeID      string     `json:"nodeId"`
	Kind        string     `json:"kind"`
	Status      string     `json:"status"`
	LastFiredAt *time.Time `json:"lastFiredAt,omitempty"`
	NextFireAt  *time.Time `json:"nextFireAt,omitempty"` // cron only
	LastError   string     `json:"lastError,omitempty"`
}

// Sentinel errors. Wire codes registered in transport/httpapi/response/errmap.go.
// errors.Is must unwrap through fmt.Errorf("triggerinfra.Method: %w", err)
// chains back to these sentinels (§S16).
//
// 哨兵错误。
var (
	ErrPathNotExist          = errors.New("trigger: fsnotify path not exist")
	ErrPathConflict          = errors.New("trigger: webhook path conflict")
	ErrWebhookSecretMismatch = errors.New("trigger: webhook secret mismatch")
	ErrInvalidCronExpression = errors.New("trigger: invalid cron expression")
)
