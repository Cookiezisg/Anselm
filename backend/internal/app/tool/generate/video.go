package generate

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"unicode/utf8"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

const (
	maxVideoPromptChars = 2000
	defaultVideoSeconds = 5
)

// ErrVideoPromptRequired — the tool was called with nothing to film.
var ErrVideoPromptRequired = errorspkg.New(errorspkg.KindInvalid, "VIDEO_PROMPT_REQUIRED", "prompt is required")

// GenerateVideo is the video member of the generation family (WRK-082 批D). It is the family's one
// LONG tool: every provider is asynchronous, so Execute submits, polls to a terminal state, and
// only then answers — minutes, not seconds (ADR 0013 records why it waits here rather than becoming
// a background job).
//
// While it waits it streams honest status lines through `loop.ToolProgress`, which surfaces them as
// a `progress` block under this tool_call. No new stream, no new block type, no percentage: neither
// supported provider reports progress, and a synthesized bar would sit at 99% for minutes.
//
// GenerateVideo 是生成族的视频成员(批D),也是本族唯一的**长**工具:每一家都是异步的,故 Execute
// 提交、轮询到终态、然后才作答——分钟级而非秒级(ADR 0013 记录了它为何在此等待、而不是变成后台作业)。
//
// 等待期间它经 `loop.ToolProgress` 流出诚实的状态行,呈现为本 tool_call 下的 `progress` 块。不加流、
// 不加块型、**不给百分比**:两家都不报进度,而合成的进度条会在 99% 停几分钟。
type GenerateVideo struct {
	router      *Router
	attachments Uploader
}

var _ toolapp.Tool = (*GenerateVideo)(nil)

func (t *GenerateVideo) Name() string { return "generate_video" }

func (t *GenerateVideo) Description() string {
	return "Generate a short video from a text prompt and save it as an attachment. This tool is " +
		"SLOW — generation takes minutes, and the conversation waits for it — and it is the most " +
		"EXPENSIVE tool here: one clip costs real money and a large slice of the user's daily " +
		"allowance, and that spend cannot be undone. Declare danger=dangerous so the user is asked " +
		"first, and use it only when the user actually asked for a video. The video is ALREADY " +
		"saved when this returns; reference it by attachmentId. One call makes one video."
}

func (t *GenerateVideo) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"prompt": {"type": "string", "description": "What the video should show."},
			"seconds": {"type": "integer", "description": "Clip length in seconds (default 5). Providers cap this; an impossible length is refused before anything is spent."},
			"aspect": {"type": "string", "enum": ["landscape", "portrait", "square"], "description": "Frame shape (default landscape)."}
		},
		"required": ["prompt"]
	}`)
}

type videoArgs struct {
	Prompt  string `json:"prompt"`
	Seconds int    `json:"seconds"`
	Aspect  string `json:"aspect"`
}

func (t *GenerateVideo) ValidateInput(raw json.RawMessage) error {
	var a videoArgs
	if err := json.Unmarshal(raw, &a); err != nil {
		return fmt.Errorf("invalid arguments: %w", err)
	}
	if strings.TrimSpace(a.Prompt) == "" {
		return ErrVideoPromptRequired
	}
	if utf8.RuneCountInString(a.Prompt) > maxVideoPromptChars {
		return fmt.Errorf("prompt exceeds %d characters", maxVideoPromptChars)
	}
	if _, err := normalizedAspect(a.Aspect); err != nil {
		return err
	}
	return nil
}

// Execute resolves the route per call, generates (submit → poll → fetch), lands the artifact as a
// first-class attachment, and returns the receipt.
//
// Execute 逐调用解析路由,生成(提交 → 轮询 → 取回),把产物落成一等附件,返回 receipt。
func (t *GenerateVideo) Execute(ctx context.Context, args string) (string, error) {
	var a videoArgs
	if err := json.Unmarshal([]byte(args), &a); err != nil {
		return "", fmt.Errorf("invalid arguments: %w", err)
	}
	prompt := strings.TrimSpace(a.Prompt)
	if prompt == "" {
		return "", ErrVideoPromptRequired
	}
	// An omitted shape is LANDSCAPE here, not square as it is for images: 16:9 is what a video is
	// unless someone says otherwise, and one provider (Veo) has no square form at all — defaulting
	// to a shape half the routes must silently rewrite is a default that lies.
	// 未指定形状在这里是**横向**、不是图像那边的方形:一段视频除非另有交代就是 16:9,而其中一家(Veo)
	// **根本没有**方形——默认成一个半数路由必须静默改写的形状,是一个会撒谎的默认值。
	if strings.TrimSpace(a.Aspect) == "" {
		a.Aspect = "landscape"
	}
	aspect, err := normalizedAspect(a.Aspect)
	if err != nil {
		return "", err
	}
	seconds := a.Seconds
	if seconds <= 0 {
		seconds = defaultVideoSeconds
	}
	route, err := t.router.resolveVideo(ctx)
	if err != nil {
		return "", err
	}
	// Clamp to what this route can actually do BEFORE spending: asking a provider for a length it
	// caps below is a guaranteed upstream rejection, and the honest fix is to make the shorter clip
	// rather than to fail. The receipt reports the length that was really made.
	// 在花钱**之前**钳到本路由真做得到的长度:向一个封顶更低的家要更长的片子必被上游拒,而诚实的处理是
	// **做那个更短的片子**、不是失败。receipt 报的是真正做出来的长度。
	if max := llminfra.VideoMaxDuration(route.provider); seconds > max {
		seconds = max
	}

	prog := loopapp.ToolProgress(ctx)
	defer prog.Close()
	video, err := t.router.generateVideo(ctx, route, llminfra.VideoRequest{
		Prompt:      prompt,
		DurationSec: seconds,
		Aspect:      aspect,
		Resolution:  "720p",
	}, prog.Print)
	if err != nil {
		return "", err
	}
	att, err := t.attachments.Upload(reqctxpkg.SetMediaSource(ctx, "generate_video"),
		artifactFilename(video.Mime), video.Mime, video.Bytes)
	if err != nil {
		return "", fmt.Errorf("save video artifact: %w", err)
	}
	receipt := map[string]any{
		"attachmentId": att.ID,
		"filename":     att.Filename,
		"mime":         att.MimeType,
		"sizeBytes":    att.SizeBytes,
		"provider":     route.provider,
		"seconds":      seconds,
		"aspect":       aspect,
		"source":       "generate_video",
	}
	if route.model != "" {
		receipt["model"] = route.model
	}
	return toolapp.ToJSON(receipt), nil
}
