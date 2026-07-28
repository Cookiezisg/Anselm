package generate

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	mediarefpkg "github.com/sunweilin/anselm/backend/internal/pkg/mediaref"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// ErrSourceRequired — an edit without a source is a generation, and the model should have called
// that tool instead. Saying so is more useful than silently drawing something new.
//
// ErrSourceRequired——没有源图的「改图」就是「出图」,模型本该去调那个工具。**说出来**比静默画一张新的
// 有用。
var ErrSourceRequired = errorspkg.New(errorspkg.KindInvalid, "IMAGE_SOURCE_REQUIRED", "attachmentId of the image to edit is required")

// ErrSourceNotImage — the referenced attachment is not an image. Caught before spending: an edit
// route handed an audio file fails upstream anyway, just later and with a stranger message.
//
// ErrSourceNotImage——被引用的附件不是图。**花钱之前**就拦:把一段音频递给改图路由,上游反正也会失败,
// 只是更晚、且报出一句更莫名其妙的话。
var ErrSourceNotImage = errorspkg.New(errorspkg.KindInvalid, "IMAGE_SOURCE_NOT_IMAGE", "the referenced attachment is not an image")

// maxEditSourceBytes bounds what we will base64 into a request body. The upstream's own ceiling is
// 10MB (官方文档核准); staying under it locally turns a remote 413 into a local sentence.
//
// maxEditSourceBytes 界我们愿意 base64 进请求体的大小。上游自己的上限是 10MB(官方文档核准);在本地
// 卡在它之下,把一个远端 413 变成一句本地的话。
const maxEditSourceBytes = 10 << 20

// EditImage is the edit_image tool (WRK-082 H9): an EXISTING attachment + an instruction → a new
// image. It is a separate tool rather than an optional argument on generate_image, because honest
// absence and the capability gate both work at TOOL granularity: a workspace whose image provider
// cannot edit must see no edit tool at all, rather than a tool that exists and always fails.
//
// **The source is an attachmentId, not a path or a URL.** That is the MediaRef currency doing its
// job — "edit the one you just made" and "edit the one I uploaded" are the same call, and neither
// needs an address the upstream could fetch.
//
// EditImage 是 edit_image 工具(H9):一个**已存在**的附件 + 一条指令 → 一张新图。它是**独立工具**、
// 而非 generate_image 上的可选参数,因为诚实缺席与能力闸都按**工具**粒度工作:图像家不会改图的
// workspace,应该**根本看不到**改图工具,而不是看到一个存在却必然失败的工具。
//
// **源是 attachmentId,不是路径、也不是 URL。** 那正是 MediaRef 这个货币在干活——「改你刚做的那张」
// 与「改我上传的那张」是同一次调用,而两者都不需要一个上游取得到的地址。
type EditImage struct {
	router      *Router
	attachments Uploader
	source      Fetcher
}

func (*EditImage) Name() string { return "edit_image" }

func (*EditImage) Description() string {
	return "Edit an EXISTING image: give the attachmentId of the image and an instruction describing " +
		"the change (\"make it night\", \"remove the car\", \"turn it into a watercolour\"). Returns a " +
		"JSON receipt with the new attachmentId — the edited image is saved and rendered to the user; " +
		"the original is untouched. Use generate_image instead when there is no source image. " +
		"It costs a small metered amount per edit (declare danger=cautious)."
}

func (*EditImage) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"attachmentId": {"type": "string", "description": "The att_… id of the image to edit."},
			"prompt": {"type": "string", "description": "What to change about it."},
			"aspect": {"type": "string", "enum": ["square", "landscape", "portrait"], "description": "Canvas orientation for the result; defaults to square."}
		},
		"required": ["attachmentId", "prompt"]
	}`)
}

type editImageInput struct {
	AttachmentID string `json:"attachmentId"`
	Prompt       string `json:"prompt"`
	Aspect       string `json:"aspect,omitempty"`
}

func (*EditImage) ValidateInput(raw json.RawMessage) error {
	var in editImageInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return fmt.Errorf("edit_image.ValidateInput: %w", err)
	}
	if !mediarefpkg.IsAttachmentID(strings.TrimSpace(in.AttachmentID)) {
		return ErrSourceRequired
	}
	if strings.TrimSpace(in.Prompt) == "" {
		return ErrPromptRequired
	}
	if len([]rune(in.Prompt)) > maxImagePromptChars {
		return fmt.Errorf("prompt exceeds %d characters", maxImagePromptChars)
	}
	if _, err := normalizedAspect(in.Aspect); err != nil {
		return err
	}
	return nil
}

// Execute reads the source attachment, edits it, and lands the RESULT as a new attachment. The
// original is never modified — an edit produces a sibling, so a user can always go back to what
// they had, and the conversation keeps both.
//
// Execute 读源附件、改它、把**结果**落成一个**新**附件。原图**从不被修改**——改图产出的是一个兄弟,
// 故用户永远回得去,而对话把两者都留着。
func (e *EditImage) Execute(ctx context.Context, args string) (string, error) {
	var in editImageInput
	if err := json.Unmarshal([]byte(args), &in); err != nil {
		return "", fmt.Errorf("edit_image: %w", err)
	}
	aspect, err := normalizedAspect(in.Aspect)
	if err != nil {
		return "", err
	}
	src, data, err := e.source.Download(ctx, strings.TrimSpace(in.AttachmentID))
	if err != nil {
		return "", err
	}
	if !strings.HasPrefix(src.MimeType, "image/") {
		return "", ErrSourceNotImage
	}
	if len(data) > maxEditSourceBytes {
		return "", fmt.Errorf("%w: source image is %d bytes, over the %d-byte upstream limit",
			ErrSourceNotImage, len(data), maxEditSourceBytes)
	}
	route, err := e.router.resolveImage(ctx)
	if err != nil {
		return "", err
	}
	img, err := e.router.edit(ctx, route, strings.TrimSpace(in.Prompt), aspect,
		llminfra.DataURL{Mime: src.MimeType, Bytes: data})
	if err != nil {
		return "", err
	}
	att, err := e.attachments.Upload(reqctxpkg.SetMediaSource(ctx, "edit_image"),
		artifactFilename(img.Mime), img.Mime, img.Bytes)
	if err != nil {
		return "", fmt.Errorf("edit_image: store artifact: %w", err)
	}
	w, h := sniffDims(img.Bytes)
	receipt := map[string]any{
		"attachmentId": att.ID,
		"filename":     att.Filename,
		"mime":         att.MimeType,
		"sizeBytes":    att.SizeBytes,
		"provider":     route.provider,
		"aspect":       aspect,
		// The source rides the receipt so the lineage is on the record: which picture this one came
		// from is a question the transcript should answer without anyone re-reading the prompt.
		// 源随 receipt 走,使血缘在案:「这张是从哪张来的」不该要人回头重读 prompt 才答得出。
		"sourceAttachmentId": src.ID,
		"source":             "edit_image",
	}
	if w > 0 && h > 0 {
		receipt["width"], receipt["height"] = w, h
	}
	return toolapp.ToJSON(receipt), nil
}
