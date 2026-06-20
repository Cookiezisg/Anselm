package llm

// anselmProvider is the built-in free-tier provider: the Anselm gateway, an OpenAI-wire proxy in
// front of DeepSeek (api.anselm.host). It embeds deepseekProvider to inherit the ENTIRE DeepSeek
// wire dialect verbatim — BuildRequest, ParseStream, the reasoning_content round-trip, tool-call
// streaming — overriding only identity (Name/DefaultBaseURL) and the model catalog. The managed
// api_key row (provider "anselm") carries the gwk_ install token as its Bearer key, so the
// inherited BuildRequest authenticates with zero change. Tools flow through unchanged: the gateway
// forwards them to DeepSeek, so the free tier is fully agentic.
//
// anselmProvider 是内置免费档 provider：Anselm 网关（DeepSeek 前置的 OpenAI-wire 反代，api.anselm.host）。
// embed deepseekProvider 原样继承整套 DeepSeek wire 方言——BuildRequest / ParseStream /
// reasoning_content round-trip / tool-call 流式——仅覆盖身份与模型目录。受管 api_key 行（provider
// "anselm"）以 gwk_ install token 作 Bearer key，故继承的 BuildRequest 零改即可鉴权。tools 原样透传：
// 网关转发给 DeepSeek，免费档全 agentic。
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
const AnselmBaseURL = "https://api.anselm.host/v1"

func (p *anselmProvider) Name() string           { return "anselm" }
func (p *anselmProvider) DefaultBaseURL() string { return AnselmBaseURL }

// anselmSpecs is the gateway's static catalog: exactly one model, deepseek-v4-flash (1M ctx /
// 384K out), no vision/docs, and crucially no knobs — the gateway strips thinking/reasoning_effort,
// so offering the picker those would be dead UI. Kept separate from deepseekSpecs precisely so the
// DescribeModels override below yields knob-free entries.
//
// anselmSpecs 是网关静态目录：仅 deepseek-v4-flash（1M/384K），无 vision/docs，且关键地无 knobs——网关
// 剥离 thinking/reasoning_effort，给 picker 这些钮是死 UI。与 deepseekSpecs 分开，正是为让下面的
// DescribeModels 覆盖产出无旋钮条目。
var anselmSpecs = []modelSpec{
	{"deepseek-v4-flash", 1_000_000, 384_000, nil, false, false},
}

// DescribeModels parses the gateway's id-only /models body against anselmSpecs (NOT deepseekSpecs).
// Overriding this is MANDATORY: without it the embedded deepseekProvider.DescribeModels would attach
// dsKnobs(), showing dead thinking/reasoning_effort controls in the picker for a gateway that strips
// them.
//
// DescribeModels 用 anselmSpecs（非 deepseekSpecs）解析网关仅含 id 的 /models 返回。必须覆盖：否则继承的
// deepseekProvider.DescribeModels 会挂 dsKnobs()，给一个会剥离它们的网关在 picker 里显示死的
// thinking/reasoning_effort 钮。
func (p *anselmProvider) DescribeModels(raw string) ([]ModelInfo, error) {
	return describeFromSpecs(anselmSpecs, raw), nil
}
