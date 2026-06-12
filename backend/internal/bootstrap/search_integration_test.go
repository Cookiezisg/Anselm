package bootstrap

import (
	"context"
	"testing"
	"time"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	workspaceapp "github.com/sunweilin/forgify/backend/internal/app/workspace"
	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// TestBuild_SearchEndToEnd proves the whole search chain through the real
// composition root: entity write → publish hook → Notifier → index worker →
// FTS projection → omni-search hit; then delete → zero residue. This is the
// wiring test — package-level tests cover the engine itself.
//
// TestBuild_SearchEndToEnd 经真实装配根证明搜索全链：实体写 → publish 钩子 →
// Notifier → 索引 worker → FTS 投影 → 综搜命中；再删 → 零残留。这是接线测试——
// 引擎本体由包内测试覆盖。
func TestBuild_SearchEndToEnd(t *testing.T) {
	app, err := Build(Config{DataDir: t.TempDir()})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	defer app.svc.search.Close()

	ws, err := app.svc.workspace.Create(context.Background(), workspaceapp.CreateInput{Name: "搜索测试"})
	if err != nil {
		t.Fatalf("create workspace: %v", err)
	}
	ctx := reqctxpkg.Detached(ws.ID)
	app.svc.search.Start([]string{ws.ID})

	doc, err := app.svc.document.Create(ctx, documentapp.CreateInput{
		Name:    "持久化设计",
		Content: "# 引擎\n\n工作流引擎采用节点结果记忆化实现崩溃恢复。",
	})
	if err != nil {
		t.Fatalf("create document: %v", err)
	}

	search := func(q string) []*searchdomain.Hit {
		page, err := app.svc.search.Search(ctx, &searchdomain.Query{Q: q, IncludeArchived: true})
		if err != nil {
			t.Fatalf("search %q: %v", q, err)
		}
		return page.Hits
	}
	wait := func(desc string, cond func() bool) {
		t.Helper()
		deadline := time.Now().Add(5 * time.Second)
		for time.Now().Before(deadline) {
			if cond() {
				return
			}
			time.Sleep(10 * time.Millisecond)
		}
		t.Fatalf("timeout: %s", desc)
	}

	// Content hit (trigram CJK) with the document's heading anchor.
	// 正文命中（trigram 中文），附文档标题锚。
	wait("content indexed", func() bool {
		hits := search("记忆化")
		return len(hits) == 1 && hits[0].EntityID == doc.ID && hits[0].EntityType == searchdomain.TypeDocument
	})
	// Cross-workspace isolation through the real stack.
	// 真实栈下的跨 workspace 隔离。
	ws2, err := app.svc.workspace.Create(context.Background(), workspaceapp.CreateInput{Name: "另一个"})
	if err != nil {
		t.Fatalf("create ws2: %v", err)
	}
	if page, err := app.svc.search.Search(reqctxpkg.Detached(ws2.ID), &searchdomain.Query{Q: "记忆化", IncludeArchived: true}); err != nil || len(page.Hits) != 0 {
		t.Fatalf("isolation broken: %v %+v", err, page)
	}

	// Delete → the publish hook drives the index to zero residue.
	// 删除 → publish 钩子驱动索引零残留。
	if _, err := app.svc.document.Delete(ctx, doc.ID); err != nil {
		t.Fatalf("delete document: %v", err)
	}
	wait("index cleaned after delete", func() bool { return len(search("记忆化")) == 0 })
}
