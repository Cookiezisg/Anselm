package search

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// fakeRepo records writes and serves canned lexical hits — app-layer tests pin
// ranking/folding/pagination logic, the SQL layer has its own tests.
//
// fakeRepo 记录写入并返回预置词法命中——app 层测试钉排序/折叠/分页逻辑，SQL 层有
// 自己的测试。
type fakeRepo struct {
	mu       sync.Mutex
	hits     []*searchdomain.DocHit
	replaced map[string][]searchdomain.SourceDoc // key: type/id
	upserted map[string]searchdomain.SourceDoc   // key: type/id#chunk
	stamps   map[searchdomain.EntityType]map[string]time.Time
	meta     map[string]string
	purged   []string
	purgeGo  chan struct{} // non-nil → PurgeWorkspace blocks until closed. 非 nil → PurgeWorkspace 阻塞到关闭。
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		replaced: map[string][]searchdomain.SourceDoc{},
		upserted: map[string]searchdomain.SourceDoc{},
		stamps:   map[searchdomain.EntityType]map[string]time.Time{},
		meta:     map[string]string{},
	}
}

func (f *fakeRepo) ReplaceDocs(_ context.Context, t searchdomain.EntityType, id string, docs []searchdomain.SourceDoc) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.replaced[string(t)+"/"+id] = docs
	return nil
}

func (f *fakeRepo) UpsertDocAt(_ context.Context, t searchdomain.EntityType, id string, d searchdomain.SourceDoc) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.upserted[string(t)+"/"+id+"#"+d.Anchor] = d
	return nil
}

func (f *fakeRepo) DeleteEntity(ctx context.Context, t searchdomain.EntityType, id string) error {
	return f.ReplaceDocs(ctx, t, id, nil)
}

func (f *fakeRepo) PurgeWorkspace(_ context.Context, ws string) error {
	if f.purgeGo != nil {
		<-f.purgeGo
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.purged = append(f.purged, ws)
	return nil
}

func (f *fakeRepo) SearchLexical(_ context.Context, _ searchdomain.LexicalQuery) ([]*searchdomain.DocHit, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.hits, nil
}

func (f *fakeRepo) EntityStamps(_ context.Context, t searchdomain.EntityType) (map[string]time.Time, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := map[string]time.Time{}
	for id, ts := range f.stamps[t] {
		out[id] = ts
	}
	return out, nil
}

func (f *fakeRepo) GetMeta(_ context.Context, key string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.meta[key], nil
}

func (f *fakeRepo) SetMeta(_ context.Context, key, value string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.meta[key] = value
	return nil
}

func (f *fakeRepo) DropAll(context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.hits = nil
	return nil
}

var _ searchdomain.Repository = (*fakeRepo)(nil)

func dh(t searchdomain.EntityType, id string, chunk int, anchor, title string, score float64) *searchdomain.DocHit {
	return &searchdomain.DocHit{
		EntityType: t, EntityID: id, ChunkNo: chunk, Anchor: anchor, Title: title,
		Score: score, UpdatedAt: time.Date(2026, 6, 12, 10, 0, 0, 0, time.UTC),
	}
}

func ctxWS(ws string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), ws) }

func TestSearch_BoostRelativeOrder(t *testing.T) {
	repo := newFakeRepo()
	// Body-only hit scores highest lexically — exact/prefix name must still win.
	// 仅正文命中词法分最高——exact/prefix 名仍必须排前。
	repo.hits = []*searchdomain.DocHit{
		dh(searchdomain.TypeDocument, "doc_body", 0, "", "无关标题", 9.0),
		dh(searchdomain.TypeFunction, "fn_prefix", 0, "", "天气预报增强版", 2.0),
		dh(searchdomain.TypeFunction, "fn_exact", 0, "", "天气预报", 1.0),
	}
	svc := New(repo, nil)
	page, err := svc.Search(ctxWS("ws_a"), &searchdomain.Query{Q: "天气预报", IncludeArchived: true})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	got := []string{page.Hits[0].EntityID, page.Hits[1].EntityID, page.Hits[2].EntityID}
	want := []string{"fn_exact", "fn_prefix", "doc_body"}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("relative order broken: got %v want %v", got, want)
		}
	}
	if page.Hits[0].RefHint != "fn_exact" {
		t.Fatalf("block refHint missing: %+v", page.Hits[0])
	}
	if page.Hits[2].RefHint != "" {
		t.Fatalf("content hit must have no refHint: %+v", page.Hits[2])
	}
}

