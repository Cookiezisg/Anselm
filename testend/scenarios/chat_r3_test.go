// chat_r3_test.go — R3（A8 Chat 高标准补全，首轮缺格的补课）。
//
// PLAN A8 逐格：附件三路（文本内联 / vision image_url / PDF sandbox 抽取——按模型能力门控）；
// skill 两路 activate（inline 渲染注入 / fork 派 subagent）+ allowed-tools 预授权免确认；
// memory 的 LLM 面（write→新对话注入→forget→消失）；@mention 发送时刻冻结快照；归档 Send
// 自动解档；删除对话取消在途生成；并行工具批（同 execution_group 多 tool_call 一回合都执行、
// 结果一并回喂）；Subagent 嵌套树（sub-message 落父对话、不污染父 LLM 历史）；SSE 重连
// replay（durable 帧续传、ephemeral delta 不重放）；utility 缺席静默降级。
package scenarios

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// tinyPNG is a decoder-valid 1×1 RGB PNG for static wire coverage. Real visual providers can have
// a larger pixel floor, so managed real-money acceptance uses its own 32×32 fixture.
// tinyPNG 是静态线缆覆盖用、可被解码器接受的 1×1 RGB PNG；真实视觉供应商可能有更高像素下限，
// 故受管真钱验收另用 32×32 夹具。
var tinyPNG = []byte{
	0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
	0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
	0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
	0x00, 0x03, 0x01, 0x01, 0x00, 0xC9, 0xFE, 0x92, 0xEF, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
	0x44, 0xAE, 0x42, 0x60, 0x82,
}

// buildPDF 构造一个结构合法（带 xref 偏移）的单页文本 PDF——pdfplumber 能真抽出
// text 的最小载荷（手写常量缺 xref 会被解析器拒）。
func buildPDF(text string) []byte {
	stream := "BT /F1 12 Tf 20 50 Td (" + text + ") Tj ET"
	objs := []string{
		"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n",
		"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n",
		"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 100]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n",
		fmt.Sprintf("4 0 obj<</Length %d>>stream\n%s\nendstream\nendobj\n", len(stream), stream),
		"5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n",
	}
	var b strings.Builder
	b.WriteString("%PDF-1.4\n")
	offsets := make([]int, len(objs))
	for i, o := range objs {
		offsets[i] = b.Len()
		b.WriteString(o)
	}
	xref := b.Len()
	fmt.Fprintf(&b, "xref\n0 %d\n0000000000 65535 f \n", len(objs)+1)
	for _, off := range offsets {
		fmt.Fprintf(&b, "%010d 00000 n \n", off)
	}
	fmt.Fprintf(&b, "trailer<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF\n", len(objs)+1, xref)
	return []byte(b.String())
}

// uploadAtt 上传一个附件并返回 att_ id。
func uploadAtt(t *testing.T, wc *harness.Client, name, mime string, content []byte) string {
	t.Helper()
	r := wc.Upload(t, "/api/v1/attachments", name, mime, content)
	if r.Status < 200 || r.Status > 299 {
		t.Fatalf("upload %s: %d %s", name, r.Status, r.Raw)
	}
	var m struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(r.Data, &m); err != nil || m.ID == "" {
		t.Fatalf("upload %s: no id in %s", name, r.Data)
	}
	return m.ID
}

// sendWith 发送带附件/mention 的用户回合。
func sendWith(t *testing.T, wc *harness.Client, convID string, body map[string]any) string {
	t.Helper()
	return wc.POST("/api/v1/conversations/"+convID+"/messages", body).Field(t, "id") // MD3
}

// nonNativeDocsModel is a vision model that does NOT read PDF inline, which is what route 3 needs.
// The default `gpt-4o` used to be one — then the capability catalog was rebuilt from models.dev
// (批A) and gained `pdf` on gpt-4o's inputs, so this scenario silently started exercising the
// NATIVE branch while still asserting the extracted text. It stayed red on main because testend is
// deliberately outside `make verify` (T5). Pinning a dated snapshot keeps the same provider and the
// same mock while restoring the premise (WRK-082 H7).
//
// nonNativeDocsModel 是一个**有视觉、但不原生读 PDF** 的模型,正是第三条路需要的。默认的 `gpt-4o`
// 曾经就是——后来能力目录按 models.dev 重建(批A),gpt-4o 的输入多了 `pdf`,于是本场景**悄悄改跑了原生
// 分支**、却仍在断言抽取出来的文本。它就这样在 main 上红着,因为 testend 刻意不进 `make verify`(T5)。
// 钉一个带日期的快照,供应商与 mock 都不变、而前提回来了(H7)。
const nonNativeDocsModel = "gpt-4o-2024-11-20"

