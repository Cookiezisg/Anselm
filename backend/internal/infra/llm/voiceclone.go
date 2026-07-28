package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Desktop-side voice cloning (WRK-082 H9). One provider, deliberately: `qwen-tts` is the only
// reachable one, and WHY is the finding that changed this batch's plan.
//
// DashScope offers two cloning families. CosyVoice's enrollment takes the reference audio ONLY as
// a publicly fetchable URL; qwen-tts also accepts a base64 data URL (官方文档核准 2026-07-28). An
// Anselm attachment lives in the loopback sidecar behind a bearer token — there is no address the
// upstream could fetch, and minting a public one for it would buy a hosting responsibility and an
// SSRF surface to save a cloning fee. So qwen-tts it is, at **$0.2 per voice created** (CosyVoice
// creation is free but unreachable). The price is on the official page — this one is NOT an
// `assumed-` debt.
//
// 桌面侧音色克隆(H9)。**刻意只有一家**:`qwen-tts` 是唯一够得着的那家,而**为什么**正是推翻本批
// 方案的那个发现。
//
// DashScope 有两支克隆。CosyVoice 的登记**只收公开可取的 URL**;qwen-tts **还收 base64 data URL**
// (官方文档核准 2026-07-28)。Anselm 的附件住在回环 sidecar 的 bearer 之后——上游**没有地址可取**,
// 而为它凭空造一个公开地址,是为省一笔克隆费买下一份托管责任加一个 SSRF 面。故选 qwen-tts,代价是
// **每创建一个音色 $0.2**(CosyVoice 创建免费,但够不着)。这个价在官方页上明码——它**不是**一笔
// `assumed-` 债。
//
// The three verbs live in one file because they are one resource's lifecycle over one endpoint
// (`audio/tts/customization`, discriminated by an `action` field), not three services.
//
// 三个动词同住一文件,因为它们是**一个**资源在**一条**端点上的生命周期(`audio/tts/customization`,
// 由 `action` 字段判别),不是三个服务。

// ErrVoiceCloneFailed is the neutral sentinel for an enrollment the upstream refused; Message
// carries the human-facing cause (S20).
//
// ErrVoiceCloneFailed 是上游拒绝登记的中立 sentinel;Message 携人话原因(S20)。
var ErrVoiceCloneFailed = errorspkg.New(errorspkg.KindUnavailable, "VOICE_CLONE_FAILED", "voice enrollment failed")

// voiceCloneBudget bounds one enrollment. Enrollment is a short upload + a synchronous answer, so
// this is a stuck-upstream ceiling rather than an expected duration.
//
// voiceCloneBudget 界一次登记。登记是一次短上传 + 同步应答,故这是「卡死上游」的顶棚、非预期时长。
const voiceCloneBudget = 90 * time.Second

// VoiceCloneMaxSeconds is the upstream's reference-audio ceiling. Checked BEFORE the request so a
// too-long sample fails locally with a sentence a user can act on, rather than as a remote 400.
//
// VoiceCloneMaxSeconds 是上游对参考音频的上限。**请求之前**就查,使过长的样本在本地以一句用户能据以
// 行动的话失败,而不是变成一个远端 400。
const VoiceCloneMaxSeconds = 30

// VoiceCloneModel is the enrollment model id — the `model` field of the customization call, not the
// synthesis model. The voice it mints is then usable by the ordinary TTS route.
//
// VoiceCloneModel 是**登记**模型 id——customization 调用的 `model` 字段,不是合成模型。它铸出的音色
// 随后由普通 TTS 路径使用。
//
// Exported because the spend ledger books enrollments under it: the ledger's model column must be
// the id we actually called, not a second copy of the string that can drift from it.
//
// 导出,因为支出台账按它记登记:台账的 model 列必须是我们**真正调用**的那个 id,而不是一份会与它漂移的
// 字符串副本。
const VoiceCloneModel = "qwen-tts"

