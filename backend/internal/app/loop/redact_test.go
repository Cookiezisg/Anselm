package loop

import (
	"context"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
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

func TestRedactOpaqueMachineValuesKeepsHumanSemantics(t *testing.T) {
	input := "mode warm -> cool; prefix alpha; bootId changed; 7 steps"
	if got := redactOpaqueMachineValues(input); got != input {
		t.Fatalf("human-readable semantics changed: got %q, want %q", got, input)
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
	t.Logf("redacted current flowrun report: %q", got)
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