// TestChatR3_AttachmentsThreeRoutes: 附件三路按模型能力门控（vision=true、nativeDocs=false）
// ——文本直接内联、图片成 image_url part、PDF 走 sandbox 真抽取后内联。
func TestChatR3_AttachmentsThreeRoutes(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	var keys []struct {
		ID string `json:"id"`
	}
	wc.GET("/api/v1/api-keys?limit=1").OK(t, &keys)
	wc.PUT("/api/v1/workspaces/"+wc.WorkspaceID()+"/default-models/dialogue",
		map[string]any{"apiKeyId": keys[0].ID, "modelId": nonNativeDocsModel}).OK(t, nil)

	txtID := uploadAtt(t, wc, "notes.txt", "text/plain", []byte("TXTINLINE bravo content"))
	pngID := uploadAtt(t, wc, "shot.png", "image/png", tinyPNG)
	pdfID := uploadAtt(t, wc, "doc.pdf", "application/pdf", buildPDF("PDFEXTRACT alpha"))

	mock.Enqueue(nonNativeDocsModel, harness.LLMTurn{Text: "read them all"})
	convID := convCreate(t, wc, "attachments")
	mid := sendWith(t, wc, convID, map[string]any{
		"content":       "see the three files",
		"attachmentIds": []string{txtID, pngID, pdfID},
	})
	// PDF 路线首跑要装抽取 env（pdfplumber，吃 uv 缓存）——给宽限。
	turn := waitTurn(t, wc, convID, mid, 120000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	raw := string(mock.DumpsFor(nonNativeDocsModel)[0].Raw)
	if !strings.Contains(raw, "TXTINLINE") {
		t.Error("text attachment must inline its content into the model view")
	}
	if !strings.Contains(raw, "image_url") {
		t.Error("image attachment must render as an image_url part for a vision model")
	}
	if !strings.Contains(raw, "PDFEXTRACT") {
		t.Error("pdf on a non-native-docs model must arrive as sandbox-extracted text")
	}
}

// TestChatR3_SkillInlineActivateAndPreauth: skill 两路之 inline——activate_skill 返回渲染正文
// （注入对话）；active skill 的 allowed-tools 成预授权：自报 dangerous 的工具**不再询问**直接执行
// （对照 W4 危险门默认必询问）。
func TestChatR3_SkillInlineActivateAndPreauth(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "deploy_step", "def deploy_step() -> dict:\n    return {\"deployed\": True}\n")

	wc.POST("/api/v1/skills", map[string]any{
		"name": "deploy-guide", "description": "deploy runbook",
		"body":         "RUNBOOKMARK: ship with deploy_step, no fear.",
		"allowedTools": []string{"run_function"},
	}).OK(t, nil)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "activate_skill",
			Args: fw(map[string]any{"name": "deploy-guide"})}}},
		// dangerous run_function——active skill 的 allowed-tools 应免确认直接跑。
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_function",
			Args: map[string]any{"functionId": fnID, "args": map[string]any{},
				"summary": "deploy now", "danger": "dangerous", "execution_group": 1}}}},
		harness.LLMTurn{Text: "deployed per runbook"},
	)
	convID := convCreate(t, wc, "skill inline")
	mid := sendMsg(t, wc, convID, "activate the deploy guide and ship")
	turn := waitTurn(t, wc, convID, mid, 30000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete WITHOUT pending interaction, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	// inline 正文真回喂；危险调用真执行（预授权生效、零交互挂起）。
	dumps := mock.DumpsFor(dlgModel)
	fed := false
	for _, d := range dumps {
		for _, m := range d.Messages {
			if m.Role == "tool" && strings.Contains(m.Content, "RUNBOOKMARK") {
				fed = true
			}
		}
	}
	if !fed {
		t.Fatal("inline activation must feed the rendered skill body back")
	}
	var page struct {
		Aggregates struct {
			OKCount int `json:"okCount"`
		} `json:"aggregates"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &page)
	if page.Aggregates.OKCount != 1 {
		t.Fatalf("allowed-tools preauth must run the dangerous tool without asking, executions=%+v", page.Aggregates)
	}
	var pending []struct{}
	wc.GET("/api/v1/conversations/"+convID+"/interactions").OK(t, &pending)
	if len(pending) != 0 {
		t.Fatalf("no interaction may pend under preauth, got %d", len(pending))
	}
}

// TestChatR3_SkillForkRoute: skill 两路之 fork——activate_skill 派隔离 subagent 跑正文、
// 同步拿回结果；sub-message 落父对话（SubagentID 非空）、父 LLM 历史不被污染。
func TestChatR3_SkillForkRoute(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	wc.POST("/api/v1/skills", map[string]any{
		"name": "fork-probe", "description": "forked task",
		"body":    "Compute the answer and reply exactly FORKRESULT-99.",
		"context": "fork", "agent": "general-purpose", // fork 必须声明 subagent 类型。
	}).OK(t, nil)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "activate_skill",
			Args: fw(map[string]any{"name": "fork-probe"})}}},
		// 下一帧服务 fork 出的 subagent run（同 dialogue 模型队列，顺序确定）。
		harness.LLMTurn{Text: "FORKRESULT-99"},
		// 然后父回合收尾。
		harness.LLMTurn{Text: "the fork said FORKRESULT-99"},
	)
	convID := convCreate(t, wc, "skill fork")
	mid := sendMsg(t, wc, convID, "run the fork probe")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	// fork 结果作为工具结果回喂父对话。
	dumps := mock.DumpsFor(dlgModel)
	fed := false
	for _, d := range dumps {
		for _, m := range d.Messages {
			if m.Role == "tool" && strings.Contains(m.Content, "FORKRESULT-99") {
				fed = true
			}
		}
	}
	if !fed {
		t.Fatal("fork result must feed back as the activation's tool result")
	}

	// sub-message 落库（SubagentID 非空）供重建嵌套；父历史只见 tool_call/tool_result。
	var msgs []struct {
		SubagentID string `json:"subagentId"`
		Role       string `json:"role"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)
	hasSub := false
	for _, m := range msgs {
		if m.SubagentID != "" {
			hasSub = true
		}
	}
	if !hasSub {
		t.Fatalf("fork must persist sub-messages with subagentId, got %+v", msgs)
	}
}

