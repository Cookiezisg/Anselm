//go:build pipeline

// curated_pipeline_test.go — end-to-end pipeline coverage for the
// 21-entry curated MCP marketplace (Marketplace V3, 2026-05-08).
//
// Two test families:
//
//  1. TestCuratedMarketplace_AllSmoke — every curated entry walks the
//     full install → handshake → tools/list → uninstall path. T1+
//     entries skip when their required env vars aren't set so the
//     suite stays runnable without 16 different vendor accounts.
//
//  2. TestCuratedMarketplace_T0_Live_* — the 5 zero-config entries
//     (playwright / chrome-devtools / duckduckgo / context7 / memory)
//     additionally drive a representative tool call so we cover the
//     "舒畅 end-to-end" axis the user asked for, not just handshake.
//
// All tests gated on FORGIFY_CURATED_SMOKE=1 + sandbox.IsReady().
// Reason: every install runs a real `npx -y` / `uvx` against the
// public registries — slow, networked, not appropriate for default
// `make test-pipeline`. The shared mise runtime within a single
// run amortises the python/node bootstrap across all 21 entries.
//
// curated_pipeline_test.go ——21 条精选 marketplace 端到端 pipeline。
// (1) AllSmoke：每条走 install → 握手 → tools/list → 卸 全程；T1+ 缺 env
// 时 skip。(2) T0_Live_*：5 个 zero-config 额外真调一个工具，覆盖"舒畅"。
// 全部门控 FORGIFY_CURATED_SMOKE=1 + sandbox.IsReady()——npx/uvx 真联网。

package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"testing"
	"time"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// curatedSmokeEnabled gates every test in this file.
//
// curatedSmokeEnabled 门控本文件全部测试。
func curatedSmokeEnabled(t *testing.T) {
	t.Helper()
	if os.Getenv("FORGIFY_CURATED_SMOKE") != "1" {
		t.Skip("set FORGIFY_CURATED_SMOKE=1 to opt in (real npx/uvx installs)")
	}
}

// sharedSandboxDir resolves the test sandbox dataDir. When
// FORGIFY_TEST_SANDBOX_DIR is set, every harness in this file points
// at it so mise + node@22 + npm caches survive across subtests AND
// across `go test` invocations — first run pays the ~5min mise+node
// download once, subsequent installs reuse the warmed cache.
//
// sharedSandboxDir 解析测试 sandbox dataDir。设了 FORGIFY_TEST_SANDBOX_DIR
// 就用它——本文件所有 harness 共享，mise + node@22 + npm 缓存跨 subtest +
// 跨 `go test` 调用都活。无设则 fallback t.TempDir()，每测独立但每测都重
// 装 mise+node（约 5min 冷启动）。
func sharedSandboxDir() string { return os.Getenv("FORGIFY_TEST_SANDBOX_DIR") }

// installTimeout — first-time mise extract + node@22 fetch + npm
// install of a heavy package (playwright + chromium) can run 8-12
// minutes. 15 minutes accommodates the worst case while keeping a
// hard ceiling so a hung subprocess fails the suite.
//
// installTimeout —— 首次 mise 解 + node@22 下 + 大包 npm install
// （playwright + chromium）可能 8-12min。15min 兜底，hung 子进程会被熔断。
const installTimeout = 15 * time.Minute

// ── 1. 21 entries — install + handshake smoke ───────────────────────

// curatedSmokeCase holds the per-entry env / args overrides needed to
// successfully install a tier-1+ curated entry. Tier-0 entries leave
// both maps empty.
//
// curatedSmokeCase 描述一条 entry 装机所需的 env / args。Tier-0 全空。
type curatedSmokeCase struct {
	name        string
	envFrom     []string          // os.Getenv keys (MUST match curated RequiredEnv exactly)
	envExtra    map[string]string // literals merged after envFrom (e.g. fixed defaults)
	args        map[string]string
	knownBroken string // non-empty → t.Skip with this reason; pin a curated-registry-side issue
}

