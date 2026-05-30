// permissions.go — HTTP for V1.2 §3 final-sweep settings + permissions
// inspection. 5 endpoints; settings file is read/written atomically
// (tmp + rename) so partial writes can't corrupt the live snapshot.
//
// permissions.go ——V1.2 §3 settings + permissions 查看 HTTP，5 端点。
// settings 文件 atomic 读写（tmp + rename），不让半成品破坏快照。
package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	permgate "github.com/sunweilin/forgify/backend/internal/app/tool/permissionsgate"
	permdomain "github.com/sunweilin/forgify/backend/internal/domain/permissions"
	limitspkg "github.com/sunweilin/forgify/backend/internal/pkg/limits"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// SettingsService is the port wired from infra/settings.Service.
// GetRules returns the live snapshot; Reload rereads from disk; Path
// is the underlying settings.json location for PUT writes.
//
// SettingsService 是从 infra/settings.Service 接的 port。
type SettingsService interface {
	GetRules() *permdomain.Settings
	Reload() error
	Limits() limitspkg.Limits
	UpdateLimits(limitspkg.Limits) error
}

// PermissionsHandler serves the 5 endpoints for V1.2 §3.
//
// PermissionsHandler 提供 V1.2 §3 的 5 个端点。
type PermissionsHandler struct {
	settings     SettingsService
	settingsPath string
	gate         *permgate.Gate
	tools        []toolapp.Tool // for tools-listing endpoint
	log          *zap.Logger
}

// NewPermissionsHandler wires deps. settingsPath is where PUT writes;
// tools snapshot is used by GET /tools to list registered tools.
//
// NewPermissionsHandler 装配依赖。settingsPath 是 PUT 写入位置；tools
// 给 GET /tools 列已注册 tool 用。
func NewPermissionsHandler(s SettingsService, gate *permgate.Gate, settingsPath string, tools []toolapp.Tool, log *zap.Logger) *PermissionsHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &PermissionsHandler{
		settings:     s,
		settingsPath: settingsPath,
		gate:         gate,
		tools:        tools,
		log:          log,
	}
}

// Register mounts the 5 endpoints. Idempotent.
//
// Register 挂 5 个端点。幂等。
func (h *PermissionsHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/settings", h.Get)
	mux.HandleFunc("PUT /api/v1/settings", h.Put)
	mux.HandleFunc("POST /api/v1/settings:reload", h.Reload)
	mux.HandleFunc("GET /api/v1/settings/limits", h.GetLimits)
	mux.HandleFunc("PUT /api/v1/settings/limits", h.PutLimits)
	mux.HandleFunc("GET /api/v1/permissions/tools", h.ListTools)
	mux.HandleFunc("POST /api/v1/permissions/test", h.Test)
}

// Get returns the current parsed Settings snapshot.
//
// Get 返当前解析的 Settings 快照。
func (h *PermissionsHandler) Get(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.settings.GetRules())
}

