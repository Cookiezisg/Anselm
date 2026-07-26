// chat_workdir_test.go — WRK-077 WD1 对话驻地（可选工作目录）的黑盒验收。
//
// 要害是用户那句话:驻地是**可选**的、语义是**告诉 AI 聚焦这里**、**不是牢笼**——外面仍可看。故每一条场景
// 都成对断言:挂了驻地会发生什么，以及**没挂**时行为与 WD1 之前逐字相同。
//
// 六项由工单点名、各自独立场景（每个是隔离宇宙，可 -run 单跑）：
//   - 挂 / 不挂两态（PATCH 面 + `GET /{id}/workdir` 投影 + 系统提示注入）
//   - 越界写弹闸（LLM 自报 safe 照样弹；批准即真写；拒绝即真没写）
//   - 相对路径以驻地为根（Write 落在目录里，未挂时同一次调用被拒）
//   - Bash 的 cmd.Dir（`pwd -P` 报驻地）
//   - marker 落行且可读（`GET /{id}/messages` 带回 attrs，且**不新增 SSE 帧型**）
//   - subagent 继承（子运行的相对写落进同一驻地）
//
// 只有物理行/进程输出能证明的才下潜到工具的真实副作用（真文件、真 pwd）;线缆能证明的用线缆。
package scenarios

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// wdMount PATCHes the residency and returns the row the server echoed back (the authoritative value —
// `~` is expanded and the path Cleaned server-side, so a test must never assume its own spelling won).
//
// wdMount 打 PATCH 挂驻地并返回服务端回显的行（权威值——`~` 在服务端展开、路径在服务端 Clean，故测试绝不
// 该假定自己那种拼法胜出）。
func wdMount(t *testing.T, wc *harness.Client, convID, dir string) string {
	t.Helper()
	var row struct {
		WorkDir string `json:"workDir"`
	}
	wc.PATCH("/api/v1/conversations/"+convID, map[string]any{"workDir": dir}).OK(t, &row)
	return row.WorkDir
}

// wdInfo reads the live residency projection.
//
// wdInfo 读驻地的活投影。
type wdInfoRow struct {
	Path      string `json:"path"`
	Exists    bool   `json:"exists"`
	IsGitRepo bool   `json:"isGitRepo"`
	Branch    string `json:"branch"`
	Dirty     bool   `json:"dirty"`
}

func wdInfo(t *testing.T, wc *harness.Client, convID string) wdInfoRow {
	t.Helper()
	var info wdInfoRow
	wc.GET("/api/v1/conversations/"+convID+"/workdir").OK(t, &info)
	return info
}

