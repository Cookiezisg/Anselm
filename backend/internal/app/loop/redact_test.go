package loop

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func TestRedactOpaqueMachineValues(t *testing.T) {
	input := "bootId=1785570385396807000 handler hd_2a5fdba507830767 at 2026-08-01T07:46:40.084187Z"
	want := "bootId=the numeric value handler at the recorded time"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("redactOpaqueMachineValues() = %q, want %q", got, want)
	}
}

func TestRedactVoiceIDParentheticalKeepsVoiceName(t *testing.T) {
	for _, input := range []string{
		"已注册声音 acceptance-narrator（voiceId: the requested item）。",
		"已注册声音 acceptance-narrator (voiceId: 这个输入)。",
		"已注册声音 acceptance-narrator (voiceId: `vce_0b93239bbd46bedd`)。",
	} {
		got := redactOpaqueMachineValues(input)
		if got != "已注册声音 acceptance-narrator。" {
			t.Fatalf("voice ID parenthetical = %q", got)
		}
		if strings.Contains(got, "voiceId") || strings.Contains(got, "这个输入") || strings.Contains(got, "vce_") {
			t.Fatalf("voice ID machine detail leaked: %q", got)
		}
	}
}

func TestTextRedactorRemovesSplitVoiceIDParenthetical(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"已注册声音 acceptance-narrator（voiceId: ",
		"the requested item）并已准备好。",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	if got.String() != "已注册声音 acceptance-narrator并已准备好。" {
		t.Fatalf("split voice ID parenthetical = %q", got.String())
	}
}

func TestRedactVoiceIDAssignmentLineRemovesMachinePlaceholder(t *testing.T) {
	for _, input := range []string{
		"语音名称：edge346-fixed-first\n\n语音 ID：这个输入\n\n剩余可用槽位：1",
		"语音名称：edge346-fixed-first\n\n- **语音 ID**：vce_7d6226ab69b44643\n- **提供方**：anselm\n- **剩余可用槽位**：1",
	} {
		got := redactOpaqueMachineValues(input)
		if strings.Contains(got, "语音ID") || strings.Contains(got, "语音 ID") || strings.Contains(got, "这个输入") || strings.Contains(got, "vce_") {
			t.Fatalf("standalone voice ID leaked: %q", got)
		}
		if !strings.Contains(got, "语音名称：edge346-fixed-first") || !strings.Contains(got, "剩余可用槽位") {
			t.Fatalf("useful enrollment details were lost: %q", got)
		}
	}
}

func TestTextRedactorRemovesSplitVoiceIDAssignmentLine(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"语音名称：edge346-fixed-first\n\n- **语音 ID**：vce_",
		"7d6226ab69b44643\n- **提供方**：anselm\n- **剩余可用槽位**：1",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "语音ID") || strings.Contains(got.String(), "语音 ID") || strings.Contains(got.String(), "这个输入") || strings.Contains(got.String(), "vce_") {
		t.Fatalf("split standalone voice ID leaked: %q", got.String())
	}
	if !strings.Contains(got.String(), "剩余可用槽位") || !strings.Contains(got.String(), "1") {
		t.Fatalf("the following useful line was lost: %q", got.String())
	}
}

func TestTextRedactorRemovesVoiceIDLineWhenProviderStartsNextBullet(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"语音已成功注册！\n\n- **语音名称**：`edge347-delete-failure`\n- voiceId: ",
		"\n- remainingSlots: 1",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "voiceId") || strings.Contains(got.String(), "语音 ID") || strings.Contains(got.String(), "这个输入") {
		t.Fatalf("voice ID line leaked across following bullet: %q", got.String())
	}
	if !strings.Contains(got.String(), "remainingSlots") || !strings.Contains(got.String(), "1") {
		t.Fatalf("following useful line was lost: %q", got.String())
	}
}

func TestRedactChineseOpaqueIDAssignmentKeepsProseNatural(t *testing.T) {
	input := "找到了，文档 ID 为 `doc_3ec2e562757ebbef`。现在查看其关系邻域："
	want := "找到了，文档已定位。现在查看其关系邻域："
	got := redactOpaqueMachineValues(input)
	if got != want {
		t.Fatalf("Chinese opaque ID assignment = %q, want %q", got, want)
	}
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "doc_") {
		t.Fatal("Chinese opaque ID assignment leaked a placeholder or entity ID")
	}
}

func TestRedactPreservesPublicTodoToolNames(t *testing.T) {
	input := "- **search_function**：找到函数 `sync_inventory`，ID 为 `fn_9d7a2dde34adb3b1`。\n" +
		"- **todo_read**：读取当前清单。\n" +
		"- **todo_write**：更新当前清单。"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "fn_9d7a2dde34adb3b1") {
		t.Fatalf("public tool summary leaked an opaque value: %q", got)
	}
	for _, toolName := range []string{"todo_read", "todo_write"} {
		if !strings.Contains(got, toolName) {
			t.Fatalf("public tool name %q was redacted: %q", toolName, got)
		}
	}
	if gotID := redactOpaqueMachineValues("todo_1234567890abcdef"); gotID == "todo_1234567890abcdef" {
		t.Fatal("opaque todo id was not redacted")
	}
}

func TestTextRedactorPreservesSplitPublicTodoToolNames(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"- **todo",
		"_read**：读取当前清单。\n- **todo",
		"_write**：更新当前清单。\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) {
			t.Fatalf("split public tool name leaked placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, toolName := range []string{"todo_read", "todo_write"} {
		if !strings.Contains(got.String(), toolName) {
			t.Fatalf("split public tool name %q was redacted: %q", toolName, got.String())
		}
	}
}

func TestRedactChineseLocatedIDAssignmentKeepsProseNatural(t *testing.T) {
	input := "我已经找到了这个文档的 ID：`doc_3ec2e562757ebbef`。"
	want := "我已经找到了这个文档。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("Chinese located opaque ID assignment = %q, want %q", got, want)
	}
}

func TestRedactChineseIDAdvisoryHidesOpaqueValueAndPlaceholder(t *testing.T) {
	input := `用户写的是 "IDfn_0000000000000000"。实际的 ID 应该是 ` + "`the requested item`" + `。`
	want := `用户写的是 "ID 见相邻工具卡"。实际的 ID 见相邻工具卡。`
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("Chinese ID advisory = %q, want %q", got, want)
	}
}

func TestTextRedactorHoldsChineseIDAdvisoryAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		`用户写的是 "ID`,
		`fn_0000000000000000"。实际的 ID 应该是 ` + "`",
		`the requested item`,
		"`。",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "fn_0000000000000000") || strings.Contains(piece, opaqueEntityPlaceholder) {
			t.Fatalf("Chinese ID advisory leaked in live piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := `用户写的是 "ID 见相邻工具卡"。实际的 ID 见相邻工具卡。`
	if got.String() != want {
		t.Fatalf("stream Chinese ID advisory = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorHoldsChineseLocatedIDAssignmentAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"我已经找到了这个文档的 ID：`",
		"doc_3ec2e562757ebbef",
		"`。\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "doc_") {
			t.Fatalf("Chinese located ID assignment leaked in %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if got.String() != "我已经找到了这个文档。\n" {
		t.Fatalf("stream Chinese located opaque ID assignment = %q", got.String())
	}
}

func TestRedactBareExactIDAssignmentKeepsProseNatural(t *testing.T) {
	for _, tc := range []struct {
		input string
		want  string
	}{
		{input: "找到了确切 ID：`doc_3ec2e562757ebbef`。", want: "找到了确切文档。"},
		{input: "I found the exact ID: `doc_3ec2e562757ebbef`.", want: "I found the exact document."},
		{input: "I found the exact document ID: `doc_3ec2e562757ebbef`.", want: "I found the exact document."},
		{input: "I found its ID: `doc_3ec2e562757ebbef`.", want: "I found the document."},
		{input: "找到了确切 ID：\n`doc_3ec2e562757ebbef`。", want: "找到了确切文档。"},
		{input: "我已经找到了确切的 ID：`doc_3ec2e562757ebbef`。", want: "我已经找到了确切文档。"},
		{input: "**文档 ID**: `doc_3ec2e562757ebbef`", want: "文档已定位"},
	} {
		if got := redactOpaqueMachineValues(tc.input); got != tc.want {
			t.Fatalf("bare exact ID assignment = %q, want %q", got, tc.want)
		}
	}
}

func TestTextRedactorHoldsBareExactIDAssignmentAcrossLineBreak(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"找到了确切 ID：\n",
		"`doc_3ec2e562757ebbef`。\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "doc_") {
			t.Fatalf("bare exact ID assignment leaked in %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if got.String() != "找到了确切文档。\n" {
		t.Fatalf("stream bare exact ID assignment = %q", got.String())
	}
}

func TestTextRedactorHoldsDecoratedChineseIDAssignmentAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"**文档 ID**: `",
		"doc_3ec2e562757ebbef",
		"`\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "doc_") || strings.Contains(piece, "**") {
			t.Fatalf("decorated Chinese ID assignment leaked in %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if got.String() != "文档已定位\n" {
		t.Fatalf("stream decorated Chinese ID assignment = %q", got.String())
	}
}

func TestRedactReasoningJSONIDFieldKeepsShapeWithoutOpaqueValue(t *testing.T) {
	input := `[Tool call: get_relations]\n{ "depth": 2, "id": "doc_3ec2e562757ebbef", "kind": "document" }`
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"doc_3ec2e562757ebbef", opaqueEntityPlaceholder, opaqueEntityPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("reasoning JSON leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, `"id": "document"`) || !strings.Contains(got, `"depth": 2`) {
		t.Fatalf("reasoning JSON lost useful shape: %q", got)
	}
}

func TestTextRedactorHoldsReasoningJSONIDFieldAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		`{ "depth": 2, "id": "`,
		"doc_3ec2e562757ebbef",
		`", "kind": "document" }`,
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "doc_3ec2e562757ebbef") || strings.Contains(piece, opaqueEntityPlaceholder) {
			t.Fatalf("reasoning JSON stream leaked opaque value: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if !strings.Contains(got.String(), `"id": "document"`) {
		t.Fatalf("reasoning JSON stream lost redacted field: %q", got.String())
	}
}

func TestTextRedactorHoldsEnglishItsIDAssignmentAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"I found its ID: `",
		"doc_3ec2e562757ebbef",
		"`. Now I will inspect it.",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "doc_") {
			t.Fatalf("English pronoun ID assignment leaked in %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if got.String() != "I found the document. Now I will inspect it." {
		t.Fatalf("stream English pronoun ID assignment = %q", got.String())
	}
}

func TestRedactOpaqueIDWithHumanNameParentheticalKeepsName(t *testing.T) {
	input := "I checked `doc_3ec2e562757ebbef` (Neighbour B) and found two edges."
	want := "I checked Neighbour B and found two edges."
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("opaque ID name parenthetical = %q, want %q", got, want)
	}
}

func TestTextRedactorHoldsOpaqueIDNameParentheticalAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"I checked `doc_3ec2e562757ebbef` (",
		"Neighbour B) and found two edges.",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "doc_") {
			t.Fatalf("opaque ID name parenthetical leaked in %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if got.String() != "I checked Neighbour B and found two edges." {
		t.Fatalf("stream opaque ID name parenthetical = %q", got.String())
	}
}

func TestTextRedactorHoldsChineseOpaqueIDAssignmentAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"找到了，文档 ID 为 `",
		"doc_3ec2e562757ebbef",
		"`。现在查看其关系邻域：",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "doc_") {
			t.Fatalf("stream leaked opaque ID or placeholder in %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "找到了，文档已定位。现在查看其关系邻域："
	if got.String() != want {
		t.Fatalf("stream Chinese opaque ID assignment = %q, want %q", got.String(), want)
	}
}

func TestRedactEnglishOpaqueIDAssignmentKeepsReasoningNatural(t *testing.T) {
	input := "I found the document ID: `doc_3ec2e562757ebbef`."
	want := "I found the document."
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("English opaque ID assignment = %q, want %q", got, want)
	}
}

func TestRedactEnglishOpaqueIDFieldRemovesMachineParameter(t *testing.T) {
	input := "For documents, the kind would be \"document\".\n- id: \"doc_3ec2e562757ebbef\"\n- depth: 2\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"doc_3ec2e562757ebbef", opaqueEntityPlaceholder, "- id:"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("English reasoning field leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"the kind would be \"document\"", "- depth: 2"} {
		if !strings.Contains(got, want) {
			t.Fatalf("English reasoning lost useful parameter %q: %q", want, got)
		}
	}
}

func TestTextRedactorHoldsEnglishOpaqueIDAssignmentAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"I found the document ID: `",
		"doc_3ec2e562757ebbef",
		"`.\n\nFor documents, the kind would be \"document\".\n- id: \"doc_3ec2e562757ebbef\"\n- depth: 2\n",
	} {
		piece := r.Write(delta)
		for _, forbidden := range []string{"doc_3ec2e562757ebbef", opaqueEntityPlaceholder, "- id:"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("English reasoning stream leaked %q in %q", forbidden, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "doc_3ec2e562757ebbef") || strings.Contains(got.String(), opaqueEntityPlaceholder) {
		t.Fatalf("English reasoning stream leaked opaque value: %q", got.String())
	}
	if strings.Contains(got.String(), "- id:") || !strings.Contains(got.String(), "I found the document.") {
		t.Fatalf("English reasoning stream shape = %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesCleansActivationReasoningFields(t *testing.T) {
	input := "返回的字段有：\n- id: tra_f98331ff0472114c\n- triggerId: the requested item\n- kind: cron\n- fired: true\n- createdAt: the recorded time\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, opaqueTimestampPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("activation reasoning leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "精确触发器 ID 见旁边的触发器卡片。") {
		t.Fatalf("activation reasoning missing trigger-card guidance: %q", got)
	}
}

func TestRedactRelationSummaryKeepsMeaningWithoutOpaqueRefs(t *testing.T) {
	input := "以下是 `the requested item`（函数 **greet**）在 depth 1 下的全部关系边：\n\n" +
		"| # | 方向 | 关系类型 | 端点 | 引用 |\n" +
		"|---|------|----------|------|------|\n" +
		"| 1 | ← 入边（from → to） | `equip` | from: **deploy-helper**（skill, `deploy-helper`） → to: **greet**（function, `the requested item`） | `rel_2ddb48708bc167e6` |"
	want := "以下是函数 **greet** 在 depth 1 下的全部关系边：\n\n" +
		"| # | 方向 | 关系类型 | 端点 | 引用 |\n" +
		"|---|------|----------|------|------|\n" +
		"| 1 | ← 入边（from → to） | `equip` | from: **deploy-helper**（skill, `deploy-helper`） → to: **greet**（function） | 精确 ref 见关系卡 |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("relation summary redaction = %q, want %q", got, want)
	}
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "rel_"} {
		if strings.Contains(redactOpaqueMachineValues(input), forbidden) {
			t.Fatalf("relation summary leaked %q", forbidden)
		}
	}
}

func TestTextRedactorHoldsRelationSummaryAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是 `the requested ",
		"item`（函数 **greet**）在 depth 1 下的全部关系边：\n",
		"| # | 方向 | 关系类型 | 端点 | 引用 |\n|---|------|----------|------|------|\n",
		"| 1 | ← 入边（from → to） | `equip` | from: **deploy-helper**（skill, `deploy-helper`） → to: **greet**（function, `the requested ",
		"item`） | `rel_2ddb48708bc167e6` |\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) || strings.Contains(piece, "rel_") {
			t.Fatalf("relation summary leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "rel_"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("stream relation summary leaked %q: %q", forbidden, got.String())
		}
	}
	for _, want := range []string{"以下是函数 **greet** 在 depth 1 下的全部关系边：", "`equip`", "精确 ref 见关系卡", "deploy-helper"} {
		if !strings.Contains(got.String(), want) {
			t.Fatalf("stream relation summary missing %q: %q", want, got.String())
		}
	}
}

func TestTextRedactorHoldsActualRelationIntroAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是 \x60the requested item\x60（函数 **",
		"greet**）在 depth=1 下的全部关系边：\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("actual relation intro leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), legacyEntityPlaceholder) {
		t.Fatalf("actual relation intro leaked: %q", got.String())
	}
}

func TestTextRedactorRedactsReasoningEdgePlaceholder(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"The function is \"greet\". It has one edge:\n\n- Edge ",
		"the requested item: kind \"equip\", from skill \"deploy-helper\" to function \"greet\".",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("reasoning edge leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), legacyEntityPlaceholder) {
		t.Fatalf("reasoning edge leaked: %q", got.String())
	}
}

func TestRedactRelationReasoningPlaceholderLine(t *testing.T) {
	input := "用户要求我调用 get_relations 并返回所有边。\n\n结果只有一条边：\n- the requested item\n- kind: equip\n"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("relation reasoning placeholder leaked: %q", got)
	}
	if !strings.Contains(got, "- 该关系") {
		t.Fatalf("relation reasoning lost neutral label: %q", got)
	}
}

func TestRedactRelationDetailsCurrentModelVariant(t *testing.T) {
	input := "关系查询结果\n\n实体: the requested item (greet)\n类型: function\n" +
		"创建时间: the recorded time\n更新时间: the recorded time\n\n" +
		"以下是 get_relations 对 the requested item（function: greet）在 depth=1 下返回的全部边，共 1 条：\n\n" +
		"详细字段\n\n" +
		"• the requested item\n" +
		"  • 方向：from → to\n" +
		"  • to endpoint：kind=function，name=greet，id=the requested item\n" +
		"  • createdAt：the recorded time\n" +
		"  • updatedAt：the recorded time\n" +
		"  - 含义：skill deploy-helper 装备（equip）了 function greet，即 deploy-helper 在其 allowedTools 中引用了 greet。\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		opaqueEntityPlaceholder,
		legacyEntityPlaceholder,
		opaqueTimestampPlaceholder,
		"get_relations",
		"id=the requested item",
		"createdAt",
		"updatedAt",
		"创建时间",
		"更新时间",
		"allowedTools",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("current relation variant leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "实体: greet") ||
		!strings.Contains(got, "以下是 函数 greet 在") ||
		!strings.Contains(got, "• 目标函数") ||
		!strings.Contains(got, "name=greet") {
		t.Fatalf("current relation variant lost meaning: %q", got)
	}
}

func TestTextRedactorHoldsCurrentRelationDetailsVariant(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是 get_relations 对 the requested ",
		"item（function: greet）在 depth=1 下返回的全部边，共 1 条：\n\n",
		"详细字段\n\n• the requested item\n",
		"  • to endpoint：kind=function，name=greet，id=the requested item\n",
		"  • createdAt：the recorded time\n",
	} {
		piece := r.Write(delta)
		for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder, "get_relations", "createdAt"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("current relation stream leaked %q in %q", forbidden, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder, "get_relations", "createdAt"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("current relation stream leaked %q: %q", forbidden, got.String())
		}
	}
}

func TestNormalizeRelationEndpointDisplay(t *testing.T) {
	cases := map[string]string{
		"deploy-helper（skill，deploy-helper）": "deploy-helper（skill）",
		"deploy-helper（deploy-helper）":       "deploy-helper",
		"skill deploy-helper（deploy-helper）": "skill deploy-helper",
		"greet（function，）":                   "greet（function）",
	}
	for input, want := range cases {
		if got := normalizeRelationEndpointDisplay(input); got != want {
			t.Fatalf("endpoint display %q = %q, want %q", input, got, want)
		}
	}
}

func TestRedactRelationEndpointCellHidesMachineReferences(t *testing.T) {
	cases := map[string]string{
		"skill deploy-helper（fromId: deploy-helper）": "skill deploy-helper",
		"function greet (toId: greet)":               "function greet",
		"skill deploy-helper（deploy-helper）":         "skill deploy-helper",
	}
	for input, want := range cases {
		if got := redactRelationEndpointCell(input, false); got != want {
			t.Fatalf("endpoint cell %q = %q, want %q", input, got, want)
		}
	}
}

func TestRedactRelationTableHidesMachineReferencesFromNamedEndpoints(t *testing.T) {
	input := "函数 `greet` 在 depth=1 下的全部关系边如下（共 1 条）：\n\n" +
		"| # | 方向 | 关系类型 (kind) | 起点 (from) | 终点 (to) |\n" +
		"|---|------|-----------------|-------------|-----------|\n" +
		"| 1 | 入边 (into the function) | `equip` | skill **`deploy-helper`** (fromId: `deploy-helper`) | function **`greet`** ) |"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"fromId", "toId", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("named endpoint table leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "skill **`deploy-helper`**") || strings.Contains(got, "(fromId") {
		t.Fatalf("named endpoint table lost readable endpoint: %q", got)
	}
}

func TestRedactRelationRemovesBarePlaceholderLine(t *testing.T) {
	got := redactOpaqueMachineValues("根据关系查询结果：\nthe requested item\n")
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("bare relation placeholder leaked: %q", got)
	}
}

func TestTextRedactorHoldsActualRelationMarkdownVariantAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是 \x60the requested item\x60（函数 **",
		"greet**）在 depth=1 下的全部关系边：\n\n---\n\n### 关系边（共 1 条）\n\n",
		"| 方向 | 关系类型 | 起点 | 终点 | 关系 ID |\n",
		"|------|----------|------|------|---------|\n",
		"| ← 入边 | **equip** | skill **deploy-helper** | function **",
		"greet** | \x60the requested item\x60 |\n\n",
		"---\n\n**解读：**",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("actual relation markdown leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), legacyEntityPlaceholder) {
		t.Fatalf("actual relation markdown leaked: %q", got.String())
	}
}

func TestRedactRelationSummaryDropsUnavailableCreationTime(t *testing.T) {
	input := "- 创建时间：\nthe recorded time。\n- 创建/更新时间：\nthe recorded time\n- Created at: the recorded time."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"创建时间", "创建/更新时间", "Created at", opaqueTimestampPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("unavailable relation creation time leaked %q: %q", forbidden, got)
		}
	}
}

func TestRedactRelationSummaryHandlesTargetFirstMultilineVariant(t *testing.T) {
	input := "以下是\nthe requested item\n (function greet) 在 depth=1 下的全部关系边：\n\n" +
		"起点：skill deploy-helper（fromName = deploy-helper，fromId = deploy-helper）\n" +
		"终点：function greet（toName = greet，toId = the requested item）\n" +
		"创建/更新时间：the recorded time"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder, "rel_"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("multiline relation summary leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"以下是 function greet 在 depth=1 下的全部关系边：", "起点：skill deploy-helper", "终点：function greet"} {
		if !strings.Contains(got, want) {
			t.Fatalf("multiline relation summary missing %q: %q", want, got)
		}
	}
}

func TestRedactRelationSummaryHandlesTypedTargetFirstVariant(t *testing.T) {
	input := "以下是函数 \nthe requested item\n（greet）在 depth=1 下的全部关系边："
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("typed relation intro leaked %q: %q", forbidden, got)
		}
	}
	if got != "以下是函数 greet 在 depth=1 下的全部关系边：" {
		t.Fatalf("typed relation intro = %q", got)
	}
}

func TestRedactRelationSummaryHandlesBareTargetAndTimeVariant(t *testing.T) {
	input := "以下是 \nthe requested item\n 在 depth 1 下的全部关系边：\n创建/更新时间均为 \n`the recorded time`\n- 该函数被技能 `deploy-helper` 通过 `equip` 关系装备（即 `deploy-helper` 在其 `allowedTools` 中挂载了 `greet`）。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder, "创建/更新时间", "allowedTools"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("bare relation summary leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "以下是该函数在 depth 1 下的全部关系边：") {
		t.Fatalf("bare relation intro lost semantic fallback: %q", got)
	}
	if !strings.Contains(got, "该函数被技能 deploy-helper 通过 equip 关系装备。") {
		t.Fatalf("malformed equip explanation was not normalized: %q", got)
	}
}

func TestRedactRelationSummaryHandlesToolPrefixedTarget(t *testing.T) {
	input := "`get_relations` 对 `the requested item`（函数 **greet**）在 depth 1 下返回 **1 条边**："
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "get_relations"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("tool-prefixed relation intro leaked %q: %q", forbidden, got)
		}
	}
	if got != "函数 **greet** 在 depth 1 下返回 **1 条边**：" {
		t.Fatalf("tool-prefixed relation intro = %q", got)
	}
}

func TestRedactRelationSummaryHandlesFieldValueDetails(t *testing.T) {
	input := "针对 `the requested item` (function: greet) 的关系查询返回 1 条边：\n\n" +
		"| 字段 | 值 |\n|------|-----|\n" +
		"| **边 ID** | `the requested item` |\n" +
		"| **起点引用** | `fromId: deploy-helper` |\n" +
		"| **终点引用** | `toId: the requested item` |\n" +
		"| **创建时间** | `the recorded time` |\n" +
		"| **更新时间** | `the recorded time` |"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder, "fromId:", "toId:", "创建时间", "更新时间"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("relation field table leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "针对 function: greet 的关系查询") || !strings.Contains(got, relationTableRefHint) {
		t.Fatalf("relation field table lost semantic fallback: %q", got)
	}
}

func TestRedactRelationSummaryHandlesDirectionAndRelationIDVariants(t *testing.T) {
	input := "以下是 \x60the requested item\x60（函数 **greet**）在 depth 1 下的全部关系边（共 1 条）：\n\n" +
		"| # | 方向 | 关系类型 | 端点名 | 精确引用 |\n|---|------|----------|--------|----------|\n" +
		"| 1 | 入向 (→ the requested item) | equip | from: **deploy-helper** (skill, \x60deploy-helper\x60) → to: **greet** (function) | 精确 ref 见关系卡 |\n\n" +
		"**说明：**\n- 关系 id：\x60the requested item\x60"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "rel_", "关系 id："} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("relation summary leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "| 1 | 入向 | equip |") || !strings.Contains(got, "精确关系引用见关系卡") {
		t.Fatalf("relation summary lost semantic fallback: %q", got)
	}
}

func TestRedactRelationReasoningDoesNotLeakTargetID(t *testing.T) {
	input := "The user wants me to call get_relations exactly once with specific parameters: kind=\"function\", id=\"fn_e2273c21262f45db\", depth=1."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "fn_e2273c21262f45db"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("relation reasoning leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "kind=\"function\", depth=1") {
		t.Fatalf("relation reasoning lost useful parameters: %q", got)
	}
}

func TestRedactRelationSummaryHandlesSplitEndpointIDColumns(t *testing.T) {
	input := "以下是函数 greet 在 depth 1 下的全部关系边：\n\n" +
		"| # | 方向 | 关系类型 | 端点 A（kind / name / id） | 端点 B（kind / name / id） | 关系引用 ID |\n" +
		"|---|------|----------|----------------------------|----------------------------|-------------|\n" +
		"| 1 | ← (入边) | equip | skill · \x60deploy-helper\x60 · deploy-helper | function · \x60greet\x60 · the requested item | - |"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, " / id", "关系引用 ID"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("split endpoint relation table leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"端点 A（kind / name）", "端点 B（kind / name）", "skill · \x60deploy-helper\x60", "function · \x60greet\x60", relationTableRefHint} {
		if !strings.Contains(got, want) {
			t.Fatalf("split endpoint relation table missing %q: %q", want, got)
		}
	}
}

func TestTextRedactorHoldsTargetFirstRelationVariantAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是\n",
		"the requested ",
		"item\n (function greet) 在 depth=1 下的全部关系边：\n",
		"终点：function greet（toName = greet，toId = ",
		"the requested item）\n创建/更新时间：\n",
		"`the recorded time`\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) || strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("multiline relation variant leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("stream multiline relation variant leaked %q: %q", forbidden, got.String())
		}
	}
}

func TestTextRedactorHoldsBareRelationVariantAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是\n",
		"the requested item\n 在 depth 1 下的全部关系边：\n",
		"创建/更新时间均为\n",
		"the recorded time\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) || strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("bare relation variant leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder, "创建/更新时间"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("stream bare relation variant leaked %q: %q", forbidden, got.String())
		}
	}
}

func TestTextRedactorHoldsToolPrefixedRelationVariantAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"`get_relations` 对 `the requested ",
		"item`（函数 **greet**）在 depth 1 下返回 **1 条边**：\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) || strings.Contains(piece, "get_relations") {
			t.Fatalf("tool-prefixed relation variant leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "get_relations"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("stream tool-prefixed relation variant leaked %q: %q", forbidden, got.String())
		}
	}
}

func TestTextRedactorHoldsRelationFieldRowsAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| 字段 | 值 |\n|------|-----|\n| **终点引用** | `toId: the requested ",
		"item` |\n| **创建时间** | `the recorded time` |\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) || strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("relation field row leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, opaqueTimestampPlaceholder, "toId:", "创建时间"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("stream relation field row leaked %q: %q", forbidden, got.String())
		}
	}
	if !strings.Contains(got.String(), relationTableRefHint) {
		t.Fatalf("stream relation field row lost semantic fallback: %q", got.String())
	}
}

func TestTextRedactorHoldsRelationIDAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"**说明：**\n- 关系 id：\x60",
		"the requested item\x60\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("relation id leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "关系 id：") || !strings.Contains(got.String(), "精确关系引用见关系卡") {
		t.Fatalf("relation id lost semantic fallback: %q", got.String())
	}
}

func TestTextRedactorHoldsRelationReasoningIDAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"The user wants me to call get_relations exactly once with specific parameters: kind=\"function\", id=\"",
		"fn_e2273c21262f45db\", depth=1.",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) || strings.Contains(piece, "fn_e2273c21262f45db") {
			t.Fatalf("relation reasoning leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), "fn_e2273c21262f45db") || !strings.Contains(got.String(), "kind=\"function\", depth=1") {
		t.Fatalf("relation reasoning stream result = %q", got.String())
	}
}

func TestRedactSearchConversationPointerRows(t *testing.T) {
	input := "Match\n- Conversation ID: cv_0123456789abcdef\n- conversationId: cv_0123456789abcdef\n- Title: Not returned for this hit.\n- Message pointer: msg_0123456789abcdef\n- messageId: msg_0123456789abcdef\n| **Conversation ID** | cv_0123456789abcdef |\n| **Message pointer** | msg_0123456789abcdef |"
	want := "Match\n- Conversation ID: See the exact conversation in the search card.\n- conversationId: See the exact conversation in the search card.\n- Title: See the exact conversation in the search card.\n- Message pointer: See the exact matching message in the search card.\n- messageId: See the exact matching message in the search card.\n| **Conversation ID** | See the exact conversation in the search card. |\n| **Message pointer** | See the exact matching message in the search card. |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("search pointer rows must point to the adjacent card, got %q want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsHumanSemantics(t *testing.T) {
	input := "mode warm -> cool; prefix alpha; bootId changed; 7 steps"
	if got := redactOpaqueMachineValues(input); got != input {
		t.Fatalf("human-readable semantics changed: got %q, want %q", got, input)
	}
}

func TestRedactOpaqueMachineValuesPreservesExplicitLastMessageAt(t *testing.T) {
	input := "lastMessageAt: 2026-08-04T13:28:46Z; observed at 2026-08-04T13:29:01Z"
	want := "lastMessageAt: 2026-08-04T13:28:46Z; observed at the recorded time"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("explicit lastMessageAt redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesPreservesLastMessageAtTableColumn(t *testing.T) {
	input := "| Title | lastMessageAt | Created at |\n|---|---|---|\n| Gamma roadmap | 2026-08-04T13:28:46Z | 2026-08-04T13:18:31Z |"
	want := "| Title | lastMessageAt | Created at |\n|---|---|---|\n| Gamma roadmap | 2026-08-04T13:28:46Z | See the exact upload time in the attachment card. |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("lastMessageAt table redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesPreservesExplicitNextFireAt(t *testing.T) {
	input := "nextFireAt: 2026-08-26T09:00:00+08:00; createdAt: 2026-08-25T01:09:12Z"
	want := "nextFireAt: 2026-08-26T09:00:00+08:00; createdAt: the recorded time"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("explicit nextFireAt redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesPreservesTranslatedNextFireRow(t *testing.T) {
	input := "| 字段 | 值 |\n|---|---|\n| **下次触发时间** | 2026-08-26 09:00:00 +08:00 |"
	want := "| 字段 | 值 |\n|---|---|\n| **下次触发时间** | 2026-08-26 09:00:00 +08:00 |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("translated nextFireAt row redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorPreservesSplitNextFireAtRow(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| 字段 | 值 |\n|---|---|\n| **下次触发时间** | 2026-08-26 09:",
		"00:00 +08:00 |\n\n已启用。",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("split nextFireAt row leaked placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "| 字段 | 值 |\n|---|---|\n| **下次触发时间** | 2026-08-26 09:00:00 +08:00 |\n\n已启用。"
	if got.String() != want {
		t.Fatalf("split nextFireAt row = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorPreservesLastMessageAtAcrossTableChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Title | lastMessa",
		"geAt |\n",
		"|---|---|\n| Gamma roadmap | 2026-08-04T13:",
		"28:46Z |\n",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	want := "| Title | lastMessageAt |\n|---|---|\n| Gamma roadmap | 2026-08-04T13:28:46Z |\n"
	if got.String() != want {
		t.Fatalf("streamed lastMessageAt = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorPreservesLastMessageAtAcrossProviderTableChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Title | last",
		"MessageAt",
		" |\n|-------",
		"|---------------|\n",
		"| Gamma roadmap |",
		" `2",
		"026-",
		"08-0",
		"4T13",
		":43:",
		"32Z`",
		" |\n| Alpha",
		" planning | `2",
		"026-",
		"08-0",
		"4T13",
		":18:",
		"50Z`",
		" |\n| Beta",
		" research | `2",
		"026-",
		"08-0",
		"4T13",
		":18:",
		"31Z`",
		" |\n\nWalk complete",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	want := "| Title | lastMessageAt |\n|-------|---------------|\n| Gamma roadmap | `2026-08-04T13:43:32Z` |\n| Alpha planning | `2026-08-04T13:18:50Z` |\n| Beta research | `2026-08-04T13:18:31Z` |\n\nWalk complete"
	if got.String() != want {
		t.Fatalf("provider-chunked lastMessageAt = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorPreservesLastMessageAtWhenTableEndsWithoutTrailingNewline(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Title | last",
		"MessageAt",
		" |\n|-------",
		"|---------------|\n",
		"| Gamma roadmap |",
		" `2",
		"026-",
		"08-0",
		"4T13",
		":48:",
		"57Z`",
		" |\n| Alpha",
		" planning | `2",
		"026-0",
		"8-04",
		"T13:",
		"18:",
		"50Z`",
		" |\n| Beta",
		" research | `2",
		"026-0",
		"8-04",
		"T13:",
		"18:3",
		"1",
		"Z` |",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("stream leaked timestamp placeholder before table ended: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "| Title | lastMessageAt |\n|-------|---------------|\n| Gamma roadmap | `2026-08-04T13:48:57Z` |\n| Alpha planning | `2026-08-04T13:18:50Z` |\n| Beta research | `2026-08-04T13:18:31Z` |"
	if got.String() != want {
		t.Fatalf("unterminated streamed lastMessageAt table = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorPreservesLastMessageAtWithoutMarkdownCodeSpans(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"|",
		" Title | lastMessage",
		"At |\n|",
		"-------",
		"|---------------|\n",
		"| Gamma roadmap |",
		" 202",
		"6-08",
		"-04T",
		"1",
		"3:56",
		":20Z",
		" |\n| Alpha",
		" planning | 2",
		"026-",
		"08-0",
		"4T13",
		":18:",
		"50Z |",
		"\n| Beta research",
		" | 20",
		"26-0",
		"8-04",
		"T13:",
		"18:3",
		"1Z |",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("stream leaked timestamp placeholder before table ended: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "| Title | lastMessageAt |\n|-------|---------------|\n| Gamma roadmap | 2026-08-04T13:56:20Z |\n| Alpha planning | 2026-08-04T13:18:50Z |\n| Beta research | 2026-08-04T13:18:31Z |"
	if got.String() != want {
		t.Fatalf("unquoted streamed lastMessageAt table = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorPreservesLastMessageAtAcrossLiveProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Title", " |", " lastMessageAt |", "\n|-------", "|---------------|\n",
		"| Gamma", " roadmap | 2", "0", "26-0", "8-04", "T14:", "08:1", "0Z |\n",
		"| Alpha planning |", " 20", "26-0", "8-04", "T13:", "18", ":50Z", " |\n|",
		" Beta research | ", "2026", "-08-", "04T1", "3:18", ":31Z", " |",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("live provider chunk leaked timestamp placeholder after %q: %q", delta, piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "| Title | lastMessageAt |\n|-------|---------------|\n| Gamma roadmap | 2026-08-04T14:08:10Z |\n| Alpha planning | 2026-08-04T13:18:50Z |\n| Beta research | 2026-08-04T13:18:31Z |"
	if got.String() != want {
		t.Fatalf("live provider chunked lastMessageAt = %q, want %q", got.String(), want)
	}
}

func TestRedactOpaqueMachineValuesPointsAttachmentTimestampToCard(t *testing.T) {
	input := "| Filename | Kind | Uploaded |\n|---|---|---|\n| report.txt | text | 2026-08-03T10:09:27Z |"
	want := "| Filename | Kind | Uploaded |\n|---|---|---|\n| report.txt | text | See the exact upload time in the attachment card. |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("attachment timestamp redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesPointsActivationDetailsToCard(t *testing.T) {
	input := "| Field | Value |\n|---|---|\n" +
		"| **triggerId** | `trg_dcba2607dce9e2a9` |\n" +
		"| **kind** | `cron` |\n" +
		"| **fired** | `true` |\n" +
		"| **payload** | {\"manual\":true} |\n" +
		"| **firingCount** | `0` |\n" +
		"| **createdAt** | 2026-08-08T01:32:14.898871Z |"
	want := "| Field | Value |\n|---|---|\n" +
		"| **triggerId** | See the exact activation ID in the adjacent activation card. |\n" +
		"| **kind** | `cron` |\n" +
		"| **fired** | `true` |\n" +
		"| **payload** | {\"manual\":true} |\n" +
		"| **firingCount** | `0` |\n" +
		"| **createdAt** | See the exact creation time in the adjacent activation card. |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("activation detail redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorPointsActivationDetailsToCardAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Field | Value |\n|---|---|\n| **triggerId** | `trg_dcba",
		"2607dce9e2a9` |\n| **kind** | `cron` |\n| **fired** | `true` |\n",
		"| **createdAt** | 2026-08-08T01:32:14.",
		"898871Z |\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "trg_") || strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("stream leaked activation opaque value: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "trg_") || strings.Contains(got.String(), "2026-08-08T01:32:14.898871Z") || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("activation details leaked exact or vague value: %q", got.String())
	}
	for _, want := range []string{activationIDTableRowHint, activationCreatedAtTableHint} {
		if !strings.Contains(got.String(), want) {
			t.Fatalf("stream activation details missing %q: %q", want, got.String())
		}
	}
}

func TestTextRedactorHoldsActivationTableContextAcrossWholeRowChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Field | Value |\n",
		"|---|---|\n",
		"| **activationId** | `tra_dcba2607dce9e2a9` |\n",
		"| **triggerId** | `the requested item` |\n",
		"| **kind** | `cron` |\n",
		"| **fired** | `true` |\n",
		"| **payload** | `{\"manual\": true}` |\n",
		"| **firingCount** | `0` |\n",
		"\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) {
			t.Fatalf("stream leaked activation placeholder after %q: %q", delta, piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) {
		t.Fatalf("activation table retained placeholder: %q", got.String())
	}
	if !strings.Contains(got.String(), activationIDTableRowHint) {
		t.Fatalf("activation table missing card guidance: %q", got.String())
	}
}

func TestTextRedactorHoldsGatewayActivationTableWithChineseHeader(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是 `tra_dcba2607dce9e2a9` 这条激活审计记录的完整字段：\n\n",
		"| 字段 | 值 |\n",
		"|---|---|\n",
		"| **id**（激活记录 ID） | `tra_dcba2607dce9e2a9` |\n",
		"| **triggerId**（触发器 ID） | `the requested item` |\n",
		"| **kind**（触发器类型） | `cron`（定时触发） |\n",
		"| **fired**（是否已触发） | `true`（已触发） |\n",
		"| **payload**（触发载荷） | `{\"manual\": true}`（手动触发） |\n",
		"| **firingCount**（触发计数） | `0` |\n",
		"| **createdAt**（创建时间） | `the recorded time` |\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("gateway activation table leaked placeholder after %q: %q", delta, piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("gateway activation table retained placeholder: %q", got.String())
	}
	if !strings.Contains(got.String(), activationTriggerIDTableHint) {
		t.Fatalf("gateway activation table missing localized trigger guidance: %q", got.String())
	}
	if !strings.Contains(got.String(), "精确创建时间见旁边的活动卡片。") {
		t.Fatalf("gateway activation table missing localized creation-time guidance: %q", got.String())
	}
}

func TestTextRedactorHoldsGatewayActivationTableWithInlineAnnotations(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是该激活记录的完整字段：\n\n",
		"| 字段 | 值 |\n",
		"|------|-----|\n",
		"| **id（激活 ID）** | tra_f82182fcb7601442 |\n",
		"| **triggerId（触发器 ID）** | the requested item |\n",
		"| **kind（类型）** | cron（定时任务） |\n",
		"| **fired（是否触发）** | true（已触发） |\n",
		"| **payload（载荷）** | {\"manual\": true}（手动触发） |\n",
		"| **firingCount（触发计数）** | 0 |\n",
		"| **createdAt",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("inline-annotation activation table leaked placeholder after %q: %q", delta, piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("inline-annotation activation table retained placeholder: %q", got.String())
	}
	if !strings.Contains(got.String(), activationTriggerIDTableHint) {
		t.Fatalf("inline-annotation activation table missing localized trigger guidance: %q", got.String())
	}
}

func TestTextRedactorLocalizesActivationNarrativePlaceholdersAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"这是一条由 ",
		"cron ",
		"类型触发器（",
		"`the requested item",
		"`）在 ",
		"the recorded time ",
		"产生的激活记录，已触发。",
	} {
		piece := r.Write(delta)
		for _, forbidden := range []string{opaqueEntityPlaceholder, opaqueTimestampPlaceholder} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("activation narrative leaked %q after %q: %q", forbidden, delta, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("activation narrative retained placeholder: %q", got.String())
	}
	if !strings.Contains(got.String(), opaqueTimestampChinesePlaceholder) {
		t.Fatalf("activation narrative lost localized time: %q", got.String())
	}
	if strings.Contains(got.String(), "（") || strings.Contains(got.String(), "）") {
		t.Fatalf("activation narrative retained unavailable ID parenthetical: %q", got.String())
	}
}

func TestRedactActivationDetailsLocalizesCardGuidanceToResponseLanguage(t *testing.T) {
	input := "以下是该激活记录的详情：\n\n| 字段 | 值 |\n|---|---|\n" +
		"| **triggerId** | `trg_dcba2607dce9e2a9` |\n" +
		"| **kind** | `cron` |\n" +
		"| **fired** | `true` |\n" +
		"| **createdAt** | 2026-08-08T01:32:14.898871Z |"
	want := "以下是该激活记录的详情：\n\n| 字段 | 值 |\n|---|---|\n" +
		"| **triggerId** | 精确触发器 ID 见旁边的活动卡片。 |\n" +
		"| **kind** | `cron` |\n" +
		"| **fired** | `true` |\n" +
		"| **createdAt** | 精确创建时间见旁边的活动卡片。 |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("localized activation guidance = %q, want %q", got, want)
	}
}

func TestTextRedactorDoesNotStreamAttachmentTimestampPlaceholder(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Filename | Uploaded |\n|---|---|\n| report.txt | 2026-08-03T10:",
		"09:27Z |",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("stream leaked timestamp placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "2026-08-03T10:09:27Z") || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("stream leaked exact or vague timestamp: %q", got.String())
	}
	if !strings.Contains(got.String(), attachmentTimestampTableHint) {
		t.Fatalf("stream did not point to attachment card: %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesPointsMCPConnectionTimestampToCard(t *testing.T) {
	input := "| Server | Status | Connected at |\n|---|---|---|\n| context7 | ready | 2026-08-04T07:30:18Z |"
	want := "| Server | Status | Connected at |\n|---|---|---|\n| context7 | ready | See the exact connection time in the MCP status card. |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("MCP connection timestamp redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesPointsMCPLabeledTimestampToCard(t *testing.T) {
	for _, tc := range []struct {
		input string
		want  string
	}{
		{
			input: "•\nConnected at: 2026-08-04T07:30:18Z",
			want:  "•\nConnected at: See the exact connection time in the MCP status card.",
		},
		{
			input: "**Connected at:** the recorded time",
			want:  "**Connected at:** See the exact connection time in the MCP status card.",
		},
	} {
		if got := redactOpaqueMachineValues(tc.input); got != tc.want {
			t.Fatalf("MCP labeled timestamp redaction = %q, want %q", got, tc.want)
		}
	}
}

func TestRedactOpaqueMachineValuesPointsMCPCallTimingRowsToCallCard(t *testing.T) {
	input := "以下是 MCP 调用详情：\n\n" +
		"| 字段 | 值 |\n|---|---|\n" +
		"| **服务器** | mcp-server |\n" +
		"| **工具** | `fail_detail` |\n" +
		"| **状态** | failed |\n" +
		"| **开始时间** | `2026-08-09T00:17:33.520418Z` |\n" +
		"| **结束时间** | `2026-08-09T00:17:33.523772Z` |"
	want := "以下是 MCP 调用详情：\n\n" +
		"| 字段 | 值 |\n|---|---|\n" +
		"| **服务器** | mcp-server |\n" +
		"| **工具** | `fail_detail` |\n" +
		"| **状态** | failed |\n" +
		"| **开始时间** | 精确时间见旁边的 MCP 调用卡片。 |\n" +
		"| **结束时间** | 精确时间见旁边的 MCP 调用卡片。 |"
	got := redactOpaqueMachineValues(input)
	if got != want {
		t.Fatalf("MCP call timing table redaction = %q, want %q", got, want)
	}
	if strings.Contains(got, "相应时间") || strings.Contains(got, "2026-08-09T00:17:33") {
		t.Fatalf("MCP call timing table retained a misleading or opaque value: %q", got)
	}
}

func TestTextRedactorPointsMCPCallTimingRowsToCallCardAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| 字段 | 值 |\n|---|---|\n",
		"| **服务器** | mcp-server |\n| **工具** | `fail_detail` |\n",
		"| **状态** | failed |\n| **开始时间** | `2026-08-09T00:17:",
		"33.520418Z` |\n| **结束时间** | `2026-08-09T00:17:33.523772Z` |\n",
	} {
		piece := r.Write(delta)
		for _, forbidden := range []string{"相应时间", "the recorded time", "2026-08-09T00:17:33"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("MCP call timing value leaked after %q: %q", delta, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	final := got.String()
	for _, want := range []string{
		"| **开始时间** | 精确时间见旁边的 MCP 调用卡片。 |",
		"| **结束时间** | 精确时间见旁边的 MCP 调用卡片。 |",
	} {
		if !strings.Contains(final, want) {
			t.Fatalf("streamed MCP call timing table missing %q: %q", want, final)
		}
	}
}

func TestRedactOpaqueMachineValuesDoesNotEmbedPlaceholderInPath(t *testing.T) {
	input := "| 字段 | 值 |\n|---|---|\n| cwd | `/private/tmp/data/workspaces/ws_00112233445566/skills/script-runner` |\n| CLAUDE_SKILL_DIR | `/private/tmp/data/workspaces/ws_00112233445566/skills/script-runner` |"
	want := "| 字段 | 值 |\n|---|---|\n| cwd | See the exact path in the tool card. |\n| CLAUDE_SKILL_DIR | See the exact path in the tool card. |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("path placeholder redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsSkillContextLabelsHonest(t *testing.T) {
	input := "The skill was activated.\nSession: the requested item\nDirectory: /private/tmp/data/workspaces/the requested item/skills/demo\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "/the requested item/"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("skill activation context leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{
		"Session: See the exact session in the activation card.",
		"Directory: See the exact path in the tool card.",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("skill activation context lost %q: %q", want, got)
		}
	}
}

func TestTextRedactorKeepsSkillContextLabelsHonestAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"Session: the requested ",
		"item\nDirectory: /private/tmp/data/workspaces/the requested ",
		"item/skills/demo\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("skill activation context placeholder leaked in stream: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	final := redactOpaqueMachineValues(got.String())
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "/the requested item/"} {
		if strings.Contains(final, forbidden) {
			t.Fatalf("skill activation context placeholder survived close: %q", final)
		}
	}
	if !strings.Contains(final, "Directory: See the exact path in the tool card.") {
		t.Fatalf("skill activation path did not point to the tool card: %q", final)
	}
}

func TestRedactOpaqueMachineValuesKeepsSkillContextTablesTruthful(t *testing.T) {
	input := "以下是激活结果的渲染字段：\n\n" +
		"| 字段 | 渲染值 |\n|---|---|\n" +
		"| **Session** | `the requested item` |\n" +
		"| **Directory** | `/private/tmp/data/workspaces/the requested item/skills/ep111-inline` |\n\n" +
		"以上所有值均从激活工具返回结果中原样引用，未做任何替换或臆造。"
	want := "以下是激活结果的渲染字段：\n\n" +
		"| 字段 | 渲染值 |\n|---|---|\n" +
		"| **Session** | See the exact session in the activation card. |\n" +
		"| **Directory** | See the exact path in the tool card. |\n\n" +
		"可安全展示的人话字段已原样引用；精确的 Session 和 Directory 请查看相邻激活工具卡。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("skill activation table redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsEnglishSkillContextTablesTruthful(t *testing.T) {
	input := "Activation result:\n\n" +
		"| Field | Rendered value |\n|---|---|\n" +
		"| **Session ID** | `the requested item` |\n" +
		"| **Path** | `/private/tmp/data/workspaces/the requested item/skills/demo` |\n\n" +
		"All values below are quoted verbatim from the activation result without substitution or fabrication."
	want := "Activation result:\n\n" +
		"| Field | Rendered value |\n|---|---|\n" +
		"| **Session ID** | See the exact session in the activation card. |\n" +
		"| **Path** | See the exact path in the tool card. |\n\n" +
		"Human-readable fields are quoted above; exact Session and Directory values remain in the adjacent activation card."
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("English skill activation table redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorKeepsSkillContextTableAndTruthClaimHonestAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是激活结果的渲染字段：\n\n",
		"| 字段 | 渲染值 |\n|---|---|\n",
		"| **Session** | `the requested ",
		"item` |\n",
		"| **Directory** | `/private/tmp/data/workspaces/the requested ",
		"item/skills/ep111-inline` |\n\n",
		"以上所有值均从激活工具返回结果中原样引用，未做任何替换或臆造。\n",
	} {
		piece := r.Write(delta)
		for _, forbidden := range []string{
			opaqueEntityPlaceholder,
			legacyEntityPlaceholder,
			"/the requested item/",
			"原样引用，未做任何替换或臆造",
		} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("skill table or false truth claim leaked after %q: %q", delta, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	final := got.String()
	for _, want := range []string{
		"| **Session** | See the exact session in the activation card. |",
		"| **Directory** | See the exact path in the tool card. |",
		"可安全展示的人话字段已原样引用；精确的 Session 和 Directory 请查看相邻激活工具卡。",
	} {
		if !strings.Contains(final, want) {
			t.Fatalf("streamed skill table missing %q: %q", want, final)
		}
	}
}

func TestTextRedactorDoesNotStreamPlaceholderInsidePath(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	input := "| 字段 | 值 |\n|---|---|\n| cwd | `/private/tmp/data/workspaces/ws_00112233445566/skills/script-runner` |\n"
	for _, delta := range []string{input[:len(input)/2], input[len(input)/2:]} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("stream leaked placeholder inside path: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), legacyEntityPlaceholder) {
		t.Fatalf("final stream still contains path placeholder: %q", got.String())
	}
	if !strings.Contains(got.String(), opaquePathTableHint) {
		t.Fatalf("stream did not point to tool card: %q", got.String())
	}
}

func TestTextRedactorDoesNotStreamMCPConnectionTimestampPlaceholder(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| Server | Status | Connected at |\n|---|---|---|\n| context7 | ready | 2026-08-04T07:",
		"30:18Z |",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueTimestampPlaceholder) {
			t.Fatalf("stream leaked timestamp placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "2026-08-04T07:30:18Z") || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("stream leaked exact or vague timestamp: %q", got.String())
	}
	if !strings.Contains(got.String(), mcpConnectionTimestampTableHint) {
		t.Fatalf("stream did not point to MCP status card: %q", got.String())
	}
}

func TestTextRedactorDoesNotStreamMCPLabeledTimestampPlaceholder(t *testing.T) {
	for _, deltas := range [][]string{
		{"Connected at: 2026-08-04T07:", "30:18Z\n"},
		{"**Connected a", "t:** the recorded time\n"},
	} {
		var r textRedactor
		var got strings.Builder
		for _, delta := range deltas {
			piece := r.Write(delta)
			if strings.Contains(piece, opaqueTimestampPlaceholder) {
				t.Fatalf("stream leaked timestamp placeholder: %q", piece)
			}
			got.WriteString(piece)
		}
		got.WriteString(r.Flush())
		if strings.Contains(got.String(), "2026-08-04T07:30:18Z") || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
			t.Fatalf("stream leaked exact or vague timestamp: %q", got.String())
		}
		if !strings.Contains(got.String(), mcpConnectionTimestampTableHint) {
			t.Fatalf("stream did not point to MCP status card: %q", got.String())
		}
	}
}

func TestRedactOpaqueMachineValuesRemovesRedundantEntityParenthetical(t *testing.T) {
	for _, input := range []string{
		"The workflow nightly (wf_00112233445566) is staged.",
		"The workflow nightly (`wf_00112233445566`) is staged.",
	} {
		want := "The workflow nightly is staged."
		if got := redactOpaqueMachineValues(input); got != want {
			t.Fatalf("parenthetical entity redaction = %q, want %q", got, want)
		}
	}

	input := "The workflow is wf_00112233445566."
	want := "The workflow is the requested item."
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("standalone entity redaction = %q, want %q", got, want)
	}

	for _, input := range []string{
		"The workflow nightly (the referenced item) is staged.",
		"The workflow nightly (`the referenced item`) is staged.",
	} {
		want := "The workflow nightly is staged."
		if got := redactOpaqueMachineValues(input); got != want {
			t.Fatalf("placeholder parenthetical redaction = %q, want %q", got, want)
		}
	}
}

func TestRedactOpaqueMachineValuesRemovesIDPlaceholderParenthetical(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{
			input: "Agent **EP031 Planner** created (id `the requested item`) with description \"Break tasks into executable steps\".",
			want:  "Agent **EP031 Planner** created with description \"Break tasks into executable steps\".",
		},
		{
			input: "Agent created (IDENTIFIER: the referenced item) and is ready.",
			want:  "Agent created and is ready.",
		},
	}
	for _, tt := range tests {
		if got := redactOpaqueMachineValues(tt.input); got != tt.want {
			t.Fatalf("ID placeholder parenthetical redaction = %q, want %q", got, tt.want)
		}
	}
}

func TestTextRedactorDoesNotStreamIDPlaceholderParenthetical(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"Created agent **EP",
		"03",
		"1 Planner** (",
		"id:",
		" ag_78",
		"67c9",
		"0",
		"42fb8",
		"4",
		"b3a)",
		" with tags",
		" [acceptance,",
		" planner",
		"]. No tools,",
		" skill, knowledge,",
		" or model override configured",
		".",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("stream leaked ID placeholder parenthetical: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), legacyEntityPlaceholder) {
		t.Fatalf("flush leaked ID placeholder parenthetical: %q", got.String())
	}
	if !strings.Contains(got.String(), "Planner** with tags") {
		t.Fatalf("stream lost the human sentence after redaction: %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesRemovesMediaIDFromMixedParenthetical(t *testing.T) {
	input := "The original attachment (red circle, `att_00112233445566`) and the edited attachment (blue circle, `att_ffeeddccbbaa99`) are distinct."
	want := "The original attachment (red circle) and the edited attachment (blue circle) are distinct."
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("media parenthetical redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsMediaReasoningReadable(t *testing.T) {
	input := "The attachment ID is `att_00112233445566`. The original attachment is att_00112233445566 and the edited one is att_ffeeddccbbaa99."
	want := "The attachment is ready. The original attachment is ready and the edited one is ready."
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("media reasoning redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesRemovesUnavailableMediaIDTableRow(t *testing.T) {
	input := "海报已生成，以下是附件元数据：\n\n" +
		"| 字段 | 值 |\n|------|------|\n" +
		"| **attachmentId** | att_00112233445566 |\n" +
		"| 文件名 | `generated.png` |\n" +
		"| MIME 类型 | `image/png` |"
	want := "海报已生成，以下是附件元数据：\n\n" +
		"| 字段 | 值 |\n|------|------|\n" +
		"| 文件名 | `generated.png` |\n" +
		"| MIME 类型 | `image/png` |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("media ID table row redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRemovesUnavailableMediaIDTableRowAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	for _, delta := range []string{
		"海报已生成，以下是附件元数据：\n\n| 字段 | 值 |\n|------|------|\n",
		"| **attachmentId** | att_001122",
		"33445566 |\n| 文件名 | `generated.png` |\n| MIME 类型 | `image/png` |",
	} {
		got += r.Write(delta)
	}
	got += r.Flush()
	want := "海报已生成，以下是附件元数据：\n\n| 字段 | 值 |\n|------|------|\n| 文件名 | `generated.png` |\n| MIME 类型 | `image/png` |"
	if got != want {
		t.Fatalf("stream media ID table row redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsNameAfterPositionID(t *testing.T) {
	cases := map[string]string{
		"- Position 0: `doc_00112233445566` (Existing First)": "- Position 0: Existing First",
		"- Position 1: the requested item (Existing Last)":    "- Position 1: Existing Last",
	}
	for input, want := range cases {
		if got := redactOpaqueMachineValues(input); got != want {
			t.Fatalf("position name redaction = %q, want %q", got, want)
		}
	}
}

func TestTextRedactorKeepsPositionNameAfterSplitID(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"- Position 0: `doc_001122",
		"33445566` (Existing First)\n",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	if got.String() != "- Position 0: Existing First\n" {
		t.Fatalf("stream position name redaction = %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesDoesNotDuplicateEntityNoun(t *testing.T) {
	for _, input := range []string{
		"The workflow wf_00112233445566 remains intact.",
		"The workflow the referenced item remains intact.",
		"The function fn_00112233445566 completed.",
	} {
		got := redactOpaqueMachineValues(input)
		if strings.Contains(got, "the referenced item") {
			t.Fatalf("entity noun should not be duplicated: input=%q got=%q", input, got)
		}
	}
	if got := redactOpaqueMachineValues("The workflow wf_00112233445566 remains intact."); got != "The workflow remains intact." {
		t.Fatalf("entity noun cleanup = %q", got)
	}
	if got := redactOpaqueMachineValues("The workflow **wf_00112233445566** remains intact."); got != "The workflow remains intact." {
		t.Fatalf("decorated entity noun cleanup = %q", got)
	}
	if got := redactOpaqueMachineValues("Workflow `the referenced item` remains intact."); got != "Workflow remains intact." {
		t.Fatalf("backtick entity noun cleanup = %q", got)
	}
}

func TestRedactOpaqueMachineValuesCleansChineseTypedEntityPlaceholder(t *testing.T) {
	for _, input := range []string{
		"producer（函数 the requested item）的输出未声明。",
		"producer (function the requested item) has an advisory warning.",
		"函数 the requested item 的输出未声明。",
	} {
		got := redactOpaqueMachineValues(input)
		if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
			t.Fatalf("typed entity placeholder leaked: input=%q got=%q", input, got)
		}
	}
}

func TestRedactOpaqueMachineValuesRemovesUnavailableIDColumn(t *testing.T) {
	input := "| Document | Path | ID |\n|---|---|---|\n| **Release Atlas** | `/Release Atlas` | `the requested item` |\n| **Ship Checklist** | `/Release Atlas/Ship Checklist` | `the requested item` |"
	want := "| Document | Path |\n| --- | --- |\n| **Release Atlas** | `/Release Atlas` |\n| **Ship Checklist** | `/Release Atlas/Ship Checklist` |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("unavailable ID column redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsOrdinaryEmptyTableCells(t *testing.T) {
	input := "| Name | State | Notes |\n|---|---|---|\n| Release Atlas | active |  |"
	if got := redactOpaqueMachineValues(input); got != input {
		t.Fatalf("ordinary empty table cell changed: got %q, want %q", got, input)
	}
}

func TestRedactOpaqueMachineValuesRemovesPlaceholderLabeledField(t *testing.T) {
	input := "Ship Checklist\n- Path: /Release Atlas/Ship Checklist\n- ID: the requested item\n- Description: Release gates to run"
	want := "Ship Checklist\n- Path: /Release Atlas/Ship Checklist\n- Description: Release gates to run"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("placeholder labeled field redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesRemovesBoldColonPlaceholderLabeledField(t *testing.T) {
	input := "Handler **ep014compat** has been created successfully:\n\n- **ID:** `the requested item`\n- **Python:** 3.12\n- **Status:** ready (v1)"
	want := "Handler **ep014compat** has been created successfully:\n\n- **Python:** 3.12\n- **Status:** ready (v1)"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("bold-colon placeholder labeled field redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorDoesNotStreamBoldColonPlaceholderLabeledField(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"Handler **ep014compat** has been created successfully:\n\n- **ID:",
		"** `the requested ",
		"item`\n- **Python:** 3.12\n- **Status:** ready (v1)",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "the requested item") || strings.Contains(piece, "**ID:") {
			t.Fatalf("stream leaked bold-colon placeholder labeled field: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "the requested item") || strings.Contains(got.String(), "**ID:") {
		t.Fatalf("flush leaked bold-colon placeholder labeled field: %q", got.String())
	}
	if !strings.Contains(got.String(), "**Python:** 3.12") || !strings.Contains(got.String(), "**Status:** ready (v1)") {
		t.Fatalf("stream redaction lost neighboring fields: %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesRemovesUnavailableIDRowFromFieldTable(t *testing.T) {
	input := "| **Field** | **Value** |\n|---|---|\n| **Name** | `convertcelsiustofahrenheit` |\n| **ID** | `the requested item` |\n| **Version** | 1 |"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "the requested item") || strings.Contains(got, "**ID**") {
		t.Fatalf("unavailable ID row leaked: %q", got)
	}
	if !strings.Contains(got, "**Name**") || !strings.Contains(got, "**Version**") {
		t.Fatalf("neighboring fields were lost: %q", got)
	}
	if strings.Contains(got, "|---|---|\n\n") {
		t.Fatalf("redaction split the Markdown table with an empty row: %q", got)
	}
}

func TestTextRedactorDoesNotStreamUnavailableIDRow(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| **Field** | **Value** |\n|---|---|\n| **Name** | `convertcelsiustofahrenheit` |\n",
		"| **ID** | `the requested ",
		"item` |\n| **Version** | 1 |",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "the requested item") || strings.Contains(piece, "**ID**") {
			t.Fatalf("stream leaked unavailable ID row: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "the requested item") || strings.Contains(got.String(), "**ID**") {
		t.Fatalf("flush leaked unavailable ID row: %q", got.String())
	}
	if !strings.Contains(got.String(), "**Name**") || !strings.Contains(got.String(), "**Version**") {
		t.Fatalf("stream redaction lost neighboring fields: %q", got.String())
	}
	if strings.Contains(got.String(), "|---|---|\n\n") {
		t.Fatalf("stream redaction split the Markdown table with an empty row: %q", got.String())
	}
}

func TestTextRedactorNeverStreamsPlaceholderLabeledField(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"Ship Checklist\n- ID: the requested",
		" item\n- Description: Release gates to run",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "the requested item") || strings.Contains(piece, "the referenced item") {
			t.Fatalf("stream leaked labeled placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "the requested item") || strings.Contains(got.String(), "the referenced item") {
		t.Fatalf("flush leaked labeled placeholder: %q", got.String())
	}
	if !strings.Contains(got.String(), "Description: Release gates to run") {
		t.Fatalf("redaction removed neighboring field: %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesKeepsEntitySearchReasoningFluent(t *testing.T) {
	input := "I found the document \"Edit Atlas\" with id \"doc_00112233445566aa\".\n- `doc_00112233445566aa` — \"Edit Atlas\" at path `/Edit Atlas`"
	want := "I found the document \"Edit Atlas\".\n- \"Edit Atlas\" at path `/Edit Atlas`"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("entity search reasoning redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesMakesSearchRefsActionable(t *testing.T) {
	input := "这些 ref（如 `ag_00112233445566aa`、`hd_00112233445566aa.place`、`mcp:searchblocks115/route_order`）可以直接用于 workflow 节点中引用对应的构建块。如需查看某个块的详细配置，告诉我即可。"
	want := "这些可接线 ref 的精确值见相邻 search_blocks 结果卡，可直接复制到 workflow 节点。如需查看某个块的详细配置，告诉我即可。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("search ref prose = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesMakesAbbreviatedSearchRefsActionable(t *testing.T) {
	input := "handler 同时以实体级 ref（`hd_…`）和方法级 ref（`hd_….place` / `hd_….cancel`）出现，workflow 节点可按需引用整体或具体方法。"
	want := "这些可接线 ref 的精确值见相邻 search_blocks 结果卡，可直接复制到 workflow 节点。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("abbreviated search ref prose = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesMakesTemplateSearchRefsActionable(t *testing.T) {
	input := "handler 的方法级块（`order_desk.place`、`order_desk.cancel`）以 hd_<id>.<method> 形式返回，workflow 节点可按需引用。"
	want := "这些可接线 ref 的精确值见相邻 search_blocks 结果卡，可直接复制到 workflow 节点。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("template search ref prose = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesMakesSearchBlocksSummaryActionable(t *testing.T) {
	input := "**汇总：**\n- **agent** ×1：`the requested item`（报表助手）\n- **function** ×2：`the requested item`（sync_inventory）、`the requested item`（greet）\n- **handler** ×3：`the requested item`（order_desk）及其两个方法 `.place` / `.cancel`"
	want := "**汇总：**\n- **agent** ×1：精确 ref 见相邻 search_blocks 结果卡（报表助手）\n- **function** ×2：精确 ref 见相邻 search_blocks 结果卡（sync_inventory）、精确 ref 见相邻 search_blocks 结果卡（greet）\n- **handler** ×3：精确 ref 见相邻 search_blocks 结果卡（order_desk）及其两个方法 `.place` / `.cancel`"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("search_blocks summary = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsSearchBlocksRefTableActionable(t *testing.T) {
	input := "| # | ref | kind | name | snippet |\n|---|---|---|---|---|\n| 1 | `ag_00112233445566aa` | agent | 报表助手 | 整理周报 |\n| 2 | `hd_00112233445566aa.place` | handler | order_desk.place | 下单方法 |\n| 3 | `mcp:searchblocks115/route_order` | mcp tool | route_order | Route an order |"
	want := "| # | ref | kind | name | snippet |\n|---|---|---|---|---|\n| 1 | See the exact ref in the search_blocks result card. | agent | 报表助手 | 整理周报 |\n| 2 | See the exact ref in the search_blocks result card. | handler | order_desk.place | 下单方法 |\n| 3 | See the exact ref in the search_blocks result card. | mcp tool | route_order | Route an order |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("search_blocks ref table = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesDoesNotConfuseSearchBlocksTableWithFlowrun(t *testing.T) {
	input := "| # | ref | kind | name | snippet |\n|---|---|---|---|---|\n| 1 | the requested item | agent | 报表助手 | 整理周报 |"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "See the run card") {
		t.Fatalf("search_blocks ref table was mislabeled as a flowrun row: %q", got)
	}
	if !strings.Contains(got, "See the exact ref in the search_blocks result card.") {
		t.Fatalf("search_blocks ref table lost its actionable hint: %q", got)
	}
}

func TestRedactOpaqueMachineValuesKeepsSearchBlocksPropertyRefActionable(t *testing.T) {
	input := "### 推荐：函数 `sync_inventory`\n\n| 属性 | 值 |\n|---|---|\n| **类型** | Function（无状态函数） |\n| **引用 ID** | `fn_8e51db58507888aa` |\n| **描述** | 同步库存快照 |"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "这个输入") || strings.Contains(got, "fn_8e51db58507888aa") {
		t.Fatalf("search_blocks property table leaked an unavailable ref: %q", got)
	}
	if !strings.Contains(got, "精确 ref 见相邻 search_blocks 结果卡，可直接复制。") {
		t.Fatalf("search_blocks property table lost its actionable hint: %q", got)
	}
}

func TestTextRedactorKeepsSearchBlocksPropertyRefActionableAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"### 推荐：函数 `sync_inventory`\n\n| 属性 | 值 |\n|---|---|\n| **类型** | Function（无状态函数） |\n| **引用 ID** | `fn_8e51",
		"db58507888aa` |\n| **描述** | 同步库存快照 |",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "这个输入") || strings.Contains(piece, "fn_8e51db58507888aa") {
			t.Fatalf("stream leaked search_blocks property ref: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "这个输入") || strings.Contains(got.String(), "fn_8e51db58507888aa") {
		t.Fatalf("flushed stream leaked search_blocks property ref: %q", got.String())
	}
	if !strings.Contains(got.String(), "精确 ref 见相邻 search_blocks 结果卡，可直接复制。") {
		t.Fatalf("stream search_blocks property table lost its actionable hint: %q", got.String())
	}
}

func TestTextRedactorKeepsSearchRefsActionableAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"这些 ref（如 `ag_00112233445566aa`、`hd_00112233445566aa.",
		"place`、`mcp:searchblocks115/route_order`）可以直接用于 workflow 节点中引用对应的构建块。",
		"如需查看某个块的详细配置，告诉我即可。",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	want := "这些可接线 ref 的精确值见相邻 search_blocks 结果卡，可直接复制到 workflow 节点。如需查看某个块的详细配置，告诉我即可。"
	if got.String() != want {
		t.Fatalf("stream search ref prose = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorKeepsSearchBlocksSummaryActionableAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"**汇总：**\n- **",
		"agent** ×",
		"1：`the requested",
		" item`（报表助手）\n- **function** ×2：`the requested item`（sync_inventory）、`the requested item`（greet）\n- **handler** ×3：`the requested item`（order_desk）及其两个方法 `.place` / `.cancel`\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("stream leaked search_blocks summary placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "**汇总：**\n- **agent** ×1：精确 ref 见相邻 search_blocks 结果卡（报表助手）\n- **function** ×2：精确 ref 见相邻 search_blocks 结果卡（sync_inventory）、精确 ref 见相邻 search_blocks 结果卡（greet）\n- **handler** ×3：精确 ref 见相邻 search_blocks 结果卡（order_desk）及其两个方法 `.place` / `.cancel`\n"
	if got.String() != want {
		t.Fatalf("stream search_blocks summary = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorKeepsEntitySearchReasoningFluentAcrossChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"I found the document \"Edit Atlas\" with id \"doc_001122",
		"33445566aa\".\n- `doc_00112233445566aa` — \"Edit Atlas\" at path `/Edit Atlas`",
	} {
		got.WriteString(r.Write(delta))
	}
	got.WriteString(r.Flush())
	want := "I found the document \"Edit Atlas\".\n- \"Edit Atlas\" at path `/Edit Atlas`"
	if got.String() != want {
		t.Fatalf("stream entity search reasoning redaction = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorNeverStreamsUnavailableIDPlaceholder(t *testing.T) {
	var r textRedactor
	for _, delta := range []string{
		"| Document | Path | ID |\n",
		"|---|---|---|\n",
		"| **Release Atlas** | `/Release Atlas` | `the requested",
		" item` |\n",
		"| **Ship Checklist** | `/Release Atlas/Ship Checklist` | `the requested item` |\n",
	} {
		if piece := r.Write(delta); strings.Contains(piece, "the requested item") || strings.Contains(piece, "the referenced item") {
			t.Fatalf("stream leaked redaction placeholder: %q", piece)
		}
	}
	if piece := r.Flush(); strings.Contains(piece, "the requested item") || strings.Contains(piece, "the referenced item") {
		t.Fatalf("flush leaked redaction placeholder: %q", piece)
	}
}

func TestRedactOpaqueMachineValuesHidesTriggerIDs(t *testing.T) {
	input := "The trigger trg_00112233445566 is live."
	want := "The trigger is live."
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("trigger ID redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesMakesWebhookEndpointHonest(t *testing.T) {
	input := "Once active:\n\n```\nPOST /api/v1/webhooks/trg_00112233445566/acceptance-077-hook\n```"
	want := "Once active:\n\n```\nSee the exact webhook endpoint in the trigger card.\n```"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("webhook endpoint redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesPointsTriggerIDToCard(t *testing.T) {
	for _, input := range []string{
		"**Trigger ID:** `the requested item`",
		"**Trigger ID：** `the requested item`",
		"**触发器 ID：** `the requested item`",
		"| **Trigger ID** | `the requested item` |",
	} {
		got := redactOpaqueMachineValues(input)
		if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "trg_") {
			t.Fatalf("trigger ID placeholder leaked for %q: %q", input, got)
		}
		if containsHan(input) {
			if got != "精确触发器 ID 见旁边的触发器卡片。" {
				t.Fatalf("Chinese trigger ID guidance = %q", got)
			}
		} else if strings.HasPrefix(input, "|") {
			if got != "| **Trigger ID** | See the exact trigger ID in the adjacent trigger card. |" {
				t.Fatalf("English trigger ID table guidance = %q", got)
			}
		} else if got != "See the exact trigger ID in the adjacent trigger card." {
			t.Fatalf("English trigger ID guidance = %q", got)
		}
	}
}

func TestTextRedactorPointsTriggerIDTableToCardAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"| **Trigger ID** | `the requested",
		" item` |\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "trg_") {
			t.Fatalf("stream leaked trigger ID table placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "| **Trigger ID** | See the exact trigger ID in the adjacent trigger card. |\n"
	if got.String() != want {
		t.Fatalf("stream trigger ID table guidance = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorPointsTriggerIDToCardAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"**Trigger ID：** `the requested",
		" item`",
		"\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "trg_") {
			t.Fatalf("stream leaked trigger ID placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if got.String() != "See the exact trigger ID in the adjacent trigger card.\n" {
		t.Fatalf("stream trigger ID guidance = %q", got.String())
	}
}

func TestTextRedactorHidesWebhookEndpointAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"Once active:\n\n```\nPOST /api/v1/webhooks/",
		"trg_00112233445566/acceptance-077-hook",
		"\n```",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "/api/v1/webhooks/") || strings.Contains(piece, "trg_") {
			t.Fatalf("stream leaked executable webhook endpoint in intermediate piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	want := "Once active:\n\n```\nSee the exact webhook endpoint in the trigger card.\n```"
	if got.String() != want {
		t.Fatalf("stream webhook endpoint redaction = %q, want %q", got.String(), want)
	}
}

func TestTextRedactorHidesTriggerIDsAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"The trigger ",
		"trg_001122334455",
		"66 is live.",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "trg_") {
			t.Fatalf("stream leaked trigger ID in intermediate piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "trg_") {
		t.Fatalf("stream leaked trigger ID after flush: %q", got.String())
	}
	if got.String() != "The trigger is live." {
		t.Fatalf("stream trigger redaction = %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesKeepsOpaqueIDSentenceGrammatical(t *testing.T) {
	for _, input := range []string{
		"The ID fr_00112233445566 does not correspond to any existing flowrun.",
		"The ID `fr_00112233445566` does not correspond to any existing flowrun.",
	} {
		want := "The requested item does not correspond to any existing flowrun."
		if got := redactOpaqueMachineValues(input); got != want {
			t.Fatalf("opaque ID subject redaction = %q, want %q", got, want)
		}
	}
}

func TestTextRedactorKeepsOpaqueIDSentenceGrammaticalAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The ID `fr_001122334455")
	got += r.Write("66` does not correspond to any existing flowrun.")
	got += r.Flush()

	want := "The requested item does not correspond to any existing flowrun."
	if got != want {
		t.Fatalf("stream opaque ID subject redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesRewritesTypedOpaqueIDSubject(t *testing.T) {
	for _, input := range []string{
		"The flowrun with ID fr_00112233445566 was not found.",
		"The flowrun with ID `fr_00112233445566` was not found.",
		"The flowrun ID fr_00112233445566 was not found.",
		"The flowrun ID `fr_00112233445566` was not found.",
		"The flow run ID fr_00112233445566 was not found.",
		"The flow run ID `fr_00112233445566` was not found.",
	} {
		want := "The requested flowrun was not found."
		if strings.Contains(input, "flow run") {
			want = "The requested flow run was not found."
		}
		if got := redactOpaqueMachineValues(input); got != want {
			t.Fatalf("typed opaque ID subject redaction = %q, want %q", got, want)
		}
	}
}

func TestTextRedactorRewritesTypedOpaqueIDSubjectAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The flowrun with ID `fr_001122334455")
	got += r.Write("66` was not found.")
	got += r.Flush()

	want := "The requested flowrun was not found."
	if got != want {
		t.Fatalf("stream typed opaque ID subject redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRewritesBareTypedOpaqueIDSubjectAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The flowrun ID `fr_001122334455")
	got += r.Write("66` was not found.")
	got += r.Flush()

	want := "The requested flowrun was not found."
	if got != want {
		t.Fatalf("stream bare typed opaque ID subject redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRewritesFlowRunIDWithoutMatchingOnlyRun(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The flow run ID `fr_001122334455")
	got += r.Write("66` does not exist.")
	got += r.Flush()

	want := "The requested flow run does not exist."
	if got != want {
		t.Fatalf("flow run noun redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRewritesFlowRunIDWhenCompoundNounSplitsEarly(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The flow ")
	got += r.Write("run with ID `fr_001122334455")
	got += r.Write("66` does not exist.")
	got += r.Flush()

	want := "The requested flow run does not exist."
	if got != want {
		t.Fatalf("early-split flow run noun redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesRemovesRedundantReportTarget(t *testing.T) {
	for _, input := range []string{
		"Here's the flowrun report for fr_00112233445566:",
		"Here's the flowrun report for `fr_00112233445566`:",
		"Here's the flowrun report for **`fr_00112233445566`**:",
	} {
		want := "Here's the flowrun report:"
		if got := redactOpaqueMachineValues(input); got != want {
			t.Fatalf("report target redaction = %q, want %q", got, want)
		}
	}
}

func TestRedactOpaqueMachineValuesKeepsFlowrunReportCraft(t *testing.T) {
	input := "## Flowrun: `fr_00112233445566`\n| **Version** | `wfv_c29a9d1dfaaef740` |\n| **Pinned Refs** | `apf_00112233445566` -> `apfv_00112233445566` |\nPinned reference: One pinned ref is present — function pinned to version `fnv_867a899febe1637a`.\nTo unblock it, use flowrunId = `fr_00112233445566`."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the referenced item", "fr_", "wfv_", "apf_", "apfv_", "flowrunId ="} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("report craft still exposes %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"## Flowrun", "| **Version** | Current version |", "| **References** | Internal references |", "Pinned reference: The function version is pinned.", "the current run"} {
		if !strings.Contains(got, want) {
			t.Fatalf("report craft missing %q in %q", want, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunSummaryAndPinnedVersion(t *testing.T) {
	input := "Run summary for the requested item:\n\nPinned reference: One pinned ref is present — function pinned to version fnv_867a899febe1637a."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "fnv_"} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("flowrun summary leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"Run summary:", "Pinned reference: The function version is pinned."} {
		if !strings.Contains(got, want) {
			t.Fatalf("flowrun summary semantic replacement missing %q in %q", want, got)
		}
	}
}

func TestTextRedactorCleansFlowrunSummaryAndPinnedVersionAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("Run summary for the ")
	got += r.Write("requested item:\n\nPinned reference: One pinned ref is present — function pinned to version fnv_")
	got += r.Write("867a899febe1637a.\n")
	got += r.Flush()
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "fnv_"} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("stream flowrun summary leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "Run summary:\n\nPinned reference: The function version is pinned.\n") {
		t.Fatalf("stream flowrun summary semantic replacement = %q", got)
	}
}

func TestRedactOpaqueMachineValuesCleansPreRedactedFlowrunPlaceholders(t *testing.T) {
	input := "## Flowrun: `the referenced item`\n| **Flowrun ID** | `the referenced item` |\n| **Version** | `the referenced item` |\n| **Node Record ID** | `the referenced item` |\n| **Ref** | `the referenced item` |\n**Pinned Refs:**\n- Approval form `the referenced item` -> version `the referenced item`\nTo unblock it, use flowrunId = the referenced item."
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, opaqueEntityPlaceholder) {
		t.Fatalf("pre-redacted placeholder leaked: %q", got)
	}
	for _, want := range []string{"## Flowrun", "| **Run** | Current run |", "| **Version** | Current version |", "| **Node record** | Internal record |", "| **Ref** | Internal reference |", "**References:** Internal references", "- Internal approval references", "the current run"} {
		if !strings.Contains(got, want) {
			t.Fatalf("pre-redacted semantic replacement missing %q in %q", want, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansCurrentFlowrunReportPlaceholders(t *testing.T) {
	input := "## Flowrun Report: `the requested item`\n| **Flowrun ID** | `the requested item` |\n| **Workflow Version** | `the requested item` |\n### Pinned References\n| Entity | Pinned Version |\n| `the requested item` (approval form) | `the requested item` |\n| **Node Record ID** | `the requested item` |"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("current flowrun report placeholder leaked: %q", got)
	}
}

func TestRedactOpaqueMachineValuesMakesSearchRunRowsDistinctAndActionable(t *testing.T) {
	input := "| # | Run ID | Workflow | Status | Started |\n|---|---|---|---|---|\n| 1 | `the requested item` | **failed_workflow** | ❌ Failed | 20:09:40 |\n| 2 | `the requested item` | **completed_workflow** | ✅ Completed | 20:09:41 |"
	got := redactOpaqueMachineValues(input)
	for _, want := range []string{
		"| 1 | See the run card | **failed_workflow** | ❌ Failed | 20:09:40 |",
		"| 2 | See the run card | **completed_workflow** | ✅ Completed | 20:09:41 |",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("search run row must point to the exact adjacent card, missing %q in %q", want, got)
		}
	}
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("search run rows leaked a placeholder: %q", got)
	}
}

func TestRedactOpaqueMachineValuesLocalizesChineseSearchRunList(t *testing.T) {
	input := "查询到 5 条工作流运行记录：\n\n1. the requested item - running状态\n2. the requested item - failed状态（有错误信息）\n\n- `the requested item` - 工作流 `the requested item`，开始于 20:05:41"
	got := redactOpaqueMachineValues(input)
	for _, want := range []string{
		"1. 该运行记录 - running状态",
		"2. 该运行记录 - failed状态（有错误信息）",
		"- 该运行 - 该工作流，开始于 20:05:41",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("Chinese search list must remain natural, missing %q in %q", want, got)
		}
	}
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("Chinese search list leaked a placeholder: %q", got)
	}
}

func TestRedactOpaqueMachineValuesRemovesPlaceholderOnlyStatusDetails(t *testing.T) {
	input := "- running: 1 (the requested item - tool071_approval)\n- failed: 1 (the requested item - tool071_failed)\n- completed: 3 (the requested item, the requested item, the requested item - all tool071_completed)"
	want := "- running: 1 (tool071_approval)\n- failed: 1 (tool071_failed)\n- completed: 3 (all tool071_completed)"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("placeholder-only status details = %q, want %q", got, want)
	}
}

func TestTextRedactorHandlesUnicodeBeforeHeldEntityPrefix(t *testing.T) {
	var r textRedactor
	_ = r.Write("失败摘要：\n• the workflow ")
	_ = r.Write("fr_1234567890abcdef")
	_ = r.Flush()
}

func TestTextRedactorHoldsStatusPlaceholderUntilLineCompletes(t *testing.T) {
	var r textRedactor
	if got := r.Write("- running: 1 (the requested item - tool071_approval"); got != "" {
		t.Fatalf("status placeholder leaked before line completion: %q", got)
	}
	if got := r.Write(")\n"); got != "- running: 1 (tool071_approval)\n" {
		t.Fatalf("completed status line = %q", got)
	}
}

func TestRedactOpaqueMachineValuesCleansAnnotatedPinnedReference(t *testing.T) {
	input := "| `the requested item` (approval form) | `the requested item` |"
	want := "| Internal approval reference | Current version |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("annotated pinned reference redaction = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunOverviewSemantics(t *testing.T) {
	input := "Flowrun overview:\n- ID: the requested item\n- Version: `the requested item`\n\n**Pinned Refs:** Approval form `the requested item` pinned to version `the requested item`."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("flowrun overview placeholder leaked: %q", got)
		}
	}
	for _, want := range []string{"- Run: Current run", "- Version: Current version", "**References:** Internal approval reference is pinned to the current version."} {
		if !strings.Contains(got, want) {
			t.Fatalf("flowrun overview semantic replacement missing %q in %q", want, got)
		}
	}
}

func TestTextRedactorHoldsAnnotatedPinnedReferenceUntilRowCompletes(t *testing.T) {
	var r textRedactor
	var pieces []string
	pieces = append(pieces, r.Write("| `the requested item` (approval form) | `"))
	pieces = append(pieces, r.Write("the requested item` |\n"))
	pieces = append(pieces, r.Flush())

	var got strings.Builder
	for _, piece := range pieces {
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("placeholder leaked in streaming piece %q", piece)
		}
		got.WriteString(piece)
	}
	if got.String() != "| Internal approval reference | Current version |\n" {
		t.Fatalf("stream annotated pinned reference redaction = %q", got.String())
	}
}

func TestTextRedactorHoldsFlowrunStructuredLinesUntilComplete(t *testing.T) {
	var r textRedactor
	var pieces []string
	pieces = append(pieces, r.Write("## Flowrun Report: `"))
	pieces = append(pieces, r.Write("the requested item`\n"))
	pieces = append(pieces, r.Write("| **Workflow Version** | `"))
	pieces = append(pieces, r.Write("the requested item` |\n"))
	pieces = append(pieces, r.Write("**Pinned Refs:** Approval form `"))
	pieces = append(pieces, r.Write("the requested item` pinned to version `"))
	pieces = append(pieces, r.Write("the requested item`.\n"))
	pieces = append(pieces, r.Flush())

	var got strings.Builder
	for _, piece := range pieces {
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("flowrun structured placeholder leaked in streaming piece %q", piece)
		}
		got.WriteString(piece)
	}
	for _, want := range []string{"## Flowrun Report", "| **Version** | Current version |", "**References:** Internal approval reference is pinned to the current version."} {
		if !strings.Contains(got.String(), want) {
			t.Fatalf("stream flowrun semantic replacement missing %q in %q", want, got.String())
		}
	}
}

func TestTextRedactorHoldsTablePrefixBeforeOpaqueValue(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("| **Version**")
	got += r.Write(" | `the requested item` |\n")
	got += r.Flush()

	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("table prefix allowed placeholder to leak: %q", got)
	}
	if got != "| **Version** | Current version |\n" {
		t.Fatalf("stream table redaction = %q", got)
	}
}

func TestTextRedactorCleansFlowrunProseAndPinnedBulletAcrossChunks(t *testing.T) {
	var r textRedactor
	var pieces []string
	pieces = append(pieces, r.Write("Here is the complete flowrun report for **"))
	pieces = append(pieces, r.Write("the requested item**:\n"))
	pieces = append(pieces, r.Write("- `the requested item` → `"))
	pieces = append(pieces, r.Write("the requested item`\n"))
	pieces = append(pieces, r.Flush())

	var got strings.Builder
	for _, piece := range pieces {
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("flowrun prose placeholder leaked in streaming piece %q", piece)
		}
		got.WriteString(piece)
	}
	for _, want := range []string{"Here is the complete flowrun report:", "- Internal approval references"} {
		if !strings.Contains(got.String(), want) {
			t.Fatalf("stream flowrun prose replacement missing %q in %q", want, got.String())
		}
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunFailureReport(t *testing.T) {
	input := "**Flowrun ID:** `the requested item`\n\nThe requested item does not correspond to any flowrun in this workspace."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("flowrun failure placeholder leaked: %q", got)
		}
	}
	for _, want := range []string{"**Requested ID:** Supplied run ID", "The supplied run ID does not correspond to any flowrun in this workspace."} {
		if !strings.Contains(got, want) {
			t.Fatalf("flowrun failure semantic replacement missing %q in %q", want, got)
		}
	}
}

func TestTextRedactorCleansFlowrunFailureReportAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("**Flowrun ID:** `")
	got += r.Write("the requested item`\n\nThe requested item")
	got += r.Write(" does not correspond to any flowrun in this workspace.\n")
	got += r.Flush()
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("flowrun failure placeholder leaked across chunks: %q", got)
	}
	for _, want := range []string{"**Requested ID:** Supplied run ID", "The supplied run ID does not correspond to any flowrun in this workspace."} {
		if !strings.Contains(got, want) {
			t.Fatalf("stream flowrun failure replacement missing %q in %q", want, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansObservedFlowrunFailureLanguage(t *testing.T) {
	input := "The call to `get_flowrun` with flowrunId: the requested item failed with an error.\n\nWhat this means\n- The requested item doesn't correspond to any actual run in this workspace.\n- Find the actual fr_... ID you need."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "flowrunId:", "fr_..."} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("observed flowrun failure language leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"The run lookup for the supplied run failed", "The supplied run ID does not correspond to any flowrun", "Find the run ID you need."} {
		if !strings.Contains(got, want) {
			t.Fatalf("observed flowrun semantic replacement missing %q in %q", want, got)
		}
	}
}

func TestTextRedactorCleansObservedFlowrunFailureLanguageAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The call to `get_flowrun` with flowrunId: the requested")
	got += r.Write(" item failed with an error.\n\nWhat this means\n- The requested item")
	got += r.Write(" doesn't correspond to any actual run in this workspace.\n- Find the actual fr_")
	got += r.Write("... ID you need.\n")
	got += r.Flush()
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "flowrunId:", "fr_..."} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("observed flowrun placeholder leaked across chunks %q: %q", forbidden, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunFailureFragments(t *testing.T) {
	input := "The get_flowrun call failed because no workflow run exists with the requested item in this workspace.\nThe requested item is all zeroes after the run ID prefix."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"get_flowrun", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("flowrun failure fragment leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"The run lookup failed", "for the supplied run", "The supplied run ID has an all-zero suffix"} {
		if !strings.Contains(got, want) {
			t.Fatalf("flowrun failure fragment replacement missing %q in %q", want, got)
		}
	}
}

func TestTextRedactorHoldsFlowrunFailureContextAcrossObservedDeltas(t *testing.T) {
	var r textRedactor
	var got string
	for _, delta := range []string{
		"### What this means\n\nThere is no ",
		"workflow run in this workspace wi",
		"th ",
		"the requested item. This can happen for a few reasons:\n\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(strings.ToLower(piece), opaqueEntityPlaceholder) || strings.Contains(strings.ToLower(piece), legacyEntityPlaceholder) {
			t.Fatalf("stream emitted flowrun placeholder before line completion: %q", piece)
		}
		got += piece
	}
	got += r.Flush()
	if strings.Contains(strings.ToLower(got), opaqueEntityPlaceholder) || strings.Contains(strings.ToLower(got), legacyEntityPlaceholder) {
		t.Fatalf("flowrun placeholder leaked after buffered line: %q", got)
	}
	if !strings.Contains(got, "There is no workflow run in this workspace") || !strings.Contains(got, "supplied run") {
		t.Fatalf("flowrun failure line was not normalized: %q", got)
	}
}

func TestTextRedactorHoldsSplitFlowrunToolNameAcrossReasoningDeltas(t *testing.T) {
	var r textRedactor
	var got string
	for _, delta := range []string{
		"The user wants me to call ge",
		"t_flowrun with run ID \"the requested item\" and explain the failure.\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(strings.ToLower(piece), "get_flowrun") || strings.Contains(strings.ToLower(piece), opaqueEntityPlaceholder) {
			t.Fatalf("reasoning emitted split flowrun internals: %q", piece)
		}
		got += piece
	}
	got += r.Flush()
	for _, forbidden := range []string{"get_flowrun", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("reasoning flowrun internals leaked after flush %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "run lookup") || !strings.Contains(got, "supplied run ID") {
		t.Fatalf("reasoning flowrun internals were not normalized: %q", got)
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunLookupNotFoundTemplate(t *testing.T) {
	input := "Flowrun Lookup Failed: Not Found\n\nThe call to get_flowrun with ID the requested item returned a \"flowrun not found\" error.\n\nThere is no workflow run in this workspace with the requested item."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"get_flowrun", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("lookup not-found template leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"The run lookup for the supplied run ID returned", "matching the supplied run"} {
		if !strings.Contains(got, want) {
			t.Fatalf("lookup not-found semantic replacement missing %q in %q", want, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunLookupPlaceholderContext(t *testing.T) {
	input := "The call to `get_flowrun` with ID `the requested item` failed because no workflow run exists with that ID in this workspace.\nThe ID is incorrect or fabricated. `the requested item` looks like a placeholder (all zeros after the run ID prefix).\nVerify the ID — check where you got `the requested item` from. If unsure, use `search_flowruns`."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"get_flowrun", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("lookup context leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"run lookup", "for the supplied run ID failed", "The supplied run ID looks like a placeholder", "got the supplied run ID from"} {
		if !strings.Contains(got, want) {
			t.Fatalf("lookup context semantic replacement missing %q in %q", want, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunArticleExampleAndNoun(t *testing.T) {
	input := "The requested flowrun does not correspond to any workflow run in this workspace. To inspect a real workflow run, you would need an actual `fr_...` ID."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the requested flowrun", "fr_...", "fr_"} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("flowrun article/example leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"The supplied run ID does not correspond", "a real run ID"} {
		if !strings.Contains(got, want) {
			t.Fatalf("flowrun article/example replacement missing %q in %q", want, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunRequestedPhrase(t *testing.T) {
	input := "The get_flowrun tool looks up a specific workflow run. The ID is incorrect — the requested flowrun may have been mistyped. The value the supplied run ID looks like a placeholder. Real flowrun IDs are generated by the system."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"get_flowrun tool", "the requested flowrun", "flowrun IDs"} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("flowrun requested phrase leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"run lookup tool", "the supplied run ID may have been mistyped", "the supplied run ID looks like a placeholder", "Real run IDs"} {
		if !strings.Contains(got, want) {
			t.Fatalf("flowrun requested phrase replacement missing %q in %q", want, got)
		}
	}
}

func TestRedactOpaqueMachineValuesCleansFlowrunFailureListPlaceholder(t *testing.T) {
	input := "The ID is fabricated/test value — the requested item appears to be a placeholder or made-up ID, not a real flowrun."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("flowrun failure list placeholder leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "the supplied run ID appears to be a placeholder") {
		t.Fatalf("flowrun failure list was not normalized: %q", got)
	}
}

func TestRedactOpaqueMachineValuesKeepsFlowrunTableSemantic(t *testing.T) {
	input := "| **Flowrun ID** | `fr_00112233445566` |\n| **Status** | running |"
	want := "| **Run** | Current run |\n| **Status** | running |"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("flowrun id table redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRemovesRedundantReportTargetAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("Here's the flowrun report for ")
	got += r.Write("`fr_00112233445566`:")
	got += r.Flush()

	want := "Here's the flowrun report:"
	if got != want {
		t.Fatalf("stream report target redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRedactsAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("bootId=178557")
	got += r.Write("0385396807000 and handler hd_2a5f")
	got += r.Write("dba507830767 done")
	got += r.Flush()

	want := "bootId=the numeric value and handler done"
	if got != want {
		t.Fatalf("stream redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRemovesEntityParentheticalAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The workflow nightly (`")
	got += r.Write("wf_00112233445566")
	got += r.Write("`) is staged.")
	got += r.Flush()

	want := "The workflow nightly is staged."
	if got != want {
		t.Fatalf("stream parenthetical redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRemovesMediaIDFromMixedParentheticalAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The original attachment (red circle, `att_001122")
	got += r.Write("33445566`) and the edited attachment (blue circle, `att_ffeedd")
	got += r.Write("ccbbaa99`) are distinct.")
	got += r.Flush()

	want := "The original attachment (red circle) and the edited attachment (blue circle) are distinct."
	if got != want {
		t.Fatalf("stream media parenthetical redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorKeepsMediaReasoningReadableAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The attachment ID is `att_001122")
	got += r.Write("33445566`. The original attachment is att_001122")
	got += r.Write("33445566 and the edited one is att_ffeeddccbbaa99.")
	got += r.Flush()

	want := "The attachment is ready. The original attachment is ready and the edited one is ready."
	if got != want {
		t.Fatalf("stream media reasoning redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorRemovesEntityNounAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("The workflow ")
	got += r.Write("**wf_00112233445566** remains intact.")
	got += r.Flush()

	if got != "The workflow remains intact." {
		t.Fatalf("stream entity noun redaction = %q", got)
	}
}

func TestTextRedactorRemovesPlaceholderMarkdownAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("Deletion denied as expected. Workflow `")
	got += r.Write("the referenced item`")
	got += r.Write(" remains intact and unaffected.")
	got += r.Flush()

	want := "Deletion denied as expected. Workflow remains intact and unaffected."
	if got != want {
		t.Fatalf("stream placeholder markdown redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorFlushesOrdinaryTrailingWord(t *testing.T) {
	var r textRedactor
	if got := r.Write("hello"); got != "" {
		t.Fatalf("trailing word emitted before delimiter: %q", got)
	}
	if got := r.Write(" world"); got != "hello " {
		t.Fatalf("first completed word = %q, want %q", got, "hello ")
	}
	if got := r.Flush(); got != "world" {
		t.Fatalf("flush = %q, want %q", got, "world")
	}
}

func TestStreamLLM_PreservesOpaqueValuesForWorkflowAgent(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv(`{"attachmentId":"att_00112233445566aa","source":"function_artifact"}`),
		finishEv(),
	}}}
	ctx := reqctxpkg.SetFlowrunID(context.Background(), "fr_00112233445566aa")
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, _, _, _, _, _ := streamLLM(ctx, client, llminfra.Request{}, noBuild, nil)

	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeText {
		t.Fatalf("workflow text blocks = %+v", blocks)
	}
	if blocks[0].Content != `{"attachmentId":"att_00112233445566aa","source":"function_artifact"}` {
		t.Fatalf("workflow agent data was redacted: %q", blocks[0].Content)
	}
}

func TestStreamLLM_RedactsOpaqueValuesForChat(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv(`done att_00112233445566aa`),
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, _, _, _, _, _ := streamLLM(context.Background(), client, llminfra.Request{}, noBuild, nil)

	if len(blocks) != 1 || blocks[0].Content != "done the requested item" {
		t.Fatalf("chat prose redaction changed: %+v", blocks)
	}
}

func TestStreamLLM_DoesNotStreamActivationTablePlaceholder(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv("以下是"),
		textEv("该激活记录的完整"),
		textEv("字段："),
		textEv("\n\n| 字段"),
		textEv(" | 值 |"),
		textEv("\n|------|"),
		textEv("-----"),
		textEv("|\n| **"),
		textEv("id（激活 ID"),
		textEv("）** | tra_f"),
		textEv("821"),
		textEv("82fcb"),
		textEv("7601"),
		textEv("442"),
		textEv(" |\n| **"),
		textEv("triggerId（触发"),
		textEv("器 ID）** |"),
		textEv(" trg_76"),
		textEv("4eb53"),
		textEv("840f"),
		textEv("0276"),
		textEv("d |\n|"),
		textEv(" **kind（类型"),
		textEv("）** | cron（"),
		textEv("定时任务） |"),
		textEv("\n| **f"),
		textEv("ired（是否触发"),
		textEv("）** | true（"),
		textEv("已触发）"),
		textEv(" |\n| **"),
		textEv("payload（载荷）**"),
		textEv(" | {\"manual"),
		textEv("\": true}（"),
		textEv("手动触发） |"),
		textEv("\n| **f"),
		textEv("iringCount（触发"),
		textEv("计数）** | "),
		textEv("0"),
		textEv(" |\n| **"),
		textEv("createdAt（创建时间"),
		textEv("）** | 2026-"),
		textEv("08-08T02"),
		textEv(":30:54"),
		textEv(".690194Z"),
		textEv(" |\n\n本次返回"),
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	_, _, _, _, _, _ = streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		if strings.Contains(delta.Chunk, opaqueEntityPlaceholder) || strings.Contains(delta.Chunk, opaqueTimestampPlaceholder) {
			t.Fatalf("live messages delta leaked activation placeholder: %q", delta.Chunk)
		}
	}
}

func TestStreamLLM_DoesNotStreamChineseActivationTablePlaceholder(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv("以下是该激活记录的完整字段：\n\n"),
		textEv("| 字段 |"),
		textEv(" 值 |\n|---|---|\n| 激活ID | tra_842dd55c696f9334 |\n| 触发器"),
		textEv("ID | the requested item |\n| 类型 | cron |\n| 是否触发 | 是 |\n| 负载 | {\\\"manual\\\": true} |\n| 触发次数 | 0 |\n| 创建时间 | the recorded time |\n\n"),
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)

	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		if strings.Contains(delta.Chunk, opaqueEntityPlaceholder) || strings.Contains(delta.Chunk, opaqueTimestampPlaceholder) {
			t.Fatalf("live Chinese activation delta leaked placeholder: %q", delta.Chunk)
		}
	}

	var got strings.Builder
	for _, block := range blocks {
		if block.Type != messagesdomain.BlockTypeText {
			continue
		}
		got.WriteString(block.Content)
	}
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("Chinese activation block retained placeholder: %q", got.String())
	}
	for _, want := range []string{"精确触发器 ID 见旁边的活动卡片。", "精确创建时间见旁边的活动卡片。"} {
		if !strings.Contains(got.String(), want) {
			t.Fatalf("Chinese activation block missing %q: %q", want, got.String())
		}
	}
}

func TestStreamLLM_DoesNotStreamActivationReasoningPlaceholder(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "返回的字段有：\n- id: tra_f98331ff0472114c\n- triggerId: the requested"},
		{Type: llminfra.EventReasoning, Delta: " item\n- kind: cron\n- fired: true\n- createdAt: the recorded"},
		{Type: llminfra.EventReasoning, Delta: " time\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)

	var live strings.Builder
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		live.WriteString(delta.Chunk)
		if strings.Contains(delta.Chunk, opaqueEntityPlaceholder) || strings.Contains(delta.Chunk, opaqueTimestampPlaceholder) {
			t.Fatalf("live reasoning delta leaked activation placeholder: %q", delta.Chunk)
		}
	}
	if strings.Contains(live.String(), opaqueEntityPlaceholder) || strings.Contains(live.String(), opaqueTimestampPlaceholder) {
		t.Fatalf("live reasoning retained activation placeholder: %q", live.String())
	}

	for _, block := range blocks {
		if block.Type != messagesdomain.BlockTypeReasoning {
			continue
		}
		if strings.Contains(block.Content, opaqueEntityPlaceholder) || strings.Contains(block.Content, opaqueTimestampPlaceholder) {
			t.Fatalf("durable reasoning retained activation placeholder: %q", block.Content)
		}
		if !strings.Contains(block.Content, "精确触发器 ID 见旁边的触发器卡片。") {
			t.Fatalf("durable reasoning lost trigger-card guidance: %q", block.Content)
		}
		return
	}
	t.Fatal("durable reasoning block missing")
}

func TestRedactOpaqueMachineValuesKeepsFlowrunErrorProseNatural(t *testing.T) {
	input := "The call to `get_flowrun` for `the referenced item` failed with an error.\nThere is no workflow run with the requested item in this workspace.\nThe ID doesn't exist — the referenced item appears to be fabricated.\n| **Requested ID** | `the referenced item` |\nThe requested item is not a valid, existing flowrun.\nThe placeholder uses the `fr_` prefix."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the referenced item", "the requested item", "fr_"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("flowrun error prose still contains %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"run lookup for the requested run", "workflow run matching the request", "the requested run appears", "Supplied run ID", "the run ID prefix"} {
		if !strings.Contains(got, want) {
			t.Fatalf("flowrun error prose missing %q: %q", want, got)
		}
	}
}

func TestTextRedactorKeepsFlowrunErrorPlaceholderNaturalAcrossChunks(t *testing.T) {
	var r textRedactor
	var got string
	for _, piece := range []string{
		r.Write("The call to `get_flowrun` for `the referenced"),
		r.Write(" item` failed."),
		r.Flush(),
	} {
		if strings.Contains(piece, "the referenced") {
			t.Fatalf("stream emitted a partial legacy placeholder: %q", piece)
		}
		got += piece
	}
	if strings.Contains(got, "the referenced item") || strings.Contains(got, "the requested item") {
		t.Fatalf("stream flowrun error placeholder leaked: %q", got)
	}
	if got != "The run lookup for the requested run failed." {
		t.Fatalf("stream flowrun error prose = %q", got)
	}
}

func TestStreamLLM_RedactsDuplicatedRequestedItemIDAcrossChunks(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "run_function requires functionId, which should be the the requested item "},
		{Type: llminfra.EventReasoning, Delta: "id. So I need to search first."},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, _, _, _, _, _ := streamLLM(context.Background(), client, llminfra.Request{}, noBuild, nil)
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("reasoning blocks = %+v", blocks)
	}
	got := blocks[0].Content
	for _, forbidden := range []string{"the the requested item", "the requested item id"} {
		if strings.Contains(strings.ToLower(got), forbidden) {
			t.Fatalf("duplicated opaque placeholder leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "the ID shown in the adjacent result card") {
		t.Fatalf("reasoning lost the honest adjacent-card hint: %q", got)
	}
}

func TestRedactDuplicatedRequestedItemIDAtDurableClose(t *testing.T) {
	input := "The execution lookup needs the the requested item id before it can continue."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the the requested item", "the requested item id"} {
		if strings.Contains(strings.ToLower(got), forbidden) {
			t.Fatalf("durable redaction leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "the ID shown in the adjacent result card") {
		t.Fatalf("durable redaction lost the adjacent-card hint: %q", got)
	}
}

func TestStreamLLM_RedactsOpaqueValuesForChatReasoning(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The flowrun "},
		{Type: llminfra.EventReasoning, Delta: "fr_00112233445566 belongs to workflow wf_00112233445566."},
		{Type: llminfra.EventReasoning, Delta: " Started at 2026-08-02T16:36:38.585915Z."},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, _, _, _, _, _ := streamLLM(context.Background(), client, llminfra.Request{}, noBuild, nil)
	for _, block := range blocks {
		if block.Type != messagesdomain.BlockTypeReasoning {
			continue
		}
		for _, forbidden := range []string{"fr_", "wf_", "2026-08-02T16:36:38", "the numeric value"} {
			if strings.Contains(block.Content, forbidden) {
				t.Fatalf("chat reasoning still exposes %q: %q", forbidden, block.Content)
			}
		}
		return
	}
	t.Fatal("chat reasoning block missing")
}

func TestStreamLLM_ReappliesWholeBlockRedactionAtClose(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv("## Flowrun Report — `the referenced item`\n| **Flowrun ID** | `the referenced item` |\n| **Workflow Version** | `the referenced item` |\n| **Node Record ID** | `the referenced item` |\n| **Ref** | `the referenced item` |\n| **Started At** | 2026-08-02 16:36:38 UTC |\n**Pinned Refs:**\n- `the referenced item` → `the referenced item`\n- Approval form `the referenced item` pinned to version `the referenced item`"),
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, _, _, _, _, _ := streamLLM(context.Background(), client, llminfra.Request{}, noBuild, nil)
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeText {
		t.Fatalf("whole-block text blocks = %+v", blocks)
	}
	forbiddenValues := []string{opaqueEntityPlaceholder, legacyEntityPlaceholder, "fr_", "wfv_", "apf_", "apfv_"}
	for _, forbidden := range forbiddenValues {
		if strings.Contains(blocks[0].Content, forbidden) {
			t.Fatalf("close snapshot still contains %q: %q", forbidden, blocks[0].Content)
		}
	}
	if !strings.Contains(blocks[0].Content, "## Flowrun Report") {
		t.Fatalf("close snapshot lost the report heading: %q", blocks[0].Content)
	}
	for _, want := range []string{"| **Run** | Current run |", "| **Version** | Current version |", "| **Node record** | Internal record |", "**References:** Internal references", "- Internal approval references"} {
		if !strings.Contains(blocks[0].Content, want) {
			t.Fatalf("close snapshot missing %q: %q", want, blocks[0].Content)
		}
	}
	if !strings.Contains(blocks[0].Content, "the recorded time") || strings.Contains(blocks[0].Content, "2026-08-02 16:36:38") {
		t.Fatalf("close snapshot timestamp redaction = %q", blocks[0].Content)
	}
}

func TestStreamLLM_UsesContextAwareRedactionForDurableDossierClose(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The execution audit dossier is ready. The execution ID is `the requested item`."},
		{Type: llminfra.EventReasoning, Delta: " The exact value is recorded in the adjacent card."},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)

	var live strings.Builder
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if ok {
			live.WriteString(delta.Chunk)
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("dossier blocks = %+v", blocks)
	}
	for _, output := range []string{live.String(), blocks[0].Content} {
		if strings.Contains(output, opaqueEntityPlaceholder) || strings.Contains(output, "the requested item") {
			t.Fatalf("dossier placeholder leaked from live or durable path: %q", output)
		}
	}
	if !strings.Contains(blocks[0].Content, "available in the adjacent execution card") {
		t.Fatalf("durable dossier lost context-aware adjacent-card wording: %q", blocks[0].Content)
	}
}

func TestStreamLLM_RedactsFailureExplanationAtLiveAndDurableClose(t *testing.T) {
	const failureExplanation = "## 失败原因说明\n\n调用 `get_function` 时传入了 ID `the requested item`，系统返回了 \"function not found\"。\n\n实际失败原因：该函数 ID `the requested item` 在系统中并不存在。当前工作区里没有任何函数使用这个 ID，因此系统无法找到对应的函数记录。"
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv(failureExplanation),
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)

	var live strings.Builder
	var durable string
	for _, event := range bridge.events {
		switch frame := event.Frame.(type) {
		case streamdomain.Delta:
			live.WriteString(frame.Chunk)
		case streamdomain.Close:
			if frame.Result != nil && frame.Result.Type == messagesdomain.BlockTypeText {
				var snapshot textContent
				if err := json.Unmarshal(frame.Result.Content, &snapshot); err != nil {
					t.Fatalf("decode durable text snapshot: %v", err)
				}
				durable = snapshot.Content
			}
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeText {
		t.Fatalf("failure explanation blocks = %+v", blocks)
	}
	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": durable,
		"final":   blocks[0].Content,
	} {
		if strings.Contains(output, opaqueEntityPlaceholder) || strings.Contains(output, "fn_") {
			t.Fatalf("%s failure explanation leaked opaque value: %q", name, output)
		}
		if !strings.Contains(output, "传入的目标见相邻工具卡") || !strings.Contains(output, "该函数在系统中并不存在") {
			t.Fatalf("%s failure explanation lost readable card guidance: %q", name, output)
		}
		if strings.Contains(output, "该函数 ID") {
			t.Fatalf("%s failure explanation retained machine-field grammar: %q", name, output)
		}
	}
}

func TestRedactChineseToolIDFailureExplanationAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "## 失败说明\n\n调用 `get_function` 并传入 ID `fn_0000000000000000` 后，返回结果为 **\"function not found\"**。\n\n**真实原因：** 该函数 ID 不存在。`fn_0000000000000000` 是一个格式合法但并不对应任何已注册函数的虚构 ID。系统中没有与之匹配的记录，因此接口返回了\"未找到\"的错误。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"## 失败说明\n\n调用 `get_function` 并传入 ID `",
		"fn_0000000000000000",
		"` 后，返回结果为 **\"function not found\"**。\n\n**真实原因：** 该函数 ID ",
		"不存在。`fn_0000000000000000` ",
		"是一个格式合法但并不对应任何已注册函数的虚构 ID。系统中没有与之匹配的记录，因此接口返回了\"未找到\"的错误。",
	} {
		piece := redactor.Write(delta)
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())

	outputs := map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	}
	for name, output := range outputs {
		for _, forbidden := range []string{"fn_0000000000000000", "the requested item", opaqueEntityPlaceholder, "该目标", "函数 ID", "并传入的"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s failure explanation leaked %q: %q", name, forbidden, output)
			}
		}
		expectedPhrases := []string{"调用 `get_function` 后", "该函数不存在", "这个输入是一个格式合法"}
		if name == "durable" {
			expectedPhrases = []string{"这个输入格式合法，但对应的函数目前未注册。", "这是正常的\"未找到\"结果，不是格式问题。", "如需查找已有函数"}
		}
		for _, expected := range expectedPhrases {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s failure explanation lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseToolQueryFailureExplanationAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "## 失败说明\n\n**操作结果**：调用 `get_function` 查询 ID 为 `fn_0000000000000000` 的函数，返回了 **\"function not found\"**（未找到该函数）。\n\n**真实原因**：\n\n这个函数 ID `fn_0000000000000000` 在系统中并不存在。它是一个格式正确（符合 `fn_` 前缀 + 16 位十六进制字符的 ID 结构）但实际上从未被创建过的虚构 ID。\n\n当前工作区中存在的函数只有：\n- `greet`（打个招呼）\n- `sync_inventory`（同步库存快照）\n\n因此，系统无法返回任何函数的活跃版本信息（代码、参数、返回结构、依赖、环境状态等），只能报告\"未找到\"。这不是工具调用格式错误，也不是权限问题，而是**目标实体本身不存在**。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"## 失败说明\n\n**操作结果**：调用 `get_function` 查询 ID 为 `fn_0000000000000000",
		"` 的函数，返回了 **\"function not found\"**（未找到该函数）。\n\n**真实原因**：\n\n这个函数 ID `fn_0000000000000000",
		"` 在系统中并不存在。它是一个格式正确（符合 `fn_` 前缀 + 16 位十六进制字符的 ID 结构）但实际上从未被创建过的虚构 ID。\n\n",
		"当前工作区中存在的函数只有：\n- `greet`（打个招呼）\n- `sync_inventory`（同步库存快照）\n\n因此，系统无法返回任何函数的活跃版本信息（代码、参数、返回结构、依赖、环境状态等），只能报告\"未找到\"。这不是工具调用格式错误，也不是权限问题，而是**目标实体本身不存在**。",
	} {
		piece := redactor.Write(delta)
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())

	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	} {
		for _, forbidden := range []string{"fn_", "the requested item", opaqueEntityPlaceholder, "该目标", "函数 ID", "ID 已定位"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s tool-query failure leaked %q: %q", name, forbidden, output)
			}
		}
		for _, expected := range []string{"调用 `get_function` 查询目标函数", "这个函数在系统中并不存在", "格式正确但实际上从未被创建过"} {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s tool-query failure lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseToolFailureCurrentGatewayVariantAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "**实际失败原因说明：**\n\n调用 `get_function` 传入 `fn_0000000000000000` 后，系统返回了 `function not found`。\n\n这说明该函数 ID `fn_0000000000000000` 在系统中不存在。`get_function` 要求传入一个真实已注册的函数 ID（格式为 `fn_` 开头），而 `fn_0000000000000000` 是一个虚构的、未注册的 ID，因此系统无法找到对应的函数，返回了\"未找到\"的错误。\n\n如需查看当前可用的函数，可以使用 `search_function` 工具进行检索。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"**实际失败原因说明：**\n\n调用 `get_function` 传入 `fn_0000000000000000` 后，系统返回了 `function not found`。\n\n这说明",
		"该函数 ID `fn_0000000000000000` 在系统中不存在。`get_function` 要求传入一个真实已注册的函数 ID（格式为 `fn_` 开头），而",
		" `fn_0000000000000000` 是一个虚构的、未注册的 ID，因此系统无法找到对应的函数，返回了\"未找到\"的错误。\n\n如需查看当前可用的函数，可以使用 `search_function` 工具进行检索。",
	} {
		live.WriteString(redactor.Write(delta))
	}
	live.WriteString(redactor.Flush())

	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	} {
		for _, forbidden := range []string{"fn_", "the requested item", opaqueEntityPlaceholder, "该目标", "函数 ID", "ID 已定位"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s current-gateway failure leaked %q: %q", name, forbidden, output)
			}
		}
		expectedPhrases := []string{"调用 `get_function` 后", "该函数在系统中不存在", "格式合法", "而这个输入是一个"}
		if name == "durable" {
			expectedPhrases = []string{"这个输入格式合法，但对应的函数目前未注册。", "这是正常的\"未找到\"结果，不是格式问题。", "如需查找已有函数"}
		}
		for _, expected := range expectedPhrases {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s current-gateway failure lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseToolFailureWorkspaceVariantAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "调用 `get_function` 后，返回结果为 `function not found`。\n\n**失败原因：** 该 ID `fn_0000000000000000` 在工作区中并不存在。工作区当前注册的函数只有 `greet` 和 `sync_inventory` 等，它们各自拥有系统分配的真实 ID（以 `fn_` 开头），而这个输入是一个虚构的、不存在的标识符，因此系统无法找到对应的函数，直接返回了\"未找到\"的错误。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"调用 `get_function` 后，返回结果为 `function not found`。\n\n**失败原因：** 该 ID `fn_0000000000000000",
		"` 在工作区中并不存在。工作区当前注册的函数只有 `greet` 和 `sync_inventory` 等，它们各自拥有系统分配的真实 ID（以 `fn_` 开头），而",
		"这个输入是一个虚构的、不存在的标识符，因此系统无法找到对应的函数，直接返回了\"未找到\"的错误。",
	} {
		live.WriteString(redactor.Write(delta))
	}
	live.WriteString(redactor.Flush())

	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	} {
		for _, forbidden := range []string{"fn_", "the requested item", opaqueEntityPlaceholder, "该目标", "该 ID", "真实 ID"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s workspace-variant failure leaked %q: %q", name, forbidden, output)
			}
		}
		expectedPhrases := []string{"调用 `get_function` 后", "这个输入在工作区中并不存在", "真实标识（格式合法）", "这个输入是一个"}
		if name == "durable" {
			expectedPhrases = []string{"这个输入格式合法，但对应的函数目前未注册。", "这是正常的\"未找到\"结果，不是格式问题。", "如需查找已有函数"}
		}
		for _, expected := range expectedPhrases {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s workspace-variant failure lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseToolFailureNaturalTemplateAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "调用 `get_function` 时传入了 `fn_0000000000000000` 这个 ID，系统返回了 **\"function not found\"**。**实际失败原因：** 该函数 ID 不存在。`fn_0000000000000000` 并不是系统中已注册的真实函数标识符——它是一个虚构的、格式合法但不存在的 ID。`get_function` 要求传入一个实际存在于目录中的函数 ID（以 `fn_` 开头），而当前工作区中并没有与这个 ID 对应的函数记录，因此查询失败并返回\"未找到\"。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"调用 `get_function` 时传入了 `fn_0000000000000000` 这个 ID，系统返回了 **\"function not found\"**。**实际失败原因：** 该函数 ID ",
		"不存在。`fn_0000000000000000` 并不是系统中已注册的真实函数标识符——它是一个虚构的、格式合法但不存在的 ID。`get_function` 要求传入一个实际存在于目录中的函数 ID（以 `fn_` 开头），而当前工作区中并没有与这个 ID 对应的函数记录，因此查询失败并返回\"未找到\"。",
	} {
		live.WriteString(redactor.Write(delta))
	}
	live.WriteString(redactor.Flush())

	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	} {
		for _, forbidden := range []string{"fn_", "the requested item", opaqueEntityPlaceholder, "该目标", "这个 ID", "真实 ID", "函数 ID"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s natural-template failure leaked %q: %q", name, forbidden, output)
			}
		}
		expectedPhrases := []string{"调用 `get_function` 后", "这个输入并不是系统中已注册的真实函数标识符", "当前工作区中没有与之对应的函数记录"}
		if name == "durable" {
			expectedPhrases = []string{"这个输入格式合法，但对应的函数目前未注册。", "这是正常的\"未找到\"结果，不是格式问题。", "如需查找已有函数"}
		}
		for _, expected := range expectedPhrases {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s natural-template failure lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseToolFailureParentheticalIDAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "调用 `get_function` 并传入 `fn_0000000000000000` 后，系统返回了 **\"function not found\"**。**实际失败原因：** 该函数 ID（`fn_0000000000000000`）在当前工作区的函数目录中并不存在。这是一个伪造的、不合法的 ID，没有对应任何已创建的函数实体，因此系统无法查找到匹配的记录，直接返回了\"未找到\"错误。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"调用 `get_function` 并传入 `fn_0000000000000000` 后，系统返回了 **\"function not found\"**。**实际失败原因：** 该函数 ID（`fn_0000000000000000`）",
		"在当前工作区的函数目录中并不存在。这是一个伪造的、不合法的 ID，没有对应任何已创建的函数实体，因此系统无法查找到匹配的记录，直接返回了\"未找到\"错误。",
	} {
		live.WriteString(redactor.Write(delta))
	}
	live.WriteString(redactor.Flush())

	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	} {
		for _, forbidden := range []string{"fn_", "the requested item", opaqueEntityPlaceholder, "该目标", "函数 ID", "不合法的 ID"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s parenthetical failure leaked %q: %q", name, forbidden, output)
			}
		}
		for _, expected := range []string{"调用 `get_function` 后", "该函数在当前工作区的函数目录中并不存在", "伪造的、不合法的标识"} {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s parenthetical failure lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseToolFailureAllZeroVariantAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "以下是实际失败情况的说明：**调用结果：** 工具返回 `function not found`（函数未找到）。**原因：** `fn_0000000000000000` 这个 ID 在工作区中并不存在。当前工作区里可用的函数有 `greet` 和 `sync_inventory` 等，它们的真实 ID 均以 `fn_` 开头，但并非这个全零的 ID。`get_function` 要求传入一个确实存在于目录中的函数 ID，传入不存在的 ID 会直接返回\"未找到\"错误，不会返回任何函数代码或版本信息。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"以下是实际失败情况的说明：**调用结果：** 工具返回 `function not found`（函数未找到）。**原因：** `fn_0000000000000000` 这个 ID 在工作区中并不存在。当前工作区里可用的函数有 `greet` 和 `sync_inventory` 等，它们的真实 ID 均以 `fn_` 开头，",
		"但并非这个全零的 ID。`get_function` 要求传入一个确实存在于目录中的函数 ID，传入不存在的 ID 会直接返回\"未找到\"错误，不会返回任何函数代码或版本信息。",
	} {
		live.WriteString(redactor.Write(delta))
	}
	live.WriteString(redactor.Flush())

	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	} {
		for _, forbidden := range []string{"fn_", "the requested item", opaqueEntityPlaceholder, "该目标", "这个 ID", "真实 ID", "函数 ID", "全零的 ID"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s all-zero failure leaked %q: %q", name, forbidden, output)
			}
		}
		for _, expected := range []string{"这个输入在工作区中并不存在", "真实标识均符合合法格式", "并非这个输入", "要求传入一个确实存在于目录中的函数"} {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s all-zero failure lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseToolReferenceFailureVariantsAcrossStreamBoundaries(t *testing.T) {
	const failureExplanation = "## 失败说明\n\n调用 `get_function` 传入 `fn_0000000000000000` 后，返回结果为 **\"function not found\"**。\n\n**真实原因：** 这个 ID 是一个格式合法（符合 `fn_` 前缀 + 16 位十六进制字符的 ID 规范）但并不存在的函数标识符。当前工作区中没有任何函数的 ID 是 `fn_0000000000000000`，系统无法找到对应的函数实体，因此返回了\"未找到\"的错误。\n\n如需查询实际可用的函数，可以先使用 `search_function` 搜索现有函数列表，获取真实的 `fn_0000000000000000` ID 后再进行调用。"
	var redactor textRedactor
	var live strings.Builder
	for _, delta := range []string{
		"## 失败说明\n\n调用 `get_function` 传入 `fn_0000000000000000` 后，返回结果为 **\"function not found\"**。\n\n**真实原因：** 这个 ID 是一个格式合法（符合 `fn_` 前缀 + 16 位十六进制字符的 ID 规范）但并不存在的函数标识符。当前工作区中没有任何函数的 ID 是 `fn_0000000000000000",
		"`，系统无法找到对应的函数实体，因此返回了\"未找到\"的错误。\n\n如需查询实际可用的函数，可以先使用 `search_function` 搜索现有函数列表，获取真实的 `fn_0000000000000000",
		"` ID 后再进行调用。",
	} {
		piece := redactor.Write(delta)
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())

	for name, output := range map[string]string{
		"live":    live.String(),
		"durable": redactCompleteUserBlock(failureExplanation),
	} {
		for _, forbidden := range []string{"fn_", "the requested item", opaqueEntityPlaceholder, "该目标", "ID 已定位", "函数的 ID"} {
			if strings.Contains(output, forbidden) {
				t.Fatalf("%s tool-reference failure leaked %q: %q", name, forbidden, output)
			}
		}
		for _, expected := range []string{"调用 `get_function` 后", "当前工作区中没有任何函数与其匹配", "获取实际可用的函数后再进行调用"} {
			if !strings.Contains(output, expected) {
				t.Fatalf("%s tool-reference failure lost natural wording %q: %q", name, expected, output)
			}
		}
	}
}

func TestRedactChineseConjoinedMissingIDReference(t *testing.T) {
	for _, input := range []string{
		"调用 `get_function` 并传入 `the requested item` 后，返回结果为 `function not found`。",
		"调用 `get_function` 传入 `the requested item` 后，返回结果为 `function not found`。",
	} {
		got := redactOpaqueMachineValues(input)
		if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "该目标") {
			t.Fatalf("conjoined missing-ID reference leaked placeholder: %q", got)
		}
		if !strings.Contains(got, "调用 `get_function` 后") {
			t.Fatalf("conjoined missing-ID reference was not made natural: %q", got)
		}
	}
}

func TestRedactChineseGenericMissingIDSentence(t *testing.T) {
	got := redactOpaqueMachineValues("实际失败原因：这个 ID `the requested item` 在系统中并不存在。")
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "该目标") {
		t.Fatalf("generic missing-ID sentence leaked placeholder: %q", got)
	}
	if !strings.Contains(got, "这个输入在系统中并不存在") {
		t.Fatalf("generic missing-ID sentence was not made natural: %q", got)
	}
}

func TestRedactChineseQualifiedMissingIDReference(t *testing.T) {
	got := redactOpaqueMachineValues("调用 `get_function` 时传入了一个不存在的函数 ID `the requested item`，系统返回了错误。")
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "该目标") || strings.Contains(got, "函数 ID") {
		t.Fatalf("qualified missing-ID reference leaked machine wording: %q", got)
	}
	if !strings.Contains(got, "传入了一个不存在的函数，系统返回了错误") {
		t.Fatalf("qualified missing-ID reference lost readable meaning: %q", got)
	}
}

func TestRedactChineseMissingIDVariants(t *testing.T) {
	tests := []struct {
		input string
		want  string
		bad   []string
	}{
		{
			input: "调用 `get_function` 时传入 `the requested item` 这个 ID，返回失败。",
			want:  "传入这个输入",
			bad:   []string{"the requested item", "该目标"},
		},
		{
			input: "该函数 ID 并不存在于系统中。",
			want:  "该函数并不存在于系统中",
			bad:   []string{"函数 ID"},
		},
		{
			input: "该目标是一个虚构的、格式合法但从未被创建过的标识符。",
			want:  "这个输入是一个虚构的、格式合法但从未被创建过的标识符",
			bad:   []string{"该目标"},
		},
	}
	for _, test := range tests {
		got := redactOpaqueMachineValues(test.input)
		for _, forbidden := range test.bad {
			if strings.Contains(got, forbidden) {
				t.Fatalf("missing-ID variant leaked %q: %q", forbidden, got)
			}
		}
		if !strings.Contains(got, test.want) {
			t.Fatalf("missing-ID variant lost natural wording %q: %q", test.want, got)
		}
	}
}

func TestRedactAttachmentPlaceholderLabeledLine(t *testing.T) {
	input := "The image was saved successfully.\n\n**Attachment ID:** the requested item"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "Attachment ID") {
		t.Fatalf("attachment placeholder leaked: %q", got)
	}
	if !strings.Contains(got, "The image was saved successfully.") {
		t.Fatalf("readable result was removed with attachment placeholder: %q", got)
	}
}

func TestRedactChineseAttachmentIDReferenceKeepsProseNatural(t *testing.T) {
	input := "图像已保存并可通过附件 ID `att_336de2c9f26095f7` 引用。"
	want := "图像已保存并可通过附件卡片引用。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("Chinese attachment reference = %q, want %q", got, want)
	}
}

func TestTextRedactorHoldsChineseAttachmentIDReferenceAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"图像已保存并可通过附件 ID `att_336de2c9",
		"f26095f7` 引用。",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "附件 ID") || strings.Contains(piece, opaqueEntityPlaceholder) {
			t.Fatalf("Chinese attachment reference leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if got.String() != "图像已保存并可通过附件卡片引用。" {
		t.Fatalf("stream Chinese attachment reference = %q", got.String())
	}
}

func TestTextRedactorHoldsAttachmentPlaceholderLabeledLine(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"The image was saved successfully.\n\n**",
		"Attachment ID:** `att_0123456789abcdef",
		"`\n**Filename:** `generated.png`",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, "Attachment ID") {
			t.Fatalf("attachment placeholder leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), opaqueEntityPlaceholder) || strings.Contains(got.String(), "Attachment ID") {
		t.Fatalf("attachment placeholder leaked in stream: %q", got.String())
	}
	if !strings.Contains(got.String(), "The image was saved successfully.") {
		t.Fatalf("readable result was removed with attachment placeholder: %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesRemovesVersionIDPlaceholderLine(t *testing.T) {
	input := "- **Version**: Updated to v2 (from v1)\n- **Version ID**: `fnv_00112233445566` (new version created)\n- **Environment Status**: ready\n"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "Version ID") || strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "fnv_") {
		t.Fatalf("version ID placeholder leaked: %q", got)
	}
	for _, want := range []string{"Version", "Updated to v2", "Environment Status", "ready"} {
		if !strings.Contains(got, want) {
			t.Fatalf("version ID redaction lost %q: %q", want, got)
		}
	}
}

func TestTextRedactorHoldsVersionIDPlaceholderAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"- **Version**: Updated to v2\n- **Version ID**: the requested ",
		"item (new version created)\n- **Environment Status**: ready\n",
	} {
		piece := r.Write(delta)
		if strings.Contains(piece, "Version ID") || strings.Contains(piece, opaqueEntityPlaceholder) {
			t.Fatalf("version ID placeholder leaked in stream piece %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	if strings.Contains(got.String(), "Version ID") || strings.Contains(got.String(), opaqueEntityPlaceholder) {
		t.Fatalf("version ID placeholder leaked in stream: %q", got.String())
	}
	if !strings.Contains(got.String(), "Version") || !strings.Contains(got.String(), "Environment Status") || !strings.Contains(got.String(), "ready") {
		t.Fatalf("stream redaction lost readable fields: %q", got.String())
	}
}

func TestRedactOpaqueMachineValuesRewritesVersionIDPlaceholderSentence(t *testing.T) {
	input := "The edit succeeded; versionId changed to the requested item, and envStatus is ready."
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "versionId") {
		t.Fatalf("version ID sentence leaked: %q", got)
	}
	if !strings.Contains(got, "version reference updated") || !strings.Contains(got, "envStatus is ready") {
		t.Fatalf("version ID sentence lost readable facts: %q", got)
	}
}

func TestRedactChineseAuditMachineFields(t *testing.T) {
	input := "完整审计档案\n" +
		"执行ID: fne_d30271b93e040960\n" +
		"版本ID: `the requested item`\n" +
		"会话ID: \"the requested item\"\n" +
		"工具调用ID: `the requested item`\n" +
		"开始时间:`相应时间`\n" +
		"结束时间: `2026-08-17T23:29:01.123Z`\n" +
		"耗时: 63ms\n" +
		"日志输出\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"fne_d30271b93e040960", "the requested item", "相应时间", "the recorded time",
		"执行ID:", "版本ID:", "会话ID:", "工具调用ID:", "开始时间:", "结束时间:",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("Chinese audit machine field leaked %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"完整审计档案", "耗时: 63ms", "日志输出"} {
		if !strings.Contains(got, want) {
			t.Fatalf("Chinese audit prose lost readable field %q: %q", want, got)
		}
	}
}

func TestTextRedactorHoldsChineseAuditMachineFieldsAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"完整审计档案\n执行ID: fne_d30271",
		"b93e040960\n版本ID: the requested ",
		"item\n会话ID: the requested item\n工具调用ID: the requested item\n",
		"开始时间:相应时间\n结束时间: 2026-08-17T23:29:01Z\n耗时: 63ms\n",
	} {
		piece := r.Write(delta)
		for _, forbidden := range []string{"fne_", "the requested item", "相应时间", "the recorded time", "执行ID:", "版本ID:", "会话ID:", "工具调用ID:", "开始时间:", "结束时间:"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("Chinese audit field leaked in intermediate stream piece %q: %q", forbidden, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(r.Flush())
	for _, forbidden := range []string{"fne_", "the requested item", "相应时间", "the recorded time", "执行ID:", "版本ID:", "会话ID:", "工具调用ID:", "开始时间:", "结束时间:"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("Chinese audit field leaked in final stream for %q: %q", forbidden, got.String())
		}
	}
	for _, want := range []string{"完整审计档案", "耗时: 63ms"} {
		if !strings.Contains(got.String(), want) {
			t.Fatalf("Chinese audit stream lost readable field %q: %q", want, got.String())
		}
	}
}

func TestRedactChineseAuditTableRemovesMachineRowsOnlyFromExecutionDossier(t *testing.T) {
	input := "以下是函数本次执行的完整审计档案：\n\n" +
		"| 字段 | 值 |\n|---|---|\n" +
		"| **执行 ID** | `fne_d30271b93e040960` |\n" +
		"| **函数 ID** | `fn_082ca98ecf1a3ec7` |\n" +
		"| **版本 ID** | `the requested item` |\n" +
		"| **状态** | ✅ `ok` |\n" +
		"| **开始时间** |相应时间|\n" +
		"| **结束时间** |相应时间|\n" +
		"| **耗时** | 174 ms |\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"fne_", "fn_", "the requested item", "相应时间", "执行 ID", "函数 ID", "版本 ID", "开始时间", "结束时间",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("execution dossier table leaked machine field %q: %q", forbidden, got)
		}
	}
	for _, want := range []string{"状态", "ok", "耗时", "174 ms"} {
		if !strings.Contains(got, want) {
			t.Fatalf("execution dossier table lost readable field %q: %q", want, got)
		}
	}

	mcp := "| 字段 | 值 |\n|---|---|\n| **服务器** | mcp-server |\n| **开始时间** | 精确时间见旁边的 MCP 调用卡片。 |"
	if gotMCP := redactOpaqueMachineValues(mcp); !strings.Contains(gotMCP, "精确时间见旁边的 MCP 调用卡片。") {
		t.Fatalf("MCP timing row was incorrectly removed: %q", gotMCP)
	}
}

func TestRedactExecutionIDReasoningSentencePointsToAdjacentCard(t *testing.T) {
	input := "The execution id is `fne_d30271b93e040960`. The record is ready."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"fne_", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("execution ID reasoning leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "The execution is available in the adjacent execution card") || !strings.Contains(got, "The record is ready.") {
		t.Fatalf("execution reasoning lost readable facts: %q", got)
	}
}

func TestRedactCamelCaseExecutionIDReasoningSentencePointsToAdjacentCard(t *testing.T) {
	input := "The executionId is \"the requested item\". The record is ready."
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"executionId", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("camelCase execution ID reasoning leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "The execution ID is available in the adjacent execution card") || !strings.Contains(got, "The record is ready.") {
		t.Fatalf("camelCase execution reasoning lost readable facts: %q", got)
	}
}

func TestStreamLLM_RedactsCamelCaseExecutionIDAcrossChunks(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The executionId is \""},
		{Type: llminfra.EventReasoning, Delta: "the requested item\". The record is ready."},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"executionId", opaqueEntityPlaceholder, legacyEntityPlaceholder} {
			if strings.Contains(strings.ToLower(delta.Chunk), strings.ToLower(forbidden)) {
				t.Fatalf("live camelCase execution ID delta leaked %q: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("reasoning blocks = %+v", blocks)
	}
	got := blocks[0].Content
	if strings.Contains(strings.ToLower(got), "executionid") || strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, legacyEntityPlaceholder) {
		t.Fatalf("durable camelCase execution ID reasoning leaked: %q", got)
	}
	if !strings.Contains(got, "The execution ID is available in the adjacent execution card") || !strings.Contains(got, "The record is ready.") {
		t.Fatalf("durable camelCase execution reasoning lost readable facts: %q", got)
	}
}

func TestStreamLLM_RedactsSpacedExecutionIDAcrossChunks(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The execution id is \""},
		{Type: llminfra.EventReasoning, Delta: "the requested item\". The record is ready.\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"the requested item", "the referenced item", "execution id is"} {
			if strings.Contains(strings.ToLower(delta.Chunk), forbidden) {
				t.Fatalf("live spaced execution ID delta leaked %q: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("reasoning blocks = %+v", blocks)
	}
	got := blocks[0].Content
	for _, forbidden := range []string{"the requested item", "the referenced item", "execution id is"} {
		if strings.Contains(strings.ToLower(got), forbidden) {
			t.Fatalf("durable spaced execution ID reasoning leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "The execution is available in the adjacent execution card") || !strings.Contains(got, "The record is ready.") {
		t.Fatalf("durable spaced execution reasoning lost readable facts: %q", got)
	}
}

func TestRedactExecutionIDExampleAndNamedJSONFields(t *testing.T) {
	input := "The execution ID `the requested item` is used below.\n" +
		"run_function requires functionId (like `the requested item`), not a name.\n" +
		"{\n" +
		"  \"id\": \"document\",\n" +
		"  \"functionId\": \"fn_1234567890abcdef\",\n" +
		"  \"versionId\": \"the requested item\",\n" +
		"  \"executionId\": \"fne_1234567890abcdef\",\n" +
		"  \"startedAt\": \"2026-08-18T00:00:00.000Z\",\n" +
		"  \"endedAt\": \"the recorded time\"\n" +
		"}"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"the requested item", "the referenced item", "fn_1234567890abcdef", "fne_1234567890abcdef",
		"2026-08-18T00:00:00.000Z", "the recorded time", "functionId (like `",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("execution/JSON reasoning leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"The execution ID from the adjacent execution card is used below.",
		"functionId (like a real ID)",
		`"id": "document"`,
		`"functionId": "see adjacent result card"`,
		`"versionId": "see adjacent result card"`,
		`"executionId": "see adjacent result card"`,
		`"startedAt": "see adjacent result card"`,
		`"endedAt": "see adjacent result card"`,
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("execution/JSON reasoning lost %q: %q", expected, got)
		}
	}
}

func TestStreamLLM_RedactsExecutionIDExampleAndNamedJSONFieldsAcrossChunks(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The execution ID `"},
		{Type: llminfra.EventReasoning, Delta: "the requested item` is used below. run_function requires functionId (like `"},
		{Type: llminfra.EventReasoning, Delta: "the requested item`), not a name.\n{\n  \"functionId\": \"the requested item\",\n  \"startedAt\": \"the recorded time\"\n}"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"the requested item", "the referenced item", "the recorded time"} {
			if strings.Contains(strings.ToLower(delta.Chunk), strings.ToLower(forbidden)) {
				t.Fatalf("live execution/JSON delta leaked %q: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("reasoning blocks = %+v", blocks)
	}
	got := blocks[0].Content
	for _, forbidden := range []string{"the requested item", "the referenced item", "the recorded time"} {
		if strings.Contains(strings.ToLower(got), strings.ToLower(forbidden)) {
			t.Fatalf("durable execution/JSON reasoning leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"The execution ID from the adjacent execution card is used below.",
		"functionId (like a real ID)",
		`"functionId": "see adjacent result card"`,
		`"startedAt": "see adjacent result card"`,
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("durable execution/JSON reasoning lost %q: %q", expected, got)
		}
	}
}

func TestRedactLeadingPromptSectionClose(t *testing.T) {
	input := "</section>\n\n以下是完整的审计档案。"
	got := redactOpaqueMachineValues(input)
	if got != "以下是完整的审计档案。" {
		t.Fatalf("leading prompt section close = %q", got)
	}
}

func TestRedactLeadingThinkingClose(t *testing.T) {
	for _, input := range []string{"</think>\n\n以下是完整的审计档案。", "</analysis>\n正文"} {
		got := redactOpaqueMachineValues(input)
		if strings.Contains(got, "</think>") || strings.Contains(got, "</analysis>") {
			t.Fatalf("leading model delimiter leaked: %q", got)
		}
	}
}

func TestStreamLLM_RedactsSplitLeadingPromptSectionClose(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "</"},
		{Type: llminfra.EventReasoning, Delta: "section>\n\n以下是完整的审计档案。"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		if strings.Contains(delta.Chunk, "</section>") || strings.Contains(delta.Chunk, "</") {
			t.Fatalf("live reasoning leaked a prompt delimiter: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("reasoning blocks = %+v", blocks)
	}
	if blocks[0].Content != "以下是完整的审计档案。" {
		t.Fatalf("durable reasoning retained a prompt delimiter: %q", blocks[0].Content)
	}
}

func TestStreamLLM_RedactsSplitLeadingThinkingClose(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "</"},
		{Type: llminfra.EventText, Delta: "think>\n\n完整的执行审计档案。"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if ok && strings.Contains(delta.Chunk, "</") {
			t.Fatalf("live thinking delimiter leaked: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 || blocks[0].Content != "完整的执行审计档案。" {
		t.Fatalf("durable thinking delimiter remained: %+v", blocks)
	}
}

func TestRedactChineseDossierSummaryFields(t *testing.T) {
	input := "无错误（`errorMsg` 为空）。历史汇总（`okCount: 1`，`failedCount: 0`）。\n- **错误信息**：无（执行成功，`errorMsg` 为空）"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"errorMsg", "okCount", "failedCount"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("dossier machine field leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"无错误（错误信息为空）", "（成功记录：1，失败记录：0）", "无（执行成功，错误信息为空）"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("dossier summary lost %q: %q", expected, got)
		}
	}
	standalone := redactOpaqueMachineValues("- errorMsg: \"\"\n")
	if strings.Contains(standalone, "errorMsg") || !strings.Contains(standalone, "- 错误信息为空") {
		t.Fatalf("standalone dossier error field was not humanized: %q", standalone)
	}
	fieldList := redactOpaqueMachineValues("从运行结果中可以看到 errorMsg、elapsedMs、okCount、failedCount 等字段。")
	for _, forbidden := range []string{"errorMsg", "elapsedMs", "okCount", "failedCount"} {
		if strings.Contains(fieldList, forbidden) {
			t.Fatalf("dossier field list leaked %q: %q", forbidden, fieldList)
		}
	}
	for _, expected := range []string{"错误信息", "耗时", "成功记录数", "失败记录数"} {
		if !strings.Contains(fieldList, expected) {
			t.Fatalf("dossier field list lost %q: %q", expected, fieldList)
		}
	}
	fieldList = redactOpaqueMachineValues("完整记录包括 executionId、functionId、versionId、conversationId 等标识符。")
	for _, forbidden := range []string{"executionId", "functionId", "versionId", "conversationId"} {
		if strings.Contains(fieldList, forbidden) {
			t.Fatalf("execution dossier field list leaked %q: %q", forbidden, fieldList)
		}
	}
	for _, expected := range []string{"执行标识", "函数标识", "版本标识", "会话标识"} {
		if !strings.Contains(fieldList, expected) {
			t.Fatalf("execution dossier field list lost %q: %q", expected, fieldList)
		}
	}
}

func TestTextRedactorHumanizesSplitEnglishDossierErrorField(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"函数运行成功了。\n- error",
		"Msg: \"\"\n- elapsedMs: 114\n",
	} {
		piece := redactor.Write(delta)
		if strings.Contains(piece, "errorMsg") {
			t.Fatalf("split English dossier error field flashed live: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "errorMsg") || !strings.Contains(got.String(), "错误信息为空") {
		t.Fatalf("split English dossier error field was not humanized: %q", got.String())
	}
}

func TestTextRedactorRemovesStandaloneChineseCreationTimePlaceholder(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"时间戳\n记录创建",
		"时间:相应时间\n",
	} {
		piece := redactor.Write(delta)
		if strings.Contains(piece, "记录创建时间") || strings.Contains(piece, "相应时间") {
			t.Fatalf("standalone creation-time placeholder flashed live: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "记录创建时间") || strings.Contains(got.String(), "相应时间") {
		t.Fatalf("standalone creation-time placeholder remained: %q", got.String())
	}
}

func TestTextRedactorHumanizesSplitEnglishDossierFieldList(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"运行结果包含 error",
		"Msg、elapsed",
		"Ms、okCount、failedCount 字段。\n",
	} {
		piece := redactor.Write(delta)
		for _, forbidden := range []string{"errorMsg", "elapsedMs", "okCount", "failedCount"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("split English dossier field leaked %q: %q", forbidden, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	for _, forbidden := range []string{"errorMsg", "elapsedMs", "okCount", "failedCount"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("split English dossier field remained %q: %q", forbidden, got.String())
		}
	}
}

func TestTextRedactorHoldsSplitEntityIDClauseWithoutLeadingSpace(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"I found it wi",
		"th id \"",
		"the requested item\"\n",
	} {
		piece := redactor.Write(delta)
		if strings.Contains(piece, "the requested item") {
			t.Fatalf("split entity-id placeholder leaked live: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "the requested item") {
		t.Fatalf("split entity-id placeholder remained: %q", got.String())
	}
}

func TestTextRedactorHoldsEntityIDClauseAfterOpenPrefix(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"I found the function with ",
		"id \"the requested item\". Now I need to run it.\n",
	} {
		piece := redactor.Write(delta)
		if strings.Contains(piece, "the requested item") {
			t.Fatalf("open entity-id prefix leaked live placeholder: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "the requested item") {
		t.Fatalf("open entity-id prefix placeholder remained: %q", got.String())
	}
}

func TestRedactEnglishExecutionTimingTablePointsToExecutionCard(t *testing.T) {
	input := "| Field | Value |\n|---|---|\n" +
		"| Started At | the recorded time |\n" +
		"| Ended At | the recorded time |\n" +
		"| Elapsed | 133 ms |"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, opaqueTimestampPlaceholder) {
		t.Fatalf("execution timing placeholder leaked: %q", got)
	}
	if strings.Count(got, executionTimingTableHint) != 2 {
		t.Fatalf("execution timing rows did not point to the card: %q", got)
	}
	if !strings.Contains(got, "| Elapsed | 133 ms |") {
		t.Fatalf("execution timing lost elapsed value: %q", got)
	}
}

func TestStreamLLMRedactsEnglishExecutionTimingTable(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "| Field | Value |\n|---|---|\n| Started At | "},
		{Type: llminfra.EventText, Delta: "the recorded time |\n| Ended At | the recorded time |\n| Elapsed | 133 ms |\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if ok && strings.Contains(delta.Chunk, opaqueTimestampPlaceholder) {
			t.Fatalf("execution timing placeholder leaked in live delta: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 || strings.Contains(blocks[0].Content, opaqueTimestampPlaceholder) {
		t.Fatalf("execution timing placeholder leaked in durable block: %+v", blocks)
	}
	if strings.Count(blocks[0].Content, executionTimingTableHint) != 2 {
		t.Fatalf("execution timing durable rows did not point to the card: %q", blocks[0].Content)
	}
}

func TestTextRedactorHumanizesSplitExecutionDossierFieldList(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"完整记录包括 execution",
		"Id、functionId、versionId、conversation",
		"Id 等标识符。\n",
	} {
		piece := redactor.Write(delta)
		for _, forbidden := range []string{"executionId", "functionId", "versionId", "conversationId"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("split execution dossier field leaked %q: %q", forbidden, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	for _, forbidden := range []string{"executionId", "functionId", "versionId", "conversationId"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("split execution dossier field remained %q: %q", forbidden, got.String())
		}
	}
}

func TestTextRedactorDoesNotFlashPartialDossierRow(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"## 执行审计档案\n\n### 计时\n| 指标 | 值 |\n",
		"|---|---|\n",
		"| **耗时** | 135 毫秒 |\n",
		"| **记录",
		"\n### 关联上下文（Context）\n",
		"| 字段 | 值 |\n|---|---|\n",
		"\n---\n\n### 汇总\n\n",
		"- **错误信息**：无（执行成功，`errorMsg` 为空）\n",
	} {
		piece := redactor.Write(delta)
		if strings.Contains(piece, "| **记录") {
			t.Fatalf("partial dossier row flashed in live delta: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "| **记录") || strings.Contains(got.String(), "errorMsg") {
		t.Fatalf("partial/machine dossier content remained: %q", got.String())
	}
	if !strings.Contains(got.String(), "精确消息和工具调用见上方执行卡片") {
		t.Fatalf("dossier association lost honest pointer: %q", got.String())
	}
}

func TestTextRedactorDoesNotLeakSplitExecutionIDCodeSpan(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"The user wants the complete execution audit dossier. I have the execution ID",
		" `fne_b",
		"117e76c4f8ab92d",
		"`. ",
	} {
		piece := redactor.Write(delta)
		for _, forbidden := range []string{"fne_", "117e76", "e76c4f8ab92d"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("split execution ID leaked %q in live delta: %q", forbidden, piece)
			}
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fne_", "117e76", "e76c4f8ab92d"} {
		if strings.Contains(got.String(), forbidden) {
			t.Fatalf("split execution ID remained %q after flush: %q", forbidden, got.String())
		}
	}
}

func TestTextRedactorHoldsBoldDossierTableFragmentUntilRowBoundary(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"以下是本次执行的完整执行档案：\n\n| 字段 | 值 |\n|---|---|\n",
		"| **记录",
		"** | 精确消息和工具调用见上方执行卡片。 |\n",
	} {
		piece := redactor.Write(delta)
		if strings.Contains(piece, "| **记录") {
			t.Fatalf("bold dossier table fragment flashed in live delta: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if !strings.Contains(got.String(), "记录") {
		t.Fatalf("complete dossier table row was lost after flush: %q", got.String())
	}
}

func TestRedactChineseBareExecutionIDPlaceholderWithMarkdownQuotes(t *testing.T) {
	input := "我可以看到最新的执行 ID 是 `the requested item`。现在继续。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the requested item", "执行 ID 是"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("Chinese execution ID reasoning leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "执行 ID 已定位") || !strings.Contains(got, "现在继续。") {
		t.Fatalf("Chinese execution reasoning lost readable facts: %q", got)
	}
}

func TestStreamLLM_RedactsChineseBareExecutionIDAcrossChunks(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "我可以看到最新的执行 ID 是 `"},
		{Type: llminfra.EventReasoning, Delta: "the requested item`。现在继续。"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		if strings.Contains(delta.Chunk, opaqueEntityPlaceholder) || strings.Contains(delta.Chunk, "执行 ID 是") {
			t.Fatalf("live Chinese execution ID delta leaked placeholder: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("reasoning blocks = %+v", blocks)
	}
	got := blocks[0].Content
	if strings.Contains(got, opaqueEntityPlaceholder) || strings.Contains(got, "执行 ID 是") {
		t.Fatalf("durable Chinese execution ID reasoning leaked: %q", got)
	}
	if !strings.Contains(got, "执行 ID 已定位") || !strings.Contains(got, "现在继续。") {
		t.Fatalf("durable Chinese execution reasoning lost readable facts: %q", got)
	}
}

func TestRedactChineseAuditFieldsSplitAcrossLinesAndBareIDAssignments(t *testing.T) {
	input := "找到了 audit_logger，ID 为 the requested item。现在执行它。\n\n" +
		"执行 ID: \n" +
		"the requested item\n" +
		"版本 ID:\n" +
		"fnv_c981d57061196b07\n" +
		"开始时间: \n" +
		"相应时间\n" +
		"状态: ok\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"the requested item", "fnv_", "相应时间", "ID 为", "执行 ID:", "版本 ID:", "开始时间:",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("split Chinese audit field leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "ID 已定位") || !strings.Contains(got, "状态: ok") {
		t.Fatalf("split Chinese audit field lost readable facts: %q", got)
	}
}

func TestRedactChineseDossierPlaceholderTimelineRows(t *testing.T) {
	input := "| 字段 | 值 |\n|---|---|\n| **函数** | audit_logger |\n| **版本** | `the requested item` |\n| **状态** | ✅ **ok** |\n\n" +
		"| 事件 | 时间戳 |\n|---|---|\n| 开始 | `相应时间` |\n| 结束 | `相应时间` |\n| 耗时 | **139ms** |\n\n" +
		"| 时间点 | 值 |\n|---|---|\n| 开始时间 | `相应时间` |\n| 结束时间 | `相应时间` |\n| 耗时 | **139ms** |\n\n" +
		"⏱️ 计时\n\n| 指标 | 值 |\n|---|---|\n| 耗时 | 139ms |\n| 开始时间 | `相应时间` |\n| 结束时间 | `相应时间` |\n\n" +
		"| 字段 | 值 |\n|---|---|\n| **记录创建时间** | `相应时间` |"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the requested item", "相应时间", "**版本**", "| 开始 |", "| 结束 |", "记录创建时间"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("dossier timeline placeholder leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "audit_logger") || !strings.Contains(got, "139ms") {
		t.Fatalf("dossier timeline lost readable facts: %q", got)
	}
}

func TestRedactChineseDossierTimingRowsWithoutTableContext(t *testing.T) {
	input := "| **开始时间** | `相应时间` |\n\n| **结束时间** | `相应时间` |\n| **耗时** | **286 ms** |\n"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "开始时间") || strings.Contains(got, "结束时间") || strings.Contains(got, "相应时间") {
		t.Fatalf("uncontextualized dossier timing rows leaked: %q", got)
	}
	if !strings.Contains(got, "286 ms") {
		t.Fatalf("uncontextualized dossier timing rows lost elapsed time: %q", got)
	}
}

func TestRedactEnglishNamedIDPlaceholderAssignment(t *testing.T) {
	input := "I found the function; its id is `the requested item`.\n"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "the requested item") {
		t.Fatalf("English named ID placeholder leaked: %q", got)
	}
	if !strings.Contains(got, "its id is shown in the adjacent result card") {
		t.Fatalf("English named ID lost its honest pointer: %q", got)
	}
}

func TestRedactEnglishGenericDossierPlaceholders(t *testing.T) {
	input := "I found the function: `the requested item` named `audit_logger`.\n" +
		"The function ID is `the requested item`.\n"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "the requested item") {
		t.Fatalf("generic dossier placeholder leaked: %q", got)
	}
	if !strings.Contains(got, "I found the function named `audit_logger`.") ||
		!strings.Contains(got, "The function ID is shown in the adjacent result card.") {
		t.Fatalf("generic dossier placeholder lost readable context: %q", got)
	}
}

func TestRedactChineseInlineAuditMachineField(t *testing.T) {
	input := "从搜索结果中，我得到了执行 ID: the requested item\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"执行 ID:", "the requested item"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("inline Chinese audit field leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "我得到了执行记录（精确 ID 见相邻执行卡）") {
		t.Fatalf("inline Chinese audit field lost readable pointer: %q", got)
	}
}

func TestRedactChineseDossierPointerRows(t *testing.T) {
	input := "| 字段 | 值 |\n|---|---|\n" +
		"| **函数** | audit_logger |\n" +
		"| **消息** | `the requested item` |\n" +
		"| **工具调用** | `blk_1234567890abcdef` |\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the requested item", "blk_1234567890abcdef"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("dossier pointer row leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"See the exact message in the execution card.",
		"See the exact tool call in the execution card.",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("dossier pointer row lost %q: %q", expected, got)
		}
	}
}

func TestRedactEnglishDossierPointerRows(t *testing.T) {
	input := "### Provenance (Tool-Call Details)\n| Field | Value |\n|---|---|\n" +
		"| **Conversation ID** | `the requested item` |\n" +
		"| **Message ID** | `the requested item` |\n" +
		"| **Tool Call ID** | `the requested item` |"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the requested item", "Conversation ID", "Message ID", "Tool Call ID"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("English dossier pointer leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"See the exact conversation in the execution card.",
		"See the exact message in the execution card.",
		"See the exact tool call in the execution card.",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("English dossier pointer lost %q: %q", expected, got)
		}
	}
}

func TestRedactEmptyChineseProvenanceDossierSection(t *testing.T) {
	input := "## 执行审计档案\n\n### 溯源信息 (Provenance)\n| 字段 | 值 |\n|---|---|\n\n---\n"
	got := redactOpaqueMachineValues(input)
	if !strings.Contains(got, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("empty provenance table lost adjacent-card pointer: %q", got)
	}
}

func TestStreamLLMRedactsEnglishDossierPointerRows(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "### Provenance (Tool-Call Details)\n| Field | Value |\n|---|---|\n"},
		{Type: llminfra.EventText, Delta: "| **Conversation ID** | `the requested item` |\n| **Message ID** | `the requested item` |\n"},
		{Type: llminfra.EventText, Delta: "| **Tool Call ID** | `the requested item` |\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"the requested item", "Conversation ID", "Message ID", "Tool Call ID"} {
			if strings.Contains(delta.Chunk, forbidden) {
				t.Fatalf("English dossier pointer leaked %q in live delta: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 1 {
		t.Fatalf("English dossier pointer blocks = %+v", blocks)
	}
	for _, forbidden := range []string{"the requested item", "Conversation ID", "Message ID", "Tool Call ID"} {
		if strings.Contains(blocks[0].Content, forbidden) {
			t.Fatalf("English dossier pointer leaked %q in durable block: %q", forbidden, blocks[0].Content)
		}
	}
}

func TestRedactEnglishDossierIdentityRows(t *testing.T) {
	input := "## Execution Audit Dossier\n| Field | Value |\n|---|---|\n" +
		"| **Execution ID** | `the requested item` |\n" +
		"| **Function ID** | `the requested item` |\n" +
		"| **Version ID** | `the requested item` |\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the requested item", "Execution ID", "Function ID", "Version ID"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("English dossier identity row leaked %q: %q", forbidden, got)
		}
	}
}

func TestRedactEnglishDossierIdentityRowFragment(t *testing.T) {
	input := "| **Execution ID** | `the requested item` |\n"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "the requested item") || strings.Contains(got, "Execution ID") {
		t.Fatalf("English dossier identity fragment leaked: %q", got)
	}
}

func TestStreamLLMRedactsSplitEnglishDossierIdentityRows(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "## Execution Audit Dossier\n| Field | Value |\n|---|---|\n| **"},
		{Type: llminfra.EventText, Delta: "Execution ID** | `the requested item` |\n| **Function ID** | `the requested item` |\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"the requested item", "Execution ID", "Function ID"} {
			if strings.Contains(delta.Chunk, forbidden) {
				t.Fatalf("split English dossier identity leaked %q in live delta: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 1 {
		t.Fatalf("split English dossier identity blocks = %+v", blocks)
	}
	for _, forbidden := range []string{"the requested item", "Execution ID", "Function ID"} {
		if strings.Contains(blocks[0].Content, forbidden) {
			t.Fatalf("split English dossier identity leaked %q in durable block: %q", forbidden, blocks[0].Content)
		}
	}
}

func TestRedactEnglishDossierFieldLines(t *testing.T) {
	input := "The user wants the complete execution audit dossier.\n" +
		"- functionId: from the search result\n" +
		"- executionId: from the run result\n" +
		"I do not see an executionId in the result.\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"functionId:", "executionId:", "executionId"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("English dossier field line leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "函数标识：from the search result") ||
		!strings.Contains(got, "执行标识：from the run result") ||
		!strings.Contains(got, "execution record reference in the result") {
		t.Fatalf("English dossier field line lost readable meaning: %q", got)
	}
}

func TestRedactChineseDossierFieldLines(t *testing.T) {
	input := "## 执行审计档案\n### 工具调用详情\n" +
		"- **触发方式**: chat（聊天触发）\n" +
		"- **执行 ID**: 见上方工具卡片\n" +
		"- **函数版本 ID**: 见上方工具卡片\n" +
		"- **会话 ID**: 见上方工具卡片\n" +
		"- **消息 ID**: 见上方工具卡片\n" +
		"- **工具调用 ID**: 见上方工具卡片\n" +
		"我没有看到 executionId，也没有看到 toolCallId。\n"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"执行 ID", "函数版本 ID", "会话 ID", "消息 ID", "工具调用 ID", "executionId", "toolCallId"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("Chinese dossier machine field leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"本次执行", "函数版本", "当前会话", "当前消息", "工具调用"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("Chinese dossier field lost human label %q: %q", expected, got)
		}
	}
}

func TestTextRedactorDoesNotFlashChineseDossierBulletPrefix(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"## 执行审计档案\n\n### 时间线\n- **",
		"开始时间**: 相应时间\n### 输入参数\n",
	} {
		piece := redactor.Write(delta)
		if strings.Contains(piece, "- **") {
			t.Fatalf("Chinese dossier bullet prefix flashed in live delta: %q", piece)
		}
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "- **") || strings.Contains(got.String(), "相应时间") {
		t.Fatalf("Chinese dossier bullet/timing residue remained: %q", got.String())
	}
}

func TestStreamLLMRedactsDossierFieldsAfterContextDelta(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "用户要求查看完整的执行审计档案，包括输入和工具调用详情。"},
		{Type: llminfra.EventReasoning, Delta: "我没有看到 executionId，也没有看到 toolCallId。"},
		{Type: llminfra.EventText, Delta: "## 执行审计档案\n### 工具调用详情\n- **执行 ID**: "},
		{Type: llminfra.EventText, Delta: "见上方工具卡片\n- **函数版本 ID**: 见上方工具卡片\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"executionId", "toolCallId", "执行 ID", "函数版本 ID"} {
			if strings.Contains(delta.Chunk, forbidden) {
				t.Fatalf("dossier field leaked %q in live delta: %q", forbidden, delta.Chunk)
			}
		}
		if strings.Contains(delta.Chunk, "- **\n") || strings.HasSuffix(delta.Chunk, "- **") {
			t.Fatalf("dossier bullet prefix leaked in live delta: %q", delta.Chunk)
		}
	}
	for _, block := range blocks {
		for _, forbidden := range []string{"executionId", "toolCallId", "执行 ID", "函数版本 ID"} {
			if strings.Contains(block.Content, forbidden) {
				t.Fatalf("dossier field leaked %q in durable block: %q", forbidden, block.Content)
			}
		}
		if strings.Contains(block.Content, "- **\n") || strings.HasSuffix(block.Content, "- **") {
			t.Fatalf("dossier bullet prefix leaked in durable block: %q", block.Content)
		}
	}
}

func TestRedactEmptyChineseToolCallDossierSection(t *testing.T) {
	input := "### 工具调用详情 (Tool-Call Details)\n" +
		"| 字段 | 值 |\n|------|-----|\n\n" +
		"### 汇总统计\n- 总执行次数：1\n"
	got := redactOpaqueMachineValues(input)
	if !strings.Contains(got, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("empty tool-call dossier section lost honest pointer: %q", got)
	}
}

func TestRedactEmptyChineseToolCallDossierListSection(t *testing.T) {
	input := "## 执行审计档案\n\n## 消息与工具调用详情\n- 对话已定位\n\n## 执行统计\n该函数共有 1 次执行记录。"
	got := redactOpaqueMachineValues(input)
	if !strings.Contains(got, "- 对话已定位") ||
		!strings.Contains(got, "- 精确消息和工具调用见上方执行卡片。") {
		t.Fatalf("location-only dossier list lost honest pointer: %q", got)
	}
}

func TestRedactEmptyChineseAssociationDossierSection(t *testing.T) {
	input := "## 执行审计档案\n\n### 关联标识\n\n| 字段 | 值 |\n|---|---|\n"
	got := redactOpaqueMachineValues(input)
	if !strings.Contains(got, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("empty association dossier section lost honest pointer: %q", got)
	}
	input = "## 执行审计档案\n\n### 关联上下文\n\n| 字段 | 值 |\n|---|---|\n"
	got = redactOpaqueMachineValues(input)
	if !strings.Contains(got, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("empty association context section lost honest pointer: %q", got)
	}
	input = "## 执行审计档案\n\n### 关联信息\n\n| 字段 | 值 |\n|---|---|\n"
	got = redactOpaqueMachineValues(input)
	if !strings.Contains(got, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("empty association info section lost honest pointer: %q", got)
	}
}

func TestTextRedactorHoldsEmptyAssociationDossierTableUntilClose(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	got.WriteString(redactor.Write("## 执行审计档案\n\n### 关联标识\n\n"))
	got.WriteString(redactor.Write("| 字段 | 值 |\n|---|---|\n"))
	if strings.Contains(got.String(), "| 字段 | 值 |") {
		t.Fatalf("empty association table flashed before close: %q", got.String())
	}
	got.WriteString(redactor.Flush())
	if !strings.Contains(got.String(), "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("empty association table lost close pointer: %q", got.String())
	}
	var infoRedactor textRedactor
	var info strings.Builder
	info.WriteString(infoRedactor.Write("## 执行审计档案\n\n### 关联信息\n\n"))
	info.WriteString(infoRedactor.Write("| 字段 | 值 |\n|---|---|\n"))
	if strings.Contains(info.String(), "| 字段 | 值 |") {
		t.Fatalf("empty association info table flashed before close: %q", info.String())
	}
	info.WriteString(infoRedactor.Flush())
	if !strings.Contains(info.String(), "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("empty association info table lost close pointer: %q", info.String())
	}
}

func TestTextRedactorRemovesChineseTimingPlaceholderAcrossChunks(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"### ⏱️ 计时\n",
		"| 指标 | 值 |\n|---|---|\n",
		"| **开始时间** | `相应时间` |\n",
		"| **结束时间** | `相应时间` |\n",
		"| **耗时** | **286 毫秒** |\n",
	} {
		piece := redactor.Write(delta)
		got.WriteString(piece)
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "相应时间") || strings.Contains(got.String(), "开始时间") || strings.Contains(got.String(), "结束时间") {
		t.Fatalf("streamed Chinese timing placeholder leaked: %q", got.String())
	}
	if !strings.Contains(got.String(), "286 毫秒") {
		t.Fatalf("streamed Chinese timing lost elapsed value: %q", got.String())
	}
	var extra textRedactor
	extraOutput := extra.Write("| **开始时间** | `相应时间` |\n\n") + extra.Flush()
	if strings.Contains(extraOutput, "相应时间") || strings.Contains(extraOutput, "开始时间") {
		t.Fatalf("streamed timing row with trailing blank leaked: %q", extraOutput)
	}
}

func TestStreamLLMRemovesChineseTimingPlaceholderWithTrailingBlank(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "### 时间线\n| 时间点 | 值 |\n|---|---|\n| 开始时间 | `相应时间` |\n\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		if strings.Contains(delta.Chunk, "相应时间") || strings.Contains(delta.Chunk, "开始时间") {
			t.Fatalf("live stream timing placeholder leaked: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 || strings.Contains(blocks[0].Content, "相应时间") || strings.Contains(blocks[0].Content, "开始时间") {
		t.Fatalf("durable stream timing placeholder leaked: %+v", blocks)
	}
}

func TestTextRedactorRemovesChineseTimingAfterIncrementalDossierChunks(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"## audit_logger ", "完整执行档案\n\n### ", "基本信息\n",
		"| 字段 | 值 |\n|---|---|\n| 状态 | ✅ **ok** |\n",
		"\n### 输入 / 输出\n", "- **输出**: `{\"items\": [1, 2, 3]}`\n\n### ",
		"时间线\n", "| 时间点 | 值 |\n", "|---|---|\n",
		"| 开始时间 | `相应时间` |\n", "| 结束时间 | `相应时间` |\n",
		"| 记录", "| 耗时 | **119 ms** |\n\n### 日志\n",
	} {
		got.WriteString(redactor.Write(delta))
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "相应时间") || strings.Contains(got.String(), "开始时间") || strings.Contains(got.String(), "结束时间") {
		t.Fatalf("incremental dossier timing placeholder leaked: %q", got.String())
	}
}

func TestTextRedactorRemovesChineseIDPlaceholderAcrossChunks(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"audit_logger 函数，",
		"ID 是 ",
		"the requested item。\n\n",
		"现在我需要：\n",
	} {
		got.WriteString(redactor.Write(delta))
	}
	got.WriteString(redactor.Flush())
	if strings.Contains(got.String(), "the requested item") {
		t.Fatalf("split Chinese ID placeholder leaked: %q", got.String())
	}
	if !strings.Contains(got.String(), "ID 已定位") {
		t.Fatalf("split Chinese ID lost its honest replacement: %q", got.String())
	}
}

func TestTextRedactorHandlesActualExecutionDossierChunkBoundaries(t *testing.T) {
	var redactor textRedactor
	var got strings.Builder
	for _, delta := range []string{
		"## audit_logger ",
		"完整执行档案\n\n### ",
		"基本信息\n",
		"| 字段 | 值 |\n|---|---|\n| 状态 | ✅ **ok** |\n",
		"\n### 输入 / 输出\n",
		"- **输出**: `{\"items\": [1, 2, 3]}`\n\n### ",
		"时间线\n",
		"| 时间点 | 值 |\n",
		"|---|---|\n",
		"| 开始时间 | `相应时间` |\n",
		"| 结束时间 | `相应时间` |\n",
		"| 记录",
		"| 耗时 | **119 ms** |\n\n### 日志\n",
		"```\naudit-start\naudit-finish\n```\n\n### 关联上下文\n",
		"| 字段 | 值 |\n|---|---|\n",
		"\n### 错误信息\n",
	} {
		got.WriteString(redactor.Write(delta))
	}
	got.WriteString(redactor.Flush())
	output := got.String()
	if strings.Contains(output, "相应时间") || strings.Contains(output, "| 开始时间 |") || strings.Contains(output, "| 结束时间 |") {
		t.Fatalf("actual dossier timing placeholder leaked: %q", output)
	}
	if strings.Contains(output, "| 字段 | 值 |\n|---|---|") && !strings.Contains(output, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("actual empty association table remained opaque: %q", output)
	}
	if !strings.Contains(output, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("actual empty association section lost its honest pointer: %q", output)
	}
}

func TestStreamLLMRedactsCompactChineseDossierFieldRows(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "## audit_logger 完整执行审计档案\n\n"},
		{Type: llminfra.EventText, Delta: "**执行 ID:** the requested item\n\n"},
		{Type: llminfra.EventText, Delta: "### 基本信息\n"},
		{Type: llminfra.EventText, Delta: "- **函数 ID:** the requested item\n"},
		{Type: llminfra.EventText, Delta: "- **版本 ID:** the requested item\n"},
		{Type: llminfra.EventText, Delta: "- **状态:** ok ✓\n- **触发方式:** chat\n\n"},
		{Type: llminfra.EventText, Delta: "### 时间信息\n"},
		{Type: llminfra.EventText, Delta: "- **开始时间:**相应时间\n"},
		{Type: llminfra.EventText, Delta: "- **结束时间:**相应时间\n"},
		{Type: llminfra.EventText, Delta: "- **总耗时:** 133 毫秒\n\n"},
		{Type: llminfra.EventText, Delta: "### 追踪信息\n"},
		{Type: llminfra.EventText, Delta: "- **会话 ID:** the requested item\n"},
		{Type: llminfra.EventText, Delta: "- **消息 ID:** the requested item\n"},
		{Type: llminfra.EventText, Delta: "- **工具调用 ID:** the requested item\n\n"},
		{Type: llminfra.EventText, Delta: "函数成功执行，日志为 audit-start / audit-finish。\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"the requested item", "the referenced item", "相应时间", "执行 ID", "函数 ID", "版本 ID", "会话 ID", "消息 ID", "工具调用 ID"} {
			if strings.Contains(delta.Chunk, forbidden) {
				t.Fatalf("compact Chinese dossier leaked %q in live delta: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 1 {
		t.Fatalf("compact Chinese dossier blocks = %+v", blocks)
	}
	for _, forbidden := range []string{"the requested item", "the referenced item", "相应时间", "执行 ID", "函数 ID", "版本 ID", "会话 ID", "消息 ID", "工具调用 ID"} {
		if strings.Contains(blocks[0].Content, forbidden) {
			t.Fatalf("compact Chinese dossier leaked %q in durable block: %q", forbidden, blocks[0].Content)
		}
	}
	if !strings.Contains(blocks[0].Content, "133 毫秒") || !strings.Contains(blocks[0].Content, "audit-start") {
		t.Fatalf("compact Chinese dossier lost readable facts: %q", blocks[0].Content)
	}
}

func TestStreamLLMRedactsFoundPlaceholderAcrossChunks(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "I found "},
		{Type: llminfra.EventReasoning, Delta: "it: `"},
		{Type: llminfra.EventReasoning, Delta: "the requested item`. Now I need to run it.\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if ok && strings.Contains(delta.Chunk, "the requested item") {
			t.Fatalf("found placeholder leaked in live reasoning: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 {
		t.Fatalf("found placeholder blocks = %+v", blocks)
	}
	if strings.Contains(blocks[0].Content, "the requested item") || !strings.Contains(blocks[0].Content, "I found it") {
		t.Fatalf("found placeholder was not honestly rewritten: %q", blocks[0].Content)
	}
}

func TestStreamLLMRedactsChineseSearchIDWithTrailingSentence(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "找到了，audit_logger"},
		{Type: llminfra.EventText, Delta: "的 ID 是 `the requested item`。现在执行它。\n\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if ok && (strings.Contains(delta.Chunk, "the requested item") || strings.Contains(delta.Chunk, "ID 是")) {
			t.Fatalf("Chinese search ID leaked in live text: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 {
		t.Fatalf("Chinese search ID blocks = %+v", blocks)
	}
	if strings.Contains(blocks[0].Content, "the requested item") || strings.Contains(blocks[0].Content, "ID 是") {
		t.Fatalf("Chinese search ID leaked in durable text: %q", blocks[0].Content)
	}
	if !strings.Contains(blocks[0].Content, "ID 已定位") || !strings.Contains(blocks[0].Content, "现在执行它") {
		t.Fatalf("Chinese search ID lost readable facts: %q", blocks[0].Content)
	}
}

func TestStreamLLMRedactsChineseSearchIDWithQuotedEntity(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventText, Delta: "找到了，`"},
		{Type: llminfra.EventText, Delta: "audit_logger` "},
		{Type: llminfra.EventText, Delta: "的 ID 是 `the requested item`。现在执行它。\n\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if ok && (strings.Contains(delta.Chunk, "the requested item") || strings.Contains(delta.Chunk, "ID 是")) {
			t.Fatalf("quoted Chinese search ID leaked in live text: %q", delta.Chunk)
		}
	}
	if len(blocks) != 1 {
		t.Fatalf("quoted Chinese search ID blocks = %+v", blocks)
	}
	if strings.Contains(blocks[0].Content, "the requested item") || strings.Contains(blocks[0].Content, "ID 是") {
		t.Fatalf("quoted Chinese search ID leaked in durable text: %q", blocks[0].Content)
	}
	if !strings.Contains(blocks[0].Content, "ID 已定位") || !strings.Contains(blocks[0].Content, "现在执行它") {
		t.Fatalf("quoted Chinese search ID lost readable facts: %q", blocks[0].Content)
	}
}

func TestStreamLLMRedactsObservedRunDossierPlaceholders(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The function was found — done, it's `the requested item`"},
		{Type: llminfra.EventReasoning, Delta: ". I have the execution ID `the requested item`."},
		{Type: llminfra.EventText, Delta: "找到了，函数名为 **audit_logger**，ID 为 `the requested item`。现在先查看其完整定义，然后执行它。\n\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if ok && (strings.Contains(delta.Chunk, opaqueEntityPlaceholder) || strings.Contains(delta.Chunk, legacyEntityPlaceholder)) {
			t.Fatalf("observed run-dossier placeholder leaked in live stream: %q", delta.Chunk)
		}
	}
	if len(blocks) != 2 {
		t.Fatalf("observed run-dossier blocks = %+v", blocks)
	}
	for _, block := range blocks {
		if strings.Contains(block.Content, opaqueEntityPlaceholder) || strings.Contains(block.Content, legacyEntityPlaceholder) {
			t.Fatalf("observed run-dossier placeholder leaked in durable block: %q", block.Content)
		}
	}
	if !strings.Contains(blocks[1].Content, "函数名为 **audit_logger**") || !strings.Contains(blocks[1].Content, "ID 已定位") {
		t.Fatalf("observed Chinese search result lost readable context: %q", blocks[1].Content)
	}
}

func TestStreamLLMRedactsR25RunDossierWireShapes(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "I found the function: id is \""},
		{Type: llminfra.EventReasoning, Delta: "the requested item\", name is \"audit_logger\".\n"},
		{Type: llminfra.EventReasoning, Delta: "I found it: the requested item. Now I need to run it.\n"},
		{Type: llminfra.EventReasoning, Delta: "1. 找到函数 ✓ (已找到 the requested item)\n现在我有了执行 ID \"the requested item\"，继续读取记录。\n"},
		{Type: llminfra.EventText, Delta: "## 执行审计档案\n\n| 字段 | 详情 |\n|---|---|\n| **执行 ID** | `the requested item` |\n| **函数 ID** | `the requested item` |\n| **版本 ID** | `the requested item` |\n| **状态** | ✅ **ok**（成功） |\n| **触发方式** | chat（对话触发） |\n\n### 时间线\n| 时间点 | 值 |\n|---|---|\n| **耗时** | **136 ms** |\n"},
		{Type: llminfra.EventText, Delta: "| **开始时间** | `相应时间` |\n"},
		{Type: llminfra.EventText, Delta: "| **结束时间** | `相应时间` |\n\n### 关联追踪\n| 字段 | 值 |\n|---|---|\n"},
		{Type: llminfra.EventText, Delta: "| **对话 ID** | `the requested item` |\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"the requested item", "相应时间", "开始时间", "结束时间", "对话 ID"} {
			if strings.Contains(delta.Chunk, forbidden) {
				t.Fatalf("r25 wire shape leaked %q in live delta: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 2 {
		t.Fatalf("r25 wire shape blocks = %+v", blocks)
	}
	for _, block := range blocks {
		for _, forbidden := range []string{"the requested item", "相应时间", "开始时间", "结束时间", "对话 ID"} {
			if strings.Contains(block.Content, forbidden) {
				t.Fatalf("r25 wire shape leaked %q in durable block: %q", forbidden, block.Content)
			}
		}
	}
	if !strings.Contains(blocks[1].Content, "136 ms") {
		t.Fatalf("r25 wire shape lost elapsed time: %q", blocks[1].Content)
	}
	if !strings.Contains(blocks[1].Content, "| **状态** | ✅ **ok**（成功） |") ||
		!strings.Contains(blocks[1].Content, "| **触发方式** | chat（对话触发） |") {
		t.Fatalf("r25 wire shape lost readable dossier fields: %q", blocks[1].Content)
	}
	if !strings.Contains(blocks[1].Content, "| 详情 | 精确消息和工具调用见上方执行卡片。 |") {
		t.Fatalf("r25 wire shape lost empty association pointer: %q", blocks[1].Content)
	}
}

func TestStreamLLMRedactsObservedExecutionIDReleaseChunks(t *testing.T) {
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	for name, script := range map[string][]llminfra.StreamEvent{
		"english": {
			{Type: llminfra.EventReasoning, Delta: "The user wants the complete execution audit dossier. I have"},
			{Type: llminfra.EventReasoning, Delta: " the execution ID `"},
			{Type: llminfra.EventReasoning, Delta: "the requested item`. Now I "},
			{Type: llminfra.EventReasoning, Delta: "need to call `get_function_execution` to get the full record including logs and all details"},
			finishEv(),
		},
		"chinese-camel-case": {
			{Type: llminfra.EventReasoning, Delta: "我已经有了 search_function_executions 的结果，显示最近一次执行的 ID 已定位。现在我需要使用 get_function_execution 来获取完整的执行记录。\n\n"},
			{Type: llminfra.EventReasoning, Delta: "get_function_execution 需要 executionId "},
			{Type: llminfra.EventReasoning, Delta: "参数，我已经有了："},
			{Type: llminfra.EventReasoning, Delta: "the requested item"},
			finishEv(),
		},
	} {
		client := &fakeClient{scripts: [][]llminfra.StreamEvent{script}}
		bridge := &captureBridge{}
		blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
		for _, event := range bridge.events {
			delta, ok := event.Frame.(streamdomain.Delta)
			if ok && (strings.Contains(delta.Chunk, opaqueEntityPlaceholder) || strings.Contains(delta.Chunk, legacyEntityPlaceholder)) {
				t.Fatalf("%s execution-ID release leaked placeholder in live delta: %q", name, delta.Chunk)
			}
		}
		if len(blocks) != 1 {
			t.Fatalf("%s blocks = %+v", name, blocks)
		}
		if strings.Contains(blocks[0].Content, opaqueEntityPlaceholder) || strings.Contains(blocks[0].Content, legacyEntityPlaceholder) {
			t.Fatalf("%s execution-ID release leaked placeholder in durable block: %q", name, blocks[0].Content)
		}
	}
}

func TestRedactReasoningDoesNotExposeHypotheticalOrLocatedIDs(t *testing.T) {
	input := "The actual ID (which would be something like `the requested item`) is not needed.\n" +
		"The execution failed (which should be something like `the requested item`).\n" +
		"The actual function ID (which would be something like `the requested item`).\n" +
		"找到了 audit_logger 的 ID：the requested item。现在执行它。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"the requested item", "the referenced item", "which would be something like", "which should be something like"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("reasoning ID placeholder leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "找到了 audit_logger 的 ID 已定位") || !strings.Contains(got, "The actual ID") {
		t.Fatalf("reasoning lost readable context: %q", got)
	}
}

func TestStreamLLM_RedactsSplitHypotheticalIDPlaceholder(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The execution failed (which should be something like `"},
		{Type: llminfra.EventReasoning, Delta: "the requested item`). Let me search again."},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{"the requested item", "which should be something like"} {
			if strings.Contains(delta.Chunk, forbidden) {
				t.Fatalf("live hypothetical reasoning leaked %q: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("reasoning blocks = %+v", blocks)
	}
	if blocks[0].Content != "The execution failed. Let me search again." {
		t.Fatalf("durable hypothetical reasoning = %q", blocks[0].Content)
	}
}

func TestStreamLLM_RedactsRunDossierPlaceholdersAcrossChunks(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		{Type: llminfra.EventReasoning, Delta: "The actual function ID (which would be something like `"},
		{Type: llminfra.EventReasoning, Delta: "the requested item`). I found the latest execution ID `the requested item`.\n"},
		{Type: llminfra.EventText, Delta: "好的，以下是完整执行档案：\n\n- **执行 ID**: `"},
		{Type: llminfra.EventText, Delta: "the requested item`  \n- **版本 ID**: `the requested item`  \n- **会话 ID**: `the requested item`\n- **工具调用 ID**: `the requested item`\n\n| 字段 | 值 |\n|---|---|\n| **消息** | `the requested item` |\n| **工具调用** | `blk_1234567890abcdef` |\n\n日志：audit-finish\n"},
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	bridge := &captureBridge{}
	blocks, _, _, _, _, _ := streamLLM(streamCtx(bridge), client, llminfra.Request{}, noBuild, nil)
	for _, event := range bridge.events {
		delta, ok := event.Frame.(streamdomain.Delta)
		if !ok {
			continue
		}
		for _, forbidden := range []string{
			"the requested item", "the referenced item", "which would be something like",
			"执行 ID", "版本 ID", "会话 ID", "工具调用 ID",
		} {
			if strings.Contains(strings.ToLower(delta.Chunk), strings.ToLower(forbidden)) {
				t.Fatalf("live run dossier leaked %q: %q", forbidden, delta.Chunk)
			}
		}
	}
	if len(blocks) != 2 {
		t.Fatalf("run dossier blocks = %+v", blocks)
	}
	for _, block := range blocks {
		for _, forbidden := range []string{"the requested item", "the referenced item", "which would be something like", "执行 ID", "版本 ID", "会话 ID", "工具调用 ID"} {
			if strings.Contains(strings.ToLower(block.Content), strings.ToLower(forbidden)) {
				t.Fatalf("durable run dossier leaked %q: %q", forbidden, block.Content)
			}
		}
	}
	if !strings.Contains(blocks[1].Content, "日志：audit-finish") {
		t.Fatalf("run dossier lost readable log content: %q", blocks[1].Content)
	}
}

func TestTextRedactorRedactsHostedFunctionFailureChunking(t *testing.T) {
	chunks := []string{
		"调用 `get_function",
		"` 并传入",
		" `fn",
		"_000",
		"0",
		"0000",
		"0000",
		"0000",
		"` 后，",
		"返回了 **\"function",
		" not found\"**",
		"。\n\n**实际",
		"失败原因：** ",
		"该",
		"函数 ID `fn",
		"_00",
		"0000",
		"0000",
		"0",
		"0000",
		"0` 在工作",
		"区中并不存在",
		"。",
		"这是一个格式合法但",
		"虚构",
		"的 ID——当前",
		"工作区里没有任何",
		"函数与此",
		" ID 对应，",
		"因此系统无法",
		"查找到对应的函数",
		"记录",
		"，直接返回了",
		"\"未",
		"找到\"的错误。",
		"\n\n",
		"如需查看当前已有的",
		"函数，可以使用 `search_function`",
		"（不传 query 即可列出全部）",
		"来确认实际存在的函数 ID。",
	}
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range chunks {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "并传入的"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("hosted failure leaked %q in live delta %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "并传入的"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("hosted failure leaked %q in live stream %q", forbidden, live.String())
		}
	}
	for _, expected := range []string{"调用 `get_function` 后", "该函数在工作区中并不存在", "当前工作区里没有任何函数与之对应"} {
		if !strings.Contains(live.String(), expected) {
			t.Fatalf("hosted failure lost readable wording %q: %q", expected, live.String())
		}
	}
}

func TestRedactChineseFunctionSuggestionDropsMachineIDLabel(t *testing.T) {
	got := redactOpaqueMachineValues("如需查看当前已有的函数，可以使用 `search_function` 来确认实际存在的函数 ID。")
	if strings.Contains(got, "函数 ID") {
		t.Fatalf("function suggestion leaked machine label: %q", got)
	}
	if !strings.Contains(got, "确认实际存在的函数") {
		t.Fatalf("function suggestion lost readable wording: %q", got)
	}
}

func TestTextRedactorRedactsChineseCreationFailureChunking(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"失败原因：该输入在系统中并不存在。由于 `fn_",
		"0000000000000000",
		"` 从未被创建",
		"过，系统无法找到对应的函数记录。",
	} {
		piece := redactor.Write(chunk)
		if strings.Contains(piece, "该目标") || strings.Contains(piece, "fn_") {
			t.Fatalf("creation failure leaked redaction artifact: %q", piece)
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"该目标", "fn_", "the requested item", "函数 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("creation failure leaked %q: %q", forbidden, live.String())
		}
	}
	if !strings.Contains(live.String(), "由于这个输入从未被创建过") {
		t.Fatalf("creation failure lost natural wording: %q", live.String())
	}
}

func TestTextRedactorRedactsChineseFunctionShapeChunking(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"get_function 要求传入一个真实已注册的函数 ID（形如 `fn",
		"_...`），而这个 ID 是虚构的，",
		"系统找不到对应的函数记录。",
	} {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "该目标", "函数 ID", "这个 ID"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("function-shape failure leaked %q in %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "该目标", "函数 ID", "这个 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("function-shape failure leaked %q: %q", forbidden, live.String())
		}
	}
	for _, expected := range []string{"函数标识", "这个输入尚未注册"} {
		if !strings.Contains(live.String(), expected) {
			t.Fatalf("function-shape failure lost readable wording %q: %q", expected, live.String())
		}
	}
}

func TestTextRedactorRedactsChineseFunctionReferenceVariants(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"然后用一个不存在但格式正确的 ID `the requested item",
		"` 来调用 get_function。",
		"而该 ID 对应的函数从未被创建过，因此返回失败。",
		"找到实际存在的 `the requested item` ID 后再调用 get_function。",
	} {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"the requested item", "该目标", "函数 ID", "这个 ID"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("function-reference variant leaked %q in %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"the requested item", "该目标", "函数 ID", "这个 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("function-reference variant leaked %q: %q", forbidden, live.String())
		}
	}
	for _, expected := range []string{"不存在但格式正确的标识来调用", "这个输入对应的函数从未被创建过", "找到实际存在的函数后再调用"} {
		if !strings.Contains(live.String(), expected) {
			t.Fatalf("function-reference variant lost readable wording %q: %q", expected, live.String())
		}
	}
}

func TestTextRedactorRedactsChineseIDFabricatedFunctionChunking(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"失败原因：该 ID `fn_0000000000000000` 是一个格式合法但并不存在的函数标识符。",
		"工作区中没有注册过这个 ID 对应的函数，所以系统无法找到。简而言之——ID 格式没问题。",
	} {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "该 ID", "这个 ID", "该目标", "函数 ID"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("fabricated-function explanation leaked %q in %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "该 ID", "这个 ID", "该目标", "函数 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("fabricated-function explanation leaked %q: %q", forbidden, live.String())
		}
	}
	for _, expected := range []string{"这个输入是一个格式合法但并不存在的函数标识符", "工作区中没有注册过与这个输入对应的函数", "简而言之——格式没问题"} {
		if !strings.Contains(live.String(), expected) {
			t.Fatalf("fabricated-function explanation lost readable wording %q: %q", expected, live.String())
		}
	}
}

func TestTextRedactorRedactsR24ChineseFailureChunking(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	chunks := []string{
		"用户要求我调用 get_function，使用一个不存在但格式正确的 ID：",
		"fn_0000000000000000",
		"。",
		"调用 `",
		"get_function` ",
		"时传入了 `",
		"fn",
		"_000",
		"0",
		"0000",
		"0000",
		"0000",
		"0000",
		"` 这个 ",
		"ID，系统返回了 **\"function not found\"**。",
	}
	for _, chunk := range chunks {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("r24 failure leaked %q in live delta %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("r24 failure leaked %q in live stream %q", forbidden, live.String())
		}
	}
	for _, expected := range []string{"使用一个不存在但格式正确的函数标识", "调用 `get_function` 后"} {
		if !strings.Contains(live.String(), expected) {
			t.Fatalf("r24 failure lost readable wording %q: %q", expected, live.String())
		}
	}
}

func TestTextRedactorRedactsBareMissingIDColonChunking(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"用户要求我调用 get_function，传入一个不存在但格式正确的 ID：",
		"fn_0000000000000000",
		"。不能重试。",
	} {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("bare missing-ID colon variant leaked %q in live delta %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("bare missing-ID colon variant leaked %q in live stream %q", forbidden, live.String())
		}
	}
	if !strings.Contains(live.String(), "传入一个不存在但格式正确的函数标识") {
		t.Fatalf("bare missing-ID colon variant lost readable wording: %q", live.String())
	}
}

func TestTextRedactorRedactsR26DirectCallVariants(t *testing.T) {
	tests := []struct {
		name   string
		chunks []string
		want   []string
	}{
		{
			name: "english exact id reference",
			chunks: []string{
				"Then call get_function with the exact ID ",
				"fn_0000000000000000",
				". Do not retry.",
			},
			want: []string{"with the exact function reference"},
		},
		{
			name: "chinese missing id direct call",
			chunks: []string{
				"然后用一个不存在但格式正确的 ID ",
				"fn_0000000000000000",
				" 调用 get_function。",
			},
			want: []string{"不存在但格式正确的函数标识调用"},
		},
		{
			name: "chinese fabricated id direct call",
			chunks: []string{
				"用这个虚构的标识 ",
				"fn_0000000000000000",
				" 调用 get_function。",
			},
			want: []string{"用一个不存在的函数标识调用"},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var redactor textRedactor
			var live strings.Builder
			for _, chunk := range tc.chunks {
				piece := redactor.Write(chunk)
				for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "这个 ID"} {
					if strings.Contains(piece, forbidden) {
						t.Fatalf("direct-call variant leaked %q in live delta %q", forbidden, piece)
					}
				}
				live.WriteString(piece)
			}
			live.WriteString(redactor.Flush())
			for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "这个 ID"} {
				if strings.Contains(live.String(), forbidden) {
					t.Fatalf("direct-call variant leaked %q in live stream %q", forbidden, live.String())
				}
			}
			for _, expected := range tc.want {
				if !strings.Contains(live.String(), expected) {
					t.Fatalf("direct-call variant lost readable wording %q: %q", expected, live.String())
				}
			}
		})
	}
}

func TestTextRedactorRedactsR27ProviderChunking(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"Then call get_function with",
		" the exact ID \"",
		"fn_00",
		"00",
		"0000",
		"0000",
		"0000",
		"0000",
		"\"\n",
		"3. Do not use any other tool.",
	} {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("r27 provider chunking leaked %q in live delta %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("r27 provider chunking leaked %q in live stream %q", forbidden, live.String())
		}
	}
	if !strings.Contains(live.String(), "with the exact function reference") {
		t.Fatalf("r27 provider chunking lost natural wording: %q", live.String())
	}
}

func TestTextRedactorRedactsR27ChineseModelVariants(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"然后用一个不存在的 ID `fn_0000000000000000` 调用 get_function。",
		"这个 ID `fn_0000000000000000` 在系统中并不存在。当前工作区里没有注册过对应这个 ID 的函数。",
		"`get_function` 要求传入的是一个真实存在的、已创建的函数 ID（格式为 `fn_` 前缀 + 实际分配的不透明标识符），而这里提供的是一个虚构的、全零的占位 ID，因此无法找到。",
		"如需获取真实函数的详情，可以先通过 `search_function` 查找现有函数，拿到正确的 `fn_...` ID 后再调用 `get_function`。",
	} {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "这个 ID", "对应这个 ID"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("r27 Chinese variant leaked %q in live delta %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "这个 ID", "对应这个 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("r27 Chinese variant leaked %q in live stream %q", forbidden, live.String())
		}
	}
	for _, expected := range []string{
		"一个不存在的函数标识调用",
		"这个输入在系统中并不存在",
		"当前工作区里没有注册过对应的函数",
		"格式合法",
		"拿到正确的函数后再调用",
	} {
		if !strings.Contains(live.String(), expected) {
			t.Fatalf("r27 Chinese variant lost readable wording %q: %q", expected, live.String())
		}
	}
}

func TestTextRedactorRedactsR28ProviderChunking(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"用户要求我调用 get",
		"_function，传入一个",
		"不存在",
		"但格式正确的 ID",
		"：",
		"fn_00",
		"00",
		"0000",
		"0000",
		"0000",
		"。",
		"记录的值。系统在",
		"根据该 ID ",
		"查找函数",
		"时，找不到任何匹配项。",
	} {
		piece := redactor.Write(chunk)
		for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "这个 ID", "该 ID"} {
			if strings.Contains(piece, forbidden) {
				t.Fatalf("r28 provider chunking leaked %q in live delta %q", forbidden, piece)
			}
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "函数 ID", "这个 ID", "该 ID"} {
		if strings.Contains(live.String(), forbidden) {
			t.Fatalf("r28 provider chunking leaked %q in live stream %q", forbidden, live.String())
		}
	}
	for _, expected := range []string{"传入一个不存在但格式正确的函数标识", "系统在根据这个输入查找函数"} {
		if !strings.Contains(live.String(), expected) {
			t.Fatalf("r28 provider chunking lost readable wording %q: %q", expected, live.String())
		}
	}
}

func TestTextRedactorRedactsR29ProviderVariants(t *testing.T) {
	tests := []struct {
		name   string
		chunks []string
		want   []string
	}{
		{
			name: "english nonexistent id reasoning",
			chunks: []string{
				"The user wants me to call get_function with the ",
				"nonexistent ID ",
				"the requested item.",
			},
			want: []string{"with the nonexistent function reference"},
		},
		{
			name: "chinese tool id assignment",
			chunks: []string{
				"调用 `get_function",
				"` 时传入",
				"的 ID 为 `",
				"fn_0000",
				"000000000000",
				"`，系统返回了失败。",
			},
			want: []string{"时传入的目标"},
		},
		{
			name: "chinese id format structure",
			chunks: []string{
				"它虽然格式上符合 `",
				"fn_",
				"` 前缀 + 16 位十六进制字符的 ID 结构，但实际上不存在。",
			},
			want: []string{"符合合法的函数标识格式"},
		},
		{
			name:   "chinese bare missing id label",
			chunks: []string{"这个 ID 并不存在于当前工作区的函数目录中。"},
			want:   []string{"这个输入并不存在于"},
		},
		{
			name:   "chinese natural function requirement",
			chunks: []string{"要成功获取函数信息，需要传入一个真实存在的函数 ID（例如工作区中的函数）。"},
			want:   []string{"需要传入一个真实存在的函数"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var redactor textRedactor
			var live strings.Builder
			for _, chunk := range tc.chunks {
				piece := redactor.Write(chunk)
				for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID", "functionId", "不透明 ID", "the ID shown in the adjacent result card"} {
					if strings.Contains(piece, forbidden) {
						t.Fatalf("r29 variant leaked %q in live delta %q", forbidden, piece)
					}
				}
				live.WriteString(piece)
			}
			live.WriteString(redactor.Flush())
			for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID", "functionId", "不透明 ID", "the ID shown in the adjacent result card"} {
				if strings.Contains(live.String(), forbidden) {
					t.Fatalf("r29 variant leaked %q in final text %q", forbidden, live.String())
				}
			}
			for _, expected := range tc.want {
				if !strings.Contains(live.String(), expected) {
					t.Fatalf("r29 variant lost readable wording %q: %q", expected, live.String())
				}
			}
		})
	}
}

func TestTextRedactorRedactsR30LiveProviderFrames(t *testing.T) {
	tests := []struct {
		name   string
		chunks []string
		want   []string
	}{
		{
			name: "placeholder before direct-call suffix",
			chunks: []string{
				"用户要求我用 ",
				"search_tools 激活 ",
				"get_function，",
				"然后用",
				"一个不存在但格式正确的 ID 该目标 ",
				"调用它，不重试，并用中文解释实际失败原因。\\n\\n",
			},
			want: []string{"不存在但格式正确的函数标识调用它"},
		},
		{
			name: "format norm instead of structure",
			chunks: []string{
				"说明这是一个格式合法（",
				"符合 `fn_` 前缀 + 16 位十六进制字符的 ID 规范）但实际并不存在的函数记录。",
			},
			want: []string{"符合合法的函数标识格式"},
		},
		{
			name:   "bare function id label",
			chunks: []string{"这个函数 ID 不存在。这个输入不是工作区中的有效函数标识。"},
			want:   []string{"这个函数标识不存在"},
		},
		{
			name:   "input id glue and spacing",
			chunks: []string{"要求传入一个已存在的、有效的 这个输入 ID，拿到真实标识 后再调用。"},
			want:   []string{"有效的函数标识", "真实标识后再调用"},
		},
		{
			name: "function call and format examples",
			chunks: []string{
				"调用 `get_function(functionId=\"the requested item\")` 返回的结果是：",
				"要求传入一个已注册函数的真实不透明 ID（形如 the requested item），",
				"传入一个格式合法（前缀 `fn_` + 16 位十六进制）但实际未注册的标识时，",
				"再从返回结果中取得对应的 the requested item ID。",
			},
			want: []string{"调用 `get_function`", "函数标识格式", "合法的函数标识格式", "对应的函数标识"},
		},
		{
			name: "tool id prefix split before missing sentence",
			chunks: []string{
				"调用 `get_function",
				"` 时传入的 ID `",
				"fn_0000000000000000",
				"` 在系统中不存在。系统中没有注册过这个 ID 对应的函数。",
			},
			want: []string{"时传入的目标在系统中不存在", "这个输入对应的函数"},
		},
		{
			name:   "provider glues id label to neutral input",
			chunks: []string{"ID这个输入是一个格式合法但并不存在的函数标识。系统中没有与该 ID 对应的函数记录。"},
			want:   []string{"这个输入是一个格式合法", "没有与之对应的函数记录"},
		},
		{
			name:   "provider emits camel field and fabricated label",
			chunks: []string{"现在我需要调用 get_function，传入 functionID 已定位。这个输入是一个虚构 ID。"},
			want:   []string{"传入的目标已准备好", "虚构的函数标识"},
		},
		{
			name:   "provider duplicates input reference and leaves trailing id label",
			chunks: []string{"这个 ID 这个输入并不存在。系统根据该 ID 查找对应记录。拿到真实的 这个输入 ID 后再调用。"},
			want:   []string{"这个输入并不存在", "根据这个输入查找", "真实标识后再调用"},
		},
		{
			name:   "provider leaves format field wording",
			chunks: []string{"要求传入一个已注册的、有效的函数（函数标识前缀 开头），但当前工作区没有与此 ID 匹配的记录。ID 格式本身是合法的。"},
			want:   []string{"（格式合法）", "与之匹配", "标识格式本身合法"},
		},
		{
			name:   "provider leaves bare input id phrase",
			chunks: []string{"用户指定的确切 ID 不存在，系统没有找到这个 ID 对应的函数。"},
			want:   []string{"用户指定的函数标识不存在", "这个输入对应的函数"},
		},
		{
			name:   "provider duplicates prefix wording and test suffix",
			chunks: []string{"这个输入符合函数标识前缀 前缀 + 16 位字符，但不存在的标识 来测试系统。"},
			want:   []string{"合法的函数标识格式", "标识来测试"},
		},
		{
			name:   "provider glues location and follow-up spacing",
			chunks: []string{"该 ID在工作区中并不存在。获取其真实标识 后再调用。"},
			want:   []string{"这个输入在工作区中并不存在", "真实标识后再调用"},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var redactor textRedactor
			var live strings.Builder
			for _, chunk := range tc.chunks {
				piece := redactor.Write(chunk)
				for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID", "functionId", "functionID", "虚构 ID", "不透明 ID", "时传入的 ID"} {
					if strings.Contains(piece, forbidden) {
						t.Fatalf("r30 provider frame leaked %q in live delta %q", forbidden, piece)
					}
				}
				live.WriteString(piece)
			}
			live.WriteString(redactor.Flush())
			for _, forbidden := range []string{"fn_", "the requested item", "the referenced item", "该目标", "这个 ID", "该 ID", "函数 ID", "functionId", "functionID", "虚构 ID", "不透明 ID", "时传入的 ID"} {
				if strings.Contains(live.String(), forbidden) {
					t.Fatalf("r30 provider frame leaked %q in final text %q", forbidden, live.String())
				}
			}
			for _, expected := range tc.want {
				if !strings.Contains(live.String(), expected) {
					t.Fatalf("r30 provider frame lost readable wording %q: %q", expected, live.String())
				}
			}
		})
	}
}

func TestTextRedactorDoesNotFlashToolValuePrefixAcrossFrames(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	chunks := []string{
		"调用 `get_function",
		"`",
		" 传入 `fn",
		"_000",
		"0000",
		"0000",
		"0000",
		"0000",
		"` 后，",
		"返回的结果是 **\"function not found\"**。",
	}
	for i, chunk := range chunks {
		piece := redactor.Write(chunk)
		if strings.Contains(piece, "传入") || strings.Contains(piece, "fn_") {
			t.Fatalf("tool value prefix or opaque ID flashed at chunk %d (%q): %q", i, chunk, piece)
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	if strings.Contains(live.String(), "传入") || strings.Contains(live.String(), "fn_") {
		t.Fatalf("tool value prefix or opaque ID leaked in final stream %q", live.String())
	}
	if !strings.Contains(live.String(), "调用 `get_function` 后") {
		t.Fatalf("tool reference lost natural wording: %q", live.String())
	}
}

func TestRedactChineseFunctionRecommendationUsesNaturalCopy(t *testing.T) {
	input := "要成功调用 `get_function`，需要传入一个真实存在的函数（例如 函数标识以合法格式开头的、系统中已注册的函数标识符）。"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "函数标识以合法格式开头的、") {
		t.Fatalf("function recommendation kept machine-shaped wording: %q", got)
	}
	if !strings.Contains(got, "例如系统中已注册的函数") {
		t.Fatalf("function recommendation lost natural wording: %q", got)
	}
}

func TestRedactChineseBareTargetIDUsesNaturalReference(t *testing.T) {
	got := redactOpaqueMachineValues("这说明该 ID 从未被创建过，或已被删除。")
	if strings.Contains(got, "该 ID") {
		t.Fatalf("bare target ID leaked: %q", got)
	}
	if got != "这说明这个输入从未被创建过，或已被删除。" {
		t.Fatalf("bare target ID was not naturalized: %q", got)
	}
}

func TestTextRedactorRedactsPlaceholderAloneAfterChineseDelta(t *testing.T) {
	var redactor textRedactor
	var live strings.Builder
	for _, chunk := range []string{
		"现在我需要调用 get_function，使用 函数标识 参数为 ",
		"the requested item。\n",
	} {
		piece := redactor.Write(chunk)
		if strings.Contains(piece, opaqueEntityPlaceholder) || strings.Contains(piece, legacyEntityPlaceholder) {
			t.Fatalf("placeholder flashed in live delta %q", piece)
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	if strings.Contains(live.String(), opaqueEntityPlaceholder) || strings.Contains(live.String(), legacyEntityPlaceholder) {
		t.Fatalf("placeholder leaked in final stream %q", live.String())
	}
	if !strings.Contains(live.String(), "这个输入") {
		t.Fatalf("placeholder lost its natural Chinese reference: %q", live.String())
	}
}

func TestRedactChineseNonexistentIDAssignmentUsesNegativeCopy(t *testing.T) {
	got := redactOpaqueMachineValues("系统中不存在 ID 为 `fn_0000000000000000` 的函数。")
	if strings.Contains(got, "ID 已定位") {
		t.Fatalf("negative ID assignment became positive-looking copy: %q", got)
	}
	if !strings.Contains(got, "系统中不存在的函数") {
		t.Fatalf("negative ID assignment lost natural wording: %q", got)
	}
}

func TestRedactChineseNotFoundCopyKeepsValidShapeMeaning(t *testing.T) {
	input := "这个输入是一个虚构的、不合法的 ID，工作区里没有任何函数与之对应。"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "不合法") || strings.Contains(got, "函数标识以合法格式开头的 ID") {
		t.Fatalf("not-found copy kept contradictory or machine-shaped wording: %q", got)
	}
	if !strings.Contains(got, "未注册的函数标识") {
		t.Fatalf("not-found copy lost the not-registered meaning: %q", got)
	}

	recommendation := redactOpaqueMachineValues("拿到正确的 `fn_` 开头的 ID 后再调用 `get_function`。")
	if recommendation != "拿到真实存在的函数标识后再调用 `get_function`。" {
		t.Fatalf("function recommendation was not naturalized: %q", recommendation)
	}
}

func TestRedactChineseNotFoundCopyHasNaturalSpacing(t *testing.T) {
	input := "这说明 `fn_0000000000000000` 在系统中并不存在。虽然 `fn_0000000000000000` 在格式上是一个合法的函数标识（以 `fn_` 开头、后跟十六进制字符），但系统中并没有注册过这个函数。get_function 要求传入一个已经存在的函数，对不存在的 ID 会直接返回\"未找到\"，不会创建或猜测。如果需要查找实际可用的函数，应先用 search_function 按关键词搜索，获取真实的 `fn_...` ID 后再调用 get_function。"
	want := "这说明这个输入在系统中并不存在。虽然这个输入在格式上是一个合法的函数标识（以合法格式开头、后跟十六进制字符），但这个输入对应的函数目前未注册。get_function 要求传入一个已经存在的函数，对不存在的函数标识会直接返回\"未找到\"，不会创建或猜测。如果需要查找实际可用的函数，应先用 search_function 按关键词搜索，获取真实存在的函数标识后再调用 get_function。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("not-found copy kept awkward placeholder spacing or wording:\n got: %q\nwant: %q", got, want)
	}
}

func TestRedactChineseNotFoundCopyPreservesWellFormedSemantics(t *testing.T) {
	input := "原因：该 ID（`fn_0000000000000000`）是一个虚构的、不存在的函数标识符。系统中并没有任何函数与此 ID 对应，因此 `get_function` 无法检索到任何匹配的记录，直接返回了\"未找到\"的错误。"
	want := "原因：这个输入是一个未注册的函数标识。系统中并没有任何函数与这个输入对应，因此 `get_function` 无法检索到任何匹配的记录，直接返回了\"未找到\"的错误。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("not-found copy changed valid-shape semantics or kept machine wording:\n got: %q\nwant: %q", got, want)
	}
}

func TestRedactChineseNotFoundCopyRemovesFabricatedLabel(t *testing.T) {
	input := "失败原因：这个输入是一个虚构的、格式合法但实际上不存在的标识符。"
	want := "失败原因：这个输入是一个格式合法但尚未注册的函数标识。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("not-found copy retained fabricated wording:\n got: %q\nwant: %q", got, want)
	}
}

func TestRedactChineseNotFoundCopyNaturalizesToolSpecificVariant(t *testing.T) {
	input := "调用 `get_function` 时传入的 ID `fn_0000000000000000` 在系统中并不存在，因此返回了\"function not found\"。get_function 工具要求传入一个真实存在的函数（格式合法的合法标识符）。虽然这个输入在格式上是合法的，但系统中并没有注册过这个输入对应的函数。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"时传入的目标", "格式合法的合法标识符", "注册过这个输入对应的函数"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("tool-specific not-found copy kept %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"调用 get_function 时传入的函数标识在系统中并不存在", "格式合法的函数标识", "并没有注册过与这个输入对应的函数"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("tool-specific not-found copy lost %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNaturalizesWellFormedFabricatedVariant(t *testing.T) {
	input := "我调用了 `get_function`，传入的 `functionId` 为 `fn_0000000000000000`。系统返回了\"function not found\"。原因：这个 ID 是一个格式上合法（符合 `fn_` 前缀 + 16 位十六进制字符的结构）但实际上并不存在的虚构 ID。工作区中没有任何函数与之对应，因此查询失败。简而言之：ID 格式正确，但目标函数不存在，查询失败。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"传入的 函数标识 为", "格式上合法（符合合法的函数标识格式）但实际上并不存在的虚构的函数标识", "ID 格式正确"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("well-formed not-found copy kept %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"传入的函数标识为这个输入", "这个输入是一个格式合法但尚未注册的函数标识", "函数标识格式正确"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("well-formed not-found copy lost %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyRemovesDuplicateIdentifierSubject(t *testing.T) {
	got := redactOpaqueMachineValues("该标识符 `fn_0000000000000000` 在格式上是合法的，但它并未在系统中注册。")
	if strings.Contains(got, "该标识符") {
		t.Fatalf("duplicate identifier subject leaked: %q", got)
	}
	if !strings.Contains(got, "这个输入格式合法") {
		t.Fatalf("duplicate identifier subject was not naturalized: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedSyntaxClauseVariant(t *testing.T) {
	const input = "您提供的函数标识 `fn_0000000000000000` 在格式上是正确的（符合 fn_ 前缀加字符的命名规范），但这个输入未在系统中注册。这是一个正常的\"未找到\"结果，而非格式错误或无效 ID 的问题。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"前缀 前缀加", "这个输入 的", "无效 ID", "fn_"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted syntax variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"这个输入格式合法", "这个输入未在系统中注册", "不是格式问题"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted syntax variant lost natural wording %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesIDStructureVariant(t *testing.T) {
	const input = "您提供的 ID 在格式上是合法的（符合 函数标识前缀 前缀加标识符的结构），但这个输入并未在系统中注册。系统中根本不存在与此 ID 对应的函数。或用已知的真实标识 再次调用 get_function。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"您提供的 ID", "此 ID", "函数标识前缀 前缀加", "真实标识 再次调用"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("ID structure variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"这个输入格式合法", "这个输入对应的函数", "找到已注册的函数后再调用"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("ID structure variant lost natural wording %q: %q", expected, got)
		}
	}
}

func TestRedactEnglishGetFunctionCopyDoesNotExposePlaceholder(t *testing.T) {
	got := redactOpaqueMachineValues("The user wants me to call get_function with the requested item. The supplied function is the referenced item.")
	for _, forbidden := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("English get_function reasoning leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "the supplied function identifier") {
		t.Fatalf("English get_function reasoning lost natural reference: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesRepeatedInputAndPrefix(t *testing.T) {
	input := "这个输入这个输入 虽然格式上是合法的（以 函数标识前缀 为前缀，后跟字符序列），但这个输入并未在系统中注册。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"这个输入这个输入", "函数标识前缀 为前缀"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("repeated-input variant leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "这个输入虽然格式合法") {
		t.Fatalf("repeated-input variant lost natural wording: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesTechnicalFormatExplanation(t *testing.T) {
	input := "这个输入这个输入 虽然格式上是合法的（具有正确的 函数标识前缀 前缀和标准的长度结构），但该标识符并未在系统中注册。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"这个输入这个输入", "函数标识前缀", "该标识符"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("technical-format variant leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "这个输入虽然格式合法") {
		t.Fatalf("technical-format variant lost natural wording: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesToolLineAndIDWording(t *testing.T) {
	input := "调用\n`get_function` 返回结果。系统中根本不存在对应这个输入的函数实体。如需查找，可以使用\n`search_function`，或获取正确的 ID。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"调用\n", "使用\n", "对应这个输入", "正确的 ID"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("tool/ID wording leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"调用 `get_function`", "使用 `search_function`", "与这个输入对应的函数实体", "正确的函数标识"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("tool/ID wording lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyRemovesSubjectSpacing(t *testing.T) {
	got := redactOpaqueMachineValues("这说明 这个输入在格式上是合法的，但这个输入并未在系统中注册。")
	if strings.Contains(got, "说明 这个输入") {
		t.Fatalf("subject spacing leaked: %q", got)
	}
	if !strings.Contains(got, "说明这个输入格式合法") {
		t.Fatalf("subject spacing normalization lost sentence: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesFinalVariant(t *testing.T) {
	input := "调用\n`get_function` 查询 这个输入 返回结果。这个输入格式是合法的（以合法格式开头、后跟十六进制字符），但系统中并未注册。这个输入是一个格式正确但不存在的函数标识符。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"查询 这个输入", "以合法格式开头", "格式正确但不存在的函数标识符"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("final not-found variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"查询这个输入", "这个输入格式合法", "格式合法但尚未注册的函数标识"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("final not-found variant lost natural wording %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesMarkdownAndLifecycleCopy(t *testing.T) {
	input := "这个输入在**格式上是合法的**（格式合法），但未注册。这个输入指向一个从未被创建（或已被删除）的函数。"
	got := redactOpaqueMachineValues(input)
	if strings.Contains(got, "格式上是合法的") || strings.Contains(got, "从未被创建") {
		t.Fatalf("markdown/lifecycle wording leaked: %q", got)
	}
	for _, expected := range []string{"这个输入在格式合法", "这个输入对应的函数目前未注册"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("markdown/lifecycle wording lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedFormatAndRegistrationCopy(t *testing.T) {
	input := "这个输入的格式是合法的（符合合法的函数标识格式），但系统中并没有注册过这个函数。这是一个正常的未找到结果——并非 ID 格式有误，也不是系统故障，只是当前函数目录中不存在与之对应的函数记录。如需查找，可以找到真实的 ID 后再调用。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"的格式是合法的",
		"符合函数标识格式",
		"该函数并未在系统中注册",
		"系统中并没有注册过这个函数",
		"系统里根本不存在",
		"真实的 ID",
		"符合合法的函数标识格式",
		"并非 ID 格式有误",
		"当前函数目录中不存在与之对应的函数记录",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted not-found wording leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"找到已注册的函数后再调用",
		"也不是系统故障",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted not-found wording lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedShapeVariant(t *testing.T) {
	input := "这个输入在格式上是完全合法的（符合 合法的函数标识格式的结构），但它并没有在工作区中注册过。也就是说，这不是一个\"格式错误\"的问题，而是一个正常的\"未找到\"结果——与之对应的函数在当前工作区的函数目录中不存在。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"在格式上是完全合法的",
		"符合 合法的函数标识格式的结构",
		"它并没有在工作区中注册过",
		"格式错误\"的问题",
		"与之对应的函数在当前工作区的函数目录中不存在",
		"之对应的函数",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted shape variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"这不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted shape variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedSyntaxVariant(t *testing.T) {
	input := "这个输入在语法格式上是合法的——它符合 函数标识格式，所以不是\"格式错误\"。但它并未在系统中注册，也就是说，当前工作区里根本不存在与这个输入对应的函数。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"在语法格式上是合法的",
		"符合 函数标识格式",
		"不是\"格式错误\"",
		"它并未在系统中注册",
		"当前工作区里根本不存在与这个输入对应的函数",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted syntax variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted syntax variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedLegalIdentifierVariant(t *testing.T) {
	input := "这个输入是一个格式合法的函数标识（符合合法的函数标识格式），但这个输入并未在工作区中注册。也就是说，系统中不存在与这个输入对应的函数实体，因此 get_function 返回了\"未找到\"。这属于正常的\"查无此函数\"结果，而非参数格式错误。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"是一个格式合法的函数标识",
		"符合合法的函数标识格式",
		"这个输入并未在工作区中注册",
		"系统中不存在与这个输入对应的函数实体",
		"查无此函数",
		"而非参数格式错误",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted legal-identifier variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"正常的\"未找到\"结果",
		"也不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted legal-identifier variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedCompactVariant(t *testing.T) {
	input := "这说明这个输入在格式上是合法的，但这个输入对应的函数目前未注册。这是一个正常的\"未找到\"结果——不是格式问题或非法，而是当前工作区中不存在与之对应的函数实体。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"这个输入在格式上是合法的",
		"不是格式问题或非法",
		"当前工作区中不存在与之对应的函数实体",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted compact variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"不是格式问题。",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted compact variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedResidualVariant(t *testing.T) {
	input := "这个输入在格式合法，但它并没有在系统中注册过。也就是说，这不是格式问题，而是当前函数目录中不存在对应 ID 的函数。简单来说：函数标识格式正确，但该函数不存在。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"这个输入在格式合法",
		"它并没有在系统中注册过",
		"当前函数目录中不存在对应 ID 的函数",
		"简单来说：",
		"函数标识格式正确，但该函数不存在",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted residual variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted residual variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedBulletVariant(t *testing.T) {
	input := "具体原因如下：\n• 传入的 ID 在格式上是合法的（符合函数标识格式）。\n• 但这个输入并未在系统中注册——即当前函数目录中不存在与这个输入对应的函数实体。\n因此这不是格式问题输入的问题，而是一次正常的\"查无此函数\"响应。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"传入的 ID",
		"符合函数标识格式",
		"这个输入并未在系统中注册",
		"当前函数目录中不存在与这个输入对应的函数实体",
		"格式问题输入的问题",
		"查无此函数",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted bullet variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"不是格式问题",
		"正常的\"未找到\"结果",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted bullet variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedParentheticalVariant(t *testing.T) {
	input := "这个输入虽然格式上是合法的函数标识（以合法格式开头、后跟十六进制字符），但这个输入对应的函数目前未注册。它不是一个语法错误或参数格式问题，而是这个输入对应的函数实体根本不存在于当前工作区的函数目录中。简而言之：函数标识格式正确，但对应的函数未注册，所以查询结果为\"未找到\"。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"虽然格式上是合法的函数标识",
		"以合法格式开头、后跟十六进制字符",
		"它不是一个语法错误或参数格式问题",
		"而是这个输入对应的函数实体根本不存在于当前工作区的函数目录中",
		"简而言之：函数标识格式正确",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted parenthetical variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"这不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted parenthetical variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedLifecycleVariant(t *testing.T) {
	input := "这个输入格式合法，但这个输入对应的函数目前未注册。也就是说，这不是一个格式错误或无效的请求，而是当前工作区中不存在与这个输入对应的函数实体。简而言之：标识符格式正确，但该函数未被创建或已被删除，因此返回\"未找到\"。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"格式错误或无效的请求",
		"当前工作区中不存在与这个输入对应的函数实体",
		"简而言之：标识符格式正确",
		"未被创建或已被删除",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted lifecycle variant leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "这个输入格式合法") || !strings.Contains(got, "这个输入对应的函数目前未注册") || !strings.Contains(got, "这不是格式问题") {
		t.Fatalf("hosted lifecycle variant lost natural copy: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedIDRequirementVariant(t *testing.T) {
	input := "这个输入是一个格式合法的函数标识（以合法格式开头、后跟十六进制字符），但这个输入并未在系统中注册。也就是说，这不是一个格式错误，而是与这个输入对应的函数目前未注册。get_function 要求传入的 ID 必须指向一个已存在的函数，未注册的标识只会返回正常的\"未找到\"结果。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"是一个格式合法的函数标识",
		"以合法格式开头、后跟十六进制字符",
		"这个输入并未在系统中注册",
		"get_function 要求传入的 ID",
		"未注册的标识只会返回",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted ID requirement variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"这不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted ID requirement variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedShortLegalVariant(t *testing.T) {
	input := "这个输入虽然格式上是合法的（以合法格式开头、长度正确），但在系统中并未注册任何对应的函数。这是正常的\"未找到\"结果——系统里不存在这个函数，而不是参数格式有误。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"虽然格式上是合法的",
		"以合法格式开头、长度正确",
		"在系统中并未注册任何对应的函数",
		"系统里不存在这个函数",
		"参数格式有误",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted short legal variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted short legal variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedConstructedIDVariant(t *testing.T) {
	input := "这个输入格式合法，但这个输入对应的函数目前未注册。也就是说，系统里不存在任何与之对应的函数实体，因此 get_function 返回了\"未找到\"。这属于正常的\"未找到\"响应，而不是格式问题或系统故障——ID本身是良好构造的，只是它指向了一个不存在的函数。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"系统里不存在任何与之对应的函数实体",
		"get_function 返回了",
		"ID本身是良好构造的",
		"它指向了一个不存在的函数",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted constructed-ID variant leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "这个输入格式合法") || !strings.Contains(got, "这个输入对应的函数目前未注册") || !strings.Contains(got, "不是格式问题") {
		t.Fatalf("hosted constructed-ID variant lost natural copy: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedGrammarVariant(t *testing.T) {
	input := "这个输入格式合法（以合法格式开头，后跟十六进制字符），属于语法良好的函数标识符。但系统中并没有注册过与这个输入对应的函数，所以返回的是正常的\"未找到\"结果——这不是格式问题，而是这个输入在当前工作区中不存在。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"格式合法（以合法格式开头，后跟十六进制字符）",
		"属于语法良好的函数标识符",
		"系统中并没有注册过与这个输入对应的函数",
		"返回的是正常的",
		"而是这个输入在当前工作区中不存在",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted grammar variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted grammar variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedDirectorySummaryVariant(t *testing.T) {
	input := "这个输入格式合法，但这个输入对应的函数目前未注册。也就是说，当前工作区里不存在与这个输入对应的函数实体，所以返回了正常的\"未找到\"结果。这属于查无此函数，而非格式错误或系统异常。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"当前工作区里不存在与这个输入对应的函数实体",
		"查无此函数",
		"格式错误或系统异常",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted directory-summary variant leaked %q: %q", forbidden, got)
		}
	}
	if !strings.Contains(got, "这个输入格式合法") || !strings.Contains(got, "这个输入对应的函数目前未注册") || !strings.Contains(got, "正常的\"未找到\"结果，不是格式问题") {
		t.Fatalf("hosted directory-summary variant lost natural copy: %q", got)
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedMarkdownVariant(t *testing.T) {
	input := "调用返回了 **\"function not found\"**（未找到函数）。实际原因如下：您提供的函数标识在格式上是合法的（符合合法的函数标识格式），但这个输入**并未在系统中注册**。也就是说，当前函数目录里不存在与这个输入对应的函数实体，因此系统返回了\"未找到\"。如需查找实际存在的函数，可以使用 `search_function` 按关键词搜索，获取真实的函数标识后再进行调用。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"您提供的函数标识",
		"符合合法的函数标识格式",
		"这个输入**并未在系统中注册**",
		"当前函数目录里不存在与这个输入对应的函数实体",
		"获取真实的函数标识后再进行调用",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted markdown variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"找到已注册的函数后再调用",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted markdown variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyNormalizesHostedToolCardVariant(t *testing.T) {
	input := "实际原因：你提供的标识符格式是合法的，但这个输入对应的函数目前未注册。这是一个正常的\"未找到\"结果，而非格式错误。系统工具卡中列出的才是已注册的有效标识符。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{
		"你提供的标识符",
		"而非格式错误",
		"系统工具卡中列出的才是已注册的有效标识符",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("hosted tool-card variant leaked %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{
		"这个输入格式合法",
		"这个输入对应的函数目前未注册",
		"正常的\"未找到\"结果，不是格式问题",
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("hosted tool-card variant lost natural copy %q: %q", expected, got)
		}
	}
}

func TestRedactCompleteUserBlockNormalizesHostedFunctionNotFoundCopy(t *testing.T) {
	input := "调用 `get_function` 返回的结果是 **function not found**（函数未找到）。\n\n实际原因说明：\n\n您提供的 ID `fn_0000000000000000` 格式上是合法的（符合 `fn_` 前缀 + 十六进制字符的结构），但它并没有在工作区中注册过。也就是说，这不是一个格式错误，而是该 ID 对应的函数根本不存在——当前函数目录里没有任何函数与这个 ID 关联。\n\n如果需要查找实际存在的函数，可以使用 `search_function` 按关键词或语义来检索。"
	got := redactCompleteUserBlock(input)
	want := "调用 `get_function` 返回了\"未找到\"结果。\n\n实际原因说明：\n\n这个输入格式合法，但对应的函数目前未注册。\n这是正常的\"未找到\"结果，不是格式问题。\n\n如需查找已有函数，可使用 `search_function` 按关键词检索。"
	if got != want {
		t.Fatalf("complete function-not-found copy did not normalize:\nwant: %q\n got: %q", want, got)
	}
}

func TestRedactCompleteUserBlockNormalizesHostedFunctionNotFoundReasonHeading(t *testing.T) {
	input := "调用结果：function not found（函数未找到）。\n\n原因说明：\n\n您提供的标识符在语法格式上是合法的（符合函数标识格式），但这个输入对应的函数目前未注册。也就是说，这是一个格式正确但不存在的函数标识——系统里没有任何函数对应这个标识符，因此返回了正常的\"未找到\"结果。\n\n如需查找实际存在的函数，可以使用 `search_function` 按关键词检索已注册的函数列表。"
	got := redactCompleteUserBlock(input)
	if !strings.Contains(got, "这个输入格式合法，但对应的函数目前未注册。") ||
		!strings.Contains(got, "这是正常的\"未找到\"结果，不是格式问题。") {
		t.Fatalf("reason-heading variant did not normalize: %q", got)
	}
	for _, forbidden := range []string{"语法格式", "符合函数标识格式", "格式正确但不存在", "系统里没有任何函数对应", "已注册的函数列表"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("reason-heading variant leaked %q: %q", forbidden, got)
		}
	}
}

func TestRedactChineseNotFoundCopyRemovesOpaqueTerminology(t *testing.T) {
	input := "调用 `get_function` 时传入了 `functionId: fn_0000000000000000`，系统返回\"function not found\"。失败原因：这个输入在工作区的函数目录中并不存在。get_function 要求传入一个已注册函数的真实 opaque ID（即 函数标识以合法格式开头的有效标识符），而这个输入是虚构的，因此后端无法匹配。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"opaque", "函数标识以合法格式开头的有效标识符", "这个输入是虚构的", "函数标识: 这个输入"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("not-found copy kept internal or fabricated wording %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"格式合法的函数标识", "这个输入尚未注册", "函数标识为这个输入"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("not-found copy lost natural wording %q: %q", expected, got)
		}
	}
}

func TestRedactChineseNotFoundCopyRemovesPrefixDuplication(t *testing.T) {
	input := "您提供的 ID 格式本身是合法的（符合 `fn_` 前缀加标识符的结构），但该 ID 并未在系统中注册过任何函数。这属于正常的\"未找到\"响应，而非参数格式错误。"
	got := redactOpaqueMachineValues(input)
	for _, forbidden := range []string{"函数标识前缀 前缀", "这个输入并未在系统中注册过任何函数", "标识格式本身合法"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("not-found copy kept duplicated wording %q: %q", forbidden, got)
		}
	}
	for _, expected := range []string{"函数标识格式合法", "系统中没有注册与这个输入对应的函数"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("not-found copy lost natural wording %q: %q", expected, got)
		}
	}
}