func TestSearch_FoldsChunksPerEntity(t *testing.T) {
	repo := newFakeRepo()
	repo.hits = []*searchdomain.DocHit{
		dh(searchdomain.TypeDocument, "doc_1", 2, "h2", "设计稿", 5.0),
		dh(searchdomain.TypeDocument, "doc_1", 0, "h0", "设计稿", 8.0),
		dh(searchdomain.TypeDocument, "doc_1", 1, "h1", "设计稿", 3.0),
		dh(searchdomain.TypeDocument, "doc_2", 0, "", "另一篇", 4.0),
	}
	svc := New(repo, nil)
	page, err := svc.Search(ctxWS("ws_a"), &searchdomain.Query{Q: "设计", IncludeArchived: true})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(page.Hits) != 2 {
		t.Fatalf("fold broken: %d hits", len(page.Hits))
	}
	if page.Hits[0].MatchedChunks != 3 || page.Hits[0].Anchor != "h0" {
		t.Fatalf("best chunk must win with sibling count: %+v", page.Hits[0])
	}
}

func TestSearch_CursorPagination(t *testing.T) {
	repo := newFakeRepo()
	for i := range 30 {
		repo.hits = append(repo.hits, dh(searchdomain.TypeFunction, "fn_"+string(rune('a'+i)), 0, "", "工具函数", float64(30-i)))
	}
	svc := New(repo, nil)
	q := &searchdomain.Query{Q: "工具", Limit: 10, IncludeArchived: true}
	p1, err := svc.Search(ctxWS("ws_a"), q)
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	if len(p1.Hits) != 10 || p1.NextCursor == "" || p1.Total != 30 {
		t.Fatalf("page1 wrong: %d hits, cursor %q, total %d", len(p1.Hits), p1.NextCursor, p1.Total)
	}
	q.Cursor = p1.NextCursor
	p2, err := svc.Search(ctxWS("ws_a"), q)
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if len(p2.Hits) != 10 || p2.Hits[0].EntityID == p1.Hits[0].EntityID {
		t.Fatalf("page2 must continue, not repeat: %+v", p2.Hits[0])
	}
	// A cursor from a different query is stale — reject, don't mis-slice.
	// 来自不同查询的 cursor 已过期——拒绝而非切错。
	q2 := &searchdomain.Query{Q: "别的查询", Cursor: p1.NextCursor}
	if _, err := svc.Search(ctxWS("ws_a"), q2); !errors.Is(err, searchdomain.ErrCursorInvalid) {
		t.Fatalf("stale cursor must be ErrCursorInvalid, got %v", err)
	}
}

func TestSearch_Validation(t *testing.T) {
	svc := New(newFakeRepo(), nil)
	if _, err := svc.Search(ctxWS("ws_a"), &searchdomain.Query{Q: "  "}); !errors.Is(err, searchdomain.ErrQueryRequired) {
		t.Fatalf("blank query: %v", err)
	}
	if _, err := svc.Search(ctxWS("ws_a"), &searchdomain.Query{Q: "x", Types: []searchdomain.EntityType{"nope"}}); !errors.Is(err, searchdomain.ErrTypeInvalid) {
		t.Fatalf("bad type: %v", err)
	}
}

// fakeSource is a scriptable Source (+IncrementalSource).
//
// fakeSource 是可编排的 Source（+IncrementalSource）。
type fakeSource struct {
	t      searchdomain.EntityType
	mu     sync.Mutex
	docs   map[string][]searchdomain.SourceDoc
	atDocs map[string]searchdomain.SourceDoc // key: id#anchor
	stamps map[string]time.Time
}

func newFakeSource(t searchdomain.EntityType) *fakeSource {
	return &fakeSource{t: t, docs: map[string][]searchdomain.SourceDoc{}, atDocs: map[string]searchdomain.SourceDoc{}, stamps: map[string]time.Time{}}
}

func (f *fakeSource) Type() searchdomain.EntityType { return f.t }

func (f *fakeSource) Docs(_ context.Context, id string) ([]searchdomain.SourceDoc, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.docs[id], nil
}

func (f *fakeSource) Stamps(context.Context) (map[string]time.Time, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := map[string]time.Time{}
	for k, v := range f.stamps {
		out[k] = v
	}
	return out, nil
}

func (f *fakeSource) DocAt(_ context.Context, id, anchor string) (*searchdomain.SourceDoc, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	d, ok := f.atDocs[id+"#"+anchor]
	if !ok {
		return nil, false, nil
	}
	return &d, true, nil
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("condition not reached in time")
}

