package document

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	documentapp "github.com/sunweilin/anselm/backend/internal/app/document"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
)

const deleteDocumentDescription = `Delete a document and all of its descendants recursively. This changes recoverable state: set danger="cautious" so the user sees the action, but do not claim it is irreversible. Tombstoned documents can be recovered; already-sent messages keep resolving. Returns the deleted count.`

var deleteDocumentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id": {"type": "string"}
	}
}`)

// DeleteDocument implements the delete_document system tool.
//
// DeleteDocument 是 delete_document 系统工具的实现。
type DeleteDocument struct{ svc *documentapp.Service }

func (t *DeleteDocument) Name() string                       { return "delete_document" }
func (t *DeleteDocument) MinimumDanger() toolapp.DangerLevel { return toolapp.DangerCautious }
func (t *DeleteDocument) Description() string                { return deleteDocumentDescription }
func (t *DeleteDocument) Parameters() json.RawMessage        { return deleteDocumentSchema }

func (t *DeleteDocument) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_document: bad args: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return ErrIDRequired
	}
	return nil
}

func (t *DeleteDocument) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("delete_document: %w", err)
	}
	n, err := t.svc.Delete(ctx, a.ID)
	if err != nil {
		if errors.Is(err, documentdomain.ErrNotFound) {
			return fmt.Sprintf("Document %q not found (already deleted?).", a.ID), nil
		}
		return "", err
	}
	if n <= 1 {
		return fmt.Sprintf("Deleted document %s (no descendants).", a.ID), nil
	}
	return fmt.Sprintf("Deleted document %s along with %d descendant(s).", a.ID, n-1), nil
}
