//go:build pipeline

// Package relation_test runs end-to-end pipeline tests for the cross-entity relations
// domain. Drives source-domain service methods (trinity Create / AcceptPending / Revert /
// Delete; document Create / Update / SoftDeleteSubtree; conversation Delete) and verifies
// the relation hooks produce / update / cascade edges per the §17 invariants.
//
// Package relation_test 跑跨实体关系 domain 的端到端 pipeline 测试。直接驱动 source
// domain service 方法，验证 hook 按 §17 不变量正确生成 / 更新 / 级联边。
package relation_test

import (
	"context"
	"encoding/json"
	"testing"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
	th "github.com/sunweilin/forgify/backend/test/harness"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
)

// fnOpsCreate emits the set_meta + set_code ops sequence (same as harness.NewFunction).
//
// fnOpsCreate 发 set_meta + set_code ops 序列（同 harness.NewFunction）。
func fnOpsCreate(name, code string) []functionapp.Op {
	rawMeta, _ := json.Marshal(map[string]any{"name": name})
	rawCode, _ := json.Marshal(map[string]any{"code": code})
	return []functionapp.Op{
		{Type: "set_meta", Raw: rawMeta},
		{Type: "set_code", Raw: rawCode},
	}
}

// fnOpsEdit emits a set_code op alone (for Edit path).
func fnOpsEdit(code string) []functionapp.Op {
	rawCode, _ := json.Marshal(map[string]any{"code": code})
	return []functionapp.Op{
		{Type: "set_code", Raw: rawCode},
	}
}

func ctxAsConv(base context.Context, convID string) context.Context {
	return reqctxpkg.WithConversationID(base, convID)
}