// TestChatR3_MemoryLLMFace: memory 的 LLM 环（两段式注入）——write_memory 真落库；新对话
// system 注入 name+description **索引**（非全文）、read_memory 取回全文；pin 后全文直接
// 入 system；forget 后新对话彻底消失。
func TestChatR3_MemoryLLMFace(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	// 对话 1：写记忆。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "write_memory",
			Args: fw(map[string]any{"name": "launch-code", "description": "the launch codename note",
				"content": "MEMTOKEN-ultraviolet is the launch codename."})}}},
		harness.LLMTurn{Text: "remembered"},
	)
	conv1 := convCreate(t, wc, "writer")
	if turn := waitTurn(t, wc, conv1, sendMsg(t, wc, conv1, "remember the codename"), 30000); turn.Status != "completed" {
		t.Fatalf("write turn must complete, got %s", turn.Status)
	}
	wc.GET("/api/v1/memories/launch-code").OK(t, nil)

	// 对话 2（全新）：索引注入（name+description、非全文）+ read_memory 取回全文。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "read_memory",
			Args: fw(map[string]any{"name": "launch-code"})}}},
		harness.LLMTurn{Text: "recalled"},
	)
	conv2 := convCreate(t, wc, "reader")
	if turn := waitTurn(t, wc, conv2, sendMsg(t, wc, conv2, "what codename?"), 30000); turn.Status != "completed" {
		t.Fatalf("recall turn must complete, got %s", turn.Status)
	}
	dumps := mock.DumpsFor(dlgModel)
	sysConv2 := dumps[len(dumps)-2].System
	if !strings.Contains(sysConv2, "launch-code") || !strings.Contains(sysConv2, "launch codename note") {
		t.Fatalf("new conversation must inject the memory INDEX (name+description), got %dB system", len(sysConv2))
	}
	if strings.Contains(sysConv2, "MEMTOKEN-ultraviolet") {
		t.Fatal("unpinned memory content must NOT ride the system prompt (index only)")
	}
	readFed := false
	for _, m := range dumps[len(dumps)-1].Messages {
		if m.Role == "tool" && strings.Contains(m.Content, "MEMTOKEN-ultraviolet") {
			readFed = true
		}
	}
	if !readFed {
		t.Fatal("read_memory must return the full content")
	}

	// pin → 新对话全文直接入 system。
	wc.POST("/api/v1/memories/launch-code/pin", nil).OK(t, nil)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "pinned view"})
	conv3 := convCreate(t, wc, "pinned-reader")
	if turn := waitTurn(t, wc, conv3, sendMsg(t, wc, conv3, "codename?"), 30000); turn.Status != "completed" {
		t.Fatalf("pinned turn must complete, got %s", turn.Status)
	}
	dumps = mock.DumpsFor(dlgModel)
	if !strings.Contains(dumps[len(dumps)-1].System, "MEMTOKEN-ultraviolet") {
		t.Fatal("pinned memory must inject its FULL content into the system prompt")
	}

	// forget → 新对话彻底消失。
	wc.DELETE("/api/v1/memories/launch-code").OK(t, nil)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "nothing"})
	conv4 := convCreate(t, wc, "after-forget")
	if turn := waitTurn(t, wc, conv4, sendMsg(t, wc, conv4, "anything?"), 30000); turn.Status != "completed" {
		t.Fatalf("post-forget turn must complete, got %s", turn.Status)
	}
	dumps = mock.DumpsFor(dlgModel)
	last := dumps[len(dumps)-1].System
	if strings.Contains(last, "MEMTOKEN-ultraviolet") || strings.Contains(last, "launch-code") {
		t.Fatal("forgotten memory must vanish from new conversations entirely")
	}
}

