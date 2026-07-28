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

// EnrollVoiceAnselm enrolls through the managed gateway by NAMING a lease it already holds.
//
// Same ADR 0011 discipline as every other managed media input — the client never supplies an
// address. The sample rides the ordinary resumable upload, and the gateway alone decides what
// public URL (if any) the upstream is shown. A 30-second clip therefore never has to fit in a JSON
// body, and the host stays unrepresentable from here rather than merely validated.
//
// EnrollVoiceAnselm 经受管网关登记,方式是**指名**一个它已经持有的 lease。
//
// 与其余每一种受管媒体输入同守 ADR 0011——客户端**从不**提供地址。样本走普通断点上传,而**只有网关**
// 决定给上游看什么公开 URL(如果有的话)。故一段 30 秒的音频永远不必塞进 JSON body,而那个 host 从
// 这里**根本无法表达**、不只是「被校验」。
func EnrollVoiceAnselm(ctx context.Context, httpc *http.Client, baseURL, installID, name, leaseID string) (string, error) {
	raw, err := voiceGateway(ctx, httpc, baseURL, installID, "/voices", map[string]any{
		"name": name, "leaseId": leaseID,
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
