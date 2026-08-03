package document

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	documentapp "github.com/sunweilin/anselm/backend/internal/app/document"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

const (
	listDocumentsDefaultLimit = 50
	listDocumentsMaxLimit     = 200
)

const listDocumentsDescription = `Enumerate direct children one level under parentId (null/omit = root), cursor-paged in sibling order. Each response includes count (this page), total (all direct children), complete (true only on the final page), and hasMore; when hasMore is true, copy nextCursor byte-for-byte into cursor for the next page. Never infer completeness from count. Once an identical list_documents call has returned in the same turn, do not repeat it; use that result or make a materially different bounded request. Each row has id, name, description, path, and position; position is the 0-based sibling index (0 = first) — use it to see current ordering and to pick the target index for move_document. Default page size is 50 and the maximum is 200. Walk the tree progressively; use search_documents for keyword search.`

var listDocumentsSchema = json.RawMessage(`{
	"type": "object",
	"properties": {
		"parentId": {"type": ["string", "null"], "description": "Parent doc ID; null/omit = root."},
		"cursor": {"type": "string", "description": "Opaque nextCursor from the previous page; copy byte-for-byte."},
		"limit": {"type": "integer", "description": "Page size, 1-200; default 50. An exact decimal string is also accepted from managed callers."}
	}
}`)

type listDocumentsArgs struct {
	ParentID *string
	Cursor   string
	Limit    int
}

func (a *listDocumentsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		ParentID *string         `json:"parentId"`
		Cursor   string          `json:"cursor"`
		Limit    json.RawMessage `json:"limit"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	limit, err := decodeListDocumentsInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = listDocumentsArgs{ParentID: raw.ParentID, Cursor: raw.Cursor, Limit: limit}
	return nil
}

func decodeListDocumentsInt(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be an integer or exact decimal integer string")
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be an integer or exact decimal integer string")
	}
	return value, nil
}

// ListDocuments implements the list_documents system tool.
//
// ListDocuments 是 list_documents 系统工具的实现。
type ListDocuments struct{ svc *documentapp.Service }

func (t *ListDocuments) Name() string                { return "list_documents" }
func (t *ListDocuments) Description() string         { return listDocumentsDescription }
func (t *ListDocuments) Parameters() json.RawMessage { return listDocumentsSchema }

func (t *ListDocuments) ValidateInput(args json.RawMessage) error {
	if len(args) == 0 {
		return nil
	}
	var a listDocumentsArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("list_documents: bad args: %w", err)
	}
	return nil
}

func (t *ListDocuments) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a listDocumentsArgs
	if argsJSON != "" {
		if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
			return "", fmt.Errorf("list_documents: %w", err)
		}
	}
	// Empty-string parentId is treated as null (root).
	//
	// 空字符串 parentId 视为 null（根级）。
	if a.ParentID != nil && *a.ParentID == "" {
		a.ParentID = nil
	}
	limit := a.Limit
	if limit <= 0 {
		limit = listDocumentsDefaultLimit
	}
	if limit > listDocumentsMaxLimit {
		limit = listDocumentsMaxLimit
	}
	rows, total, next, err := t.svc.ListByParentPage(ctx, a.ParentID, a.Cursor, limit)
	if err != nil {
		return "", err
	}
	type slim struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Path        string `json:"path"`
		Position    int    `json:"position"`
		Description string `json:"description,omitempty"`
	}
	out := make([]slim, 0, len(rows))
	for _, d := range rows {
		out = append(out, slim{ID: d.ID, Name: d.Name, Path: d.Path, Position: d.Position, Description: d.Description})
	}
	result := map[string]any{
		"count":     len(out),
		"total":     total,
		"documents": out,
		"complete":  next == "",
		"hasMore":   next != "",
	}
	if next != "" {
		result["nextCursor"] = next
	}
	return toolapp.ToJSON(result), nil
}