// fsCall scripts one filesystem tool call at the danger level the LLM would honestly self-report for an
// ordinary edit. `safe` is the point: the residency gate must not depend on the model's own honesty.
//
// fsCall 脚本化一次文件工具调用，danger 用 LLM 对一次普通编辑本会诚实自报的等级。`safe` 正是要害:驻地闸
// 绝不能依赖模型自己的诚实。
func fsCall(id, tool string, args map[string]any) harness.MockToolCall {
	full := map[string]any{"summary": "write a file", "danger": "safe", "execution_group": 1}
	for k, v := range args {
		full[k] = v
	}
	return harness.MockToolCall{ID: id, Name: tool, Args: full}
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 挂 / 不挂两态
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDir_MountedAndUnmountedStates: the residency is OPTIONAL, so the two states must both be
// first-class on the wire. A new conversation is unmounted and its projection is a SUCCESS (not a 404) —
// the button has to render that state too; mounting echoes the normalized absolute path; unmounting is the
// empty string (there is no third state, hence no tristate); and the system prompt gains a work_dir
// section only while mounted, so an unmounted thread's prompt is what it was before WD1.
//
// TestChatWorkDir_MountedAndUnmountedStates：驻地是**可选**的，故两态在线缆上都必须是一等状态。新对话未挂、
// 其投影是**成功**（不是 404）——按钮也得渲那一态；挂载回显归一化后的绝对路径；退出驻地是空串（没有第三种
// 状态，故不要三态）；system prompt **仅在挂载时**多出 work_dir 段，故未挂线程的 prompt 与 WD1 之前相同。
func TestChatWorkDir_MountedAndUnmountedStates(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	root := t.TempDir()

	// ── unmounted: the default, and a legitimate readable state ──
	convID := convCreate(t, wc, "residency states")
	if info := wdInfo(t, wc, convID); info.Path != "" || info.Exists {
		t.Fatalf("a new conversation must be unmounted and say so successfully, got %+v", info)
	}
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "unmounted."})
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "where are we?"), 30000)
	un := mock.WaitDumps(t, dlgModel, 1, 8000)[0]
	if strings.Contains(un.System, `name="work_dir"`) {
		t.Fatalf("an unmounted thread must carry NO work_dir section:\n%s", un.System)
	}

	// ── mounted: PATCH echoes the normalized path, the projection reports the live truth ──
	if got := wdMount(t, wc, convID, root); got != root {
		t.Fatalf("PATCH echoed workDir %q, want %q", got, root)
	}
	if got := wdMount(t, wc, convID, root+"/./sub/.."); got != root {
		t.Fatalf("the stored path must be Cleaned server-side, got %q want %q", got, root)
	}
	info := wdInfo(t, wc, convID)
	if info.Path != root || !info.Exists {
		t.Fatalf("mounted projection: %+v (want path=%q exists=true)", info, root)
	}
	if info.IsGitRepo {
		t.Fatalf("a plain temp dir is not a git repo: %+v", info)
	}
	// GET /{id} carries the column too, so the rail/head needs one read, not two.
	// GET /{id} 也带这一列，故 rail/头部读一次而非两次。
	var head struct {
		WorkDir string `json:"workDir"`
	}
	wc.GET("/api/v1/conversations/"+convID).OK(t, &head)
	if head.WorkDir != root {
		t.Fatalf("the conversation row must carry workDir, got %q", head.WorkDir)
	}

	// The next turn's system prompt names the residency — that is the whole of "tell the AI to focus here".
	// 下一回合的 system prompt 点出驻地——这就是「告诉 AI 聚焦这里」的全部。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "mounted."})
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "and now?"), 30000)
	dumps := mock.WaitDumps(t, dlgModel, 2, 8000)
	sys := dumps[len(dumps)-1].System
	if !strings.Contains(sys, `name="work_dir"`) || !strings.Contains(sys, root) {
		t.Fatalf("a mounted thread's system prompt must name the work dir:\n%s", sys)
	}
	// It must state the ZOOM honestly, not imply a jail — an agent told it is caged refuses work it is
	// allowed to do. 它必须诚实地陈述 **zoom**、不暗示牢笼——被告知自己被关起来的 agent 会拒掉它本被允许做的事。
	if !strings.Contains(sys, "may still read anywhere") {
		t.Fatalf("the work_dir section must say reads outside are still allowed:\n%s", sys)
	}

	// ── unmounted again: the empty string IS the clear ──
	if got := wdMount(t, wc, convID, ""); got != "" {
		t.Fatalf("an empty workDir must unmount, got %q", got)
	}
	if info := wdInfo(t, wc, convID); info.Path != "" || info.Exists {
		t.Fatalf("after unmount the projection must be the zero one, got %+v", info)
	}

	// A relative workDir is refused ONCE, here — a root that cannot root anything would otherwise fail
	// silently on every later tool call. 相对 workDir 在此被拒**一次**——否则一个扎不住任何东西的根会在此后
	// 每次工具调用里静默失效。
	r := wc.PATCH("/api/v1/conversations/"+convID, map[string]any{"workDir": "relative/dir"})
	if r.Status != 422 {
		t.Fatalf("a relative workDir must be 422, got %d %s", r.Status, r.Raw)
	}
	if !strings.Contains(string(r.Raw), "CONVERSATION_INVALID_WORK_DIR") {
		t.Fatalf("the refusal must carry the stable code: %s", r.Raw)
	}
	// An unknown conversation is still the ordinary 404. 未知对话仍是普通 404。
	if got := wc.GET("/api/v1/conversations/cv_0000000000000000/workdir").Status; got != 404 {
		t.Fatalf("unknown conversation must 404, got %d", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ② 相对路径以驻地为根
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDir_RelativePathResolvesAgainstResidency: with a residency, `notes.md` becomes a real file
// INSIDE it — and the assertion is the file on disk, not the tool's answer, because a resolver that lies
// would happily report success. Unmounted, the SAME call is refused as before WD1, which is what makes
// this a residency feature rather than a loosening of the absolute-path rule.
//
// TestChatWorkDir_RelativePathResolvesAgainstResidency：挂了驻地时 `notes.md` 成为它**里面**一个真文件——
// 断言的是盘上的文件、不是工具的回答，因为一个撒谎的解析器也会欢快地报成功。未挂时**同一次**调用像 WD1 之前
// 一样被拒，正是这一点让它成为驻地功能、而不是对绝对路径铁律的松绑。
func TestChatWorkDir_RelativePathResolvesAgainstResidency(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	root := t.TempDir()

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("c1", "Write", map[string]any{
			"file_path": "notes.md", "content": "RESIDENT-CONTENT",
		})}},
		harness.LLMTurn{Text: "written."},
	)
	convID := convCreate(t, wc, "relative write")
	wdMount(t, wc, convID, root)
	if turn := waitTurn(t, wc, convID, sendMsg(t, wc, convID, "write notes.md"), 30000); turn.Status != "completed" {
		t.Fatalf("turn: %s %s", turn.Status, turn.ErrorMessage)
	}
	got, err := os.ReadFile(filepath.Join(root, "notes.md"))
	if err != nil || string(got) != "RESIDENT-CONTENT" {
		t.Fatalf("a relative path must land INSIDE the residency: err=%v content=%q", err, got)
	}

	// A nested relative path too — the join is not just a basename special case.
	// 嵌套相对路径亦然——那个 join 不是只对 basename 生效的特例。
	if err := os.MkdirAll(filepath.Join(root, "docs"), 0o755); err != nil {
		t.Fatal(err)
	}
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("c2", "Write", map[string]any{
			"file_path": "docs/deep.md", "content": "NESTED",
		})}},
		harness.LLMTurn{Text: "nested."},
	)
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "write docs/deep.md"), 30000)
	if b, err := os.ReadFile(filepath.Join(root, "docs", "deep.md")); err != nil || string(b) != "NESTED" {
		t.Fatalf("nested relative write: err=%v content=%q", err, b)
	}

	// Unmounted: the very same call is refused, and the refusal names the real reason so the model can act.
	// 未挂：**同一次**调用被拒，且拒绝说出真实原因，使模型能据此行动。
	bare := convCreate(t, wc, "no residency")
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("c3", "Write", map[string]any{
			"file_path": "notes.md", "content": "SHOULD-NOT-EXIST",
		})}},
		harness.LLMTurn{Text: "refused."},
	)
	waitTurn(t, wc, bare, sendMsg(t, wc, bare, "write notes.md"), 30000)
	if !strings.Contains(toolResultsOf(t, wc, bare), "must be absolute") {
		t.Fatalf("without a residency a relative path must still be refused:\n%s", toolResultsOf(t, wc, bare))
	}
}

