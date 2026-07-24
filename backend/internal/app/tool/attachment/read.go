package attachment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const (
	readAttachmentDefaultLimitChars = 80_000
	readAttachmentMaxLimitChars     = 120_000
)

const readAttachmentDescription = `Read an uploaded attachment's content back into the conversation by id (find ids via list_attachments). Text and document files (PDF/Office) are text-extracted and returned as a bounded page: default limitChars=80000, max 120000; pass offset with the returned nextOffset to continue. Images and other binary files return a descriptor (filename, mime, size) with a note that their content can't be text-extracted here; use inspect_media for images.`

var readAttachmentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id": {"type": "string"},
		"offset": {"type": "integer", "minimum": 0, "description": "Character offset into the extracted text page. Use nextOffset from a previous result to continue."},
		"limitChars": {"type": "integer", "minimum": 1, "maximum": 120000, "description": "Maximum characters to return. Defaults to 80000; capped at 120000."}
	}
}`)

// ReadAttachment implements the read_attachment system tool.
//
// ReadAttachment 是 read_attachment 系统工具的实现。
type ReadAttachment struct{ svc *attachmentapp.Service }

func (t *ReadAttachment) Name() string                { return "read_attachment" }
func (t *ReadAttachment) Description() string         { return readAttachmentDescription }
func (t *ReadAttachment) Parameters() json.RawMessage { return readAttachmentSchema }

func (t *ReadAttachment) ValidateInput(args json.RawMessage) error {
	var a readArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("read_attachment: bad args: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return ErrIDRequired
	}
	if a.Offset < 0 {
		return fmt.Errorf("read_attachment: offset must be >= 0")
	}
	if a.LimitChars < 0 || a.LimitChars > readAttachmentMaxLimitChars {
		return fmt.Errorf("read_attachment: limitChars must be 0/default or between 1 and %d", readAttachmentMaxLimitChars)
	}
	return nil
}

func (t *ReadAttachment) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a readArgs
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("read_attachment: %w", err)
	}
	if err := t.ValidateInput([]byte(argsJSON)); err != nil {
		return "", err
	}
	meta, err := t.svc.Get(ctx, a.ID)
	if err != nil {
		if errors.Is(err, attachmentdomain.ErrNotFound) {
			return fmt.Sprintf("Attachment %q not found. Call list_attachments to see available files.", a.ID), nil
		}
		return "", err
	}
	// Binary/non-text kinds have no useful tool-result text — return a descriptor instead of
	// dumping bytes (a tool result is a plain string back to the model). Text + document kinds go
	// through ToContentParts (the shared text-extraction engine) with NativeDocs off so PDFs/Office
	// are extracted to text rather than handed over as a raw file part the model can't read here.
	//
	// 二进制/非文本类无可用工具结果文本——返回描述符而非倾倒字节（工具结果是回给模型的纯串）。
	// text + document 类走 ToContentParts（共享文本抽取引擎），关 NativeDocs 使 PDF/Office 抽成
	// 文本、而非递交模型在此读不了的原始 file part。
	switch meta.Kind {
	case attachmentdomain.KindText, attachmentdomain.KindDocument:
		parts, err := t.svc.ToContentParts(ctx, []string{a.ID}, attachmentapp.Capabilities{Vision: false, NativeDocs: false})
		if err != nil {
			return "", err
		}
		return pageAttachmentText(flattenText(parts), a.Offset, normalizeReadLimit(a.LimitChars)), nil
	default: // image / audio / video / other — content isn't text-extractable here
		return fmt.Sprintf(
			"Attachment %q (id %s, %s, %d bytes, kind %s): this tool cannot turn its content into text. An image is seen by the model ONLY if the model has vision support AND the image is attached to the chat turn — if the current model is text-only it cannot see this image at all, so do not keep trying to read it; ask the user to describe it or switch to a vision model. Audio/video/other binaries have no extractor here.",
			meta.Filename, meta.ID, meta.MimeType, meta.SizeBytes, meta.Kind), nil
	}
}

type readArgs struct {
	ID         string `json:"id"`
	Offset     int    `json:"offset"`
	LimitChars int    `json:"limitChars"`
}

// flattenText joins the text of every text part into one tool-result string. ToContentParts on a
// text/document attachment yields exactly text parts (inline text, extracted text, or a degrade
// note); a non-text part would have no string body, so it is skipped.
//
// flattenText 把每个 text part 的文本拼成一个工具结果串。text/document 附件经 ToContentParts 恰得
// text part（内联文本、抽取文本或降级提示）；非 text part 无串体，跳过。
func flattenText(parts []llminfra.ContentPart) string {
	var sb strings.Builder
	for _, p := range parts {
		if p.Type == llminfra.PartText {
			if sb.Len() > 0 {
				sb.WriteString("\n")
			}
			sb.WriteString(p.Text)
		}
	}
	return sb.String()
}

func normalizeReadLimit(limit int) int {
	if limit <= 0 {
		return readAttachmentDefaultLimitChars
	}
	if limit > readAttachmentMaxLimitChars {
		return readAttachmentMaxLimitChars
	}
	return limit
}

func pageAttachmentText(text string, offset, limit int) string {
	runes := []rune(text)
	total := len(runes)
	if offset >= total {
		return fmt.Sprintf("No attachment text at offset %d. totalChars=%d. Re-read from a smaller offset or call list_attachments if you may have the wrong id.", offset, total)
	}
	end := offset + limit
	if end > total {
		end = total
	}
	body := string(runes[offset:end])
	if offset == 0 && end == total {
		return body
	}
	next := ""
	if end < total {
		next = fmt.Sprintf(" nextOffset=%d", end)
	}
	return fmt.Sprintf("%s\n\n[read_attachment pagination: offset=%d chars=%d totalChars=%d%s]", body, offset, end-offset, total, next)
}
