package generate

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	mediarefpkg "github.com/sunweilin/anselm/backend/internal/pkg/mediaref"
)

// VoiceInventory is the per-workspace cap on enrolled voices (WRK-082 H9, 用户拍板 2026-07-28).
// It is an INVENTORY, not a quota: an enrolled voice persists upstream until deleted and costs
// money once at creation, so nothing frees a slot tomorrow — the remedy is deleting one, and every
// message about the limit has to say that or it reads as "come back later".
//
// VoiceInventory 是每 workspace 的音色上限(H9,用户 2026-07-28 拍板)。它是**库存**、不是配额:
// 一个已登记的音色在上游一直存在到被删、且创建时花一次钱,故**明天不会腾出位置**——补救办法是删一个,
// 而每一句关于这个上限的话都必须这么说,否则会被读成「过会儿再来」。
const VoiceInventory = 2

// maxVoiceSampleBytes bounds what we base64 into an enrollment body. The upstream caps the clip at
// 30 seconds; this is the byte-side companion so a huge lossless file fails locally.
//
// maxVoiceSampleBytes 界我们 base64 进登记请求体的大小。上游把片段卡在 30 秒;这是字节侧的伴生上限,
// 使一个巨大的无损文件在本地就失败。
const maxVoiceSampleBytes = 20 << 20

// EnrollVoice is the enroll_voice tool (WRK-082 H9): an EXISTING audio attachment becomes a named
// voice that generate_speech and read-aloud can then speak in.
//
// **Its danger anchor is `dangerous`, and not because of the money.** Enrollment creates persistent
// state on someone else's servers under a voice that belongs to a person — the two things S18's
// vocabulary calls irreversible, in one call. The per-voice fee is real but small; the reason this
// one blocks for a human is that a voice is an identity.
//
// EnrollVoice 是 enroll_voice 工具(H9):一个**已存在**的音频附件成为一个具名音色,generate_speech
// 与朗读随后可以用它说话。
//
// **它的 danger 锚是 `dangerous`,而理由不是钱。** 登记在**别人的服务器上**创建**持久状态**,而那个
// 状态是**属于某个人的声音**——S18 词表里称为不可逆的两件事,在一次调用里同时发生。每个音色那笔费用
// 真实但很小;这一个之所以要挡下来问人,是因为**声音是身份**。
type EnrollVoice struct {
	router *Router
	source Fetcher
	voices voicedomain.Repository
}

func (*EnrollVoice) Name() string { return "enroll_voice" }

func (*EnrollVoice) Description() string {
	return "Register an EXISTING audio attachment as a named voice, so later speech can be spoken in " +
		"it. Give the attachmentId of a clean sample (up to 30 seconds of one speaker) and a short " +
		"name; pass that name as generate_speech's `voice` afterwards. Creates PERSISTENT state on the " +
		"provider's servers for a voice belonging to a real person, and costs a one-off fee — declare " +
		"danger=dangerous so the user is asked first. Only a few voices can be kept at a time; delete " +
		"one to make room."
}

func (*EnrollVoice) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"attachmentId": {"type": "string", "description": "The att_… id of the reference audio (one speaker, up to 30s)."},
			"name": {"type": "string", "description": "Short name to call this voice later, e.g. \"narrator\"."}
		},
		"required": ["attachmentId", "name"]
	}`)
}

type enrollVoiceInput struct {
	AttachmentID string `json:"attachmentId"`
	Name         string `json:"name"`
}

func (*EnrollVoice) ValidateInput(raw json.RawMessage) error {
	var in enrollVoiceInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return fmt.Errorf("enroll_voice.ValidateInput: %w", err)
	}
	if !mediarefpkg.IsAttachmentID(strings.TrimSpace(in.AttachmentID)) {
		return ErrSourceRequired
	}
	if strings.TrimSpace(in.Name) == "" {
		return voicedomain.ErrNameRequired
	}
	return nil
}

// Execute checks the inventory, enrolls upstream, then records the pointer. The ORDER is the whole
// correctness argument: the row is written only after the upstream registration exists, because a
// row pointing at nothing is unusable, while an upstream registration with no row is invisible —
// and the second failure is the expensive one, so it is the one to avoid by going upstream-last on
// creation and upstream-first on deletion.
//
// Execute 先查库存、再上游登记、最后落指针。**顺序本身就是全部的正确性论证**:行只在上游登记确实存在
// 之后才写——因为「指向虚无的行」不可用,而「没有行的上游登记」**不可见**;后者才是贵的那种失败,故
// 创建时上游在后、删除时上游在前。
func (e *EnrollVoice) Execute(ctx context.Context, args string) (string, error) {
	var in enrollVoiceInput
	if err := json.Unmarshal([]byte(args), &in); err != nil {
		return "", fmt.Errorf("enroll_voice: %w", err)
	}
	name := strings.TrimSpace(in.Name)

	// Inventory and name collision are checked BEFORE the paid call: enrolling and then discovering
	// the row cannot be written would leave an orphan upstream that nothing local can address.
	// 库存与重名在**付费调用之前**查:先登记、再发现行写不下,会在上游留下一个本地无从寻址的孤儿。
	existing, err := e.voices.List(ctx)
	if err != nil {
		return "", err
	}
	if len(existing) >= VoiceInventory {
		return "", voicedomain.ErrInventoryFull
	}
	for _, v := range existing {
		if v.Name == name {
			return "", voicedomain.ErrNameTaken
		}
	}

	src, data, err := e.source.Download(ctx, strings.TrimSpace(in.AttachmentID))
	if err != nil {
		return "", err
	}
	if !strings.HasPrefix(src.MimeType, "audio/") {
		return "", fmt.Errorf("%w: the referenced attachment is %s, not audio",
			voicedomain.ErrNameRequired, src.MimeType)
	}
	if len(data) > maxVoiceSampleBytes {
		return "", fmt.Errorf("%w: sample is %d bytes — use a shorter clip (up to %d seconds)",
			ErrSourceNotImage, len(data), llminfra.VoiceCloneMaxSeconds)
	}

	provider, upstreamID, err := e.router.EnrollVoice(ctx, name, src.MimeType, data)
	if err != nil {
		return "", err
	}
	v := &voicedomain.Voice{
		ID:                 idgenpkg.New("vce"),
		Name:               name,
		Provider:           provider,
		UpstreamID:         upstreamID,
		SourceAttachmentID: src.ID,
		CreatedAt:          time.Now().UTC(),
	}
	if err := e.voices.Create(ctx, v); err != nil {
		// The upstream registration exists but the pointer did not land. Roll it back rather than
		// leaving a voice nobody can see, name or delete — the inventory it occupies is real.
		// 上游登记已存在,而指针没落下。**回滚它**,而不是留下一个谁也看不见、叫不出名、删不掉的音色
		// ——它占的那份库存是真的。
		if delErr := e.router.DeleteVoice(ctx, provider, upstreamID); delErr != nil {
			return "", fmt.Errorf("enroll_voice: %w (and the upstream voice %s could not be rolled back: %v)",
				err, upstreamID, delErr)
		}
		return "", err
	}
	return toolapp.ToJSON(map[string]any{
		"voiceId":            v.ID,
		"name":               v.Name,
		"provider":           v.Provider,
		"sourceAttachmentId": src.ID,
		"remainingSlots":     VoiceInventory - len(existing) - 1,
		"source":             "enroll_voice",
	}), nil
}
