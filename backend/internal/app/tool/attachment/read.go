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

const readAttachmentDescription = `Read an uploaded attachment's content back into the conversation by id (find ids via list_attachments). Text and document files (PDF/Office) are text-extracted and returned inline; images and other binary files return a descriptor (filename, mime, size) with a note that their content can't be text-extracted here.`

var readAttachmentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id": {"type": "string"}
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
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("read_attachment: bad args: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return ErrIDRequired
	}
	return nil
}

func (t *ReadAttachment) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("read_attachment: %w", err)
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
		return flattenText(parts), nil
	default: // image / audio / video / other — content isn't text-extractable here
		return fmt.Sprintf(
			"Attachment %q (id %s, %s, %d bytes, kind %s): its content can't be text-extracted here. Images reach the model only when attached to a chat turn; other binary files have no extractor.",
			meta.Filename, meta.ID, meta.MimeType, meta.SizeBytes, meta.Kind), nil
	}
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
