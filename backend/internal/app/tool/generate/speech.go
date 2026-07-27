package generate

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"unicode/utf8"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// maxSpeechChars bounds one whole utterance (across chunks). It is far above any single
// provider's request cap because the router splits — what this bounds is the total cost and wall
// clock of one tool call, not the wire.
//
// maxSpeechChars 界**整段**话(跨块)。它远高于任何一家的单请求上限,因为路由层会切块——它界的是
// 一次工具调用的总花费与墙钟,不是线缆。
const maxSpeechChars = 4000

// ErrTextRequired — the tool was called with nothing to say.
var ErrTextRequired = errorspkg.New(errorspkg.KindInvalid, "SPEECH_TEXT_REQUIRED", "text is required")

// GenerateSpeech is the speech half of the generation family (WRK-082 批C). Like its image twin it
// PERSISTS the artifact before answering: the model gets a MediaRef receipt, never bytes.
//
// GenerateSpeech 是生成族的语音半(批C)。与图像孪生件一样,它在作答前就把产物**落盘**:模型拿到的
// 是 MediaRef receipt、绝不是字节。
type GenerateSpeech struct {
	router      *Router
	attachments Uploader
}

var _ toolapp.Tool = (*GenerateSpeech)(nil)

func (t *GenerateSpeech) Name() string { return "generate_speech" }

func (t *GenerateSpeech) Description() string {
	return "Synthesize speech from text and save it as an audio attachment. The audio is ALREADY " +
		"saved and rendered to the user when this returns — reference it by attachmentId if you " +
		"need to mention it later. Use this when the user asks to hear something, wants a voiceover, " +
		"or asks for an audio version of some text. It costs a small metered amount per character " +
		"(declare danger=cautious). One call speaks one text."
}

func (t *GenerateSpeech) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"text": {"type": "string", "description": "The text to speak. Plain prose reads best; markdown syntax is spoken literally."},
			"voice": {"type": "string", "description": "Optional provider-specific voice name. Omit to use the route's default voice."}
		},
		"required": ["text"]
	}`)
}

type speechArgs struct {
	Text  string `json:"text"`
	Voice string `json:"voice"`
}

func (t *GenerateSpeech) ValidateInput(raw json.RawMessage) error {
	var a speechArgs
	if err := json.Unmarshal(raw, &a); err != nil {
		return fmt.Errorf("invalid arguments: %w", err)
	}
	text := strings.TrimSpace(a.Text)
	if text == "" {
		return ErrTextRequired
	}
	if utf8.RuneCountInString(text) > maxSpeechChars {
		return fmt.Errorf("text exceeds %d characters", maxSpeechChars)
	}
	return nil
}

// Execute resolves the route PER CALL (a key added or removed between steps takes effect on the
// next one), synthesizes, lands the artifact as a first-class attachment, and returns the receipt.
//
// Execute **逐调用**解析路由(两步之间增删 key 下一步即生效),合成、把产物落成一等附件、返回 receipt。
func (t *GenerateSpeech) Execute(ctx context.Context, args string) (string, error) {
	var a speechArgs
	if err := json.Unmarshal([]byte(args), &a); err != nil {
		return "", fmt.Errorf("invalid arguments: %w", err)
	}
	text := strings.TrimSpace(a.Text)
	if text == "" {
		return "", ErrTextRequired
	}
	route, err := t.router.resolveSpeech(ctx)
	if err != nil {
		return "", err
	}
	audio, err := t.router.synthesize(ctx, route, text, strings.TrimSpace(a.Voice))
	if err != nil {
		return "", err
	}
	att, err := t.attachments.Upload(reqctxpkg.SetMediaSource(ctx, "generate_speech"),
		artifactFilename(audio.Mime), audio.Mime, audio.Bytes)
	if err != nil {
		return "", fmt.Errorf("save speech artifact: %w", err)
	}
	receipt := map[string]any{
		"attachmentId": att.ID,
		"filename":     att.Filename,
		"mime":         att.MimeType,
		"sizeBytes":    att.SizeBytes,
		"provider":     route.provider,
		"characters":   utf8.RuneCountInString(text),
		"source":       "generate_speech",
		// Exact, measured from the PCM we just produced — not the requested character count and not
		// a guess. Omitted (0) rather than invented when the bytes are not a readable WAV.
		// **精确**值,量自我们刚产出的 PCM——不是请求的字符数、也不是猜的。字节不是可读 WAV 时**留 0**、不编。
		"durationMs": llminfra.AudioDurationMs(audio.Bytes),
	}
	if route.model != "" {
		receipt["model"] = route.model
	}
	return toolapp.ToJSON(receipt), nil
}
