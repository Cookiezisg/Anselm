package generate

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// ErrPromptRequired — the one mandatory business argument.
var ErrPromptRequired = errorspkg.New(errorspkg.KindInvalid, "IMAGE_PROMPT_REQUIRED", "prompt is required")

// maxImagePromptChars mirrors the gateway's bound so a managed-route prompt never dies late.
// maxImagePromptChars 镜像网关上限,受管路由的 prompt 绝不晚死。
const maxImagePromptChars = 2000

// GenerateImage is the generate_image tool (WRK-082 批B, P9): text instruction → one image,
// persisted as a first-class attachment, receipt returned as tool_result JSON (代拍 B7 —
// the chat card renders the attachment through the existing image pipeline).
//
// GenerateImage 是 generate_image 工具(批B,P9):文字指令 → 一张图,落一等附件,receipt 以
// tool_result JSON 返回(代拍 B7——聊天卡经既有图片管线渲附件)。
type GenerateImage struct {
	router      *Router
	attachments Uploader
}

func (*GenerateImage) Name() string { return "generate_image" }

func (*GenerateImage) Description() string {
	return "Generate an image from a text prompt using the workspace's configured image route. " +
		"Returns a JSON receipt with the stored attachmentId — the image is already saved and " +
		"rendered to the user; reference it by attachmentId if needed. One image per call. " +
		"It costs a small metered amount per image (declare danger=cautious). " +
		"Write prompts descriptively (subject, style, lighting, composition)."
}

func (*GenerateImage) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"prompt": {"type": "string", "description": "What to draw — subject, style, mood, composition."},
			"aspect": {"type": "string", "enum": ["square", "landscape", "portrait"], "description": "Canvas orientation; defaults to square."}
		},
		"required": ["prompt"]
	}`)
}

type generateImageInput struct {
	Prompt string `json:"prompt"`
	Aspect string `json:"aspect,omitempty"`
}

func (*GenerateImage) ValidateInput(raw json.RawMessage) error {
	var in generateImageInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return fmt.Errorf("generate_image.ValidateInput: %w", err)
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

// Execute resolves the route, generates, persists the artifact as an attachment, and returns the
// receipt. The route is resolved per call — the scenario config the user sees IS the routing truth.
//
// Execute 解析路由、生成、把产物落一等附件、返回 receipt。路由逐调用解析——用户看到的场景配置
// 就是路由真相。
func (g *GenerateImage) Execute(ctx context.Context, args string) (string, error) {
	var in generateImageInput
	if err := json.Unmarshal([]byte(args), &in); err != nil {
		return "", fmt.Errorf("generate_image: %w", err)
	}
	aspect, err := normalizedAspect(in.Aspect)
	if err != nil {
		return "", err
	}
	route, err := g.router.resolveImage(ctx)
	if err != nil {
		return "", err
	}
	img, err := g.router.generate(ctx, route, strings.TrimSpace(in.Prompt), aspect)
	if err != nil {
		return "", err
	}
	att, err := g.attachments.Upload(ctx, artifactFilename(img.Mime), img.Mime, img.Bytes)
	if err != nil {
		return "", fmt.Errorf("generate_image: store artifact: %w", err)
	}
	w, h := sniffDims(img.Bytes)
	receipt := map[string]any{
		"attachmentId": att.ID,
		"filename":     att.Filename,
		"mime":         att.MimeType,
		"sizeBytes":    att.SizeBytes,
		"provider":     route.provider,
		"aspect":       aspect,
		"source":       "generate_image",
	}
	if route.model != "" {
		receipt["model"] = route.model
	}
	if w > 0 && h > 0 {
		receipt["width"], receipt["height"] = w, h
	}
	return toolapp.ToJSON(receipt), nil
}
