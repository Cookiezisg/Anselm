// Package search is the raw-SQL implementation of searchdomain.Repository: the
// search_docs projection table, its FTS5 external-content index (trigram), the
// search_meta kv and the search_embeddings vectors. FTS5 virtual tables are
// outside pkg/orm's row-mapped CRUD, so this store hand-writes SQL — including
// the workspace predicate. That makes it the single D2 exemption in the
// codebase: every query here MUST carry `workspace_id = ?` (or an explicit
// purge id), and the isolation tests pin that.
//
// Package search 是 searchdomain.Repository 的 raw-SQL 实现：search_docs 投影表、
// 其 FTS5 external-content 索引（trigram）、search_meta kv 与 search_embeddings 向量。
// FTS5 虚表在 pkg/orm 行映射 CRUD 之外，故本 store 手写 SQL——包括 workspace 谓词。
// 这是全库唯一 D2 豁免点：此处每条查询必须带 `workspace_id = ?`（或显式 purge id），
// 由隔离测试钉死。
package search

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Schema is the search DDL: projection table + FTS5 external-content index +
// the standard three sync triggers (any write path to search_docs keeps the FTS
// index consistent by construction) + meta kv + embeddings.
//
// Schema 是搜索 DDL：投影表 + FTS5 external-content 索引 + 标准三触发器（对
// search_docs 的任何写法都构造性保证 FTS 同步）+ meta kv + 向量表。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS search_docs (
		id           TEXT PRIMARY KEY,
		workspace_id TEXT NOT NULL,
		entity_type  TEXT NOT NULL CHECK (entity_type IN
			('conversation','function','handler','agent','mcp','skill',
			 'document','workflow','trigger','control','approval','memory')),
		entity_id    TEXT NOT NULL,
		chunk_no     INTEGER NOT NULL DEFAULT 0,
		anchor       TEXT NOT NULL DEFAULT '',
		title        TEXT NOT NULL,
		body         TEXT NOT NULL,
		tags         TEXT NOT NULL DEFAULT '[]',
		archived     INTEGER NOT NULL DEFAULT 0,
		updated_at   DATETIME NOT NULL,
		UNIQUE(workspace_id, entity_type, entity_id, chunk_no)
	)`,
	`CREATE INDEX IF NOT EXISTS idx_sd_ws_entity ON search_docs(workspace_id, entity_type, entity_id)`,
	`CREATE VIRTUAL TABLE IF NOT EXISTS search_fts USING fts5(
		title, body, content='search_docs', content_rowid='rowid', tokenize='trigram')`,
	`CREATE TRIGGER IF NOT EXISTS search_docs_ai AFTER INSERT ON search_docs BEGIN
		INSERT INTO search_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body);
	END`,
	`CREATE TRIGGER IF NOT EXISTS search_docs_ad AFTER DELETE ON search_docs BEGIN
		INSERT INTO search_fts(search_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body);
	END`,
	`CREATE TRIGGER IF NOT EXISTS search_docs_au AFTER UPDATE ON search_docs BEGIN
		INSERT INTO search_fts(search_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body);
		INSERT INTO search_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body);
	END`,
	`CREATE TABLE IF NOT EXISTS search_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)`,
	`CREATE TABLE IF NOT EXISTS search_embeddings (
		doc_id TEXT PRIMARY KEY,
		model  TEXT NOT NULL,
		dims   INTEGER NOT NULL,
		vector BLOB NOT NULL
	)`,
}

// Store implements searchdomain.Repository over raw SQL.
//
// Store 基于 raw SQL 实现 searchdomain.Repository。
type Store struct {
	db *ormpkg.DB
}

// New builds a Store on the shared DB.
//
// New 在共享 DB 上构造 Store。
func New(db *ormpkg.DB) *Store { return &Store{db: db} }

var _ searchdomain.Repository = (*Store)(nil)

func marshalTags(tags []string) string {
	if len(tags) == 0 {
		return "[]"
	}
	b, err := json.Marshal(tags)
	if err != nil {
		return "[]"
	}
	return string(b)
}

func unmarshalTags(raw string) []string {
	if raw == "" || raw == "[]" {
		return nil
	}
	var tags []string
	if err := json.Unmarshal([]byte(raw), &tags); err != nil {
		return nil
	}
	return tags
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

const insertDoc = `INSERT INTO search_docs
	(id, workspace_id, entity_type, entity_id, chunk_no, anchor, title, body, tags, archived, updated_at)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`

// ReplaceDocs swaps the entity's whole projection inside one transaction:
// delete-then-insert keeps chunk numbering authoritative from the source, and
// the triggers translate both halves into FTS deletes/inserts. Stale embeddings
// go first (they reference doc ids about to die).
//
// ReplaceDocs 在单事务内整体置换实体投影：先删后插使 chunk 编号以 source 为准，
// 触发器把两步翻成 FTS 删/插。旧向量先删（引用即将消失的 doc id）。
func (s *Store) ReplaceDocs(ctx context.Context, t searchdomain.EntityType, entityID string, docs []searchdomain.SourceDoc) error {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return err
	}
	err = s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		if _, err := tx.Exec(ctx,
			`DELETE FROM search_embeddings WHERE doc_id IN
				(SELECT id FROM search_docs WHERE workspace_id = ? AND entity_type = ? AND entity_id = ?)`,
			wsID, string(t), entityID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx,
			`DELETE FROM search_docs WHERE workspace_id = ? AND entity_type = ? AND entity_id = ?`,
			wsID, string(t), entityID); err != nil {
			return err
		}
		for _, d := range docs {
			if _, err := tx.Exec(ctx, insertDoc,
				idgenpkg.New("sd"), wsID, string(t), entityID, d.ChunkNo, d.Anchor,
				d.Title, d.Body, marshalTags(d.Tags), boolToInt(d.Archived), d.UpdatedAt.UTC()); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("searchstore.ReplaceDocs %s/%s: %w", t, entityID, err)
	}
	return nil
}

// UpsertDocAt writes one chunk row keyed by (entity, chunk_no) — the
// incremental path. The upsert's DO UPDATE fires the AFTER UPDATE trigger, so
// the FTS index follows; a changed body also invalidates the row's embedding.
//
// UpsertDocAt 按 (entity, chunk_no) 写单 chunk 行——增量路径。upsert 的 DO UPDATE
// 触发 AFTER UPDATE 触发器，FTS 跟随；body 变化同时作废该行向量。
func (s *Store) UpsertDocAt(ctx context.Context, t searchdomain.EntityType, entityID string, d searchdomain.SourceDoc) error {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return err
	}
	err = s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		if _, err := tx.Exec(ctx,
			`DELETE FROM search_embeddings WHERE doc_id IN
				(SELECT id FROM search_docs WHERE workspace_id = ? AND entity_type = ? AND entity_id = ? AND chunk_no = ?)`,
			wsID, string(t), entityID, d.ChunkNo); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, insertDoc+` ON CONFLICT(workspace_id, entity_type, entity_id, chunk_no) DO UPDATE SET
			anchor = excluded.anchor, title = excluded.title, body = excluded.body,
			tags = excluded.tags, archived = excluded.archived, updated_at = excluded.updated_at`,
			idgenpkg.New("sd"), wsID, string(t), entityID, d.ChunkNo, d.Anchor,
			d.Title, d.Body, marshalTags(d.Tags), boolToInt(d.Archived), d.UpdatedAt.UTC())
		return err
	})
	if err != nil {
		return fmt.Errorf("searchstore.UpsertDocAt %s/%s#%d: %w", t, entityID, d.ChunkNo, err)
	}
	return nil
}

func (s *Store) DeleteEntity(ctx context.Context, t searchdomain.EntityType, entityID string) error {
	return s.ReplaceDocs(ctx, t, entityID, nil)
}

// PurgeWorkspace removes every index row of one workspace — the
// workspace-deletion cascade, which runs with an explicit id because the
// request ctx may already be scoped elsewhere.
//
// PurgeWorkspace 删尽一个 workspace 的全部索引行——workspace 删除级联；显式传 id，
// 因为彼时请求 ctx 可能已指向别处。
func (s *Store) PurgeWorkspace(ctx context.Context, workspaceID string) error {
	err := s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		if _, err := tx.Exec(ctx,
			`DELETE FROM search_embeddings WHERE doc_id IN (SELECT id FROM search_docs WHERE workspace_id = ?)`,
			workspaceID); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `DELETE FROM search_docs WHERE workspace_id = ?`, workspaceID)
		return err
	})
	if err != nil {
		return fmt.Errorf("searchstore.PurgeWorkspace %s: %w", workspaceID, err)
	}
	return nil
}

// DropAll clears the whole index (all workspaces) for the schema-version
// rebuild; reconcile repopulates from sources.
//
// DropAll 清空全索引（所有 workspace）供 schema 版本重建；对账从 source 重灌。
func (s *Store) DropAll(ctx context.Context) error {
	err := s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		if _, err := tx.Exec(ctx, `DELETE FROM search_embeddings`); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `DELETE FROM search_docs`)
		return err
	})
	if err != nil {
		return fmt.Errorf("searchstore.DropAll: %w", err)
	}
	return nil
}

// escapeLike neutralizes LIKE wildcards in user tokens (ESCAPE '\').
//
// escapeLike 中和用户 token 里的 LIKE 通配符（ESCAPE '\'）。
func escapeLike(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)
	return r.Replace(s)
}

// filterSQL renders the shared predicate tail (types/tags/archived/time) and
// its args. Tag filtering is ANY-of over the JSON array text — exact enough
// because tags are stored as `"tag"` quoted literals.
//
// filterSQL 渲染共享谓词尾（types/tags/archived/time）与参数。tag 过滤是对 JSON
// 数组文本的 ANY-of——tags 以 `"tag"` 引号字面量存储，足够精确。
func filterSQL(q searchdomain.LexicalQuery) (string, []any) {
	var sb strings.Builder
	var args []any
	if len(q.Types) > 0 {
		sb.WriteString(` AND d.entity_type IN (`)
		for i, t := range q.Types {
			if i > 0 {
				sb.WriteString(",")
			}
			sb.WriteString("?")
			args = append(args, string(t))
		}
		sb.WriteString(`)`)
	}
	if !q.IncludeArchived {
		sb.WriteString(` AND d.archived = 0`)
	}
	if len(q.Tags) > 0 {
		sb.WriteString(` AND (`)
		for i, tag := range q.Tags {
			if i > 0 {
				sb.WriteString(" OR ")
			}
			sb.WriteString(`d.tags LIKE ? ESCAPE '\'`)
			args = append(args, `%"`+escapeLike(tag)+`"%`)
		}
		sb.WriteString(`)`)
	}
	if q.UpdatedAfter != nil {
		sb.WriteString(` AND d.updated_at >= ?`)
		args = append(args, q.UpdatedAfter.UTC())
	}
	if q.UpdatedBefore != nil {
		sb.WriteString(` AND d.updated_at <= ?`)
		args = append(args, q.UpdatedBefore.UTC())
	}
	return sb.String(), args
}

