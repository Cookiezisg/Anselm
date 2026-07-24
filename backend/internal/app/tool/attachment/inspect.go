package attachment

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	mediaapp "github.com/sunweilin/anselm/backend/internal/app/media"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const (
	inspectMediaMaxOutputTokens = 900
)

const inspectMediaDescription = `Inspect one uploaded image by attachmentId using the default vision-capable Anselm route, then return concise text evidence. Use this when read_attachment says an image cannot be text-extracted, when old visual context was compacted, or when you need to verify a specific region/detail. The tool sends only one bounded image proxy/crop to the vision model and returns text; it does not dump image bytes into the conversation. Currently supports image attachments. Documents/pages, audio time ranges, and video time ranges are future capabilities and will return a self-correcting note.`

var inspectMediaSchema = json.RawMessage(`{
	"type": "object",
	"required": ["attachmentId", "question"],
	"properties": {
		"attachmentId": {"type": "string", "description": "Uploaded attachment id, e.g. att_..."},
		"question": {"type": "string", "description": "The specific visual question to answer from this image."},
		"page": {"type": "integer", "minimum": 1, "description": "Reserved for document/page inspection; not supported yet."},
		"startMs": {"type": "integer", "minimum": 0, "description": "Reserved for audio/video inspection; not supported yet."},
		"endMs": {"type": "integer", "minimum": 0, "description": "Reserved for audio/video inspection; not supported yet."},
		"crop": {
			"type": "object",
			"description": "Optional normalized crop rectangle over the image before inspection.",
			"required": ["x", "y", "width", "height"],
			"properties": {
				"x": {"type": "number", "minimum": 0, "maximum": 1},
				"y": {"type": "number", "minimum": 0, "maximum": 1},
				"width": {"type": "number", "exclusiveMinimum": 0, "maximum": 1},
				"height": {"type": "number", "exclusiveMinimum": 0, "maximum": 1}
			}
		},
		"detail": {"type": "string", "enum": ["default", "high"], "default": "default"}
	}
}`)

// InspectMediaResolver resolves the default dialogue route for an internal, one-shot media
// inspection. Bootstrap implements it with chat's model resolver so this tool inherits the normal
// Anselm default routing instead of hard-coding a provider.
//
// InspectMediaResolver 为工具内部的一次性媒体检查解析默认 dialogue 路由。bootstrap 用 chat model
// resolver 实现它，使本工具继承 Anselm 默认路由，而非硬编码 provider。
type InspectMediaResolver interface {
	ResolveInspectMedia(ctx context.Context) (InspectMediaBundle, error)
}

// InspectMediaBundle is the minimal LLM bundle inspect_media needs. RemoteMedia is set only for
// the managed gateway path; BYOK routes receive a bounded data URL instead.
//
// InspectMediaBundle 是 inspect_media 所需的最小 LLM bundle。RemoteMedia 仅在受管网关路径下存在；
// BYOK 路由退回有界 data URL。
type InspectMediaBundle struct {
	Client      llminfra.Client
	Request     llminfra.Request
	Vision      bool
	Provider    string
	RemoteMedia *attachmentapp.RemoteMedia
}

// InspectMedia implements the inspect_media system tool.
//
// InspectMedia 是 inspect_media 系统工具实现。
type InspectMedia struct {
	svc            *attachmentapp.Service
	resolver       InspectMediaResolver
	imageProcessor imageDeriver
}

type imageDeriver interface {
	Derive(context.Context, *attachmentdomain.Attachment, []byte, *mediadomain.Derivative) (mediaapp.DerivativeResult, error)
}

type mediaImageProcessor struct{}

func (mediaImageProcessor) Derive(ctx context.Context, a *attachmentdomain.Attachment, data []byte, derivative *mediadomain.Derivative) (mediaapp.DerivativeResult, error) {
	return mediaapp.NewImageProcessor().Derive(ctx, a, data, derivative)
}

func (t *InspectMedia) Name() string                { return "inspect_media" }
func (t *InspectMedia) Description() string         { return inspectMediaDescription }
func (t *InspectMedia) Parameters() json.RawMessage { return inspectMediaSchema }

func (t *InspectMedia) ValidateInput(args json.RawMessage) error {
	var a inspectMediaArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("inspect_media: bad args: %w", err)
	}
	if strings.TrimSpace(a.AttachmentID) == "" {
		return ErrIDRequired
	}
	if strings.TrimSpace(a.Question) == "" {
		return fmt.Errorf("inspect_media: question is required")
	}
	if err := validateInspectCrop(a.Crop); err != nil {
		return err
	}
	if a.Detail != "" && a.Detail != "default" && a.Detail != "high" {
		return fmt.Errorf("inspect_media: detail must be default or high")
	}
	if a.EndMS > 0 && a.StartMS > 0 && a.EndMS <= a.StartMS {
		return fmt.Errorf("inspect_media: endMs must be greater than startMs")
	}
	return nil
}

