//go:build pipeline

// skill_test.go — pipeline tests for the Skill subsystem. Three offline
// scenarios using FakeLLMServer + Script queues drive the chat loop with
// the search_skills + activate_skill system tools, exercising the full
// path: chat runner → loop → tool dispatch → Service.Search/Activate →
// (for fork) subagent spawn → tool_result back to parent LLM.
//
// Scenarios per skill.md §14:
//
//  1. Activate_Inline_E2E
//     Parent LLM emits activate_skill for a non-fork skill seeded into
//     the harness's SkillsDir. Verify the tool_result text contains the
//     substituted body (with $1 substitution from the user-supplied
//     argument).
//
//  2. Search_Then_Activate_E2E
//     Parent emits search_skills first, gets a JSON list, then emits
//     activate_skill referencing one of the returned names. Verify both
//     tool_call blocks have proper tool_result pairings and the activate
//     result carries the body.
//
//  3. PreApproval_Bash_AfterActivate
//     Skill seeded with allowed-tools: Bash(echo *). Parent emits
//     activate_skill, then Bash echo "hello". Verify Bash actually ran
//     (output contains "hello") rather than being denied — proves the
//     framework permission integration (D7-6) wires through end-to-end.
//
// All three are offline (FakeLLMServer); no LLM ranking is exercised
// because skill catalogs are tiny (≤topK short-circuit applies).
//
// skill_test.go ——Skill 子系统 pipeline 测试。3 个离线场景（FakeLLM Script
// 队列）驱动 chat loop + search_skills + activate_skill 系统工具，覆盖
// 全路径：chat runner → loop → tool dispatch → Service.Search/Activate
// →（fork 时）subagent spawn → tool_result 回父 LLM。
package skill

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// seedSkill writes a SKILL.md into the harness's SkillsDir and triggers
// Service.Scan so the in-memory cache reflects it. Pattern parallels the
// MCP harness's AddServer + connect.
//
// seedSkill 写 SKILL.md 到 harness SkillsDir 并触发 Service.Scan 让内存
// cache 反映。模式同 MCP harness AddServer + connect。
func seedSkill(t *testing.T, h *th.Harness, name, frontmatter, body string) {
	t.Helper()
	dir := filepath.Join(h.Skill.SkillsDir(), name)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("seedSkill mkdir %s: %v", dir, err)
	}
	content := "---\n" + frontmatter + "\n---\n" + body
	if err := os.WriteFile(filepath.Join(dir, "SKILL.md"), []byte(content), 0o644); err != nil {
		t.Fatalf("seedSkill write %s/SKILL.md: %v", name, err)
	}
	if err := h.Skill.Scan(context.Background()); err != nil {
		t.Fatalf("seedSkill Scan: %v", err)
	}
}

// ── 1. Activate inline (non-fork) ────────────────────────────────────

func TestSkill_Activate_Inline_E2E(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	// Turn 1: parent emits activate_skill with arg "1234".
	// turn 1：父 emit activate_skill 带 arg "1234"。
	fake.PushScript(th.ScriptSingleToolCall(
		"activate_skill", "call_act_1",
		`{"name":"pr-review","arguments":["1234"],"summary":"running pr-review skill"}`,
	))
	// Turn 2: parent reads tool_result + emits final ack.
	// turn 2：父读 tool_result + emit 最终 ack。
	fake.PushScript(th.ScriptText("Skill loaded. Following the steps for PR #1234."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	seedSkill(t, h, "pr-review",
		`name: pr-review
description: Review a GitHub PR
arguments:
  - pr_number`,
		`# Review PR #$1
Step 1: gh pr view $1`)

	conv := h.NewConversation(t, "skill-activate-inline")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Review pull request 1234")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errCode=%q errMsg=%q\nraw:\n%s",
			final.Status, final.ErrorCode, final.ErrorMessage, sub.FormatRawEvents())
	}

	tcID, ok := th.ExtractToolCallByName(final.Blocks, "activate_skill")
	if !ok {
		t.Fatalf("no activate_skill tool_call in final blocks\nraw:\n%s", sub.FormatRawEvents())
	}
	resultData, ok := th.ExtractToolResultByCallID(final.Blocks, tcID)
	if !ok {
		t.Fatalf("no paired tool_result for activate_skill call %q", tcID)
	}
	if okFlag, _ := resultData["ok"].(bool); !okFlag {
		t.Errorf("activate_skill tool_result.ok=false; data=%v", resultData)
	}
	resultText, _ := resultData["result"].(string)
	if !strings.Contains(resultText, "Review PR #1234") {
		t.Errorf("activate_skill result lacks $1 substitution: %q", resultText)
	}
	if !strings.Contains(resultText, "gh pr view 1234") {
		t.Errorf("activate_skill result lacks step body: %q", resultText)
	}
}

// ── 2. Search → Activate ─────────────────────────────────────────────