// shortTokenSQL renders the per-short-token (title OR body) LIKE predicates.
//
// shortTokenSQL 渲染逐短 token 的 (title OR body) LIKE 谓词。
func shortTokenSQL(tokens []string) (string, []any) {
	var sb strings.Builder
	var args []any
	for _, tok := range tokens {
		pat := "%" + escapeLike(tok) + "%"
		sb.WriteString(` AND (d.title LIKE ? ESCAPE '\' OR d.body LIKE ? ESCAPE '\')`)
		args = append(args, pat, pat)
	}
	return sb.String(), args
}

// SearchLexical runs the token-routed lexical query: long tokens hit the
// FTS index (bm25-ranked, title weighted 4:1, score negated to higher-better);
// queries with only short tokens fall back to a LIKE scan with Go-built
// snippets — the trigram blind spot (<3 runes) must still find 2-char names.
//
// SearchLexical 执行 token 路由词法查询：长 token 打 FTS 索引（bm25 排序、
// title 4:1 加权、取负为越大越好）；只有短 token 的查询回退 LIKE 扫描 + Go 构造
// snippet——trigram 盲区（<3 rune）也必须搜得到 2 字名。
func (s *Store) SearchLexical(ctx context.Context, q searchdomain.LexicalQuery) ([]*searchdomain.DocHit, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	limit := q.Limit
	if limit <= 0 {
		limit = 100
	}
	if len(q.LongTokens) > 0 {
		return s.searchMatch(ctx, wsID, q, limit)
	}
	if len(q.ShortTokens) > 0 {
		return s.searchLike(ctx, wsID, q, limit)
	}
	return nil, nil
}