// TestChatR3_MentionFreeze: @mention 发送时刻冻结——消息携带实体快照；之后实体被改，
// 同对话后续回合的历史里快照仍是旧内容（freeze-on-send）。
func TestChatR3_MentionFreeze(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "frozen_fn", "def frozen_fn() -> dict:\n    return {\"v\": \"SNAPSHOT-V1\"}\n")

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "I see the function"})
	convID := convCreate(t, wc, "mention freeze")
	mid := sendWith(t, wc, convID, map[string]any{
		"content":  "look at this function",
		"mentions": []map[string]any{{"type": "function", "id": fnID}},
	})
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("mention turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	raw1 := string(mock.DumpsFor(dlgModel)[0].Raw)
	if !strings.Contains(raw1, "SNAPSHOT-V1") {
		t.Fatal("mention must inline the entity snapshot at send time")
	}

	// 改实体 → 第二回合的历史快照不变（冻结），新内容不得出现。
	wc.POST("/api/v1/functions/"+fnID+":edit", map[string]any{"ops": []map[string]any{
		{"op": "set_code", "code": "def frozen_fn() -> dict:\n    return {\"v\": \"SNAPSHOT-V2\"}\n"},
	}}).OK(t, nil)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "still the old snapshot"})
	mid2 := sendMsg(t, wc, convID, "what version do you see in my earlier message?")
	if turn := waitTurn(t, wc, convID, mid2, 30000); turn.Status != "completed" {
		t.Fatalf("second turn must complete, got %s", turn.Status)
	}
	dumps := mock.DumpsFor(dlgModel)
	raw2 := string(dumps[len(dumps)-1].Raw)
	if !strings.Contains(raw2, "SNAPSHOT-V1") || strings.Contains(raw2, "SNAPSHOT-V2") {
		t.Fatal("mention snapshot must stay frozen at send time (V1 present, V2 absent)")
	}
}

// TestChatR3_ArchiveUnarchiveAndDeleteCancels: 归档对话 Send 自动解档；删除对话取消在途
// 生成（不留孤儿、删后 404）。
func TestChatR3_ArchiveUnarchiveAndDeleteCancels(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	// 归档 → Send 自动解档。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "back alive"})
	conv1 := convCreate(t, wc, "archived one")
	wc.PATCH("/api/v1/conversations/"+conv1, map[string]any{"archived": true}).OK(t, nil)
	mid := sendMsg(t, wc, conv1, "wake up")
	if turn := waitTurn(t, wc, conv1, mid, 30000); turn.Status != "completed" {
		t.Fatalf("send-to-archived must complete, got %s", turn.Status)
	}
	var conv struct {
		Archived bool `json:"archived"`
	}
	wc.GET("/api/v1/conversations/"+conv1).OK(t, &conv)
	if conv.Archived {
		t.Fatal("send must auto-unarchive the conversation")
	}

	// 在途删除：stalled 流中 DELETE → 生成取消、对话 404、无 panic。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "very long stalled reply......", StallMS: 8000})
	conv2 := convCreate(t, wc, "doomed")
	sse := wc.Subscribe(t, "messages")
	_ = sendMsg(t, wc, conv2, "talk slowly please")
	sse.WaitFor(t, 10000, "stalled stream starts", "very long")
	wc.DELETE("/api/v1/conversations/"+conv2).OK(t, nil)
	wc.Do("GET", "/api/v1/conversations/"+conv2, nil).Fail(t, 404, "CONVERSATION_NOT_FOUND")
	// 服务仍健康（取消干净、无残留 streaming 状态阻塞新对话）。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "fresh after delete"})
	conv3 := convCreate(t, wc, "fresh")
	if turn := waitTurn(t, wc, conv3, sendMsg(t, wc, conv3, "hi"), 30000); turn.Status != "completed" {
		t.Fatalf("post-delete sends must work, got %s", turn.Status)
	}
}

