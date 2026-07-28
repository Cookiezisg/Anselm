package generate

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	mediarefpkg "github.com/sunweilin/anselm/backend/internal/pkg/mediaref"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// AnimateImage is the animate_image tool (WRK-082 H9): an EXISTING image becomes the first frame of
// a clip. It shares generate_video's entire long-task machinery — submit, poll, fetch — because the
// upstream is literally the same pair of endpoints with one more input field (官方文档核准 H9 第0步).
//
// **It does NOT take an aspect or a resolution, and that absence is the design.** The clip inherits
// the frame's geometry; offering the enum would let a model letterbox or crop the very picture the
// user handed over, and it would do so silently.
//
// AnimateImage 是 animate_image 工具(H9):一张**已存在**的图成为一段片子的首帧。它与 generate_video
// 共用整套长任务机器——提交、轮询、取回——因为上游**就是**同一对端点、只多一个输入字段(H9 第0步核准)。
//
// **它不收 aspect、也不收 resolution,而这个「没有」正是设计。** 片子继承首帧的几何;把枚举暴露出去,
// 等于允许模型对用户刚递来的那张图做信箱边或裁切,而且是**静默地**做。
type AnimateImage struct {
	router      *Router
	attachments Uploader
	source      Fetcher
}

func (*AnimateImage) Name() string { return "animate_image" }

func (*AnimateImage) Description() string {
	return "Animate an EXISTING image into a short video: give the attachmentId of the picture and a " +
		"prompt describing the motion (\"slow push in\", \"the leaves start to move\"). The image " +
		"becomes the first frame, so the clip keeps its framing — do not ask for a different aspect. " +
		"Returns a JSON receipt with the video's attachmentId. This is the EXPENSIVE tool of the " +
		"family: one clip costs real money and a large slice of the user's daily allowance, and that " +
		"spend cannot be undone. Declare danger=dangerous so the user is asked first. Takes minutes."
}

func (*AnimateImage) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"attachmentId": {"type": "string", "description": "The att_… id of the image to animate — it becomes the first frame."},
			"prompt": {"type": "string", "description": "How it should move: camera motion, what comes alive, pacing."},
			"seconds": {"type": "integer", "description": "Clip length in seconds; defaults to 5."}
		},
		"required": ["attachmentId", "prompt"]
	}`)
}

type animateImageInput struct {
	AttachmentID string `json:"attachmentId"`
	Prompt       string `json:"prompt"`
	Seconds      int    `json:"seconds,omitempty"`
}

func (*AnimateImage) ValidateInput(raw json.RawMessage) error {
	var in animateImageInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return fmt.Errorf("animate_image.ValidateInput: %w", err)
	}
	if !mediarefpkg.IsAttachmentID(strings.TrimSpace(in.AttachmentID)) {
		return ErrSourceRequired
	}
	if strings.TrimSpace(in.Prompt) == "" {
		return ErrPromptRequired
	}
	return nil
}

// Execute reads the source image, submits it as the first frame, and lands the finished clip.
//
// Execute 读源图、把它作为首帧提交、把成片落盘。
func (a *AnimateImage) Execute(ctx context.Context, args string) (string, error) {
	var in animateImageInput
	if err := json.Unmarshal([]byte(args), &in); err != nil {
		return "", fmt.Errorf("animate_image: %w", err)
	}
	src, data, err := a.source.Download(ctx, strings.TrimSpace(in.AttachmentID))
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
	route, err := a.router.resolveVideo(ctx)
	if err != nil {
		return "", err
	}
	seconds := in.Seconds
	if seconds <= 0 {
		seconds = defaultVideoSeconds
	}
	// Clamp BEFORE spending, exactly as generate_video does: asking a provider for a longer clip
	// than it can make is refused upstream, and the honest handling is to make the shorter one.
	// **花钱之前**钳,与 generate_video 完全一致:向做不到那么长的家要更长的片子必被上游拒,而诚实的
	// 处理是**做那个更短的**。
	if max := llminfra.VideoMaxDuration(route.provider); seconds > max {
		seconds = max
	}
	prog := loopapp.ToolProgress(ctx)
	defer prog.Close()
	video, err := a.router.generateVideo(ctx, route, llminfra.VideoRequest{
		Prompt:      strings.TrimSpace(in.Prompt),
		DurationSec: seconds,
		FirstFrame:  &llminfra.DataURL{Mime: src.MimeType, Bytes: data},
	}, prog.Print)
	if err != nil {
		return "", err
	}
	att, err := a.attachments.Upload(reqctxpkg.SetMediaSource(ctx, "animate_image"),
		artifactFilename(video.Mime), video.Mime, video.Bytes)
	if err != nil {
		return "", fmt.Errorf("animate_image: store artifact: %w", err)
	}
	receipt := map[string]any{
		"attachmentId":       att.ID,
		"filename":           att.Filename,
		"mime":               att.MimeType,
		"sizeBytes":          att.SizeBytes,
		"provider":           route.provider,
		"seconds":            seconds,
		"sourceAttachmentId": src.ID,
		"source":             "animate_image",
	}
	if route.model != "" {
		receipt["model"] = route.model
	}
	return toolapp.ToJSON(receipt), nil
}