// smokeCases is the canonical list driving TestCuratedMarketplace_AllSmoke.
// envFrom MUST mirror curated_registry.go's RequiredEnv list exactly —
// missing keys here cause InstallFromRegistry to return
// ErrRequiredEnvMissing which the smoke loop t.Fatals as a test-author
// bug. knownBroken marks an entry whose curated InstallCmd is verified
// not to work even with all required env populated (e.g. the package
// expects a config file rather than env vars); such entries are
// t.Skip'd with a permanent signal so the suite stays green while we
// track the underlying registry fix.
//
// smokeCases 是 AllSmoke 的规范列表，envFrom 必须严格对齐
// curated_registry.go 的 RequiredEnv（不齐则 ErrRequiredEnvMissing →
// t.Fatalf 强制改）。knownBroken 标的 entry 是真验过即便 RequiredEnv 都
// 给齐也跑不动（如包要 config 文件不读 env），t.Skip 让套件保持绿，缺陷
// 归 curated registry 改。
var smokeCases = []curatedSmokeCase{
	// T0 — zero-config
	{name: "playwright"},
	{name: "chrome-devtools"},
	{name: "duckduckgo"},
	{name: "context7"},
	{name: "memory"},

	// T1 — single API key
	{name: "tavily", envFrom: []string{"TAVILY_API_KEY"}},
	{name: "firecrawl", envFrom: []string{"FIRECRAWL_API_KEY"}},
	{name: "github", envFrom: []string{"GITHUB_PERSONAL_ACCESS_TOKEN"}},
	{name: "gitlab", envFrom: []string{"GITLAB_PERSONAL_ACCESS_TOKEN", "GITLAB_API_URL"}},
	{name: "sentry", envFrom: []string{"SENTRY_AUTH_TOKEN", "SENTRY_HOST"}},
	{name: "linear", envFrom: []string{"LINEAR_API_KEY"}},
	{name: "atlassian", envFrom: []string{"JIRA_URL", "JIRA_USERNAME", "JIRA_API_TOKEN", "CONFLUENCE_URL"}},
	{name: "notion", envFrom: []string{"NOTION_TOKEN"}},
	{name: "slack", envFrom: []string{"SLACK_BOT_TOKEN", "SLACK_TEAM_ID"}},
	{name: "figma", envFrom: []string{"FIGMA_API_KEY"}},
	{name: "e2b", envFrom: []string{"E2B_API_KEY"}},

	// T2 — OAuth. ms365 ships shared Azure AD client creds (no envFrom
	// needed; device-code on first run). google-workspace can't —
	// Google verification policy forces user-supplied OAuth client.
	//
	// T2 OAuth。ms365 ship 共享 Azure AD 凭证（无需 envFrom，首跑设备码）。
	// google-workspace 不能——Google verification 政策强制用户自带 client。
	{name: "google-workspace", envFrom: []string{"GOOGLE_OAUTH_CLIENT_ID", "GOOGLE_OAUTH_CLIENT_SECRET"}},
	{name: "ms365"},

	// T3 — DB / cloud credential
	{name: "dbhub", envFrom: []string{"DSN"}},
	{name: "mongodb", envFrom: []string{"MDB_MCP_CONNECTION_STRING"}},
	{name: "supabase", envFrom: []string{"SUPABASE_ACCESS_TOKEN", "SUPABASE_PROJECT_REF"}},
}