// TestChatR3_ParallelToolBatch: 并行工具批——同回合两个 tool_call（同 execution_group）
// 都执行、两个结果在同一后续请求一并回喂、两条执行台账齐。
func TestChatR3_ParallelToolBatch(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	fnA := fnCreate(t, wc, "batch_a", "def batch_a() -> dict:\n    return {\"mark\": \"BATCH-A-RAN\"}\n")
	fnB := fnCreate(t, wc, "batch_b", "def batch_b() -> dict:\n    return {\"mark\": \"BATCH-B-RAN\"}\n")

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{
			{ID: "call_a", Name: "run_function", Args: map[string]any{"functionId": fnA, "args": map[string]any{},
				"summary": "run a", "danger": "safe", "execution_group": 1}},
			{ID: "call_b", Name: "run_function", Args: map[string]any{"functionId": fnB, "args": map[string]any{},
				"summary": "run b", "danger": "safe", "execution_group": 1}},
		}},
		harness.LLMTurn{Text: "both ran"},
	)
	convID := convCreate(t, wc, "parallel batch")
	mid := sendMsg(t, wc, convID, "run both")
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("batch turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	dumps := mock.DumpsFor(dlgModel)
	last := dumps[len(dumps)-1]
	toolMsgs := 0
	all := ""
	for _, m := range last.Messages {
		if m.Role == "tool" {
			toolMsgs++
			all += m.Content
		}
	}
	if toolMsgs != 2 || !strings.Contains(all, "BATCH-A-RAN") || !strings.Contains(all, "BATCH-B-RAN") {
		t.Fatalf("both results must feed back together (got %d tool msgs): %s", toolMsgs, all)
	}
	for _, id := range []string{fnA, fnB} {
		var page struct {
			Aggregates struct {
				OKCount int `json:"okCount"`
			} `json:"aggregates"`
		}
		wc.GET("/api/v1/functions/"+id+"/executions").OK(t, &page)
		if page.Aggregates.OKCount != 1 {
			t.Fatalf("function %s must have run exactly once", id)
		}
	}
}

// TestChatR3_SubagentNestedTree: Subagent（Task）工具——派 general-purpose 子运行，结果同步
// 回喂；sub-message 以 SubagentID 落父对话；子集剔除 Subagent（深度 1，子不能再派子）。
func TestChatR3_SubagentNestedTree(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose",
				"prompt": "Reply exactly SUBANSWER-7."})}}},
		// 子运行的回合（同队列顺序消费）。
		harness.LLMTurn{Text: "SUBANSWER-7"},
		harness.LLMTurn{Text: "the subagent said SUBANSWER-7"},
	)
	convID := convCreate(t, wc, "subagent tree")
	mid := sendMsg(t, wc, convID, "delegate this")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	// 子运行的线缆工具集必须不含 Subagent（递归守卫①）。
	dumps := mock.DumpsFor(dlgModel)
	subReq := dumps[len(dumps)-2] // 子运行的请求。
	for _, name := range subReq.Tools {
		if name == "Subagent" {
			t.Fatal("a subagent must never see the Subagent tool (depth-1 guard)")
		}
	}
	// 结果回喂父对话。
	last := dumps[len(dumps)-1]
	fed := false
	for _, m := range last.Messages {
		if m.Role == "tool" && strings.Contains(m.Content, "SUBANSWER-7") {
			fed = true
		}
	}
	if !fed {
		t.Fatal("subagent answer must feed back to the parent dialogue")
	}
	// sub-message 落库（嵌套树的重建源）。
	var msgs []struct {
		SubagentID string `json:"subagentId"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)
	hasSub := false
	for _, m := range msgs {
		if m.SubagentID != "" {
			hasSub = true
		}
	}
	if !hasSub {
		t.Fatal("subagent turns must persist as sub-messages for tree rehydration")
	}
}

// TestChatR3_SubagentFailureFeedsParent proves that a failed child is a tool-level, inspectable
// result rather than a falsely successful answer or a parent-request failure. The parent must see
// the explicit non-authoritative annotation, finish its own turn, and leave the failed sub-message
// in the durable trace so a user can understand what happened and decide whether to retry.
func TestChatR3_SubagentFailureFeedsParent(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	// Keep the parent → child request order deterministic: the first frame asks for the child,
	// the next provider frame fails the child (the streaming loop deliberately does not retry a
	// partially observable turn), and the final frame is the parent's recovery response.
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "child will fail"})}}},
		harness.LLMTurn{Status: 500},
		harness.LLMTurn{Text: "parent recovered after the child failure"},
	)

	convID := convCreate(t, wc, "subagent failure")
	mid := sendMsg(t, wc, convID, "delegate this, then continue even if the child fails")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("parent turn must complete after a child failure: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	parentSawAnnotation := false
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, "did not finish cleanly") && strings.Contains(block.Content, "partial") {
			parentSawAnnotation = true
			break
		}
	}
	if !parentSawAnnotation {
		t.Fatalf("parent tool result must identify the child answer as non-authoritative: %+v", turn.Blocks)
	}
	parentText := false
	for _, block := range turn.Blocks {
		if block.Type == "text" && strings.Contains(block.Content, "parent recovered") {
			parentText = true
			break
		}
	}
	if !parentText {
		t.Fatalf("parent must be able to continue after child failure: %+v", turn.Blocks)
	}

	var msgs []struct {
		SubagentID string `json:"subagentId"`
		Status     string `json:"status"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)
	failedChild := false
	for _, msg := range msgs {
		if msg.SubagentID != "" && msg.Status == "error" {
			failedChild = true
			break
		}
	}
	if !failedChild {
		t.Fatalf("failed subagent must remain a durable error sub-message: %+v", msgs)
	}

	dumps := mock.DumpsFor(dlgModel)
	if len(dumps) < 3 || !dumps[len(dumps)-1].HasMessage("tool", "did not finish cleanly") {
		t.Fatalf("parent retry request must carry the child failure annotation, dumps=%d", len(dumps))
	}
}

