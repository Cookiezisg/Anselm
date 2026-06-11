package handler

import "testing"

// TestCatalogSource_ListsMethodNames: a handler is a container entity — the catalog item
// carries its active version's method names as Members (aligns mcp's tool names).
//
// TestCatalogSource_ListsMethodNames：handler 是容器实体——catalog item 把 active 版本的方法名作为
// Members（对齐 mcp 的工具名）。
func TestCatalogSource_ListsMethodNames(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	if _, _, err := svc.Create(ctx, CreateInput{Ops: createOps(t, "alpha", false)}); err != nil {
		t.Fatalf("create: %v", err)
	}
	items, err := svc.AsCatalogSource().ListItems(ctx)
	if err != nil {
		t.Fatalf("catalog: %v", err)
	}
	if len(items) != 1 || items[0].Name != "alpha" {
		t.Fatalf("want 1 catalog item alpha, got %+v", items)
	}
	if len(items[0].Members) != 1 || items[0].Members[0] != "ping" {
		t.Fatalf("want Members=[ping] (the handler's method name), got %v", items[0].Members)
	}
}