func TestSkill_Search_Then_Activate_E2E(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	// Turn 1: search.
	// turn 1：搜。
	fake.PushScript(th.ScriptSingleToolCall(
		"search_skills", "call_search_1",
		`{"query":"deploy","summary":"finding deploy skill"}`,
	))
	// Turn 2: activate using a name discovered (we know it's "deploy" in the seed).
	// turn 2：用搜到的 name 激活（种了 "deploy"）。
	fake.PushScript(th.ScriptSingleToolCall(
		"activate_skill", "call_act_2",
		`{"name":"deploy","arguments":["staging"],"summary":"activating deploy"}`,
	))
	// Turn 3: ack.
	// turn 3：ack。
	fake.PushScript(th.ScriptText("Deploy steps loaded for staging."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	seedSkill(t, h, "deploy",
		`name: deploy
description: Deploy via internal CI
arguments:
  - environment`,
		`# Deploy to $1
make deploy-$1`)

	conv := h.NewConversation(t, "skill-search-activate")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "I want to deploy")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errMsg=%q\nraw:\n%s", final.Status, final.ErrorMessage, sub.FormatRawEvents())
	}

	// search_skills tool call + result.
	// search_skills tool call + result。
	searchID, ok := th.ExtractToolCallByName(final.Blocks, "search_skills")
	if !ok {
		t.Fatalf("no search_skills tool_call in final blocks")
	}
	searchResult, ok := th.ExtractToolResultByCallID(final.Blocks, searchID)
	if !ok {
		t.Fatalf("no paired tool_result for search_skills")
	}
	searchText, _ := searchResult["result"].(string)
	// Should be a JSON array including deploy.
	// 应是含 deploy 的 JSON 数组。
	var rows []map[string]any
	if err := json.Unmarshal([]byte(searchText), &rows); err != nil {
		t.Fatalf("search_skills result not JSON list: %v\nresult: %s", err, searchText)
	}
	if len(rows) < 1 || rows[0]["name"] != "deploy" {
		t.Errorf("search_skills did not surface 'deploy': %v", rows)
	}

	// activate_skill tool call + result.
	// activate_skill tool call + result。
	actID, ok := th.ExtractToolCallByName(final.Blocks, "activate_skill")
	if !ok {
		t.Fatalf("no activate_skill tool_call in final blocks")
	}
	actResult, ok := th.ExtractToolResultByCallID(final.Blocks, actID)
	if !ok {
		t.Fatalf("no paired tool_result for activate_skill")
	}
	actText, _ := actResult["result"].(string)
	if !strings.Contains(actText, "Deploy to staging") {
		t.Errorf("activate_skill result lacks $1 substitution: %q", actText)
	}
	if !strings.Contains(actText, "make deploy-staging") {
		t.Errorf("activate_skill result lacks body: %q", actText)
	}
}

// ── 3. PreApproval gates Bash via active skill ───────────────────────

// Verifies framework permission integration (D7-6) end-to-end: an
// activate_skill call sets ActiveSkill on AgentState, and the next
// tool dispatch (Bash) is short-circuited by IsToolPreApprovedBySkill
// rather than going through Bash's own CheckPermissions. We can prove
// the bypass by allowing a Bash command that the skill explicitly
// pre-approves (Bash(echo *)) and verifying it ran.
//
// 验 framework 权限集成（D7-6）端到端：activate_skill 给 AgentState 设
// ActiveSkill，后续 Bash dispatch 经 IsToolPreApprovedBySkill 短路而非
// 走 Bash 自己的 CheckPermissions。允一个 skill 显式预授权的 Bash
// （Bash(echo *)）跑 + 验确实跑。
func TestSkill_PreApproval_BashAfterActivate(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptSingleToolCall(
		"activate_skill", "call_act_3",
		`{"name":"hello-runner","summary":"loading hello-runner"}`,
	))
	fake.PushScript(th.ScriptSingleToolCall(
		"Bash", "call_bash_1",
		`{"command":"echo hello-from-skill","summary":"running echo step"}`,
	))
	fake.PushScript(th.ScriptText("All steps complete."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	seedSkill(t, h, "hello-runner",
		`name: hello-runner
description: Print hello via echo
allowed-tools:
  - Bash(echo *)`,
		`# Run echo
Just an echo demo.`)

	conv := h.NewConversation(t, "skill-preapproval")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Run hello-runner")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errMsg=%q\nraw:\n%s", final.Status, final.ErrorMessage, sub.FormatRawEvents())
	}

	// Bash tool call must have a tool_result whose output contains the
	// echoed string — proves Bash ran. (If pre-approval failed Bash's
	// own CheckPermissions would have denied; the pipeline test would
	// see ok=false here.)
	// Bash tool call 必须有 tool_result 含 echo 串——证明 Bash 跑了。
	// （预授权失败时 Bash 自己的 CheckPermissions 会拒；ok=false 出现）。
	bashID, ok := th.ExtractToolCallByName(final.Blocks, "Bash")
	if !ok {
		t.Fatalf("no Bash tool_call in final blocks\nraw:\n%s", sub.FormatRawEvents())
	}
	bashResult, ok := th.ExtractToolResultByCallID(final.Blocks, bashID)
	if !ok {
		t.Fatalf("no paired tool_result for Bash")
	}
	if okFlag, _ := bashResult["ok"].(bool); !okFlag {
		t.Errorf("Bash tool_result.ok=false; pre-approval should have allowed echo. data=%v", bashResult)
	}
	bashOutput, _ := bashResult["result"].(string)
	if !strings.Contains(bashOutput, "hello-from-skill") {
		t.Errorf("Bash output lacks echoed text; pre-approval may not have actually allowed the run.\noutput: %q", bashOutput)
	}

	// Sanity: this exercise didn't accidentally spawn a subagent. Proves
	// non-fork activate stays inline.
	// 完整性：本场景未误 spawn subagent。证非 fork activate 走 inline。
	var runCount int64
	if err := h.DB.Raw(`SELECT COUNT(*) FROM subagent_runs WHERE parent_conversation_id = ?`, conv.ID).Scan(&runCount).Error; err != nil {
		t.Fatalf("query subagent_runs: %v", err)
	}
	if runCount != 0 {
		t.Errorf("subagent_runs = %d for non-fork skill activate; want 0", runCount)
	}

	// Suppress "subagentdomain unused" if we drop the subagent_runs
	// query above in the future.
	// 防 subagentdomain unused（未来若删 subagent_runs 查询）。
	_ = subagentdomain.StatusCompleted
}