// TestChatR3_ConcurrentSubagentsKeepTheirOwnTrees proves the harder E1-sub-1 shape: two
// Subagent calls in one execution group really run at once, both results return to the same
// parent turn, and each durable child stays anchored to its own spawning tool_call. The child
// provider responses are intentionally not mapped to prompts — concurrent request arrival is
// allowed to race — so the invariant is set membership plus tree ownership, not scheduling.
func TestChatR3_ConcurrentSubagentsKeepTheirOwnTrees(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{
			{ID: "sub_a", Name: "Subagent", Args: fw(map[string]any{
				"subagent_type": "general-purpose", "prompt": "child prompt ALPHA",
				"execution_group": 1,
			})},
			{ID: "sub_b", Name: "Subagent", Args: fw(map[string]any{
				"subagent_type": "general-purpose", "prompt": "child prompt BETA",
				"execution_group": 1,
			})},
		}},
		// Both child requests race, so either answer may belong to either prompt. The parent
		// request is issued only after both Spawn calls return and therefore consumes the fourth
		// queued turn, never one of the child answers.
		harness.LLMTurn{Text: "SUB-ANSWER-ALPHA"},
		harness.LLMTurn{Text: "SUB-ANSWER-BETA"},
		harness.LLMTurn{Text: "parent combined both child answers"},
	)

	convID := convCreate(t, wc, "concurrent subagents")
	mid := sendMsg(t, wc, convID, "delegate two independent children")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("parent turn must complete after concurrent children: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	toolResults := make([]string, 0, 2)
	parentCalls := map[string]bool{}
	parentSawFinal := false
	for _, b := range turn.Blocks {
		switch b.Type {
		case "tool_call":
			// The REST id is the E3 anchor used by the child message attrs.
			parentCalls[b.ID] = true
		case "tool_result":
			toolResults = append(toolResults, b.Content)
		case "text":
			if strings.Contains(b.Content, "parent combined both child answers") {
				parentSawFinal = true
			}
		}
	}
	if len(parentCalls) != 2 {
		t.Fatalf("parent must persist two distinct Subagent tool_call blocks, got %d: %+v", len(parentCalls), turn.Blocks)
	}
	if len(toolResults) != 2 || !strings.Contains(toolResults[0]+toolResults[1], "SUB-ANSWER-ALPHA") ||
		!strings.Contains(toolResults[0]+toolResults[1], "SUB-ANSWER-BETA") {
		t.Fatalf("both child answers must feed back as tool results, got %+v", toolResults)
	}
	if !parentSawFinal {
		t.Fatalf("parent must continue after the parallel batch, blocks=%+v", turn.Blocks)
	}

	// Read the durable tree, including message-level attrs (the REST projection of the E3
	// parentBlockId anchor). A child is valid only when its anchor resolves to one of this
	// parent's two tool_call blocks; two children pointing at one anchor would be tree mixing.
	var msgs []struct {
		ID         string         `json:"id"`
		SubagentID string         `json:"subagentId"`
		Role       string         `json:"role"`
		Status     string         `json:"status"`
		Attrs      map[string]any `json:"attrs"`
		Blocks     []struct {
			Type    string `json:"type"`
			Content string `json:"content"`
		} `json:"blocks"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)

	children := make([]struct {
		id, answer, anchor string
	}, 0, 2)
	for _, m := range msgs {
		if m.SubagentID == "" {
			continue
		}
		answer := ""
		for _, b := range m.Blocks {
			if b.Type == "text" {
				answer += b.Content
			}
		}
		anchor, _ := m.Attrs["parentBlockId"].(string)
		children = append(children, struct {
			id, answer, anchor string
		}{m.SubagentID, answer, anchor})
		if m.Status != "completed" {
			t.Fatalf("child %s must reach completed durable status, got %s", m.SubagentID, m.Status)
		}
	}
	if len(children) != 2 {
		t.Fatalf("exactly two durable child messages required, got %d: %+v", len(children), msgs)
	}
	seenAnchors := map[string]bool{}
	seenAnswers := map[string]bool{}
	for _, child := range children {
		if !parentCalls[child.anchor] {
			t.Fatalf("child %s anchor %q must resolve to one of the parent's tool_call blocks %v", child.id, child.anchor, parentCalls)
		}
		if seenAnchors[child.anchor] {
			t.Fatalf("two children were attached to the same parent tool_call %q: %+v", child.anchor, children)
		}
		seenAnchors[child.anchor] = true
		for _, answer := range []string{"SUB-ANSWER-ALPHA", "SUB-ANSWER-BETA"} {
			if strings.Contains(child.answer, answer) {
				seenAnswers[answer] = true
			}
		}
	}
	if len(seenAnswers) != 2 {
		t.Fatalf("the two durable children must preserve both answers, got %+v", children)
	}

	// Provider-level evidence: there are exactly two isolated child requests, each carrying its
	// own prompt and neither leaking the parent's user message; the parent gets one final request.
	dumps := mock.DumpsFor(dlgModel)
	if len(dumps) != 4 {
		t.Fatalf("parent + two children + parent continuation must be four provider requests, got %d", len(dumps))
	}
	childPrompts := 0
	for _, d := range dumps {
		isChild := d.HasMessage("user", "child prompt ALPHA") || d.HasMessage("user", "child prompt BETA")
		if !isChild {
			continue
		}
		childPrompts++
		if strings.Contains(string(d.Raw), "delegate two independent children") {
			t.Fatal("child provider request must not leak the parent user message")
		}
	}
	if childPrompts != 2 {
		t.Fatalf("exactly two provider requests must be subagent views, got %d", childPrompts)
	}
}

// TestChatR3_ReconnectReplay: SSE 重连——fromSeq 续传重放 durable 帧（close 带快照），
// E2 ephemeral delta 不重放（重连流上无 seq=0 的 delta 残影）。
func TestChatR3_ReconnectReplay(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "REPLAYTOKEN says hello"})
	convID := convCreate(t, wc, "replay probe")
	live := wc.Subscribe(t, "messages")
	mid := sendMsg(t, wc, convID, "speak")
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s", turn.Status)
	}
	// live 流见过 delta（流式的物理证据）。
	live.WaitFor(t, 5000, "live stream carried deltas", `"delta"`)

	// 从 live 流提取首个 durable seq（fromSeq=0 是「仅实时」哨兵，重放语义 = seq > fromSeq）。
	firstSeq := int64(-1)
	for _, ev := range live.Snapshot() {
		var env struct {
			Seq int64 `json:"seq"`
		}
		if json.Unmarshal(ev.Data, &env) == nil && env.Seq > 0 {
			firstSeq = env.Seq
			break
		}
	}
	if firstSeq < 0 {
		t.Fatal("live stream must carry durable (seq>0) frames")
	}

	// 重连 from firstSeq：其后的 durable 帧重放（close 快照带全文），ephemeral delta 绝不重放。
	replay := wc.SubscribeFrom(t, "messages", firstSeq)
	replay.WaitFor(t, 8000, "durable close replays with the snapshot", "REPLAYTOKEN")
	replay.Never(t, 1500, "ephemeral deltas must not replay", `"delta"`)
}

// TestChatR3_UtilityAbsentDegrade: utility 缺席的静默降级——未命名对话不起标题、压缩越线
// 不压缩，但主链全程无错误。
func TestChatR3_UtilityAbsentDegrade(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false) // 不配 utility。
	wc.PATCH("/api/v1/limits", map[string]any{"context": map[string]any{"triggerRatio": 0.1}}).OK(t, nil)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "noted 1"},
		// 真实 input token 越线 → 压缩想跑但 utility 缺席 → 静默跳过。
		harness.LLMTurn{Text: "noted 2", PromptTokens: 60000},
		harness.LLMTurn{Text: "noted 3"},
	)
	convID := convCreate(t, wc, "") // 未命名 → 想起标题但 utility 缺席。
	for i := 0; i < 3; i++ {
		mid := sendMsg(t, wc, convID, "more words please")
		if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
			t.Fatalf("turn %d must complete despite missing utility, got %s err=%s", i+1, turn.Status, turn.ErrorCode)
		}
	}
	var conv struct {
		Title   string `json:"title"`
		Summary string `json:"summary"`
	}
	wc.GET("/api/v1/conversations/"+convID).OK(t, &conv)
	if conv.Summary != "" {
		t.Fatalf("compaction must silently skip without utility, got summary %q", conv.Summary)
	}
	if strings.Contains(conv.Title, "Mock") {
		t.Fatalf("no autotitle without utility, got %q", conv.Title)
	}
}

// TestChatR3_SkillScriptGuardSurface（WRK-076 B3）：run_skill_script 的校验面走真工具环——
// 脚本不在 skill 文件列表 → 错误文本回喂 LLM（不触发运行时下载）；越界路径同拒。真执行
// （EnsureEnv 装解释器）刻意不在 testend 跑（首用下载数百 MB），归真机验收。
func TestChatR3_SkillScriptGuardSurface(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	wc.POST("/api/v1/skills", map[string]any{
		"name": "scripted", "description": "has scripts", "body": "Run scripts/x.py.",
	}).OK(t, nil)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_skill_script",
			Args: fw(map[string]any{"name": "scripted", "script": "scripts/ghost.py"})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_skill_script",
			Args: fw(map[string]any{"name": "scripted", "script": "../other/steal.py"})}}},
		harness.LLMTurn{Text: "both refused"},
	)
	convID := convCreate(t, wc, "skill script guard")
	mid := sendMsg(t, wc, convID, "run the ghost script")
	turn := waitTurn(t, wc, convID, mid, 30000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}
	// 两次调用的 tool_result 都以 script-not-found 语义回喂（工具注册 + 校验链活着）。
	refusals := 0
	for _, d := range mock.DumpsFor(dlgModel) {
		for _, m := range d.Messages {
			if m.Role == "tool" && strings.Contains(m.Content, "script not found") {
				refusals++
			}
		}
	}
	if refusals < 2 {
		t.Fatalf("both bad scripts must be refused via tool_result, got %d refusals", refusals)
	}
}

// TestChatR3_AtSkillActivation（WRK-076）：`@skill` = 用户手动激活 inline skill——两半都验:
// ①内容半:skill 渲染 body 经 <mentions> 块注入(marker 回喂模型);②副作用半:allowed-tools 预授权
// 生效,危险 run_function 免确认直接跑、零交互挂起。这是 @ 提及激活对齐斜杠命令的黑盒证据。
func TestChatR3_AtSkillActivation(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "at_deploy_step", "def at_deploy_step() -> dict:\n    return {\"deployed\": True}\n")

	wc.POST("/api/v1/skills", map[string]any{
		"name": "at-deploy-guide", "description": "deploy runbook",
		"body":         "ATMENTIONMARK: ship with at_deploy_step, no fear.",
		"allowedTools": []string{"run_function"},
	}).OK(t, nil)

	mock.Enqueue(dlgModel,
		// 危险 run_function——@skill 的预授权应令其免确认直接跑。
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_function",
			Args: map[string]any{"functionId": fnID, "args": map[string]any{},
				"summary": "deploy now", "danger": "dangerous", "execution_group": 1}}}},
		harness.LLMTurn{Text: "deployed via @-mention"},
	)
	convID := convCreate(t, wc, "at-skill activation")
	// 关键:用 @skill 提及而非 activate_skill 工具。
	mid := sendWith(t, wc, convID, map[string]any{
		"content":  "@at-deploy-guide ship it",
		"mentions": []map[string]any{{"type": "skill", "id": "at-deploy-guide"}},
	})
	turn := waitTurn(t, wc, convID, mid, 30000)
	if turn.Status != "completed" {
		t.Fatalf("@skill turn must complete WITHOUT pending interaction, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	// ① 内容半:skill body 经 <mentions> 块注入模型视角。
	raw := string(mock.DumpsFor(dlgModel)[0].Raw)
	if !strings.Contains(raw, "ATMENTIONMARK") {
		t.Fatalf("@skill must inject the rendered skill body via the mention snapshot: %s", raw)
	}
	// ② 副作用半:预授权令危险调用免确认直接执行、零交互挂起。
	var page struct {
		Aggregates struct {
			OKCount int `json:"okCount"`
		} `json:"aggregates"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &page)
	if page.Aggregates.OKCount != 1 {
		t.Fatalf("@skill allowed-tools preauth must run the dangerous tool without asking, executions=%+v", page.Aggregates)
	}
	var pending []struct{}
	wc.GET("/api/v1/conversations/"+convID+"/interactions").OK(t, &pending)
	if len(pending) != 0 {
		t.Fatalf("no interaction may pend under @skill preauth, got %d", len(pending))
	}
}
