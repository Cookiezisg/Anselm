package document

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
)

const createDocumentDescription = `Create a document in the user's library. parentId nests it under another doc (Notion-style); null/omit = root. content is the full markdown body (split into child docs if >1MB). Name must be unique among siblings (auto-suffixed on collision).`

var createDocumentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["name"],
	"properties": {
		"name":        {"type": "string", "description": "Document title; no slashes, ≤256 chars."},
		"parentId":    {"type": ["string", "null"], "description": "Parent doc ID; null/omit = root."},
		"description": {"type": "string", "description": "One-line catalog summary."},
		"content":     {"type": "string", "description": "Full markdown body."},
		"tags":        {"type": "array", "items": {"type": "string"}}
	}
}`)

type CreateDocument struct {
	svc *documentapp.Service
}

func (t *CreateDocument) Name() string                { return "create_document" }
func (t *CreateDocument) Description() string         { return createDocumentDescription }
func (t *CreateDocument) Parameters() json.RawMessage { return createDocumentSchema }

func (t *CreateDocument) IsReadOnly() bool        { return false }
func (t *CreateDocument) NeedsReadFirst() bool    { return false }
func (t *CreateDocument) RequiresWorkspace() bool { return false }

func (t *CreateDocument) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_document.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return errors.New("create_document: name is required")
	}
	return nil
}

func (t *CreateDocument) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *CreateDocument) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		Name        string   `json:"name"`
		ParentID    *string  `json:"parentId"`
		Description string   `json:"description"`
		Content     string   `json:"content"`
		Tags        []string `json:"tags"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("create_document.Execute: %w", err)
	}
	// Empty parentId treated as null (root-level create).
	//
	// 空字符串 parentId 视为 null(根级创建)。
	if a.ParentID != nil && *a.ParentID == "" {
		a.ParentID = nil
	}
	d, err := t.svc.Create(ctx, documentapp.CreateInput{
		Name:        a.Name,
		ParentID:    a.ParentID,
		Description: a.Description,
		Content:     a.Content,
		Tags:        a.Tags,
	})
	if err != nil {
		switch {
		case errors.Is(err, documentdomain.ErrParentNotFound):
			return fmt.Sprintf("Parent doc %q not found. Confirm with list_documents or search_documents.", *a.ParentID), nil
		case errors.Is(err, documentdomain.ErrContentTooLarge):
			return "Content exceeds 1 MB. Split into smaller child docs.", nil
		case errors.Is(err, documentdomain.ErrInvalidName):
			return fmt.Sprintf("Invalid name %q (no slashes; non-empty; ≤256 chars).", a.Name), nil
		default:
			return "", err
		}
	}
	// Service auto-suffixes on name collision ("X" → "X 2"). Tell the LLM
	// when that happened so it can reason about the actual name.
	if a.Name != "" && d.Name != a.Name {
		return fmt.Sprintf("Created document %q (id=%s, path=%s). Note: requested name %q was taken; auto-renamed.", d.Name, d.ID, d.Path, a.Name), nil
	}
	return fmt.Sprintf("Created document %q (id=%s, path=%s).", d.Name, d.ID, d.Path), nil
}