func (t *InspectMedia) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args inspectMediaArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("inspect_media: %w", err)
	}
	if err := t.ValidateInput([]byte(argsJSON)); err != nil {
		return "", err
	}
	meta, original, err := t.svc.Download(ctx, args.AttachmentID)
	if err != nil {
		if errors.Is(err, attachmentdomain.ErrNotFound) {
			return fmt.Sprintf("Attachment %q not found. Call list_attachments to see available files.", args.AttachmentID), nil
		}
		return "", err
	}
	if meta.Kind != attachmentdomain.KindImage {
		return fmt.Sprintf(
			"inspect_media currently supports image attachments only. Attachment %q (id %s) is kind %s / %s. Use read_attachment for text/doc extraction; video/audio/page inspection is not implemented yet.",
			meta.Filename, meta.ID, meta.Kind, meta.MimeType), nil
	}
	bundle, err := t.resolver.ResolveInspectMedia(ctx)
	if err != nil {
		return "", fmt.Errorf("inspect_media: resolve vision route: %w", err)
	}
	if bundle.Client == nil {
		return "", fmt.Errorf("inspect_media: vision route has no client")
	}
	if !bundle.Vision {
		return fmt.Sprintf("The default model route cannot inspect images right now. Attachment %q is available, but the resolved route did not advertise vision support.", meta.Filename), nil
	}
	rendered, err := t.renderImage(ctx, meta, original, args)
	if err != nil {
		return "", err
	}
	imageURL, transport, err := inspectImageSource(ctx, bundle, meta, rendered.MimeType, rendered.Data)
	if err != nil {
		return "", err
	}
	req := inspectRequest(bundle.Request, meta, args, imageURL, rendered, transport)
	answer, err := llminfra.Generate(ctx, bundle.Client, req)
	if err != nil {
		return "", fmt.Errorf("inspect_media: vision model: %w", err)
	}
	answer = strings.TrimSpace(answer)
	if answer == "" {
		answer = "The vision model returned no textual observation."
	}
	return toolappJSON(inspectMediaResult{
		AttachmentID: meta.ID,
		Filename:     meta.Filename,
		Mime:         rendered.MimeType,
		Width:        rendered.Width,
		Height:       rendered.Height,
		Crop:         args.Crop,
		Detail:       normalizedDetail(args.Detail),
		Transport:    transport,
		Notes:        ignoredInspectFields(args),
		Answer:       answer,
	}), nil
}

type inspectMediaArgs struct {
	AttachmentID string       `json:"attachmentId"`
	Question     string       `json:"question"`
	Page         int          `json:"page"`
	StartMS      int64        `json:"startMs"`
	EndMS        int64        `json:"endMs"`
	Crop         *inspectCrop `json:"crop"`
	Detail       string       `json:"detail"`
}

type inspectCrop struct {
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
}

type renderedInspectImage struct {
	Data     []byte
	MimeType string
	Width    int
	Height   int
}

type inspectMediaResult struct {
	AttachmentID string       `json:"attachmentId"`
	Filename     string       `json:"filename"`
	Mime         string       `json:"mime"`
	Width        int          `json:"width"`
	Height       int          `json:"height"`
	Crop         *inspectCrop `json:"crop,omitempty"`
	Detail       string       `json:"detail"`
	Transport    string       `json:"transport"`
	Notes        []string     `json:"notes,omitempty"`
	Answer       string       `json:"answer"`
}

func (t *InspectMedia) renderImage(ctx context.Context, meta *attachmentdomain.Attachment, original []byte, args inspectMediaArgs) (renderedInspectImage, error) {
	params := mediaapp.ImageDerivativeParams{Version: 2, Quality: 90, Format: "auto"}
	if args.Crop != nil {
		params.Crop = &mediaapp.ImageCrop{X: args.Crop.X, Y: args.Crop.Y, Width: args.Crop.Width, Height: args.Crop.Height}
	}
	if normalizedDetail(args.Detail) == "high" {
		params.MaxWidth = 2048
		params.MaxHeight = 8192
		if args.Crop != nil {
			params.MaxEdge = 3072
			params.MaxWidth = 0
			params.MaxHeight = 0
			params.Quality = 92
		}
	}
	rawParams, err := json.Marshal(params)
	if err != nil {
		return renderedInspectImage{}, fmt.Errorf("inspect_media: marshal image params: %w", err)
	}
	processor := t.imageProcessor
	if processor == nil {
		processor = mediaImageProcessor{}
	}
	result, err := processor.Derive(ctx, meta, original, &mediadomain.Derivative{
		AttachmentID: meta.ID,
		Kind:         mediaapp.DerivativeModelDefault,
		SourceSHA256: meta.SHA256,
		ParamsJSON:   string(rawParams),
	})
	if err != nil {
		return renderedInspectImage{}, fmt.Errorf("inspect_media: render image proxy: %w", err)
	}
	return renderedInspectImage{Data: result.Data, MimeType: result.MimeType, Width: result.Width, Height: result.Height}, nil
}

