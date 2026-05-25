package document

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

const listDocumentsDescription = `List direct children one level under parentId (null/omit=root): name, description, path each. Walk the tree progressively; use search_documents for keyword search.`

var listDocumentsSchema = json.RawMessage(`{
	"type": "object",
	"properties": {
		"parentId": {"type": ["string", "null"], "description": "Parent doc ID; null/omit = root."}
	}
}`)

type ListDocuments struct {
	svc *documentapp.Service
}

func (t *ListDocuments) Name() string                { return "list_documents" }
func (t *ListDocuments) Description() string         { return listDocumentsDescription }
func (t *ListDocuments) Parameters() json.RawMessage { return listDocumentsSchema }

func (t *ListDocuments) IsReadOnly() bool        { return true }
func (t *ListDocuments) NeedsReadFirst() bool    { return false }
func (t *ListDocuments) RequiresWorkspace() bool { return false }

func (t *ListDocuments) ValidateInput(args json.RawMessage) error {
	if len(args) == 0 {
		return nil
	}
	var a struct {
		ParentID *string `json:"parentId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("list_documents.ValidateInput: %w", err)
	}
	return nil
}

func (t *ListDocuments) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *ListDocuments) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		ParentID *string `json:"parentId"`
	}
	if argsJSON != "" {
		if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
			return "", fmt.Errorf("list_documents.Execute: %w", err)
		}
	}
	// Empty string parentId is treated as null (root).
	//
	// 空 string parentId 视为 null(根级)。
	if a.ParentID != nil && *a.ParentID == "" {
		a.ParentID = nil
	}
	rows, err := t.svc.ListByParent(ctx, a.ParentID)
	if err != nil {
		return "", err
	}
	scopeLabel := "root level"
	if a.ParentID != nil {
		scopeLabel = fmt.Sprintf("under %s", *a.ParentID)
	}
	if len(rows) == 0 {
		return fmt.Sprintf("No documents at %s.", scopeLabel), nil
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "%d document(s) at %s:\n\n", len(rows), scopeLabel)
	for _, d := range rows {
		fmt.Fprintf(&sb, "- %s (id=%s, path=%s)\n", d.Name, d.ID, d.Path)
		if d.Description != "" {
			fmt.Fprintf(&sb, "  %s\n", d.Description)
		}
	}
	sb.WriteString("\nUse list_documents(parentId=<id>) to drill in or read_document(id) to load content.")
	return sb.String(), nil
}
