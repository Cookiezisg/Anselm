package llm

import (
	"context"
	"encoding/json"
	"net/http"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

// anselmProvider is the built-in free-tier provider: the Anselm gateway, an OpenAI-wire capability
// router (api.anselm.website). It embeds deepseekProvider for the compatible streaming parser,
// reasoning_content round-trip and tool-call behavior; the gateway itself decides DeepSeek text vs
// a multimodal upstream from the complete content history. The managed api_key row carries the
// public install id; the device-proof transport signs every concrete request with the installation's
// encrypted-at-rest Ed25519 key. Tools flow through unchanged, so the free tier stays agentic.
//
// anselmProvider 是内置免费档 provider：Anselm 网关（OpenAI-wire capability router，api.anselm.website）。
// embed deepseekProvider 继承兼容的 BuildRequest / ParseStream / reasoning_content / tool-call 线缆，
// 而网关按完整历史自行决定文本 DeepSeek 或图像/视频 Kimi。受管 api_key 行保存公开 install id；设备证明
// transport 用加密落盘的 Ed25519 私钥逐请求签名。tools 仍原样穿过统一入口。
type anselmProvider struct {
	*deepseekProvider
}

func newAnselmProvider() *anselmProvider {
	return &anselmProvider{deepseekProvider: newDeepSeekProvider()}
}

// AnselmBaseURL is the production free-tier gateway base (OpenAI-compat path root, including the
// /v1 prefix the gateway requires — probe appends /models, wire appends /chat/completions, install
// appends /install). Exported so the free-tier provisioner seeds the managed key's base_url and the
// install endpoint from one source of truth.
//
// AnselmBaseURL 是生产免费档网关 base（OpenAI-compat 路径根，含网关要求的 /v1 前缀——探针追加 /models、
// wire 追加 /chat/completions、install 追加 /install）。导出供免费档 provisioner 从单一事实源播种受管
// key 的 base_url 与 install 端点。
const AnselmBaseURL = "https://api.anselm.website/v1"

func (p *anselmProvider) Name() string           { return "anselm" }
func (p *anselmProvider) DefaultBaseURL() string { return AnselmBaseURL }

// BuildRequest uses DeepSeek's wire body but replaces reusable bearer auth with
// the public install id. The HTTP device-proof transport signs the final bytes.
func (p *anselmProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	httpReq, err := p.deepseekProvider.BuildRequest(ctx, req)
	if err != nil {
		return nil, err
	}
	httpReq.Header.Del("Authorization")
	httpReq.Header.Set(deviceproofinfra.HeaderInstallID, req.Key)
	return httpReq, nil
}

// anselmSpecs is the rolling-compatibility fallback for the gateway's one
// logical model. New gateways publish exact text/multimodal route profiles;
// old gateways still get the same production limits from this static entry.
// Knobs stay empty because the gateway owns reasoning behavior.
//
// anselmSpecs 是网关唯一逻辑模型的滚动兼容 fallback。新网关发布精确 text/multimodal
// route profile；旧网关仍从此静态项获得同一生产限制。网关拥有 reasoning 行为，故 knobs 为空。
const (
	anselmTextInputLimit       = 1_000_000
	anselmMultimodalInputLimit = 262_144
	anselmProductOutputLimit   = 16_384
)

var anselmSpecs = []modelSpec{{AnselmModelID, anselmTextInputLimit, anselmProductOutputLimit, nil, true, false}}

// DescribeModels parses the gateway's id-only /models body against anselmSpecs (NOT deepseekSpecs).
// Overriding this is MANDATORY: without it the embedded deepseekProvider.DescribeModels would attach
// dsKnobs(), showing dead thinking/reasoning_effort controls in the picker for a gateway that strips
// them.
//
// DescribeModels 用 anselmSpecs（非 deepseekSpecs）解析网关仅含 id 的 /models 返回。必须覆盖：否则继承的
// deepseekProvider.DescribeModels 会挂 dsKnobs()，给一个会剥离它们的网关在 picker 里显示死的
// thinking/reasoning_effort 钮。
func (p *anselmProvider) DescribeModels(raw string) ([]ModelInfo, error) {
	models := describeFromSpecs(anselmSpecs, raw)
	type routeProfile struct {
		InputLimit  int  `json:"input_limit"`
		OutputLimit int  `json:"output_limit"`
		Available   bool `json:"available"`
	}
	var wire struct {
		Data []struct {
			ID           string `json:"id"`
			Capabilities *struct {
				Version    int          `json:"version"`
				Routing    string       `json:"routing"`
				Text       routeProfile `json:"text"`
				Multimodal routeProfile `json:"multimodal"`
			} `json:"anselm_capabilities"`
		} `json:"data"`
	}
	_ = json.Unmarshal([]byte(raw), &wire)
	capsByID := make(map[string]struct {
		text, multimodal routeProfile
	}, len(wire.Data))
	for _, m := range wire.Data {
		if m.Capabilities != nil && m.Capabilities.Version == 1 && m.Capabilities.Routing == "content" {
			capsByID[m.ID] = struct {
				text, multimodal routeProfile
			}{m.Capabilities.Text, m.Capabilities.Multimodal}
		}
	}
	for i := range models {
		models[i].TextInputLimit = anselmTextInputLimit
		models[i].MultimodalInputLimit = anselmMultimodalInputLimit
		if c, ok := capsByID[models[i].ID]; ok {
			if c.text.InputLimit > 0 {
				models[i].ContextWindow = c.text.InputLimit
				models[i].TextInputLimit = c.text.InputLimit
			}
			if c.text.OutputLimit > 0 {
				models[i].MaxOutput = c.text.OutputLimit
			}
			if c.multimodal.InputLimit > 0 {
				models[i].MultimodalInputLimit = c.multimodal.InputLimit
			}
			// An explicitly unavailable route must not be advertised. Older
			// gateways omit the extension and retain the static production
			// fallback for rolling compatibility.
			if !c.multimodal.Available {
				models[i].Vision = false
				models[i].Video = false
			}
		}
		// Current gateway accepts image + MP4 video. Audio stays in the common content protocol,
		// but must remain unadvertised until a future audio upstream is wired.
		//
		// 当前网关接收图片与 MP4 视频。音频保留在公共内容协议中，但在未来接上音频上游前必须不对用户宣称可用。
		if models[i].Vision {
			models[i].Video = true
		}
		models[i].Audio = false
		models[i].MaxMediaParts = 8
		// The production gateway admits 8MiB request bodies and 3MiB decoded media. Publishing the
		// decoded limit lets attachment rendering degrade locally before transport base64 expands it.
		//
		// 生产网关允许 8MiB 请求体与 3MiB 解码媒体。发布解码上限使附件渲染可在 base64 膨胀进传输层前本地降级。
		models[i].MaxMediaBytes = 3 * 1024 * 1024
	}
	return models, nil
}

// AnselmModelID is the single logical model the free-tier gateway serves. Its name is the gateway's
// public alias, not either internal upstream model. It is the source for anselmSpecs, the seeded
// probe body, and the managed key's pinned model id.
//
// AnselmModelID 是免费档网关唯一服务的模型（它把任何请求模型 coerce 成它）。anselmSpecs / 播种探测 body /
// 受管 key 钉定模型 id 的单一事实源。
const AnselmModelID = "anselm-auto"

// AnselmProbeBody returns the synthetic OpenAI /models body the free-tier provisioner seeds into the
// managed key's probe archive, so the model module surfaces AnselmModelID without a live probe. It
// mirrors what the gateway's GET /v1/models returns and MUST list an id anselmSpecs matches, else
// describeFromSpecs would drop it and the picker would show no model.
//
// AnselmProbeBody 返回免费档 provisioner 植入受管 key 探测档案的合成 OpenAI /models body，使 model 模块
// 无需 live 探针即可呈现 AnselmModelID。镜像网关 GET /v1/models，且必须列 anselmSpecs 命中的 id，否则
// describeFromSpecs 丢弃它、picker 无模型。
func AnselmProbeBody() string {
	return `{"object":"list","data":[{"id":"` + AnselmModelID + `","object":"model","anselm_capabilities":{"version":1,"routing":"content","text":{"input_limit":1000000,"output_limit":16384,"available":true},"multimodal":{"input_limit":262144,"output_limit":16384,"available":true}}}]}`
}
