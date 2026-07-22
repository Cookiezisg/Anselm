package handlers

import (
	"net/http"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// ToolsHandler serves GET /api/v1/tools — the authorizable builtin-tool catalog (name +
// one-line summary), the candidate source for a skill's allowed-tools picker. Read-only;
// the set is fixed at boot (the toolset is static), so the handler holds a snapshot. Entity
// ids (fn_/hd_) and MCP tools are picked from their own live endpoints, NOT here.
//
// ToolsHandler 提供 GET /api/v1/tools —— 可授权内置工具目录(名 + 一行简述),skill allowed-tools
// 选择器的候选来源。只读；集合在启动时定型(工具集静态),故 handler 持快照。实体 id(fn_/hd_)与
// MCP 工具从各自的活端点挑，不在此处。
type ToolsHandler struct {
	catalog []toolapp.Descriptor
	log     *zap.Logger
}

// NewToolsHandler constructs the handler over the boot-time tool catalog snapshot.
//
// NewToolsHandler 用启动期工具目录快照构造 handler。
func NewToolsHandler(catalog []toolapp.Descriptor, log *zap.Logger) *ToolsHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &ToolsHandler{catalog: catalog, log: log.Named("handlers.tools")}
}

// Register wires the endpoint onto mux.
//
// Register 把端点挂到 mux。
func (h *ToolsHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/tools", h.List)
}

// List returns the full builtin-tool catalog. A bounded, system-fixed set — no pagination
// (N4 exemption ①); pagination params are ignored per standard HTTP rather than 4xx'd.
//
// List 返回内置工具目录全集。有界、系统固定集——不分页(N4 豁免①)；分页参数按标准 HTTP 忽略、非报错。
func (h *ToolsHandler) List(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.catalog)
}