// toolResultsOf concatenates every tool_result block in a conversation (the model's-eye answers).
//
// toolResultsOf 拼接一个对话里所有 tool_result 块（模型看到的那些答案）。
func toolResultsOf(t *testing.T, wc *harness.Client, convID string) string {
	t.Helper()
	var b strings.Builder
	for _, m := range listMsgs(t, wc, convID) {
		for _, blk := range m.Blocks {
			if blk.Type == "tool_result" {
				b.WriteString(blk.Content)
				b.WriteString("\n")
			}
		}
	}
	return b.String()
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ 越界写弹闸
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDir_OutOfRootWriteForcesTheHumanGate: the batch's core safety claim, end to end over real
// HTTP. A write OUTSIDE the residency surfaces a pending interaction even though the LLM called it `safe`,
// the pending prompt says WHY (`outsideWorkDir`), a DENY leaves the file absent (interrupt-before-side-
// effect — the refusal must be a real refusal, not an after-the-fact complaint), and an APPROVE really
// writes it. Reads outside are never gated — that is the user's own "if I want to look outside, I can".
//
// TestChatWorkDir_OutOfRootWriteForcesTheHumanGate：本批核心的安全主张，端到端走真 HTTP。驻地**之外**的写
// 会浮出一个待决 interaction，尽管 LLM 称它 `safe`；待决 prompt 说明**为什么**（`outsideWorkDir`）；**拒绝**后
// 文件不存在（interrupt-before-side-effect——拒绝必须是**真的**拒绝、不是事后抱怨）；**批准**后它真的被写。
// 往外**读**从不设闸——那是用户自己那句「想看外面什么的，都可以」。
func TestChatWorkDir_OutOfRootWriteForcesTheHumanGate(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	base := t.TempDir()
	root := filepath.Join(base, "root")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	outsideFile := filepath.Join(base, "outside.txt")
	secret := filepath.Join(base, "secret.txt")
	if err := os.WriteFile(secret, []byte("READABLE-FROM-ANYWHERE"), 0o644); err != nil {
		t.Fatal(err)
	}

	// ── deny: a `safe` out-of-root write still asks, and the denial leaves nothing behind ──
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("c-deny", "Write", map[string]any{
			"file_path": outsideFile, "content": "SHOULD-NEVER-LAND",
		})}},
		harness.LLMTurn{Text: "denied, rerouting."},
	)
	convID := convCreate(t, wc, "out of root")
	wdMount(t, wc, convID, root)
	mid := sendMsg(t, wc, convID, "write outside")

	pend := waitPending(t, wc, convID)
	if pend.Kind != "danger" || pend.Tool != "Write" {
		t.Fatalf("pending interaction wrong: %+v", pend)
	}
	var prompt map[string]any
	if err := json.Unmarshal(pend.Prompt, &prompt); err != nil {
		t.Fatalf("pending prompt is not JSON: %v (%s)", err, pend.Prompt)
	}
	if prompt["outsideWorkDir"] != true {
		t.Fatalf("the confirmation must say WHY it is asking (a prompt that cannot explain itself gets clicked through): %v", prompt)
	}
	wc.POST("/api/v1/conversations/"+convID+"/interactions/"+pend.ToolCallID,
		map[string]any{"action": "deny"}).OK(t, nil)
	waitTurn(t, wc, convID, mid, 30000)
	if _, err := os.Stat(outsideFile); err == nil {
		t.Fatal("a DENIED out-of-root write must never have run — interrupt-before-side-effect")
	}

	// ── approve: the user said yes about this path, so it really writes ──
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("c-ok", "Write", map[string]any{
			"file_path": outsideFile, "content": "APPROVED-CONTENT",
		})}},
		harness.LLMTurn{Text: "approved, wrote it."},
	)
	mid2 := sendMsg(t, wc, convID, "write outside, really")
	pend2 := waitPending(t, wc, convID)
	wc.POST("/api/v1/conversations/"+convID+"/interactions/"+pend2.ToolCallID,
		map[string]any{"action": "approve"}).OK(t, nil)
	waitTurn(t, wc, convID, mid2, 30000)
	if b, err := os.ReadFile(outsideFile); err != nil || string(b) != "APPROVED-CONTENT" {
		t.Fatalf("an APPROVED out-of-root write must land: err=%v content=%q", err, b)
	}

	// ── a write INSIDE the root never asks ──
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("c-in", "Write", map[string]any{
			"file_path": "inside.txt", "content": "NO-GATE",
		})}},
		harness.LLMTurn{Text: "wrote inside."},
	)
	mid3 := sendMsg(t, wc, convID, "write inside")
	if turn := waitTurn(t, wc, convID, mid3, 30000); turn.Status != "completed" {
		t.Fatalf("an in-root write must complete with no confirmation: %s %s", turn.Status, turn.ErrorMessage)
	}
	if b, err := os.ReadFile(filepath.Join(root, "inside.txt")); err != nil || string(b) != "NO-GATE" {
		t.Fatalf("in-root write: err=%v content=%q", err, b)
	}

	// ── a READ outside the root never asks either: the residency is a zoom, not a jail ──
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("c-read", "Read", map[string]any{
			"file_path": secret,
		})}},
		harness.LLMTurn{Text: "read it."},
	)
	mid4 := sendMsg(t, wc, convID, "read outside")
	if turn := waitTurn(t, wc, convID, mid4, 30000); turn.Status != "completed" {
		t.Fatalf("a read outside the residency must complete ungated: %s %s", turn.Status, turn.ErrorMessage)
	}
	if !strings.Contains(toolResultsOf(t, wc, convID), "READABLE-FROM-ANYWHERE") {
		t.Fatalf("the model must actually have read the outside file:\n%s", toolResultsOf(t, wc, convID))
	}
}

