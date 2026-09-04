package document

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	documentapp "github.com/sunweilin/anselm/backend/internal/app/document"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
)

const createDocumentDescription = `Create a document in the user's library. name, description, content, and tags are REQUIRED on every call, including the first call. Send the exact requested document title as a non-empty name; copy user-supplied description, tags, and content exactly. If the user did not supply one of those three fields, send an explicit empty string or empty array for that field — never omit it, invent it, or use a name-only placeholder. Never omit a required field, stage creation followed by edit, guess a default, or silently retry the same document with different arguments. One requested document gets one canonical create call; validation failure is not success. parentId nests it under another doc (Notion-style); null/omit = root. content is the full markdown body — max 1MB; larger content is REJECTED (DOCUMENT_CONTENT_TOO_LARGE), not auto-split, so break it into smaller child docs yourself. Name must be unique among siblings (auto-suffixed on collision). Hosted-provider compatibility accepts one exact JSON-encoded array string for tags (for example "[\\"release\\"]") when a provider adds one layer of quoting; comma-joined or arbitrary strings remain invalid. To embed an image the workspace already holds — one you just generated, or one attached to this conversation — write a normal markdown image whose url is anselm://media/<attachmentId>, for example: ![sales chart](anselm://media/att_0011223344556677). That is the ONLY form the library renders: a plain https url renders as an external image, and a bare attachment id renders as nothing.`

var createDocumentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["name", "description", "content", "tags"],
	"properties": {
		"name":        {"type": "string", "description": "REQUIRED on every call, including the first; exact requested document title, non-empty, no slashes, up to 256 chars. Never omit, guess, or use a placeholder."},
		"parentId":    {"type": ["string", "null"], "description": "Parent doc ID; null/omit = root."},
		"description": {"type": "string", "description": "REQUIRED on every call. Copy the user's description exactly; if none was supplied, use an empty string. Never omit or invent."},
		"content":     {"type": "string", "description": "REQUIRED on every call. Copy the user's full Markdown body exactly. This is the document body, not the title: when the user says 'with body X', send X here exactly; never copy name into content. If no body was supplied, use an empty string. Embed workspace media as an image whose url is anselm://media/<attachmentId>."},
		"tags":        {"type": "array", "items": {"type": "string"}, "description": "REQUIRED on every call. Copy one exact string per user-supplied tag; if none was supplied, use []. Hosted callers may have one extra JSON-encoded string layer; an exact encoded array is accepted, but comma-joined or arbitrary strings are invalid."}
	}
}`)

// CreateDocument implements the create_document system tool.
//
// CreateDocument 是 create_document 系统工具的实现。
type CreateDocument struct{ svc *documentapp.Service }

func (t *CreateDocument) Name() string                { return "create_document" }
func (t *CreateDocument) Description() string         { return createDocumentDescription }
func (t *CreateDocument) Parameters() json.RawMessage { return createDocumentSchema }

// CallIdentity treats a same-parent, same-name create as one business intent even when a model
// changes optional fields between calls. This prevents one assistant batch from creating a
// placeholder and a second sibling for the same requested document.
//
// CallIdentity 把同父同名 create 视为同一个业务意图，即使模型在调用间改了可选字段；避免一次
// assistant 批次先造 placeholder、再造一个同名 sibling。
func (t *CreateDocument) CallIdentity(args json.RawMessage) string {
	var a struct {
		Name     string  `json:"name"`
		ParentID *string `json:"parentId"`
	}
	if err := json.Unmarshal(args, &a); err != nil || strings.TrimSpace(a.Name) == "" {
		return ""
	}
	parent := ""
	if a.ParentID != nil {
		parent = strings.TrimSpace(*a.ParentID)
	}
	return "document:" + parent + ":" + a.Name
}

func (t *CreateDocument) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_document: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrNameRequired
	}
	return nil
}

func (t *CreateDocument) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		Name        string          `json:"name"`
		ParentID    *string         `json:"parentId"`
		Description string          `json:"description"`
		Content     string          `json:"content"`
		Tags        json.RawMessage `json:"tags"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("create_document: %w", err)
	}
	tags, err := decodeDocumentTags(a.Tags)
	if err != nil {
		return "", fmt.Errorf("create_document: %w", err)
	}
	// Empty-string parentId is treated as null (root-level create).
	//
	// 空字符串 parentId 视为 null（根级创建）。
	if a.ParentID != nil && *a.ParentID == "" {
		a.ParentID = nil
	}
	var tagValues []string
	if tags != nil {
		tagValues = *tags
	}
	d, err := t.svc.Create(ctx, documentapp.CreateInput{
		Name:        a.Name,
		ParentID:    a.ParentID,
		Description: a.Description,
		Content:     a.Content,
		Tags:        tagValues,
	})
	if err != nil {
		switch {
		case errors.Is(err, documentdomain.ErrParentNotFound):
			return "Parent doc not found. Confirm it with list_documents or search_documents.", nil
		case errors.Is(err, documentdomain.ErrContentTooLarge):
			return "Content exceeds 1 MB. Split into smaller child docs.", nil
		case errors.Is(err, documentdomain.ErrInvalidName):
			return fmt.Sprintf("Invalid name %q (no slashes; non-empty; up to 256 chars).", a.Name), nil
		default:
			return "", err
		}
	}
	// Service auto-suffixes on name collision ("X" → "X 2"); tell the LLM when that
	// happened so it reasons about the real name.
	//
	// Service 重名自动加后缀（"X" → "X 2"）；命中时告知 LLM 真实名字。
	if a.Name != "" && d.Name != a.Name {
		return fmt.Sprintf("Created document %q (id=%s, path=%s). Note: requested name %q was taken; auto-renamed.", d.Name, d.ID, d.Path, a.Name), nil
	}
	return fmt.Sprintf("Created document %q (id=%s, path=%s).", d.Name, d.ID, d.Path), nil
}