func (s *Store) searchMatch(ctx context.Context, wsID string, q searchdomain.LexicalQuery, limit int) ([]*searchdomain.DocHit, error) {
	var sb strings.Builder
	sb.WriteString(`SELECT d.id, d.entity_type, d.entity_id, d.chunk_no, d.anchor, d.title, d.tags, d.archived, d.updated_at,
		snippet(search_fts, 1, '<mark>', '</mark>', '…', 16),
		-bm25(search_fts, 4.0, 1.0)
	FROM search_fts JOIN search_docs d ON d.rowid = search_fts.rowid
	WHERE search_fts MATCH ? AND d.workspace_id = ?`)
	args := []any{searchdomain.BuildMatch(q.LongTokens), wsID}

	st, stArgs := shortTokenSQL(q.ShortTokens)
	sb.WriteString(st)
	args = append(args, stArgs...)
	f, fArgs := filterSQL(q)
	sb.WriteString(f)
	args = append(args, fArgs...)

	sb.WriteString(` ORDER BY bm25(search_fts, 4.0, 1.0) LIMIT ?`)
	args = append(args, limit)

	rows, err := s.db.Query(ctx, sb.String(), args...)
	if err != nil {
		return nil, fmt.Errorf("searchstore.SearchLexical match: %w", err)
	}
	defer rows.Close()
	return scanHits(rows, true)
}

