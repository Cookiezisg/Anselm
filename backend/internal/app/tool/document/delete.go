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

const deleteDocumentDescription = `Soft-delete a document AND all its descendants recursively. This is reversible only via the user's UI (or DB restore) — you cannot undo a delete from inside another tool call.

Set destructive=true on this call (it's a delete) so the user gets a confirmation prompt under permissions mode = ask.

Returns the deleted-count including descendants.`

var deleteDocumentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id": {
			"type": "string",
			"description": "Document ID to soft-delete (descendants also deleted recursively)."
		}
	}
}`)

type DeleteDocument struct {
	svc *documentapp.Service
}

func (t *DeleteDocument) Name() string                { return "delete_document" }
func (t *DeleteDocument) Description() string         { return deleteDocumentDescription }
func (t *DeleteDocument) Parameters() json.RawMessage { return deleteDocumentSchema }

func (t *DeleteDocument) IsReadOnly() bool        { return false }
func (t *DeleteDocument) NeedsReadFirst() bool    { return false }
func (t *DeleteDocument) RequiresWorkspace() bool { return false }

func (t *DeleteDocument) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_document.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return errors.New("delete_document: id is required")
	}
	return nil
}

func (t *DeleteDocument) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *DeleteDocument) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("delete_document.Execute: %w", err)
	}
	n, err := t.svc.Delete(ctx, a.ID)
	if err != nil {
		if errors.Is(err, documentdomain.ErrNotFound) {
			return fmt.Sprintf("Document %q not found (already deleted?).", a.ID), nil
		}
		return "", err
	}
	if n == 1 {
		return fmt.Sprintf("Deleted document %s (no descendants).", a.ID), nil
	}
	return fmt.Sprintf("Deleted document %s along with %d descendant(s).", a.ID, n-1), nil
}
