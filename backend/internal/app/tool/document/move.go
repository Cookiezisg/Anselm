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

const moveDocumentDescription = `Reparent a document; parentId=null moves to root. position is the sibling index (0=first), omit to append. Path cascades to descendants. Cycles and self-parenting are rejected.`

var moveDocumentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id":       {"type": "string"},
		"parentId": {"type": ["string", "null"], "description": "New parent ID; null = root."},
		"position": {"type": "integer", "minimum": 0, "description": "Sibling index (0=first); omit to append."}
	}
}`)

type MoveDocument struct {
	svc *documentapp.Service
}

func (t *MoveDocument) Name() string                { return "move_document" }
func (t *MoveDocument) Description() string         { return moveDocumentDescription }
func (t *MoveDocument) Parameters() json.RawMessage { return moveDocumentSchema }

func (t *MoveDocument) IsReadOnly() bool        { return false }
func (t *MoveDocument) NeedsReadFirst() bool    { return false }
func (t *MoveDocument) RequiresWorkspace() bool { return false }

func (t *MoveDocument) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("move_document.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return errors.New("move_document: id is required")
	}
	return nil
}

func (t *MoveDocument) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *MoveDocument) Execute(ctx context.Context, argsJSON string) (string, error) {
	// Raw map lets us distinguish "parentId absent" from "parentId null"
	// (both legitimate user intents; absent = no change attempt).
	//
	// 用 raw map 区分 "parentId 缺失" vs "parentId null"
	// (前者 = 不动 parent;后者 = 移到根级)。
	var raw map[string]json.RawMessage
	if err := json.Unmarshal([]byte(argsJSON), &raw); err != nil {
		return "", fmt.Errorf("move_document.Execute: %w", err)
	}
	var a struct {
		ID       string  `json:"id"`
		ParentID *string `json:"parentId"`
		Position *int    `json:"position,omitempty"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("move_document.Execute: %w", err)
	}
	if a.ParentID != nil && *a.ParentID == "" {
		a.ParentID = nil
	}
	in := documentdomain.MoveInput{Position: a.Position}
	if _, parentProvided := raw["parentId"]; parentProvided {
		in.ParentID = a.ParentID
	} else {
		// Caller omitted parentId — keep current parent.
		// We need to fetch current to express "no change"; easier:
		// reject with a friendly hint to the LLM.
		//
		// 调用方未传 parentId,需保留原父。简单处理:友好提示要求显式传入。
		return "move_document: parentId required (pass null to move to root, or a doc ID to reparent).", nil
	}
	d, err := t.svc.Move(ctx, a.ID, in)
	if err != nil {
		switch {
		case errors.Is(err, documentdomain.ErrNotFound):
			return fmt.Sprintf("Document %q not found.", a.ID), nil
		case errors.Is(err, documentdomain.ErrParentNotFound):
			return "New parent not found.", nil
		case errors.Is(err, documentdomain.ErrInvalidParent):
			return "Cannot move a document under itself or one of its own descendants (cycle).", nil
		default:
			return "", err
		}
	}
	return fmt.Sprintf("Moved %q to %s (new path: %s).", d.Name, parentLabel(d.ParentID), d.Path), nil
}

func parentLabel(parentID *string) string {
	if parentID == nil {
		return "root"
	}
	return *parentID
}