// TestRelationPipeline_FullLifecycle drives the §11.3 walkthrough end-to-end:
// forge → edit-from-different-conv → workflow-uses → doc wikilink → cascade purges.
//
// TestRelationPipeline_FullLifecycle 端到端跑 §11.3：forge → edit-异 conv → workflow-uses
// → doc wikilink → 级联 purge。
func TestRelationPipeline_FullLifecycle(t *testing.T) {
	h := th.New(t)
	baseCtx := h.LocalCtx()

	// ── Step 1: Create cv_1 (origin conversation) ──
	cv1 := h.NewConversation(t, "origin conv")
	ctxCv1 := ctxAsConv(baseCtx, cv1.ID)

	// ── Step 2: Create function fn_x v1 in cv_1 ──
	fn, _, err := h.Function.Create(ctxCv1, functionapp.CreateInput{Ops: fnOpsCreate("test_fn", "def test_fn(x: str) -> str:\n    return x\n")})
	if err != nil {
		t.Fatalf("Function.Create: %v", err)
	}
	rows, _, _, err := h.Relation.List(baseCtx, relationdomain.Filter{
		ToKind: relationdomain.EntityKindFunction, ToID: fn.ID,
		Kind: relationdomain.KindConversationForgedEntity,
	}, "", 100)
	if err != nil {
		t.Fatalf("List forged: %v", err)
	}
	if len(rows) != 1 || rows[0].FromID != cv1.ID {
		t.Errorf("step 2: expected 1 forged edge from cv_1, got %+v", rows)
	}
	// Edited edge should be suppressed (origin==editor on Create)
	editedRows, _, _, _ := h.Relation.List(baseCtx, relationdomain.Filter{
		ToKind: relationdomain.EntityKindFunction, ToID: fn.ID,
		Kind: relationdomain.KindConversationEditedEntity,
	}, "", 100)
	if len(editedRows) != 0 {
		t.Errorf("step 2: edited edge should be suppressed on Create, got %+v", editedRows)
	}

	// ── Step 3: Create cv_2 (editor conversation) ──
	cv2 := h.NewConversation(t, "editor conv")
	ctxCv2 := ctxAsConv(baseCtx, cv2.ID)

	// ── Step 4: Edit fn_x from cv_2 → produces pending → accept → ActiveVersionID flips ──
	if _, err := h.Function.Edit(ctxCv2, functionapp.EditInput{ID: fn.ID, Ops: fnOpsEdit("def test_fn(x: str) -> str:\n    return x.upper()\n")}); err != nil {
		t.Fatalf("Function.Edit: %v", err)
	}
	if _, err := h.Function.AcceptPending(ctxCv2, fn.ID); err != nil {
		t.Fatalf("Function.AcceptPending: %v", err)
	}

	// Forged edge unchanged (cv_1)
	forgedRows, _, _, _ := h.Relation.List(baseCtx, relationdomain.Filter{
		ToKind: relationdomain.EntityKindFunction, ToID: fn.ID,
		Kind: relationdomain.KindConversationForgedEntity,
	}, "", 100)
	if len(forgedRows) != 1 || forgedRows[0].FromID != cv1.ID {
		t.Errorf("step 4: forged edge should remain (cv_1), got %+v", forgedRows)
	}
	// Edited edge now points to cv_2
	editedRows, _, _, _ = h.Relation.List(baseCtx, relationdomain.Filter{
		ToKind: relationdomain.EntityKindFunction, ToID: fn.ID,
		Kind: relationdomain.KindConversationEditedEntity,
	}, "", 100)
	if len(editedRows) != 1 || editedRows[0].FromID != cv2.ID {
		t.Errorf("step 4: expected edited edge from cv_2, got %+v", editedRows)
	}

	// ── Step 5: Soft-delete cv_1 — forged edge purges, edited stays ──
	if err := h.Conversation.Delete(baseCtx, cv1.ID); err != nil {
		t.Fatalf("Conversation.Delete cv_1: %v", err)
	}
	forgedRows, _, _, _ = h.Relation.List(baseCtx, relationdomain.Filter{
		ToKind: relationdomain.EntityKindFunction, ToID: fn.ID,
		Kind: relationdomain.KindConversationForgedEntity,
	}, "", 100)
	if len(forgedRows) != 0 {
		t.Errorf("step 5: forged edge should be purged after cv_1 delete, got %+v", forgedRows)
	}
	editedRows, _, _, _ = h.Relation.List(baseCtx, relationdomain.Filter{
		ToKind: relationdomain.EntityKindFunction, ToID: fn.ID,
		Kind: relationdomain.KindConversationEditedEntity,
	}, "", 100)
	if len(editedRows) != 1 || editedRows[0].FromID != cv2.ID {
		t.Errorf("step 5: edited edge (cv_2) should remain after cv_1 delete, got %+v", editedRows)
	}

	// ── Step 6: Soft-delete function fn_x — all edges to it purge ──
	if err := h.Function.Delete(baseCtx, fn.ID); err != nil {
		t.Fatalf("Function.Delete: %v", err)
	}
	rowsAll, _, _, _ := h.Relation.List(baseCtx, relationdomain.Filter{
		ToKind: relationdomain.EntityKindFunction, ToID: fn.ID,
	}, "", 100)
	if len(rowsAll) != 0 {
		t.Errorf("step 6: all edges to fn_x should be purged, got %+v", rowsAll)
	}
}

