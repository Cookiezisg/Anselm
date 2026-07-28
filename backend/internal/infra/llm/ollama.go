package llm

import (
	"encoding/json"
	"strconv"
)

// newOllamaProvider is the Ollama family's [compatSpec], and it is the least OpenAI-shaped member of
// this dialect. Three things are its own: images ride a message-level `images` array of RAW base64
// (no content parts at all), thinking is a `think` field that is a bool for most models and an
// effort STRING for GPT-OSS, and the token cap plus context window live in an `options` bag —
// `num_ctx` exists because this is a local daemon and the client decides how much KV cache to
// allocate, which no cloud API lets you do.
//
// newOllamaProvider 是 Ollama 家的 [compatSpec],也是本方言里**最不像 OpenAI** 的一员。三样是它自己的:
// 图走消息级 `images` 数组、**裸 base64**(根本没有 content part);思考是一个 `think` 字段——多数模型
// 是 bool、GPT-OSS 是 effort **字符串**;token 上限与上下文窗口住在 `options` 袋子里——`num_ctx` 存在
// 是因为这是**本地** daemon、由客户端决定分配多少 KV cache,而云 API 不给你这个。
func newOllamaProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name: "ollama",
		// Empty on purpose: Ollama is a local daemon on a user-chosen host/port, so the caller must
		// supply base_url. 刻意为空:Ollama 是本地 daemon、host/port 由用户定,caller 必须自带。
		baseURL:                 func() string { return "" },
		wire:                    ollamaWire,
		parts:                   ollamaParts,
		forceNonStreamWithTools: true,
		encode: func(req Request, body *compatRequest) {
			if v := req.Options["think"]; v != "" {
				if v == "true" || v == "false" {
					body.Think = v == "true"
				} else {
					body.Think = v // GPT-OSS effort: low/medium/high
				}
			}
			if v := req.Options["num_ctx"]; v != "" {
				if n, err := strconv.Atoi(v); err == nil {
					body.setOption("num_ctx", n)
				}
			}
			if req.MaxTokens > 0 {
				body.setOption("num_predict", req.MaxTokens)
			}
		},
		describe: describeOllama,
	}}
}

// ollamaWire: this dialect renders text and images only — no document/PDF input exists, so a "file"
// part is skipped and the attachment layer's text extraction is what reaches the model.
//
// ollamaWire:本方言只渲文本与图——不存在文档/PDF 输入,故 "file" part 跳过,抵达模型的是附件层抽出的文本。
var ollamaWire = partMask{image: true}

// ollamaParts flattens text into `content` and appends images to the message-level `images` array as
// RAW base64. This is the one member of the dialect that does not use content parts at all, which is
// exactly the kind of difference a spec field can hold and a shared branch could not.
//
// ollamaParts 把文本压进 `content`、把图作为**裸 base64** 追加到消息级 `images` 数组。它是本方言里
// 唯一**完全不用** content part 的成员——而这正是 spec 字段装得下、共享分支装不下的那种差异。
func ollamaParts(m LLMMessage) (compatMessage, error) {
	cm := compatMessage{Role: "user"}
	var text string
	for _, part := range m.Parts {
		switch part.Type {
		case "text":
			text += part.Text
		case "image_url":
			cm.Images = append(cm.Images, ollamaStripDataURL(part.ImageURL))
		}
	}
	cm.Content = jsonString(text)
	return cm, nil
}

// ollamaStripDataURL returns the raw base64 payload of a data-URL, or the input unchanged when it
// isn't one (Ollama wants raw base64, not a data-URL).
//
// ollamaStripDataURL 取 data-URL 的裸 base64 载荷;不是 data-URL 就原样返回(Ollama 要裸 base64)。
func ollamaStripDataURL(s string) string {
	if len(s) > 5 && s[:5] == "data:" {
		for i := 0; i < len(s); i++ {
			if s[i] == ',' {
				return s[i+1:]
			}
		}
	}
	return s
}

// ── model catalog (dynamic; /api/tags lists installed models, no caps/knobs) ────

// DescribeModels parses Ollama's GET /api/tags body ({"models":[{"name":...}]}) — its native
// discovery shape, unlike the OpenAI {"data":[{"id"}]} the chat path mimics. /api/tags carries
// neither capabilities nor context window (those live behind /api/show, which the probe doesn't
// fetch), so every installed model gets the generic local-runtime knobs and an unset window.
//
// DescribeModels 解析 Ollama 的 GET /api/tags 返回（{"models":[{"name":...}]}）——其原生发现形状，
// 区别于 chat 路径模仿的 OpenAI {"data":[{"id"}]}。/api/tags 既不带能力也不带上下文窗口（那在
// /api/show 后面、探针没取），故每个已装模型都给通用本地 runtime 旋钮、窗口留空。
func describeOllama(raw string) ([]ModelInfo, error) {
	var resp struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := json.Unmarshal([]byte(raw), &resp); err != nil {
		return nil, nil
	}
	out := make([]ModelInfo, 0, len(resp.Models))
	for _, m := range resp.Models {
		if m.Name == "" {
			continue
		}
		out = append(out, ModelInfo{
			ID:          m.Name,
			DisplayName: m.Name,
			// Local model: context window is client-set per request via num_ctx, not a fixed spec.
			// 本地模型：上下文窗口由客户端每请求 num_ctx 设定，无固定规格。
			Knobs: []Knob{
				boolKnob("think", "Thinking", "false"),
				intKnob("num_ctx", "Context window", ""),
			},
		})
	}
	return out, nil
}
