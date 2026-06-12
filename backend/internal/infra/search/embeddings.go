package search

import (
	"context"
	"encoding/binary"
	"fmt"
	"math"
	"strings"

	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// encodeVector packs float32s little-endian — the search_embeddings BLOB format.
//
// encodeVector 按小端打包 float32——search_embeddings 的 BLOB 格式。
func encodeVector(v []float32) []byte {
	out := make([]byte, 4*len(v))
	for i, f := range v {
		binary.LittleEndian.PutUint32(out[i*4:], math.Float32bits(f))
	}
	return out
}

func decodeVector(b []byte) []float32 {
	out := make([]float32, len(b)/4)
	for i := range out {
		out[i] = math.Float32frombits(binary.LittleEndian.Uint32(b[i*4:]))
	}
	return out
}

func (s *Store) UpsertEmbedding(ctx context.Context, docID, model string, vector []float32) error {
	_, err := s.db.Exec(ctx,
		`INSERT INTO search_embeddings(doc_id, model, dims, vector) VALUES (?, ?, ?, ?)
		 ON CONFLICT(doc_id) DO UPDATE SET model = excluded.model, dims = excluded.dims, vector = excluded.vector`,
		docID, model, len(vector), encodeVector(vector))
	if err != nil {
		return fmt.Errorf("searchstore.UpsertEmbedding %s: %w", docID, err)
	}
	return nil
}

// MissingEmbeddings scans the ctx workspace for rows without a vector under
// model — rows embedded under a DIFFERENT model count as missing (switching
// embedders invalidates, never mixes).
//
// MissingEmbeddings 扫 ctx workspace 内缺该 model 向量的行——以**其它** model 嵌过的
// 行同样算缺（换 embedder 即失效、绝不混用）。
func (s *Store) MissingEmbeddings(ctx context.Context, model string, limit int) ([]searchdomain.EmbedDoc, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 32
	}
	rows, err := s.db.Query(ctx,
		`SELECT d.id, d.title, d.body FROM search_docs d
		 LEFT JOIN search_embeddings e ON e.doc_id = d.id AND e.model = ?
		 WHERE d.workspace_id = ? AND e.doc_id IS NULL
		 ORDER BY d.updated_at DESC LIMIT ?`,
		model, wsID, limit)
	if err != nil {
		return nil, fmt.Errorf("searchstore.MissingEmbeddings: %w", err)
	}
	defer rows.Close()
	var out []searchdomain.EmbedDoc
	for rows.Next() {
		var d searchdomain.EmbedDoc
		if err := rows.Scan(&d.DocID, &d.Title, &d.Body); err != nil {
			return nil, fmt.Errorf("searchstore.MissingEmbeddings scan: %w", err)
		}
		out = append(out, d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("searchstore.MissingEmbeddings rows: %w", err)
	}
	return out, nil
}

func (s *Store) WorkspaceVectors(ctx context.Context, model string) (map[string][]float32, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx,
		`SELECT e.doc_id, e.vector FROM search_embeddings e
		 JOIN search_docs d ON d.id = e.doc_id
		 WHERE d.workspace_id = ? AND e.model = ?`,
		wsID, model)
	if err != nil {
		return nil, fmt.Errorf("searchstore.WorkspaceVectors: %w", err)
	}
	defer rows.Close()
	out := map[string][]float32{}
	for rows.Next() {
		var id string
		var blob []byte
		if err := rows.Scan(&id, &blob); err != nil {
			return nil, fmt.Errorf("searchstore.WorkspaceVectors scan: %w", err)
		}
		out[id] = decodeVector(blob)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("searchstore.WorkspaceVectors rows: %w", err)
	}
	return out, nil
}

// DocsByIDs hydrates chunk rows for vector-only hits; Snippet is the body head
// (no lexical match to highlight), Score is left zero for the fuser to fill.
//
// DocsByIDs 为纯向量命中补行；Snippet 取正文头部（无词法命中可高亮），Score 留零
// 由融合器填。
func (s *Store) DocsByIDs(ctx context.Context, ids []string) ([]*searchdomain.DocHit, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return nil, nil
	}
	var sb strings.Builder
	sb.WriteString(`SELECT d.id, d.entity_type, d.entity_id, d.chunk_no, d.anchor, d.title, d.tags, d.archived, d.updated_at,
		substr(d.body, 1, 240)
	FROM search_docs d WHERE d.workspace_id = ? AND d.id IN (`)
	args := []any{wsID}
	for i, id := range ids {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString("?")
		args = append(args, id)
	}
	sb.WriteString(")")
	rows, err := s.db.Query(ctx, sb.String(), args...)
	if err != nil {
		return nil, fmt.Errorf("searchstore.DocsByIDs: %w", err)
	}
	defer rows.Close()
	return scanHits(rows, false)
}

// BodiesByIDs returns full bodies for RAG retrieval.
//
// BodiesByIDs 返回完整 body 供 RAG 取数。
func (s *Store) BodiesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return map[string]string{}, nil
	}
	var sb strings.Builder
	sb.WriteString(`SELECT id, body FROM search_docs WHERE workspace_id = ? AND id IN (`)
	args := []any{wsID}
	for i, id := range ids {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString("?")
		args = append(args, id)
	}
	sb.WriteString(")")
	rows, err := s.db.Query(ctx, sb.String(), args...)
	if err != nil {
		return nil, fmt.Errorf("searchstore.BodiesByIDs: %w", err)
	}
	defer rows.Close()
	out := map[string]string{}
	for rows.Next() {
		var id, body string
		if err := rows.Scan(&id, &body); err != nil {
			return nil, fmt.Errorf("searchstore.BodiesByIDs scan: %w", err)
		}
		out[id] = body
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("searchstore.BodiesByIDs rows: %w", err)
	}
	return out, nil
}

// BlockRows lists every block-palette row (six kinds) in the ctx workspace —
// the precision chain's direct-feed catalog (snippet = body head).
//
// BlockRows 列出 ctx workspace 全部积木行（六类）——精度链直喂目录（snippet=正文头）。
func (s *Store) BlockRows(ctx context.Context) ([]*searchdomain.DocHit, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx,
		`SELECT d.id, d.entity_type, d.entity_id, d.chunk_no, d.anchor, d.title, d.tags, d.archived, d.updated_at,
			substr(d.body, 1, 240)
		FROM search_docs d
		WHERE d.workspace_id = ? AND d.entity_type IN ('function','handler','mcp','agent','control','approval')
		ORDER BY d.entity_type, d.entity_id, d.chunk_no`,
		wsID)
	if err != nil {
		return nil, fmt.Errorf("searchstore.BlockRows: %w", err)
	}
	defer rows.Close()
	return scanHits(rows, false)
}