// pendingRow is one entry of GET /{id}/interactions. Prompt is kept RAW so a test can assert the payload's
// own keys rather than a re-encoded copy.
//
// pendingRow 是 GET /{id}/interactions 的一项。Prompt 保留**原始** JSON，使测试断言载荷自己的键、而非一份
// 重新编码的副本。
type pendingRow struct {
	ToolCallID string          `json:"toolCallId"`
	Kind       string          `json:"kind"`
	Tool       string          `json:"tool"`
	Prompt     json.RawMessage `json:"prompt"`
}

func waitPending(t *testing.T, wc *harness.Client, convID string) pendingRow {
	t.Helper()
	var pending []pendingRow
	harness.Eventually(t, 20000, "an interaction pends for the out-of-root write", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+convID+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	return pending[0]
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ Bash 的 cmd.Dir
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDir_BashRunsInTheResidency: `pwd -P` is asserted through the tool_result the MODEL received,
// because that is the only thing that proves the child process really chdir'd — a cmd.Dir set but not
// honoured would look identical from the outside. `pwd -P` (physical) rather than the plain builtin: sh
// inherits $PWD from the backend's environment and would happily report a stale logical path.
//
// Unmounted, the same command must NOT report the residency — otherwise the assertion could be passing on
// an inherited directory that happens to match.
//
// TestChatWorkDir_BashRunsInTheResidency：`pwd -P` 经**模型收到的** tool_result 断言，因为只有它能证明子进程
// 真的 chdir 了——设了却不生效的 cmd.Dir 从外面看一模一样。用 `pwd -P`（物理）而非朴素 builtin：sh 从后端环境
// 继承 $PWD、会欢快地报出一个过期的逻辑路径。
//
// 未挂时同一条命令**不得**报出驻地——否则那个断言可能只是碰巧命中了一个继承来的目录。
func TestChatWorkDir_BashRunsInTheResidency(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	root := t.TempDir()
	realRoot, err := filepath.EvalSymlinks(root)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "marker.txt"), []byte("SEEN-BY-RELATIVE-CAT"), 0o644); err != nil {
		t.Fatal(err)
	}

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("b1", "Bash", map[string]any{"command": "pwd -P && cat marker.txt"})}},
		harness.LLMTurn{Text: "ran it."},
	)
	convID := convCreate(t, wc, "bash cwd")
	wdMount(t, wc, convID, root)
	if turn := waitTurn(t, wc, convID, sendMsg(t, wc, convID, "where am I?"), 30000); turn.Status != "completed" {
		t.Fatalf("turn: %s %s", turn.Status, turn.ErrorMessage)
	}
	results := toolResultsOf(t, wc, convID)
	if !strings.Contains(results, realRoot) {
		t.Fatalf("Bash must run IN the residency (want %q):\n%s", realRoot, results)
	}
	// The point of cmd.Dir is not `pwd` — it is that a relative reference in the COMMAND means "here".
	// cmd.Dir 的意义不在 `pwd`——而在于**命令里**的相对引用表示「这里」。
	if !strings.Contains(results, "SEEN-BY-RELATIVE-CAT") {
		t.Fatalf("a relative reference inside the command must resolve in the residency:\n%s", results)
	}

	// Unmounted: no residency in the answer. 未挂：答案里没有驻地。
	bare := convCreate(t, wc, "bash no cwd")
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("b2", "Bash", map[string]any{"command": "pwd -P"})}},
		harness.LLMTurn{Text: "ran it."},
	)
	waitTurn(t, wc, bare, sendMsg(t, wc, bare, "where am I?"), 30000)
	if strings.Contains(toolResultsOf(t, wc, bare), realRoot) {
		t.Fatalf("an unmounted conversation must not run in anyone's residency:\n%s", toolResultsOf(t, wc, bare))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑤ marker 落行且可读
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDir_MidThreadSwitchLeavesADurableMarker: switching the residency mid-thread appends a durable
// `marker` block carrying both ends, so a reader scrolling back can see WHERE "here" changed. Four things
// are asserted because each is a way the feature could be quietly wrong:
//
//   - It lands on the ORDINARY message read (no new endpoint, no new frame type — the compaction anchor's
//     presentation path, so events.md's messages node.type vocabulary is untouched).
//   - attrs carry `{kind, from, to}` and content is EMPTY (the label is localized client-side; a Go-side
//     string would hardcode a language into a durable row).
//   - The FIRST mount on a thread that has never spoken leaves NO marker — a mark is a boundary between a
//     before and an after, and a thread with no messages has no before.
//   - Re-PATCHing the same path marks nothing (a client echoing the head back must not stamp the thread).
//
// TestChatWorkDir_MidThreadSwitchLeavesADurableMarker：线程中途切换驻地会追加一条持久 `marker` 块、带上两端，
// 使往回翻的读者看见「这里」变在**哪里**。断言四件事，因为每一件都是这个功能可能悄悄出错的方式：
//
//   - 它落在**普通**的消息读上（不加新端点、不加新帧型——走 compaction 锚的呈现路径，故 events.md 的 messages
//     node.type 词表分毫不动）。
//   - attrs 带 `{kind, from, to}` 且 content **为空**（标签由客户端本地化；Go 侧写字符串等于把一种语言硬编码
//     进一条持久行）。
//   - 在一条从未说过话的线程上**首次**挂载**不留**标记——标记是「之前」与「之后」之间的界线，而无消息的线程
//     没有「之前」。
//   - 重复 PATCH 同一路径不留标记（一个把头回显回来的客户端不该在线程上盖章）。
func TestChatWorkDir_MidThreadSwitchLeavesADurableMarker(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	first, second := t.TempDir(), t.TempDir()

	convID := convCreate(t, wc, "marker")
	// Mount BEFORE the first message: the common path (pick the folder, then start talking) and it must
	// leave the thread clean. 首发**之前**挂载：常见路径（先选目录、再开口），且它必须让线程保持干净。
	wdMount(t, wc, convID, first)
	if n := markerBlocks(t, wc, convID); len(n) != 0 {
		t.Fatalf("the first mount on a silent thread must leave no marker, got %v", n)
	}
	// Re-patching the same path is a real no-op. 重复 PATCH 同一路径是真 no-op。
	wdMount(t, wc, convID, first)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "hello from the first dir."})
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "hi"), 30000)
	if n := markerBlocks(t, wc, convID); len(n) != 0 {
		t.Fatalf("an ordinary turn must not produce markers, got %v", n)
	}

	// NOW switch: this is the "mid-thread" case the marker exists for.
	// **现在**切换：这正是标记为之存在的「线程中途」那一格。
	wdMount(t, wc, convID, second)
	marks := markerBlocks(t, wc, convID)
	if len(marks) != 1 {
		t.Fatalf("a mid-thread switch must leave exactly one marker, got %d: %v", len(marks), marks)
	}
	m := marks[0]
	if m.Content != "" {
		t.Fatalf("marker content must stay EMPTY (the label is rendered client-side, in the user's language), got %q", m.Content)
	}
	if m.Attrs["kind"] != "workdir" || m.Attrs["from"] != first || m.Attrs["to"] != second {
		t.Fatalf("marker attrs must carry {kind, from, to}: %v (want from=%q to=%q)", m.Attrs, first, second)
	}

	// Unmounting is a switch too, and `to` is empty — both ends are meaningful, which is why the pair is
	// stored rather than just the new value. 退出驻地也是一次切换，`to` 为空——两端都有意义，这正是存一对
	// 而非只存新值的原因。
	wdMount(t, wc, convID, "")
	marks = markerBlocks(t, wc, convID)
	if len(marks) != 2 {
		t.Fatalf("unmounting must mark too, got %d markers", len(marks))
	}
	if last := marks[len(marks)-1]; last.Attrs["from"] != second || last.Attrs["to"] != "" {
		t.Fatalf("the unmount marker must record from=%q to=\"\": %v", second, last.Attrs)
	}

	// The marker is never fed to the model: BlocksToAssistantLLM is a type whitelist, so a marker has no
	// case at all. 标记永不喂给模型：BlocksToAssistantLLM 是类型白名单，marker 在里面根本没有 case。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "still here."})
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "after the switch"), 30000)
	dumps := mock.WaitDumps(t, dlgModel, 2, 8000)
	last := dumps[len(dumps)-1]
	for _, msg := range last.Messages {
		if strings.Contains(msg.Content, "workdir") && strings.Contains(msg.Content, first) {
			t.Fatalf("a marker block must never reach the model's history: %+v", msg)
		}
	}
}