// TestRelationPipeline_DocumentWikilinks verifies document body wikilink parsing
// triggers document_links_entity edges, and re-saves correctly diff-sync removes
// dropped links.
func TestRelationPipeline_DocumentWikilinks(t *testing.T) {
	h := th.New(t)
	baseCtx := h.LocalCtx()

	// Seed a target function via direct service so we have a valid prefix-ID target.
	cv := h.NewConversation(t, "seed conv")
	ctxCv := ctxAsConv(baseCtx, cv.ID)
	fn, _, err := h.Function.Create(ctxCv, functionapp.CreateInput{Ops: fnOpsCreate("doc_target", "def doc_target(x: str) -> str:\n    return x\n")})
	if err != nil {
		t.Fatalf("Function.Create: %v", err)
	}

	// Create a doc that references the function in markdown body.
	body := "see [[" + fn.ID + "]] for details"
	doc, err := h.Document.Create(baseCtx, documentapp.CreateInput{Name: "notes", Content: body})
	if err != nil {
		t.Fatalf("Document.Create: %v", err)
	}
	rows, _, _, _ := h.Relation.List(baseCtx, relationdomain.Filter{
		FromKind: relationdomain.EntityKindDocument, FromID: doc.ID,
		Kind: relationdomain.KindDocumentLinksEntity,
	}, "", 100)
	if len(rows) != 1 || rows[0].ToID != fn.ID {
		t.Errorf("expected 1 doc_links edge to fn, got %+v", rows)
	}

	// Update doc to remove the wikilink — edge should disappear.
	emptyBody := "no links here"
	if _, err := h.Document.Update(baseCtx, doc.ID, documentapp.UpdateInput{Content: &emptyBody}); err != nil {
		t.Fatalf("Document.Update: %v", err)
	}
	rows, _, _, _ = h.Relation.List(baseCtx, relationdomain.Filter{
		FromKind: relationdomain.EntityKindDocument, FromID: doc.ID,
		Kind: relationdomain.KindDocumentLinksEntity,
	}, "", 100)
	if len(rows) != 0 {
		t.Errorf("expected 0 doc_links after removing wikilink, got %+v", rows)
	}

	// Soft-delete doc — confirm cascade. Re-add the link first.
	withLink := "[[" + fn.ID + "]]"
	if _, err := h.Document.Update(baseCtx, doc.ID, documentapp.UpdateInput{Content: &withLink}); err != nil {
		t.Fatalf("Document.Update re-link: %v", err)
	}
	if _, err := h.Document.Delete(baseCtx, doc.ID); err != nil {
		t.Fatalf("Document.Delete: %v", err)
	}
	rows, _, _, _ = h.Relation.List(baseCtx, relationdomain.Filter{
		FromKind: relationdomain.EntityKindDocument, FromID: doc.ID,
	}, "", 100)
	if len(rows) != 0 {
		t.Errorf("expected 0 edges after doc delete, got %+v", rows)
	}
}

// TestRelationPipeline_Relgraph_OmitsOrphanConversations builds 1 conv with edges + 1 orphan
// conv with none, calls GetRelgraph, and verifies only the connected conv appears as a node.
//
// TestRelationPipeline_Relgraph_OmitsOrphanConversations 建 1 个有边对话 + 1 个孤儿对话,
// 调 GetRelgraph,验证只有有边的进 nodes。
func TestRelationPipeline_Relgraph_OmitsOrphanConversations(t *testing.T) {
	h := th.New(t)
	baseCtx := h.LocalCtx()

	// Orphan conversation — no entities created within it
	_ = h.NewConversation(t, "orphan conv")

	// Connected conversation — creates a function
	cv := h.NewConversation(t, "active conv")
	fn, _, err := h.Function.Create(ctxAsConv(baseCtx, cv.ID),
		functionapp.CreateInput{Ops: fnOpsCreate("relgraph_test", "def relgraph_test(x: str) -> str:\n    return x\n")})
	if err != nil {
		t.Fatalf("Function.Create: %v", err)
	}

	snap, err := h.Relation.GetRelgraph(baseCtx)
	if err != nil {
		t.Fatalf("GetRelgraph: %v", err)
	}

	// Function should appear (orphan-included)
	fnSeen, cvActiveSeen, cvOrphanSeen := false, false, false
	for _, n := range snap.Nodes {
		if n.Kind == relationdomain.EntityKindFunction && n.ID == fn.ID {
			fnSeen = true
		}
		if n.Kind == relationdomain.EntityKindConversation && n.ID == cv.ID {
			cvActiveSeen = true
		}
		// Orphan conv ID isn't known here; we only assert the active one appears
		// and the count of conversation nodes is exactly 1 (no orphan).
		if n.Kind == relationdomain.EntityKindConversation && n.ID != cv.ID {
			cvOrphanSeen = true
		}
	}
	if !fnSeen {
		t.Errorf("function fn_x should appear in nodes, missing")
	}
	if !cvActiveSeen {
		t.Errorf("active conversation %s should appear (has forged edge), missing", cv.ID)
	}
	if cvOrphanSeen {
		t.Errorf("orphan conversation should be omitted from relgraph nodes")
	}
}
