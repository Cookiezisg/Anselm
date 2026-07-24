package attachment

import (
	"context"
	"encoding/json"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

const listAttachmentsDescription = `List the files uploaded to this workspace (newest first): id, filename, mime, kind, sizeBytes, createdAt each. kind is one of image/document/text/audio/video/other. Use this to discover what's attached. For text/document use read_attachment; for image/audio/video use inspect_media with a specific question so media stays bounded and does not dump raw bytes into context.`

var listAttachmentsSchema = json.RawMessage(`{
	"type": "object",
	"properties": {}
}`)

// ListAttachments implements the list_attachments system tool.
//
// ListAttachments 是 list_attachments 系统工具的实现。
type ListAttachments struct{ svc *attachmentapp.Service }

func (t *ListAttachments) Name() string                { return "list_attachments" }
func (t *ListAttachments) Description() string         { return listAttachmentsDescription }
func (t *ListAttachments) Parameters() json.RawMessage { return listAttachmentsSchema }

// ValidateInput accepts anything (no args) — list takes no parameters.
//
// ValidateInput 接受任何输入（无参）——list 不取参数。
func (t *ListAttachments) ValidateInput(json.RawMessage) error { return nil }

func (t *ListAttachments) Execute(ctx context.Context, _ string) (string, error) {
	rows, err := t.svc.List(ctx)
	if err != nil {
		return "", err
	}
	type slim struct {
		ID        string `json:"id"`
		Filename  string `json:"filename"`
		Mime      string `json:"mime"`
		Kind      string `json:"kind"`
		SizeBytes int64  `json:"sizeBytes"`
		CreatedAt string `json:"createdAt"`
	}
	out := make([]slim, 0, len(rows))
	for _, a := range rows {
		out = append(out, slim{
			ID:        a.ID,
			Filename:  a.Filename,
			Mime:      a.MimeType,
			Kind:      a.Kind,
			SizeBytes: a.SizeBytes,
			CreatedAt: a.CreatedAt.UTC().Format("2006-01-02T15:04:05Z"),
		})
	}
	return toolapp.ToJSON(map[string]any{
		"count":       len(out),
		"attachments": out,
		"usage":       "Use read_attachment for text/document. Use inspect_media for image/audio/video with a specific question; audio/video currently returns a local metadata capsule and optional time-range intent.",
	}), nil
}
