package search

import (
	"context"
	"strings"
	"testing"
	"time"

	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := dbinfra.Migrate(db, Schema...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return New(db)
}

func wsCtx(ws string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), ws)
}

func doc(chunk int, anchor, title, body string) searchdomain.SourceDoc {
	return searchdomain.SourceDoc{
		ChunkNo: chunk, Anchor: anchor, Title: title, Body: body,
		UpdatedAt: time.Date(2026, 6, 12, 10, 0, 0, 0, time.UTC),
	}
}

func lexical(q string, types ...searchdomain.EntityType) searchdomain.LexicalQuery {
	p := searchdomain.ParseQuery(q)
	return searchdomain.LexicalQuery{LongTokens: p.Long, ShortTokens: p.Short, Types: types, IncludeArchived: true, Limit: 50}
}

func TestSearch_ChineseTrigramAndSnippet(t *testing.T) {
	s := newStore(t)
	ctx := wsCtx("ws_a")
	if err := s.ReplaceDocs(ctx, searchdomain.TypeFunction, "fn_1", []searchdomain.SourceDoc{
		doc(0, "", "天气预报", "查询指定城市的天气并格式化为 markdown 摘要"),
	}); err != nil {
		t.Fatalf("replace: %v", err)
	}
	hits, err := s.SearchLexical(ctx, lexical("天气"))
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(hits) != 1 || hits[0].EntityID != "fn_1" {
		t.Fatalf("chinese trigram miss: %+v", hits)
	}
	if !strings.Contains(hits[0].Snippet, "<mark>") {
		t.Fatalf("snippet not highlighted: %q", hits[0].Snippet)
	}
	if hits[0].Score <= 0 {
		t.Fatalf("score must be positive (negated bm25): %f", hits[0].Score)
	}
}

func TestSearch_ShortQueryLikeFallback(t *testing.T) {
	s := newStore(t)
	ctx := wsCtx("ws_a")
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeFunction, "fn_1", []searchdomain.SourceDoc{
		doc(0, "", "引擎工厂", "构造执行引擎"),
	}))
	// 2-char CJK is below the trigram window — the LIKE path must still hit.
	// 2 字中文低于 trigram 窗口——LIKE 路径必须命中。
	hits, err := s.SearchLexical(ctx, lexical("引擎"))
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(hits) != 1 || !strings.Contains(hits[0].Snippet, "<mark>") {
		t.Fatalf("short-query fallback miss: %+v", hits)
	}
	if hits[0].Score != 1.0 { // title hit outranks body-only. title 命中胜 body 命中。
		t.Fatalf("title-hit score = %f, want 1.0", hits[0].Score)
	}
}

func TestSearch_MixedTokensAreConjunctive(t *testing.T) {
	s := newStore(t)
	ctx := wsCtx("ws_a")
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeDocument, "doc_1", []searchdomain.SourceDoc{
		doc(0, "", "设计稿", "工作流引擎的持久化设计"),
	}))
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeDocument, "doc_2", []searchdomain.SourceDoc{
		doc(0, "", "会议记录", "工作流排期讨论"),
	}))
	// long token narrows via FTS, short token filters via LIKE on top.
	// 长 token 经 FTS 收窄，短 token 以 LIKE 叠加过滤。
	hits, err := s.SearchLexical(ctx, lexical("工作流 引擎"))
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(hits) != 1 || hits[0].EntityID != "doc_1" {
		t.Fatalf("mixed-token AND broken: %+v", hits)
	}
}

func TestSearch_WorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	must(t, s.ReplaceDocs(wsCtx("ws_a"), searchdomain.TypeFunction, "fn_1", []searchdomain.SourceDoc{
		doc(0, "", "secret-alpha", "ws_a 专属内容"),
	}))
	hits, err := s.SearchLexical(wsCtx("ws_b"), lexical("secret-alpha"))
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(hits) != 0 {
		t.Fatalf("D2 violation: ws_b sees ws_a rows: %+v", hits)
	}
	// No workspace in ctx must hard-fail, not fall through unfiltered.
	// ctx 无 workspace 必须硬错，而非未过滤地放行。
	if _, err := s.SearchLexical(context.Background(), lexical("secret-alpha")); err == nil {
		t.Fatal("missing workspace must error")
	}
}

func TestUpsertDocAt_TriggerKeepsFTSConsistent(t *testing.T) {
	s := newStore(t)
	ctx := wsCtx("ws_a")
	d := doc(7, "msg_1", "调研会话", "讨论 elasticsearch 的方案")
	must(t, s.UpsertDocAt(ctx, searchdomain.TypeConversation, "cv_1", d))

	if n := count(t, s, ctx, "elasticsearch"); n != 1 {
		t.Fatalf("insert not searchable: %d", n)
	}
	d.Body = "改成 sqlite fts5 方案了"
	must(t, s.UpsertDocAt(ctx, searchdomain.TypeConversation, "cv_1", d))
	if n := count(t, s, ctx, "elasticsearch"); n != 0 {
		t.Fatalf("stale FTS row survived update: %d", n)
	}
	if n := count(t, s, ctx, "fts5"); n != 1 {
		t.Fatalf("updated body not searchable: %d", n)
	}
}