func (s *Store) searchLike(ctx context.Context, wsID string, q searchdomain.LexicalQuery, limit int) ([]*searchdomain.DocHit, error) {
	var sb strings.Builder
	sb.WriteString(`SELECT d.id, d.entity_type, d.entity_id, d.chunk_no, d.anchor, d.title, d.tags, d.archived, d.updated_at, d.body
	FROM search_docs d
	WHERE d.workspace_id = ?`)
	args := []any{wsID}

	st, stArgs := shortTokenSQL(q.ShortTokens)
	sb.WriteString(st)
	args = append(args, stArgs...)
	f, fArgs := filterSQL(q)
	sb.WriteString(f)
	args = append(args, fArgs...)

	sb.WriteString(` ORDER BY d.updated_at DESC LIMIT ?`)
	args = append(args, limit)

	rows, err := s.db.Query(ctx, sb.String(), args...)
	if err != nil {
		return nil, fmt.Errorf("searchstore.SearchLexical like: %w", err)
	}
	defer rows.Close()
	hits, err := scanHits(rows, false)
	if err != nil {
		return nil, err
	}
	// Score and snippet in Go: title hits beat body-only hits; the snippet
	// window centers on the first token occurrence.
	// Go 内打分与 snippet：title 命中胜 body 命中；snippet 窗口居中首个 token 出现处。
	for _, h := range hits {
		titleHit := false
		for _, tok := range q.ShortTokens {
			if strings.Contains(strings.ToLower(h.Title), strings.ToLower(tok)) {
				titleHit = true
				break
			}
		}
		if titleHit {
			h.Score = 1.0
		} else {
			h.Score = 0.5
		}
		h.Snippet = likeSnippet(h.Snippet, q.ShortTokens)
	}
	return hits, nil
}

// scanHits maps rows to DocHits. For the MATCH path the 10th column is the FTS
// snippet and the 11th the negated bm25; for the LIKE path the 10th is the raw
// body (snippet built by the caller) and the score is filled afterwards.
//
// scanHits 把行映射为 DocHit。MATCH 路径第 10 列是 FTS snippet、第 11 列是取负
// bm25；LIKE 路径第 10 列是原始 body（caller 构造 snippet）、分数由调用方补。
func scanHits(rows *sql.Rows, withScore bool) ([]*searchdomain.DocHit, error) {
	var hits []*searchdomain.DocHit
	for rows.Next() {
		h := &searchdomain.DocHit{}
		var et, tags string
		var archived int
		var err error
		if withScore {
			err = rows.Scan(&h.DocID, &et, &h.EntityID, &h.ChunkNo, &h.Anchor, &h.Title, &tags, &archived, &h.UpdatedAt, &h.Snippet, &h.Score)
		} else {
			err = rows.Scan(&h.DocID, &et, &h.EntityID, &h.ChunkNo, &h.Anchor, &h.Title, &tags, &archived, &h.UpdatedAt, &h.Snippet)
		}
		if err != nil {
			return nil, fmt.Errorf("searchstore.scanHits: %w", err)
		}
		h.EntityType = searchdomain.EntityType(et)
		h.Tags = unmarshalTags(tags)
		h.Archived = archived != 0
		hits = append(hits, h)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("searchstore.scanHits: %w", err)
	}
	return hits, nil
}