// markerBlock is one `marker` row as the ordinary message read returns it.
//
// markerBlock 是普通消息读返回的一条 `marker` 行。
type markerBlock struct {
	Content string
	Attrs   map[string]any
}

// markerBlocks walks the thread in REPLAY order (the history endpoint is newest-first by contract) and
// returns every marker block. Reading them through `GET /{id}/messages` is itself the assertion that the
// presentation path is the ordinary one.
//
// markerBlocks 按**重放**顺序走查线程（历史端点按契约最新在前）并返回每条 marker 块。**经**
// `GET /{id}/messages` 读它们，本身就是「呈现路径就是那条普通路径」这一断言。
func markerBlocks(t *testing.T, wc *harness.Client, convID string) []markerBlock {
	t.Helper()
	msgs := listMsgs(t, wc, convID)
	var out []markerBlock
	for i := len(msgs) - 1; i >= 0; i-- {
		for _, b := range msgs[i].Blocks {
			if b.Type == "marker" {
				out = append(out, markerBlock{Content: b.Content, Attrs: b.Attrs})
			}
		}
	}
	return out
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑥ subagent 继承
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDir_SubagentInheritsTheResidency: decision #7 — a subagent inherits its parent's residency.
// The assertion is a file the SUB-run wrote from a RELATIVE path: that can only land in the right place if
// the work dir survived into the sub-context, and it is exactly what a fresh AgentState would have lost had
// the residency been stored there instead of in ctx.
//
// TestChatWorkDir_SubagentInheritsTheResidency：拍板 #7——subagent 继承父对话驻地。断言的是**子运行**用
// **相对**路径写出的一个文件：只有工作目录活着进了子 ctx，它才可能落在对的地方；而若驻地当初存在 AgentState
// 里，那个全新实例正会把它丢掉。
func TestChatWorkDir_SubagentInheritsTheResidency(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	root := t.TempDir()

	mock.Enqueue(dlgModel,
		// The parent spawns a subagent... 父回合派出 subagent……
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{ID: "sub1", Name: "Subagent", Args: map[string]any{
			"type": "general", "prompt": "write sub.md in the working directory",
			"summary": "delegate", "danger": "safe", "execution_group": 1,
		}}}},
		// ...the SUB-run writes a relative path... ……**子运行**写一个相对路径……
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{fsCall("s1", "Write", map[string]any{
			"file_path": "sub.md", "content": "WRITTEN-BY-SUBAGENT",
		})}},
		harness.LLMTurn{Text: "sub done."},
		// ...and the parent wraps up. ……父回合收尾。
		harness.LLMTurn{Text: "all done."},
	)
	convID := convCreate(t, wc, "subagent residency")
	wdMount(t, wc, convID, root)
	if turn := waitTurn(t, wc, convID, sendMsg(t, wc, convID, "delegate a write"), 60000); turn.Status != "completed" {
		t.Fatalf("turn: %s %s", turn.Status, turn.ErrorMessage)
	}
	got, err := os.ReadFile(filepath.Join(root, "sub.md"))
	if err != nil || string(got) != "WRITTEN-BY-SUBAGENT" {
		t.Fatalf("the subagent's relative write must land in the parent's residency: err=%v content=%q", err, got)
	}
}
