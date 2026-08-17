package loop

import (
	"context"
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

func TestRedactChineseLocatedIDAssignmentKeepsProseNatural(t *testing.T) {
	input := "我已经找到了这个文档的 ID：`doc_3ec2e562757ebbef`。"
	want := "我已经找到了这个文档。"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("Chinese located opaque ID assignment = %q, want %q", got, want)
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
