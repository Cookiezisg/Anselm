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

const editDocumentDescription = `Update a document's fields; only supplied fields change. content and tags are full replacements (no diff/patch). Renaming cascades the path to all descendants. To change parent, use move_document.`

var editDocumentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id":          {"type": "string"},
		"name":        {"type": "string", "description": "Renaming cascades path to all descendants."},
		"description": {"type": "string"},
		"content":     {"type": "string", "description": "Full replacement; no diff/patch semantics."},
		"tags":        {"type": "array", "items": {"type": "string"}, "description": "Full replacement."}
	}
}`)

type EditDocument struct {
	svc *documentapp.Service
}

func (t *EditDocument) Name() string                { return "edit_document" }
func (t *EditDocument) Description() string         { return editDocumentDescription }
func (t *EditDocument) Parameters() json.RawMessage { return editDocumentSchema }

func (t *EditDocument) IsReadOnly() bool        { return false }
func (t *EditDocument) NeedsReadFirst() bool    { return false }
func (t *EditDocument) RequiresWorkspace() bool { return false }

func (t *EditDocument) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("edit_document.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return errors.New("edit_document: id is required")
	}
	return nil
}

func (t *EditDocument) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *EditDocument) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		ID          string    `json:"id"`
		Name        *string   `json:"name,omitempty"`
		Description *string   `json:"description,omitempty"`
		Content     *string   `json:"content,omitempty"`
		Tags        *[]string `json:"tags,omitempty"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("edit_document.Execute: %w", err)
	}
	if a.Name == nil && a.Description == nil && a.Content == nil && a.Tags == nil {
		return "edit_document: nothing to update (provide at least one of name / description / content / tags).", nil
	}
	d, err := t.svc.Update(ctx, a.ID, documentapp.UpdateInput{
		Name:        a.Name,
		Description: a.Description,
		Content:     a.Content,
		Tags:        a.Tags,
	})
	if err != nil {
		switch {
		case errors.Is(err, documentdomain.ErrNotFound):
			return fmt.Sprintf("Document %q not found.", a.ID), nil
		case errors.Is(err, documentdomain.ErrNameConflict):
			return "A sibling doc with that new name already exists. Pick another name.", nil
		case errors.Is(err, documentdomain.ErrContentTooLarge):
			return "Content exceeds 1 MB. Split into child docs.", nil
		case errors.Is(err, documentdomain.ErrInvalidName):
			return "Invalid name (no slashes; non-empty; ≤256 chars).", nil
		default:
			return "", err
		}
	}
	return fmt.Sprintf("Updated document %q (id=%s, path=%s).", d.Name, d.ID, d.Path), nil
}