func TestDeletePurgeDrop_ZeroResidue(t *testing.T) {
	s := newStore(t)
	ctxA, ctxB := wsCtx("ws_a"), wsCtx("ws_b")
	seed := func() {
		must(t, s.ReplaceDocs(ctxA, searchdomain.TypeFunction, "fn_1", []searchdomain.SourceDoc{doc(0, "", "alpha-fn", "alpha body")}))
		must(t, s.ReplaceDocs(ctxA, searchdomain.TypeAgent, "ag_1", []searchdomain.SourceDoc{doc(0, "", "alpha-ag", "alpha body")}))
		must(t, s.ReplaceDocs(ctxB, searchdomain.TypeFunction, "fn_2", []searchdomain.SourceDoc{doc(0, "", "alpha-fn-b", "alpha body")}))
	}
	seed()
	must(t, s.DeleteEntity(ctxA, searchdomain.TypeFunction, "fn_1"))
	if n := count(t, s, ctxA, "alpha"); n != 1 {
		t.Fatalf("entity delete residue: %d hits", n)
	}
	must(t, s.PurgeWorkspace(context.Background(), "ws_a"))
	if n := count(t, s, ctxA, "alpha"); n != 0 {
		t.Fatalf("purge residue: %d", n)
	}
	if n := count(t, s, ctxB, "alpha"); n != 1 {
		t.Fatalf("purge must not cross workspaces: %d", n)
	}
	seed()
	must(t, s.DropAll(context.Background()))
	if count(t, s, ctxA, "alpha")+count(t, s, ctxB, "alpha") != 0 {
		t.Fatal("drop-all residue")
	}
}

func TestSearch_OperatorInjectionIsSafe(t *testing.T) {
	s := newStore(t)
	ctx := wsCtx("ws_a")
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeFunction, "fn_1", []searchdomain.SourceDoc{
		doc(0, "", "quoter", `body with "quoted" text`),
	}))
	for _, q := range []string{`"unbalanced`, `(paren`, `star*`, `NEAR NEAR`, `a OR b`, `col:value`, `100%`} {
		if _, err := s.SearchLexical(ctx, lexical(q)); err != nil {
			t.Fatalf("query %q must not error: %v", q, err)
		}
	}
}

func TestSearch_Filters(t *testing.T) {
	s := newStore(t)
	ctx := wsCtx("ws_a")
	live := doc(0, "", "周报对话", "本周进展讨论")
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeConversation, "cv_live", []searchdomain.SourceDoc{live}))
	archived := live
	archived.Archived = true
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeConversation, "cv_arch", []searchdomain.SourceDoc{archived}))
	tagged := doc(0, "", "天气函数", "查天气")
	tagged.Tags = []string{"weather", "api"}
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeFunction, "fn_w", []searchdomain.SourceDoc{tagged}))

	q := lexical("周报对话")
	q.IncludeArchived = false
	hits, err := s.SearchLexical(ctx, q)
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(hits) != 1 || hits[0].EntityID != "cv_live" {
		t.Fatalf("archived filter broken: %+v", hits)
	}

	q2 := lexical("天气函数")
	q2.Tags = []string{"weather"}
	if hits, _ = s.SearchLexical(ctx, q2); len(hits) != 1 || hits[0].Tags[0] != "weather" {
		t.Fatalf("tag filter broken: %+v", hits)
	}
	q2.Tags = []string{"nope"}
	if hits, _ = s.SearchLexical(ctx, q2); len(hits) != 0 {
		t.Fatalf("tag mismatch must filter out: %+v", hits)
	}

	q3 := lexical("周报对话", searchdomain.TypeFunction)
	if hits, _ = s.SearchLexical(ctx, q3); len(hits) != 0 {
		t.Fatalf("type filter broken: %+v", hits)
	}
}

func TestEntityStampsAndMeta(t *testing.T) {
	s := newStore(t)
	ctx := wsCtx("ws_a")
	d := doc(0, "", "stamped", "body")
	d.UpdatedAt = time.Date(2026, 6, 12, 8, 30, 0, 0, time.UTC)
	must(t, s.ReplaceDocs(ctx, searchdomain.TypeSkill, "sk_1", []searchdomain.SourceDoc{d}))

	stamps, err := s.EntityStamps(ctx, searchdomain.TypeSkill)
	if err != nil {
		t.Fatalf("stamps: %v", err)
	}
	ts, ok := stamps["sk_1"]
	if !ok || !ts.Equal(d.UpdatedAt) {
		t.Fatalf("stamp mismatch: %v (want %v)", ts, d.UpdatedAt)
	}

	if v, _ := s.GetMeta(ctx, "missing"); v != "" {
		t.Fatalf("missing meta must be empty, got %q", v)
	}
	must(t, s.SetMeta(ctx, "embedder", "ollama"))
	must(t, s.SetMeta(ctx, "embedder", "off"))
	if v, _ := s.GetMeta(ctx, "embedder"); v != "off" {
		t.Fatalf("meta upsert broken: %q", v)
	}
}

func count(t *testing.T, s *Store, ctx context.Context, q string) int {
	t.Helper()
	hits, err := s.SearchLexical(ctx, lexical(q))
	if err != nil {
		t.Fatalf("count search %q: %v", q, err)
	}
	return len(hits)
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}