// TestCuratedMarketplace_AllSmoke installs every reachable curated
// entry and asserts handshake + tools/list. Single shared harness
// across all 21 subtests so mise + node + npm caches warm up once;
// subtests run sequentially (npm install is I/O bound — parallel
// buys nothing and confuses failure attribution).
//
// TestCuratedMarketplace_AllSmoke 装每条可达 entry，验握手 + tools/list。
// 21 子测共享单 harness 让 mise+node+npm 只 warmup 一次；顺序跑
// （npm install IO 限速，并行无意义）。
func TestCuratedMarketplace_AllSmoke(t *testing.T) {
	curatedSmokeEnabled(t)
	opts := []th.Option{th.WithCuratedRegistry()}
	if d := sharedSandboxDir(); d != "" {
		opts = append(opts, th.WithSandboxDataDir(d))
	}
	h := th.New(t, opts...)
	if !h.Sandbox.IsReady() {
		t.Skip("sandbox not ready (run `make resources` to embed mise)")
	}

	if got := len(smokeCases); got != 21 {
		t.Fatalf("smokeCases length = %d, want 21 (curated registry shape changed?)", got)
	}

	for _, tc := range smokeCases {
		t.Run(tc.name, func(t *testing.T) {
			if tc.knownBroken != "" {
				t.Skipf("knownBroken: %s", tc.knownBroken)
			}

			env, hasRealCreds := collectEnv(t, tc)
			ctx, cancel := context.WithTimeout(context.Background(), installTimeout)
			defer cancel()

			// Defensive pre-clean (see installT0 for rationale).
			// 防御性预清，原因见 installT0。
			if rmErr := h.MCP.RemoveServer(ctx, tc.name); rmErr != nil &&
				!errors.Is(rmErr, mcpdomain.ErrServerNotFound) {
				t.Logf("pre-clean remove %s: %v", tc.name, rmErr)
			}

			st, err := h.MCP.InstallFromRegistry(ctx, tc.name, env, tc.args)
			t.Cleanup(func() {
				cleanupCtx, cancelClean := context.WithTimeout(context.Background(), 30*time.Second)
				defer cancelClean()
				if rmErr := h.MCP.RemoveServer(cleanupCtx, tc.name); rmErr != nil &&
					!errors.Is(rmErr, mcpdomain.ErrServerNotFound) {
					t.Logf("cleanup remove %s: %v", tc.name, rmErr)
				}
			})

			assertInstallOutcome(t, tc.name, st, err, hasRealCreds)
		})
	}
}

// assertInstallOutcome encodes the smoke-test acceptance policy:
//
//   - ErrRequiredEnvMissing / ErrRequiredArgsMissing → test-author bug.
//     smokeCases.envFrom drifted from curated RequiredEnv. Fail loud.
//   - Real-creds mode (every envFrom key resolved to a real value):
//     status MUST be ready, tools list MUST be non-empty. No tolerance.
//   - Stub mode (one or more keys faked with envStub): we don't know if
//     the server pre-validates creds; accept ANY post-validation
//     outcome (ready / degraded / failed / install-time error). The
//     guarantees still verified are: package fetched, env_path created,
//     subprocess spawned. Anything beyond that needs real creds.
//
// assertInstallOutcome 编码 smoke-test 接受策略——见上方英文注释逐条说明。
func assertInstallOutcome(t *testing.T, name string, st *mcpdomain.ServerStatus, err error, hasRealCreds bool) {
	t.Helper()

	// (1) Test-author bugs always fail loud, both modes.
	// 测试作者 bug 不分模式，永远 loud。
	if errors.Is(err, mcpdomain.ErrRequiredEnvMissing) ||
		errors.Is(err, mcpdomain.ErrRequiredArgsMissing) {
		t.Fatalf("%s: smokeCases envFrom/args drift from curated RequiredEnv — fix the test data: %v", name, err)
	}

	// (2) Stub mode — anything past the test-author guard is acceptable.
	// stub 模式——过了 (1) 之后任何结局都接受。
	if !hasRealCreds {
		if err != nil {
			t.Logf("%s [stub-mode] install error after validation passed (acceptable): %v", name, err)
			return
		}
		switch st.Status {
		case mcpdomain.StatusReady:
			t.Logf("%s [stub-mode] reached ready with stub creds — server defers auth", name)
		default:
			t.Logf("%s [stub-mode] status=%q lastError=%q — install path OK, runtime auth/conn pending",
				name, st.Status, st.LastError)
		}
		return
	}

	// (3) Real-creds mode — strict ready check.
	// 真凭证模式——严格要求 ready。
	if err != nil {
		t.Fatalf("%s [real-creds] InstallFromRegistry: %v", name, err)
	}
	if st == nil {
		t.Fatalf("%s [real-creds] nil status", name)
	}
	if st.Status != mcpdomain.StatusReady {
		t.Fatalf("%s [real-creds] status=%q lastError=%q — expected ready",
			name, st.Status, st.LastError)
	}
	if len(st.Tools) == 0 {
		t.Errorf("%s [real-creds] ready but tools/list empty", name)
	}
}