// Put writes the entire settings.json (atomic tmp + rename) then forces
// reload so subsequent Get sees the new snapshot. Validates the body
// shape before writing; rejects on schema error.
//
// Put 写整个 settings.json（atomic tmp + rename）再强制 reload。写前
// 校验 body shape；schema 错拒。
func (h *PermissionsHandler) Put(w http.ResponseWriter, r *http.Request) {
	var s permdomain.Settings
	if err := decodeJSON(r, &s); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if err := s.Validate(); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// Merge into a generic root so the "limits" block (not part of
	// permdomain.Settings) survives a permissions/hooks edit.
	// 合并进通用 root，使 "limits" 块（不属 permdomain.Settings）在编辑
	// permissions/hooks 时不被冲掉。
	root := map[string]json.RawMessage{}
	sBytes, err := json.Marshal(&s)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	_ = json.Unmarshal(sBytes, &root)
	if limBytes, e := json.Marshal(h.settings.Limits()); e == nil {
		root["limits"] = limBytes
	}
	raw, err := json.MarshalIndent(root, "", "  ")
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// Atomic write: tmp file in same dir → rename.
	// 原子写：同目录 tmp 文件 → rename。
	dir := filepath.Dir(h.settingsPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	tmp, err := os.CreateTemp(dir, "settings-*.json.tmp")
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if _, err := tmp.Write(raw); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	tmp.Close()
	if err := os.Rename(tmp.Name(), h.settingsPath); err != nil {
		os.Remove(tmp.Name())
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if err := h.settings.Reload(); err != nil {
		// Disk write succeeded but reload failed — surface the error so
		// caller knows the live state didn't update. Disk state is the
		// new file; next start picks it up.
		// 磁盘成功但 reload 挂 —— 暴露错让 caller 知道 live 状态没更新。
		// 磁盘已是新文件；下次启动会捡。
		h.log.Warn("settings PUT: disk write ok but reload failed",
			zap.String("path", h.settingsPath), zap.Error(err))
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, h.settings.GetRules())
}

// Reload re-reads settings.json without rewriting.
//
// Reload 重读 settings.json，不重写。
func (h *PermissionsHandler) Reload(w http.ResponseWriter, r *http.Request) {
	_ = r
	if err := h.settings.Reload(); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, h.settings.GetRules())
}

// GetLimits returns the live operational limits (settings.json "limits" block
// overlaid on high-ceiling defaults).
//
// GetLimits 返活动运行上限（settings.json "limits" 块叠加高 ceiling 默认）。
func (h *PermissionsHandler) GetLimits(w http.ResponseWriter, r *http.Request) {
	_ = r
	responsehttpapi.Success(w, http.StatusOK, h.settings.Limits())
}

// PutLimits upserts the "limits" block (read-modify-write preserving the rest of
// settings.json) and reloads so limits.Current() picks up the new values.
//
// PutLimits upsert "limits" 块（read-modify-write 保留 settings.json 其余）并
// reload，使 limits.Current() 读到新值。
func (h *PermissionsHandler) PutLimits(w http.ResponseWriter, r *http.Request) {
	var l limitspkg.Limits
	if err := decodeJSON(r, &l); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if err := h.settings.UpdateLimits(l); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, h.settings.Limits())
}

type toolRow struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	DangerLevel string `json:"dangerLevel"`
}

// ListTools returns all registered tools + their danger levels for UI
// rendering (testend /config/permissions Tools tab).
//
// ListTools 返所有已注册 tool + 危险等级，给 UI 渲染。
func (h *PermissionsHandler) ListTools(w http.ResponseWriter, r *http.Request) {
	_ = r
	rows := make([]toolRow, 0, len(h.tools))
	for _, t := range h.tools {
		name := t.Name()
		rows = append(rows, toolRow{
			Name:        name,
			Description: t.Description(),
			DangerLevel: string(permgate.LookupLevel(name, t)),
		})
	}
	responsehttpapi.Success(w, http.StatusOK, rows)
}

type testRequest struct {
	ToolName    string          `json:"toolName"`
	Args        json.RawMessage `json:"args"`
	Destructive bool            `json:"destructive,omitempty"`
}

type testResponse struct {
	Action permdomain.Action `json:"action"`
	Reason string            `json:"reason"`
}

// Test runs a single tool-call through the gate's Evaluate without side
// effects — UI uses this to preview what a rule change would do.
//
// Test 把单 tool-call 经 gate.Evaluate 走一遍，无副作用——UI 预览规则
// 改动效果。
func (h *PermissionsHandler) Test(w http.ResponseWriter, r *http.Request) {
	var req testRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// Use a synthetic sessionID so the live ask-once cache isn't polluted.
	// 合成 sessionID 防污染 live ask-once 缓存。
	sessionID := "test-session-" + req.ToolName
	dec := h.gate.Evaluate(sessionID, req.ToolName, req.Args, req.Destructive)
	responsehttpapi.Success(w, http.StatusOK, testResponse{
		Action: dec.Action,
		Reason: dec.Reason,
	})
}

// _ context.Context keeps the import used if future endpoints take ctx
// directly. Currently every handler uses r.Context() inline.
var _ = context.TODO