func TestIndexer_ChangedRoutesFullAndIncremental(t *testing.T) {
	repo := newFakeRepo()
	src := newFakeSource(searchdomain.TypeConversation)
	src.docs["cv_1"] = []searchdomain.SourceDoc{{ChunkNo: 0, Title: "会话", Body: "全文"}}
	src.atDocs["cv_1#msg_9"] = searchdomain.SourceDoc{ChunkNo: 9, Anchor: "msg_9", Title: "会话", Body: "新消息"}

	svc := New(repo, nil)
	svc.RegisterSource(src)
	svc.Start(nil)
	defer svc.Close()

	// Full re-projection.
	// 整体重投影。
	svc.Notifier().Changed(ctxWS("ws_a"), searchdomain.TypeConversation, "cv_1", "")
	waitFor(t, func() bool {
		repo.mu.Lock()
		defer repo.mu.Unlock()
		return len(repo.replaced["conversation/cv_1"]) == 1
	})

	// Incremental anchor path must NOT re-project the whole entity.
	// anchor 增量路径必须不整体重投影。
	svc.Notifier().Changed(ctxWS("ws_a"), searchdomain.TypeConversation, "cv_1", "msg_9")
	waitFor(t, func() bool {
		repo.mu.Lock()
		defer repo.mu.Unlock()
		_, ok := repo.upserted["conversation/cv_1#msg_9"]
		return ok
	})

	// Vanished entity → empty docs → delete (ReplaceDocs with nil).
	// 实体消失 → docs 空 → 删除（ReplaceDocs nil）。
	svc.Notifier().Changed(ctxWS("ws_a"), searchdomain.TypeConversation, "cv_gone", "")
	waitFor(t, func() bool {
		repo.mu.Lock()
		defer repo.mu.Unlock()
		docs, ok := repo.replaced["conversation/cv_gone"]
		return ok && len(docs) == 0
	})
}

func TestIndexer_ReconcileDiffsAndOrphans(t *testing.T) {
	repo := newFakeRepo()
	src := newFakeSource(searchdomain.TypeFunction)
	now := time.Date(2026, 6, 12, 10, 0, 0, 0, time.UTC)
	src.stamps["fn_new"] = now                      // not indexed → project. 未入索 → 投影。
	src.stamps["fn_stale"] = now.Add(2 * time.Hour) // indexed but older → re-project. 已入索但旧 → 重投影。
	src.stamps["fn_fresh"] = now                    // indexed and current → untouched. 已入索且新 → 不动。
	src.docs["fn_new"] = []searchdomain.SourceDoc{{Title: "n"}}
	src.docs["fn_stale"] = []searchdomain.SourceDoc{{Title: "s"}}
	src.docs["fn_fresh"] = []searchdomain.SourceDoc{{Title: "f"}}
	repo.stamps[searchdomain.TypeFunction] = map[string]time.Time{
		"fn_stale":  now,
		"fn_fresh":  now,
		"fn_orphan": now, // indexed but no longer live → delete. 已入索但已无 → 删。
	}

	svc := New(repo, nil)
	svc.RegisterSource(src)
	svc.Start([]string{"ws_a"})
	defer svc.Close()

	waitFor(t, func() bool {
		repo.mu.Lock()
		defer repo.mu.Unlock()
		_, newDone := repo.replaced["function/fn_new"]
		_, staleDone := repo.replaced["function/fn_stale"]
		orphan, orphanDone := repo.replaced["function/fn_orphan"]
		return newDone && staleDone && orphanDone && len(orphan) == 0
	})
	repo.mu.Lock()
	defer repo.mu.Unlock()
	if _, touched := repo.replaced["function/fn_fresh"]; touched {
		t.Fatal("fresh entity must not be re-indexed")
	}
	if repo.meta["fts_schema_version"] != schemaVersion {
		t.Fatalf("schema version not stamped: %q", repo.meta["fts_schema_version"])
	}
}

func TestReindex_ConflictWhileRunning(t *testing.T) {
	repo := newFakeRepo()
	repo.purgeGo = make(chan struct{})
	svc := New(repo, nil)
	svc.Start(nil)
	defer svc.Close()

	if err := svc.Reindex(ctxWS("ws_a")); err != nil {
		t.Fatalf("first reindex: %v", err)
	}
	if err := svc.Reindex(ctxWS("ws_a")); !errors.Is(err, searchdomain.ErrReindexRunning) {
		t.Fatalf("second reindex must conflict, got %v", err)
	}
	close(repo.purgeGo)
	waitFor(t, func() bool {
		repo.mu.Lock()
		defer repo.mu.Unlock()
		return len(repo.purged) == 1 && repo.purged[0] == "ws_a"
	})
	// After completion a new reindex is accepted again.
	// 完成后新的 reindex 再次可用。
	waitFor(t, func() bool { return svc.Reindex(ctxWS("ws_a")) == nil })
}