// likeSnippet builds a ±60-rune window around the first token occurrence in
// body, mirroring the FTS snippet's <mark> markers.
//
// likeSnippet 围绕 body 中首个 token 出现处取 ±60 rune 窗口，对齐 FTS snippet 的
// <mark> 标记。
func likeSnippet(body string, tokens []string) string {
	if body == "" {
		return ""
	}
	lower := strings.ToLower(body)
	idx, tokLen := -1, 0
	for _, tok := range tokens {
		if i := strings.Index(lower, strings.ToLower(tok)); i >= 0 && (idx < 0 || i < idx) {
			idx, tokLen = i, len(tok)
		}
	}
	if idx < 0 {
		r := []rune(body)
		if len(r) > 120 {
			return string(r[:120]) + "…"
		}
		return body
	}
	start := idx
	for range 60 {
		if start == 0 {
			break
		}
		start--
		for start > 0 && !utf8RuneStart(body[start]) {
			start--
		}
	}
	end := min(idx+tokLen+180, len(body))
	for end < len(body) && !utf8RuneStart(body[end]) {
		end++
	}
	snip := body[start:idx] + "<mark>" + body[idx:idx+tokLen] + "</mark>" + body[idx+tokLen:end]
	if start > 0 {
		snip = "…" + snip
	}
	if end < len(body) {
		snip += "…"
	}
	return snip
}

func utf8RuneStart(b byte) bool { return b&0xC0 != 0x80 }

// EntityStamps returns entity_id → max(updated_at) for one type in the ctx
// workspace. MAX over the driver's canonical UTC time encoding is order-safe.
//
// EntityStamps 返回 ctx workspace 内某类的 entity_id → max(updated_at)。对驱动
// 规范 UTC 时间编码取 MAX 序安全。
func (s *Store) EntityStamps(ctx context.Context, t searchdomain.EntityType) (map[string]time.Time, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx,
		`SELECT entity_id, MAX(updated_at) FROM search_docs WHERE workspace_id = ? AND entity_type = ? GROUP BY entity_id`,
		wsID, string(t))
	if err != nil {
		return nil, fmt.Errorf("searchstore.EntityStamps: %w", err)
	}
	defer rows.Close()
	out := map[string]time.Time{}
	for rows.Next() {
		var id, raw string
		// MAX() strips the column's DATETIME affinity, so the driver hands back
		// the raw text encoding — parse it instead of scanning time.Time.
		// MAX() 剥掉列的 DATETIME 亲和性，驱动返回原始文本编码——解析而非直接扫 time.Time。
		if err := rows.Scan(&id, &raw); err != nil {
			return nil, fmt.Errorf("searchstore.EntityStamps scan: %w", err)
		}
		ts, err := parseStoredTime(raw)
		if err != nil {
			return nil, fmt.Errorf("searchstore.EntityStamps parse %q: %w", raw, err)
		}
		out[id] = ts
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("searchstore.EntityStamps rows: %w", err)
	}
	return out, nil
}

// parseStoredTime decodes the driver's text time encodings (RFC3339 with or
// without nanoseconds / the space-separated SQLite form).
//
// parseStoredTime 解析驱动的文本时间编码（带/不带纳秒的 RFC3339 / SQLite 空格形）。
func parseStoredTime(raw string) (time.Time, error) {
	for _, layout := range []string{time.RFC3339Nano, time.RFC3339, "2006-01-02 15:04:05.999999999-07:00", "2006-01-02 15:04:05"} {
		if ts, err := time.Parse(layout, raw); err == nil {
			return ts, nil
		}
	}
	return time.Time{}, fmt.Errorf("unrecognized time encoding")
}

// GetMeta returns "" for a missing key — meta values all have safe zero
// defaults (schema version 0, embedder builtin).
//
// GetMeta 对缺失 key 返回 ""——meta 值都有安全零默认（schema 版本 0、embedder builtin）。
func (s *Store) GetMeta(ctx context.Context, key string) (string, error) {
	var v string
	err := s.db.QueryRow(ctx, `SELECT value FROM search_meta WHERE key = ?`, key).Scan(&v)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("searchstore.GetMeta %s: %w", key, err)
	}
	return v, nil
}

func (s *Store) SetMeta(ctx context.Context, key, value string) error {
	_, err := s.db.Exec(ctx,
		`INSERT INTO search_meta(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
		key, value)
	if err != nil {
		return fmt.Errorf("searchstore.SetMeta %s: %w", key, err)
	}
	return nil
}