// EnrollVoiceDashScope registers a reference clip as a named voice and returns the upstream's voice
// id — the value that goes straight into the `voice` parameter of a later synthesis call.
//
// EnrollVoiceDashScope 把一段参考音频登记成一个具名音色,返回上游的 voice id——那个值直接就是此后
// 合成调用里 `voice` 参数的取值。
func EnrollVoiceDashScope(ctx context.Context, httpc *http.Client, nativeBase, key, name string, sample DataURL) (string, error) {
	raw, err := voiceCustomization(ctx, httpc, nativeBase, key, map[string]any{
		"model": VoiceCloneModel,
		"input": map[string]any{
			"action": "create",
			"voice":  name,
			"audio":  map[string]any{"data": sample.String()},
		},
	})
	if err != nil {
		return "", err
	}
	var wire struct {
		Output struct {
			Voice   string `json:"voice"`
			VoiceID string `json:"voice_id"`
		} `json:"output"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil {
		return "", fmt.Errorf("%w: dashscope response undecodable", ErrVoiceCloneFailed)
	}
	// Both field names are read because the two cloning families answer with different ones and a
	// model swap must not silently return an empty id (which would land a voice row pointing at
	// nothing). 两个字段名都读:两支克隆答的键不同,而换模型绝不能静默返回空 id——那会落下一行指向
	// 虚无的音色。
	if id := cmpOr(wire.Output.VoiceID, wire.Output.Voice); id != "" {
		return id, nil
	}
	return "", fmt.Errorf("%w: dashscope minted no voice id", ErrVoiceCloneFailed)
}

// DeleteVoiceDashScope removes a cloned voice upstream. Called when the user deletes one locally —
// the local row is not the resource, the upstream registration is, and leaving orphans there would
// silently consume the per-account voice inventory nobody can see.
//
// DeleteVoiceDashScope 删掉上游的克隆音色。用户在本地删除时调用——本地行不是那个资源,**上游的登记**
// 才是;把孤儿留在那边,会静默吃掉一份谁也看不见的账号级音色库存。
func DeleteVoiceDashScope(ctx context.Context, httpc *http.Client, nativeBase, key, voiceID string) error {
	_, err := voiceCustomization(ctx, httpc, nativeBase, key, map[string]any{
		"model": VoiceCloneModel,
		"input": map[string]any{"action": "delete", "voice": voiceID},
	})
	return err
}

func voiceCustomization(ctx context.Context, httpc *http.Client, nativeBase, key string, payload map[string]any) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, voiceCloneBudget)
	defer cancel()
	body, _ := json.Marshal(payload)
	req, err := newImageRequest(ctx, strings.TrimRight(nativeBase, "/")+"/api/v1/services/audio/tts/customization", body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+key)
	raw, err := doImageRequest(httpc, req, "qwen")
	if err != nil {
		// Remap the image sentinel this shared transport carries: a voice enrollment that failed
		// must not reach the LLM (or the user) describing itself as an image problem.
		// 重映射共享传输携带的图像 sentinel:一次失败的音色登记,绝不能以「图像出问题」的措辞抵达 LLM
		// (或用户)。
		return nil, fmt.Errorf("%w: %s", ErrVoiceCloneFailed, err.Error())
	}
	return raw, nil
}

// cmpOr returns the first non-empty string. (Go 1.22's cmp.Or is generic over comparable with a
// zero default; spelling it locally keeps this file free of an import for three lines.)
//
// cmpOr 返回第一个非空串。
func cmpOr(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// EnrollVoiceAnselm enrolls through the managed gateway. Same ADR 0011 discipline as every other
// managed media input: bytes in the body as a data URL, never an address.
//
// EnrollVoiceAnselm 经受管网关登记。与其余每一种受管媒体输入同守 ADR 0011:字节以 data URL 走在体里,
// 绝不是一个地址。
func EnrollVoiceAnselm(ctx context.Context, httpc *http.Client, baseURL, installID, name string, sample DataURL) (string, error) {
	raw, err := voiceGateway(ctx, httpc, baseURL, installID, "/voices", map[string]any{
		"name": name, "audio": sample.String(),
	})
	if err != nil {
		return "", err
	}
	var wire struct {
		VoiceID string `json:"voiceId"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || wire.VoiceID == "" {
		return "", fmt.Errorf("%w: gateway minted no voice id", ErrVoiceCloneFailed)
	}
	return wire.VoiceID, nil
}

// DeleteVoiceAnselm removes a managed registration.
//
// DeleteVoiceAnselm 删掉一个受管登记。
func DeleteVoiceAnselm(ctx context.Context, httpc *http.Client, baseURL, installID, voiceID string) error {
	_, err := voiceGateway(ctx, httpc, baseURL, installID, "/voices:delete", map[string]any{"voiceId": voiceID})
	return err
}

func voiceGateway(ctx context.Context, httpc *http.Client, baseURL, installID, path string, payload map[string]any) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, voiceCloneBudget)
	defer cancel()
	body, _ := json.Marshal(payload)
	req, err := newImageRequest(ctx, strings.TrimRight(baseURL, "/")+path, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	raw, err := doImageRequest(httpc, req, "anselm")
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrVoiceCloneFailed, err.Error())
	}
	return raw, nil
}