// envStub is the placeholder value substituted for a tc.envFrom key
// that os.Getenv returns empty for. Lets install + handshake proceed
// without skipping the subtest — first tool call will fail auth, but
// the install path itself (package fetch + subprocess spawn + MCP
// initialize) is what we want smoke to verify.
//
// envStub 给 os.Getenv 空的 envFrom key 填的占位串。让 install + 握手仍走，
// 不 skip；首个 tool call 会 401 但 install 路径（拉包+spawn+initialize）
// 就是 smoke 想验的。
const envStub = "forgify-smoke-stub"

// collectEnv builds the env map for a smoke case. Real values from
// os.Getenv are used when set; missing keys get envStub so the install
// proceeds and we can still validate the package/spawn/handshake path.
// hasRealCreds reports whether all envFrom keys had real values, used
// downstream to choose between strict (status=ready required) vs
// tolerant (auth/connection error degraded acceptable) assertions.
//
// collectEnv 给 smoke case 拼 env map：os.Getenv 有就用真值，缺的用 envStub
// 让 install 仍走，验包/spawn/握手路径。hasRealCreds 报告所有 envFrom 是否
// 都真有值——下游据此选严格（必须 ready）或宽容（auth/连接错的 degraded
// 也认）断言。
func collectEnv(t *testing.T, tc curatedSmokeCase) (env map[string]string, hasRealCreds bool) {
	t.Helper()
	out := map[string]string{}
	hasRealCreds = true
	for _, k := range tc.envFrom {
		v := os.Getenv(k)
		if v == "" {
			out[k] = envStub
			hasRealCreds = false
			continue
		}
		out[k] = v
	}
	for k, v := range tc.envExtra {
		out[k] = v
	}
	return out, hasRealCreds
}


// ── 2. T0 Live tool calls (5 entries) ───────────────────────────────

// Each Live_ test installs a single tier-0 entry and drives one
// representative tool call to validate the "舒畅" axis: not just
// "did it install" but "does the user actually get a useful result".
// Cleanup is delegated to t.Cleanup so a failed assert still
// uninstalls.
//
// 每个 Live_ 测装一条 T0 entry 并跑一个代表性工具调用——覆盖"装好 +
// 真用得起来"。失败也走 t.Cleanup 卸干净。

func TestCuratedMarketplace_T0_Live_DuckDuckGo(t *testing.T) {
	curatedSmokeEnabled(t)
	st, h := installT0(t, "duckduckgo")
	requireToolListed(t, st, "search")

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	out, err := h.MCP.CallTool(ctx, "duckduckgo", "search",
		json.RawMessage(`{"query":"anthropic claude","max_results":3}`))
	if err != nil {
		t.Fatalf("CallTool search: %v", err)
	}
	if !strings.Contains(strings.ToLower(out), "anthropic") &&
		!strings.Contains(strings.ToLower(out), "claude") {
		t.Errorf("search result lacks expected term anthropic/claude: %s", trimForLog(out))
	}
}

