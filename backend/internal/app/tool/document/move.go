package document

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"

	documentapp "github.com/sunweilin/anselm/backend/internal/app/document"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
)

const moveDocumentDescription = `Reparent a document; parentId=null moves to root. position is the sibling index (0=first), omit to append. For hosted-model compatibility, an exact decimal integer string such as "0" is also accepted; floats, booleans, arrays, and malformed strings are rejected. Path cascades to descendants. Cycles and self-parenting are rejected. A cycle rejection is final for that exact document/parent pair; do not retry it in this turn unless the requested parent changes.`

const moveCycleRejection = "Cannot move a document under itself or one of its own descendants (cycle)."

var moveDocumentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id":       {"type": "string"},
		"parentId": {"type": ["string", "null"], "description": "New parent ID; null = root."},
		"position": {"type": "integer", "minimum": 0, "description": "Sibling index (0=first); omit to append. An exact decimal integer string is also accepted from hosted callers; other strings and non-integers are invalid."}
	}
}`)

type moveDocumentArgs struct {
	ID             string
	ParentID       *string
	Position       *int
	parentProvided bool
}

func (a *moveDocumentArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		ID       string          `json:"id"`
		ParentID json.RawMessage `json:"parentId"`
		Position json.RawMessage `json:"position"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}

	var parentID *string
	parentProvided := len(raw.ParentID) != 0
	if parentProvided && !bytes.Equal(bytes.TrimSpace(raw.ParentID), []byte("null")) {
		var value string
		if err := json.Unmarshal(raw.ParentID, &value); err != nil {
			return fmt.Errorf("parentId: must be a string or null")
		}
		parentID = &value
	}
	position, err := decodeMoveDocumentPosition(raw.Position)
	if err != nil {
		return fmt.Errorf("position: %w", err)
	}
	*a = moveDocumentArgs{ID: raw.ID, ParentID: parentID, Position: position, parentProvided: parentProvided}
	return nil
}

func decodeMoveDocumentPosition(raw json.RawMessage) (*int, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		if value < 0 {
			return nil, fmt.Errorf("must be a non-negative integer or exact decimal integer string")
		}
		return &value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return nil, fmt.Errorf("must be a non-negative integer or exact decimal integer string")
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil || value < 0 {
		return nil, fmt.Errorf("must be a non-negative integer or exact decimal integer string")
	}
	return &value, nil
}

// MoveDocument implements the move_document system tool.
//
// MoveDocument 是 move_document 系统工具的实现。
type MoveDocument struct{ svc *documentapp.Service }

func (t *MoveDocument) Name() string                { return "move_document" }
func (t *MoveDocument) Description() string         { return moveDocumentDescription }
func (t *MoveDocument) Parameters() json.RawMessage { return moveDocumentSchema }

// HaltOnRepeat marks only the cycle rejection as terminal. A missing parent can become valid after
// another mutation in the same turn, so it intentionally keeps the ordinary retry path.
//
// HaltOnRepeat 只把循环拒绝标为终局。父节点不存在可能在本回合另一处变更后变得有效，故刻意保留普通重试路。
func (t *MoveDocument) HaltOnRepeat(result string, errorText string) bool {
	return errorText == "" && strings.HasPrefix(result, moveCycleRejection)
}

func (t *MoveDocument) ValidateInput(args json.RawMessage) error {
	var a moveDocumentArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("move_document: bad args: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return ErrIDRequired
	}
	return nil
}

func (t *MoveDocument) Execute(ctx context.Context, argsJSON string) (string, error) {
	// Raw map distinguishes "parentId absent" from "parentId null" — both are legitimate
	// intents (absent = caller didn't mean to move; null = move to root).
	//
	// raw map 区分 "parentId 缺失" vs "parentId null"——皆合法（缺失=无意移动；null=移到根）。
	var a moveDocumentArgs
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("move_document: %w", err)
	}
	if a.ParentID != nil && *a.ParentID == "" {
		a.ParentID = nil
	}
	if !a.parentProvided {
		return "move_document: parentId required (pass null to move to root, or a doc ID to reparent).", nil
	}
	d, err := t.svc.Move(ctx, a.ID, documentapp.MoveInput{ParentID: a.ParentID, Position: a.Position})
	if err != nil {
		switch {
		case errors.Is(err, documentdomain.ErrNotFound):
			return fmt.Sprintf("Document %q not found.", a.ID), nil
		case errors.Is(err, documentdomain.ErrParentNotFound):
			return "New parent not found.", nil
		case errors.Is(err, documentdomain.ErrInvalidParent):
			return moveCycleRejection + " This rejection is final for this exact document/parent pair; do not retry it in this turn unless the requested parent changes.", nil
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
