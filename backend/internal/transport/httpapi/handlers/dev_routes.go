// dev_routes.go — GET /dev/routes endpoint (TE-21). Returns a hand-curated
// dump of every HTTP route the backend registers, grouped by handler file.
// stdlib http.ServeMux doesn't expose its registered routes at runtime,
// so this is maintained manually. The Routes tab in testend uses it to
// give testers a quick "what endpoints exist" lookup with copy-as-curl.
//
// Maintenance: when adding/removing a mux.HandleFunc call in any *.go in
// this directory, update the matching slice below. Verifiable via:
//   grep -rEh 'mux\.HandleFunc\(' backend/internal/transport/httpapi/handlers/*.go \
//     | grep -v _test | wc -l
// should match len(devRoutes).
//
// dev_routes.go ——/dev/routes（TE-21）。返回所有注册路由的手工清单，
// 按 handler 文件分组。stdlib mux 运行时不暴露注册路由，故手维护。
// testend Routes tab 用此查"有哪些端点"+ 复制 curl 命令。
package handlers

import (
	"net/http"
	"strings"

	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

type devRoute struct {
	Method  string `json:"method"`
	Path    string `json:"path"`
	Handler string `json:"handler"`
}

// devRoutes mirrors mux.HandleFunc registrations across all handlers in
// this package. Sorted by HTTP method then path within each handler group.
//
// devRoutes 镜像本包所有 mux.HandleFunc 注册。按 method 然后 path 排序。
var devRoutes = []devRoute{
	// ── apikey
	{"POST", "/api/v1/api-keys", "apikey.Create"},
	{"GET", "/api/v1/api-keys", "apikey.List"},
	{"PATCH", "/api/v1/api-keys/{id}", "apikey.Update"},
	{"DELETE", "/api/v1/api-keys/{id}", "apikey.Delete"},
	{"POST", "/api/v1/api-keys/{id}:test", "apikey.Test"},

	// ── attachments + chat
	{"POST", "/api/v1/attachments", "chat.UploadAttachment"},
	{"POST", "/api/v1/conversations/{id}/messages", "chat.SendMessage"},
	{"DELETE", "/api/v1/conversations/{id}/stream", "chat.CancelStream"},
	{"GET", "/api/v1/conversations/{id}/messages", "chat.ListMessages"},

	// ── eventlog + notifications (SSE)
	{"GET", "/api/v1/eventlog", "eventlog.Stream"},
	{"GET", "/api/v1/conversations/{id}/eventlog", "eventlog.History"},
	{"GET", "/api/v1/notifications", "notifications.Stream"},

	// ── conversations
	{"POST", "/api/v1/conversations", "conversation.Create"},
	{"GET", "/api/v1/conversations", "conversation.List"},
	{"GET", "/api/v1/conversations/{id}", "conversation.Get"},
	{"PATCH", "/api/v1/conversations/{id}", "conversation.Rename"},
	{"DELETE", "/api/v1/conversations/{id}", "conversation.Delete"},
	{"POST", "/api/v1/conversations/{id}/answers", "ask.SubmitAnswer"},

	// ── catalog
	{"GET", "/api/v1/catalog", "catalog.Get"},
	{"POST", "/api/v1/catalog:refresh", "catalog.Refresh"},

	// ── forge
	{"POST", "/api/v1/forges", "forge.Create"},
	{"GET", "/api/v1/forges", "forge.List"},
	{"POST", "/api/v1/forges:import", "forge.Import"},
	{"GET", "/api/v1/forges/{id}", "forge.Get"},
	{"PATCH", "/api/v1/forges/{id}", "forge.Update"},
	{"DELETE", "/api/v1/forges/{id}", "forge.Delete"},
	{"POST", "/api/v1/forges/{id}:run", "forge.Run"},
	{"POST", "/api/v1/forges/{id}:test", "forge.RunTests"},
	{"POST", "/api/v1/forges/{id}:duplicate", "forge.Duplicate"},
	{"POST", "/api/v1/forges/{id}:export", "forge.Export"},
	{"GET", "/api/v1/forges/{id}/versions", "forge.ListVersions"},
	{"GET", "/api/v1/forges/{id}/versions/{version}", "forge.GetVersion"},
	{"GET", "/api/v1/forges/{id}/pending", "forge.GetPending"},
	{"POST", "/api/v1/forges/{id}/pending:accept", "forge.AcceptPending"},
	{"POST", "/api/v1/forges/{id}/pending:reject", "forge.RejectPending"},
	{"GET", "/api/v1/forges/{id}/test-cases", "forge.ListTestCases"},
	{"POST", "/api/v1/forges/{id}/test-cases", "forge.CreateTestCase"},
	{"DELETE", "/api/v1/forges/{id}/test-cases/{tcId}", "forge.DeleteTestCase"},
	{"POST", "/api/v1/forges/{id}/test-cases/{tcId}:run", "forge.RunTestCase"},
	{"GET", "/api/v1/forges/{id}/executions", "forge.ListExecutions"},

	// ── health
	{"GET", "/api/v1/health", "health.Get"},

	// ── model
	{"GET", "/api/v1/model-configs", "model.List"},
	{"PUT", "/api/v1/model-configs/{scenario}", "model.Upsert"},

	// ── skills
	{"POST", "/api/v1/skills:import", "skills.Import"},
	{"POST", "/api/v1/skills:refresh", "skills.Refresh"},
	{"GET", "/api/v1/skills", "skills.List"},
	{"POST", "/api/v1/skills", "skills.Create"},
	{"GET", "/api/v1/skills/{name}", "skills.Get"},
	{"GET", "/api/v1/skills/{name}/body", "skills.GetBody"},
	{"PUT", "/api/v1/skills/{name}", "skills.Replace"},
	{"DELETE", "/api/v1/skills/{name}", "skills.Delete"},
	{"POST", "/api/v1/skills/{name}:invoke", "skills.Invoke"},

	// ── mcp
	{"GET", "/api/v1/mcp-servers", "mcp.ListServers"},
	{"GET", "/api/v1/mcp-servers/{name}", "mcp.GetServer"},
	{"GET", "/api/v1/mcp-servers/{name}/stderr", "mcp.GetServerStderr"},
	{"PUT", "/api/v1/mcp-servers/{name}", "mcp.PutServer"},
	{"DELETE", "/api/v1/mcp-servers/{name}", "mcp.DeleteServer"},
	{"POST", "/api/v1/mcp-servers/{name}:reconnect", "mcp.Reconnect"},
	{"POST", "/api/v1/mcp-servers/{name}:health-check", "mcp.HealthCheck"},
	{"POST", "/api/v1/mcp-servers:import", "mcp.ImportServers"},
	{"GET", "/api/v1/mcp-registry?search=", "mcp.SearchRegistry (query required)"},
	{"GET", "/api/v1/mcp-registry/{name}", "mcp.GetRegistryEntry"},
	{"POST", "/api/v1/mcp-registry/{name}:install", "mcp.InstallFromRegistry"},

	// ── subagent
	// Sub-runs are unified Message rows (attrs.kind=subagent_run) since the
	// schema unification — old /subagent-runs endpoints were retired with
	// the dedicated tables. List subagent types only.
	// sub-run schema 统一后是 messages 行（attrs.kind=subagent_run），
	// 独立 /subagent-runs 端点随表删了；只剩 list types。
	{"GET", "/api/v1/subagent-types", "subagent.ListTypes"},

	// ── sandbox
	{"GET", "/api/v1/sandbox/runtimes", "sandbox.ListRuntimes"},
	{"GET", "/api/v1/sandbox/envs", "sandbox.ListEnvs"},
	{"GET", "/api/v1/sandbox/envs/{id}", "sandbox.GetEnv"},
	{"GET", "/api/v1/sandbox/disk-usage", "sandbox.DiskUsage"},
	{"GET", "/api/v1/sandbox/bootstrap-status", "sandbox.BootstrapStatus"},
	{"GET", "/api/v1/conversations/{id}/sandbox-envs", "sandbox.ListConvEnvs"},
	{"POST", "/api/v1/sandbox/envs/{id}:destroy", "sandbox.DestroyEnv"},
	{"POST", "/api/v1/sandbox/runtimes/{id}:destroy", "sandbox.DestroyRuntime"},
	{"POST", "/api/v1/sandbox/{action}", "sandbox.Action (gc/retry-bootstrap)"},
	{"POST", "/api/v1/conversations/{id}/sandbox-envs/{kind}:reset", "sandbox.ResetConvEnv"},
	{"POST", "/api/v1/conversations/{id}/sandbox-envs", "sandbox.ResetAllConvEnvs"},

	// ── dev (only when --dev) — listed so the Routes tab shows the full surface
	{"GET", "/dev/", "dev.ServeIndex (testend HTML)"},
	{"GET", "/dev/logs", "dev.StreamLogs (SSE)"},
	{"POST", "/dev/sql", "dev.QuerySQL"},
	{"GET", "/dev/schema", "dev.Schema"},
	{"GET", "/dev/collections", "dev.ListCollections"},
	{"GET", "/dev/tools", "dev.ListTools"},
	{"POST", "/dev/invoke", "dev.InvokeTool"},
	{"GET", "/dev/info", "dev.Info"},
	{"GET", "/dev/forgify-home", "dev.ForgifyHome"},
	{"GET", "/dev/runtime", "dev.Runtime"},
	{"GET", "/dev/routes", "dev.Routes (this endpoint)"},
	{"GET", "/dev/bash-processes", "dev.BashProcesses"},
	{"POST", "/dev/mock-llm/scripts", "dev.MockLLMPushScripts"},
	{"GET", "/dev/mock-llm/queue", "dev.MockLLMQueue"},
	{"DELETE", "/dev/mock-llm/scripts", "dev.MockLLMClear"},
	{"GET", "/dev/mock-llm/last-prompt", "dev.MockLLMLastPrompt"},
	{"GET", "/dev/llm-trace", "dev.LLMTrace"},
}

// Routes serves GET /dev/routes — the manifest above.
//
// Routes 服务 GET /dev/routes，返回上面的 manifest。
func (h *DevHandler) Routes(w http.ResponseWriter, r *http.Request) {
	out := make([]devRoute, len(devRoutes))
	copy(out, devRoutes)
	// Stable sort: by path, then method (so GET/POST on same path cluster).
	// 稳定排序：按 path 然后 method。
	sortRoutes(out)
	responsehttpapi.Success(w, http.StatusOK, out)
}

func sortRoutes(rs []devRoute) {
	// Insertion sort — small N, stable, no imports needed.
	// 插入排序——N 小、稳定、零依赖。
	for i := 1; i < len(rs); i++ {
		for j := i; j > 0 && lessRoute(rs[j], rs[j-1]); j-- {
			rs[j], rs[j-1] = rs[j-1], rs[j]
		}
	}
}

func lessRoute(a, b devRoute) bool {
	if a.Path != b.Path {
		return a.Path < b.Path
	}
	return strings.Compare(a.Method, b.Method) < 0
}