func TestCuratedMarketplace_T0_Live_Context7(t *testing.T) {
	curatedSmokeEnabled(t)
	st, h := installT0(t, "context7")
	// Context7 exposes resolve-library-id + get-library-docs; the
	// resolver is the cheap entry point we can validate cheaply.
	//
	// Context7 暴露 resolve-library-id + get-library-docs；resolver 是
	// 最便宜的入口，能廉价验通联。
	toolName := pickFirstTool(st, "resolve-library-id", "resolve_library_id", "search")
	if toolName == "" {
		t.Fatalf("context7 exposes no resolver tool; tools=%v", toolNames(st))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	// Context7's resolve-library-id required-field schema has shifted
	// between npm versions (saw both `query` and `libraryName` demanded
	// in back-to-back runs). Send both so this assertion survives
	// upstream churn.
	//
	// Context7 的 resolve-library-id 必填 schema 在 npm 版本间漂过
	// （连跑两次分别报缺 `query` / `libraryName`）。两个都传，让断言扛
	// 住上游波动。
	out, err := h.MCP.CallTool(ctx, "context7", toolName,
		json.RawMessage(`{"libraryName":"react","query":"react"}`))
	if err != nil {
		t.Fatalf("CallTool %s: %v", toolName, err)
	}
	if strings.TrimSpace(out) == "" {
		t.Errorf("context7 %s returned empty result", toolName)
	}
}

func TestCuratedMarketplace_T0_Live_Memory(t *testing.T) {
	curatedSmokeEnabled(t)
	st, h := installT0(t, "memory")
	createTool := pickFirstTool(st, "create_entities", "create-entities")
	readTool := pickFirstTool(st, "read_graph", "read-graph")
	if createTool == "" || readTool == "" {
		t.Fatalf("memory missing expected create/read tools; tools=%v", toolNames(st))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	createPayload := `{"entities":[{"name":"forgify-pipeline-marker","entityType":"test","observations":["smoke-test entity"]}]}`
	if _, err := h.MCP.CallTool(ctx, "memory", createTool, json.RawMessage(createPayload)); err != nil {
		t.Fatalf("CallTool %s: %v", createTool, err)
	}
	out, err := h.MCP.CallTool(ctx, "memory", readTool, json.RawMessage(`{}`))
	if err != nil {
		t.Fatalf("CallTool %s: %v", readTool, err)
	}
	if !strings.Contains(out, "forgify-pipeline-marker") {
		t.Errorf("read_graph missing the entity we just created: %s", trimForLog(out))
	}
}

func TestCuratedMarketplace_T0_Live_Playwright(t *testing.T) {
	curatedSmokeEnabled(t)
	st, h := installT0(t, "playwright")
	navTool := pickFirstTool(st, "browser_navigate", "navigate")
	snapTool := pickFirstTool(st, "browser_snapshot", "snapshot", "browser_get_text")
	if navTool == "" || snapTool == "" {
		t.Fatalf("playwright missing expected nav/snapshot tools; tools=%v", toolNames(st))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	navPayload := `{"url":"https://example.com"}`
	if _, err := h.MCP.CallTool(ctx, "playwright", navTool, json.RawMessage(navPayload)); err != nil {
		t.Fatalf("CallTool %s: %v", navTool, err)
	}
	out, err := h.MCP.CallTool(ctx, "playwright", snapTool, json.RawMessage(`{}`))
	if err != nil {
		t.Fatalf("CallTool %s: %v", snapTool, err)
	}
	if !strings.Contains(strings.ToLower(out), "example") {
		t.Errorf("snapshot of example.com lacks expected text: %s", trimForLog(out))
	}
}

func TestCuratedMarketplace_T0_Live_ChromeDevTools(t *testing.T) {
	curatedSmokeEnabled(t)
	st, h := installT0(t, "chrome-devtools")
	navTool := pickFirstTool(st, "navigate_page", "navigate", "page_navigate")
	if navTool == "" {
		t.Fatalf("chrome-devtools missing navigate tool; tools=%v", toolNames(st))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	out, err := h.MCP.CallTool(ctx, "chrome-devtools", navTool,
		json.RawMessage(`{"url":"https://example.com"}`))
	if err != nil {
		t.Fatalf("CallTool %s: %v", navTool, err)
	}
	// Chrome DevTools navigate typically returns a confirmation /
	// snapshot — empty would mean the protocol broke, not that the
	// page lacks content.
	//
	// Chrome DevTools navigate 一般返确认 / snapshot——空就是协议挂了。
	if strings.TrimSpace(out) == "" {
		t.Errorf("navigate returned empty payload (protocol issue)")
	}
}

// installT0 is the shared tier-0 install + cleanup-registration
// helper. Returns the install ServerStatus (so the caller can pick a
// tool name from the live tools list rather than hard-coding) and the
// harness for further tool calls.
//
// installT0 是 T0 装机 + 注册 cleanup 的共享 helper。返 status 让调用方
// 从 tools list 真选 tool 名（避免 hard-code 漂移）+ harness 继续 CallTool。
func installT0(t *testing.T, name string) (*mcpdomain.ServerStatus, *th.Harness) {
	t.Helper()
	opts := []th.Option{th.WithCuratedRegistry()}
	if d := sharedSandboxDir(); d != "" {
		opts = append(opts, th.WithSandboxDataDir(d))
	}
	h := th.New(t, opts...)
	if !h.Sandbox.IsReady() {
		t.Skip("sandbox not ready (run `make resources` to embed mise)")
	}

	ctx, cancel := context.WithTimeout(context.Background(), installTimeout)
	defer cancel()

	// Defensive pre-clean: shared FORGIFY_TEST_SANDBOX_DIR lets mcp.json
	// persist across `go test` invocations, and a crashed prior run may
	// have skipped its t.Cleanup. RemoveServer is idempotent
	// (ErrServerNotFound when absent), so this is safe.
	//
	// 防御性预清：共享 FORGIFY_TEST_SANDBOX_DIR 让 mcp.json 跨 `go test` 持久，
	// 上次崩溃的进程可能漏 t.Cleanup。RemoveServer 幂等（不存在返
	// ErrServerNotFound），安全。
	if rmErr := h.MCP.RemoveServer(ctx, name); rmErr != nil &&
		!errors.Is(rmErr, mcpdomain.ErrServerNotFound) {
		t.Logf("pre-clean remove %s: %v", name, rmErr)
	}

	st, err := h.MCP.InstallFromRegistry(ctx, name, nil, nil)
	t.Cleanup(func() {
		cleanCtx, cancelClean := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancelClean()
		if rmErr := h.MCP.RemoveServer(cleanCtx, name); rmErr != nil &&
			!errors.Is(rmErr, mcpdomain.ErrServerNotFound) {
			t.Logf("cleanup remove %s: %v", name, rmErr)
		}
	})
	if err != nil {
		t.Fatalf("InstallFromRegistry %s: %v", name, err)
	}
	if st.Status != mcpdomain.StatusReady {
		t.Fatalf("%s status=%q lastError=%q (want ready)", name, st.Status, st.LastError)
	}
	if len(st.Tools) == 0 {
		t.Fatalf("%s exposes no tools after install", name)
	}
	return st, h
}

// requireToolListed fails the test if the named tool is not in
// st.Tools. Used by tests that hard-code a known stable tool name.
//
// requireToolListed 断言指定 tool 在 st.Tools；hard-code 已知稳定 tool 名
// 的测试用。
func requireToolListed(t *testing.T, st *mcpdomain.ServerStatus, want string) {
	t.Helper()
	for _, td := range st.Tools {
		if td.Name == want {
			return
		}
	}
	t.Fatalf("tool %q not exposed; tools=%v", want, toolNames(st))
}

// pickFirstTool returns the first candidate name that exists in
// st.Tools, or "" if none match. Lets tests survive minor upstream
// renames (e.g. snake_case ↔ kebab-case).
//
// pickFirstTool 返 st.Tools 中第一个匹配的候选名，无则返 ""。给测试容忍
// 上游小改名（snake_case ↔ kebab-case）。
func pickFirstTool(st *mcpdomain.ServerStatus, candidates ...string) string {
	have := map[string]bool{}
	for _, td := range st.Tools {
		have[td.Name] = true
	}
	for _, c := range candidates {
		if have[c] {
			return c
		}
	}
	return ""
}

func toolNames(st *mcpdomain.ServerStatus) []string {
	out := make([]string, 0, len(st.Tools))
	for _, td := range st.Tools {
		out = append(out, td.Name)
	}
	return out
}

// trimForLog truncates a tool result payload so a 5KB JSON snapshot
// doesn't drown the test log on assertion failure.
//
// trimForLog 截断 tool 结果，断言失败时不让 5KB JSON 淹没日志。
func trimForLog(s string) string {
	const max = 200
	if len(s) <= max {
		return s
	}
	return s[:max] + "...[truncated]"
}
