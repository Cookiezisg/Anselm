package attachment

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	mediaapp "github.com/sunweilin/anselm/backend/internal/app/media"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const (
	inspectMediaMaxOutputTokens       = 900
	inspectMediaTextDefaultLimitChars = 12_000
	inspectMediaTextMaxLimitChars     = 40_000
)

const inspectMediaDescription = `Inspect one uploaded attachment by attachmentId and return concise, bounded text evidence. For images, this uses the default vision-capable Anselm route and sends only one bounded image proxy/crop; it does not dump image bytes into the conversation. For text/documents, it reuses local extraction plus query/page/offset windows and does not call a model, so large files are returned as evidence slices instead of flooding context. Audio/video time ranges are future capabilities and return a self-correcting note.`

var inspectMediaSchema = json.RawMessage(`{
	"type": "object",
	"required": ["attachmentId", "question"],
	"properties": {
		"attachmentId": {"type": "string", "description": "Uploaded attachment id, e.g. att_..."},
		"question": {"type": "string", "description": "The specific question to answer from this attachment evidence."},
		"query": {"type": "string", "maxLength": 512, "description": "For text/document attachments, optional literal query. Prefer this over a broad page read when looking for a specific phrase."},
		"page": {"type": "integer", "minimum": 1, "description": "For text/document attachments, return a bounded extracted page when page markers are available; otherwise interpreted as a fixed text window."},
		"offset": {"type": "integer", "minimum": 0, "description": "For text/document attachments, character offset for bounded text-window inspection."},
		"limitChars": {"type": "integer", "minimum": 1, "maximum": 40000, "description": "For text/document attachments, maximum evidence characters. Defaults to 12000; capped at 40000."},
		"contextChars": {"type": "integer", "minimum": 1, "maximum": 2000, "description": "For text/document query mode, characters of context on each side. Defaults to 800."},
		"maxMatches": {"type": "integer", "minimum": 1, "maximum": 10, "description": "For text/document query mode, max literal matches. Defaults to 5."},
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
	textCache      TextCache
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
	if len([]rune(strings.TrimSpace(a.Query))) > readAttachmentMaxQueryChars {
		return fmt.Errorf("inspect_media: query must be <= %d characters", readAttachmentMaxQueryChars)
	}
	if a.Offset < 0 {
		return fmt.Errorf("inspect_media: offset must be >= 0")
	}
	if a.LimitChars < 0 || a.LimitChars > inspectMediaTextMaxLimitChars {
		return fmt.Errorf("inspect_media: limitChars must be 0/default or between 1 and %d", inspectMediaTextMaxLimitChars)
	}
	if a.ContextChars < 0 || a.ContextChars > readAttachmentMaxSearchContextChars {
		return fmt.Errorf("inspect_media: contextChars must be 0/default or between 1 and %d", readAttachmentMaxSearchContextChars)
	}
	if a.MaxMatches < 0 || a.MaxMatches > readAttachmentMaxSearchMatches {
		return fmt.Errorf("inspect_media: maxMatches must be 0/default or between 1 and %d", readAttachmentMaxSearchMatches)
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
	meta, err := t.svc.Get(ctx, args.AttachmentID)
	if err != nil {
		if errors.Is(err, attachmentdomain.ErrNotFound) {
			return fmt.Sprintf("Attachment %q not found. Call list_attachments to see available files.", args.AttachmentID), nil
		}
		return "", err
	}
	switch meta.Kind {
	case attachmentdomain.KindImage:
	case attachmentdomain.KindText, attachmentdomain.KindDocument:
		return t.inspectTextual(ctx, meta, args)
	default:
		return fmt.Sprintf(
			"inspect_media currently supports image and text/document attachments. Attachment %q (id %s) is kind %s / %s. Audio/video time-range inspection is not implemented yet; attach a transcript or use speech input for dictation.",
			meta.Filename, meta.ID, meta.Kind, meta.MimeType), nil
	}
	_, original, err := t.svc.Download(ctx, args.AttachmentID)
	if err != nil {
		return "", err
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
	Query        string       `json:"query"`
	Page         int          `json:"page"`
	Offset       int          `json:"offset"`
	LimitChars   int          `json:"limitChars"`
	ContextChars int          `json:"contextChars"`
	MaxMatches   int          `json:"maxMatches"`
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

type inspectTextResult struct {
	AttachmentID string   `json:"attachmentId"`
	Filename     string   `json:"filename"`
	Mime         string   `json:"mime"`
	Kind         string   `json:"kind"`
	Question     string   `json:"question"`
	Query        string   `json:"query,omitempty"`
	Page         int      `json:"page,omitempty"`
	Offset       int      `json:"offset,omitempty"`
	LimitChars   int      `json:"limitChars"`
	Mode         string   `json:"mode"`
	Notes        []string `json:"notes,omitempty"`
	Evidence     string   `json:"evidence"`
}

func (t *InspectMedia) inspectTextual(ctx context.Context, meta *attachmentdomain.Attachment, args inspectMediaArgs) (string, error) {
	text, err := attachmentText(ctx, t.svc, t.textCache, meta)
	if err != nil {
		return "", err
	}
	limit := normalizeInspectTextLimit(args.LimitChars)
	notes := ignoredTextInspectFields(args)
	mode := "window"
	evidence := ""
	if strings.TrimSpace(args.Query) != "" {
		mode = "query"
		evidence = searchAttachmentText(text, args.Query, normalizeSearchContext(args.ContextChars), normalizeSearchMatches(args.MaxMatches))
	} else if args.Page > 0 {
		mode = "page"
		var pageNotes []string
		evidence, pageNotes = inspectDocumentPageText(text, args.Page, limit)
		notes = append(notes, pageNotes...)
	} else {
		evidence = pageAttachmentText(text, args.Offset, limit)
	}
	return toolappJSON(inspectTextResult{
		AttachmentID: meta.ID,
		Filename:     meta.Filename,
		Mime:         meta.MimeType,
		Kind:         meta.Kind,
		Question:     strings.TrimSpace(args.Question),
		Query:        strings.TrimSpace(args.Query),
		Page:         args.Page,
		Offset:       args.Offset,
		LimitChars:   limit,
		Mode:         mode,
		Notes:        notes,
		Evidence:     evidence,
	}), nil
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

func ignoredTextInspectFields(args inspectMediaArgs) []string {
	var notes []string
	if args.Crop != nil {
		notes = append(notes, "crop is only applicable to image attachments and was ignored")
	}
	if args.Detail != "" {
		notes = append(notes, "detail is only applicable to image attachments and was ignored")
	}
	if args.StartMS > 0 || args.EndMS > 0 {
		notes = append(notes, "startMs/endMs are reserved for audio/video inspection and were ignored for this text/document")
	}
	if strings.TrimSpace(args.Query) != "" && args.Page > 0 {
		notes = append(notes, "query mode takes precedence over page for text/document inspection")
	}
	if strings.TrimSpace(args.Query) != "" && args.Offset > 0 {
		notes = append(notes, "query mode ignores offset for text/document inspection")
	}
	return notes
}

func normalizeInspectTextLimit(limit int) int {
	if limit <= 0 {
		return inspectMediaTextDefaultLimitChars
	}
	if limit > inspectMediaTextMaxLimitChars {
		return inspectMediaTextMaxLimitChars
	}
	return limit
}

var inspectPageMarkerRE = regexp.MustCompile(`(?m)^# Page ([0-9]+)\b[^\n]*\n?`)

func inspectDocumentPageText(text string, page, limit int) (string, []string) {
	if page <= 0 {
		return pageAttachmentText(text, 0, limit), nil
	}
	matches := inspectPageMarkerRE.FindAllStringSubmatchIndex(text, -1)
	if len(matches) == 0 {
		offset := (page - 1) * limit
		return pageAttachmentText(text, offset, limit), []string{"no explicit page markers were found; page was interpreted as a fixed text window"}
	}
	available := make([]int, 0, len(matches))
	for i, m := range matches {
		n, err := strconv.Atoi(text[m[2]:m[3]])
		if err != nil {
			continue
		}
		available = append(available, n)
		if n != page {
			continue
		}
		start := m[0]
		end := len(text)
		if i+1 < len(matches) {
			end = matches[i+1][0]
		}
		body := strings.TrimSpace(text[start:end])
		runes := []rune(body)
		if len(runes) <= limit {
			return body, nil
		}
		return string(runes[:limit]) + fmt.Sprintf("\n\n[inspect_media page truncated: page=%d chars=%d totalPageChars=%d]", page, limit, len(runes)), nil
	}
	return fmt.Sprintf("No extracted page marker for page %d. Available pages: %s. Try a listed page or use query/offset inspection.", page, compactPageList(available)), nil
}

func compactPageList(pages []int) string {
	if len(pages) == 0 {
		return "none"
	}
	if len(pages) <= 12 {
		parts := make([]string, 0, len(pages))
		for _, p := range pages {
			parts = append(parts, strconv.Itoa(p))
		}
		return strings.Join(parts, ",")
	}
	parts := make([]string, 0, 13)
	for _, p := range pages[:10] {
		parts = append(parts, strconv.Itoa(p))
	}
	parts = append(parts, fmt.Sprintf("...(%d total)", len(pages)))
	return strings.Join(parts, ",")
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