func inspectImageSource(ctx context.Context, bundle InspectMediaBundle, meta *attachmentdomain.Attachment, mime string, data []byte) (string, string, error) {
	if bundle.RemoteMedia != nil && bundle.RemoteMedia.Uploader != nil && bundle.RemoteMedia.BaseURL != "" && bundle.RemoteMedia.InstallID != "" {
		url, err := bundle.RemoteMedia.Uploader.Upload(ctx, bundle.RemoteMedia.BaseURL, bundle.RemoteMedia.InstallID, mime, data)
		if err != nil {
			return "", "", fmt.Errorf("inspect_media: stage image proxy: %w", err)
		}
		if strings.TrimSpace(url) == "" {
			return "", "", fmt.Errorf("inspect_media: staged image proxy for %q returned an empty URL", meta.Filename)
		}
		return url, "managed-url", nil
	}
	return "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(data), "data-url", nil
}

func inspectRequest(base llminfra.Request, meta *attachmentdomain.Attachment, args inspectMediaArgs, imageURL string, rendered renderedInspectImage, transport string) llminfra.Request {
	base.System = `You are a precise visual inspection helper for an agent. Inspect exactly the supplied image. Answer the user's specific question using only visible evidence. Be concise but include enough concrete details for the agent to decide next steps. If something is not visible or uncertain, say so explicitly. Do not invent text, identities, or hidden context.`
	base.Tools = nil
	base.MaxTokens = inspectMediaMaxOutputTokens
	base.Messages = []llminfra.LLMMessage{{
		Role: llminfra.RoleUser,
		Parts: []llminfra.ContentPart{
			{Type: llminfra.PartText, Text: inspectPrompt(meta, args, rendered, transport)},
			{Type: llminfra.PartImageURL, ImageURL: imageURL},
		},
	}}
	return base
}

func inspectPrompt(meta *attachmentdomain.Attachment, args inspectMediaArgs, rendered renderedInspectImage, transport string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Attachment: %s (%s), rendered proxy: %dx%d %s via %s.\n", meta.Filename, meta.ID, rendered.Width, rendered.Height, rendered.MimeType, transport)
	if args.Crop != nil {
		fmt.Fprintf(&b, "Crop: normalized x=%.4f y=%.4f width=%.4f height=%.4f.\n", args.Crop.X, args.Crop.Y, args.Crop.Width, args.Crop.Height)
	}
	for _, note := range ignoredInspectFields(args) {
		fmt.Fprintf(&b, "Note: %s\n", note)
	}
	fmt.Fprintf(&b, "Question: %s", strings.TrimSpace(args.Question))
	return b.String()
}

func ignoredInspectFields(args inspectMediaArgs) []string {
	var notes []string
	if args.Page > 0 {
		notes = append(notes, "page is not applicable to image attachments and was ignored")
	}
	if args.StartMS > 0 || args.EndMS > 0 {
		notes = append(notes, "startMs/endMs are reserved for audio/video inspection and were ignored for this image")
	}
	return notes
}

func validateInspectCrop(crop *inspectCrop) error {
	if crop == nil {
		return nil
	}
	if crop.X < 0 || crop.X > 1 || crop.Y < 0 || crop.Y > 1 {
		return fmt.Errorf("inspect_media: crop x/y must be between 0 and 1")
	}
	if crop.Width <= 0 || crop.Width > 1 || crop.Height <= 0 || crop.Height > 1 {
		return fmt.Errorf("inspect_media: crop width/height must be in (0, 1]")
	}
	if crop.X+crop.Width <= 0 || crop.Y+crop.Height <= 0 || crop.X >= 1 || crop.Y >= 1 {
		return fmt.Errorf("inspect_media: crop is outside the image")
	}
	return nil
}

func normalizedDetail(detail string) string {
	if strings.TrimSpace(detail) == "high" {
		return "high"
	}
	return "default"
}

func toolappJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return fmt.Sprintf("%v", v)
	}
	return string(b)
}
