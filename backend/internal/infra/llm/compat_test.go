package llm

import (
	"context"
	"encoding/json"
	"maps"
	"slices"
	"strings"
	"testing"
)

// One implementation now serves eight OpenAI-compatible families, and the two things that buys us —
// a wire fix landing everywhere at once, a new provider costing a spec instead of 500 lines — are
// only safe if two properties hold. These tests are those two properties.
//
// 一份实现现在服务八个 OpenAI 兼容家族,而它换来的两样东西——一处线缆修复一次抵达所有家、新增一家的
// 代价是一份 spec 而不是 500 行——只有在**两条性质**成立时才是安全的。这两个测试就是那两条性质。

// compatFamilies is every provider that speaks this dialect, with the request-body keys its family
// is allowed to put on the wire beyond the shape everyone sends.
//
// compatFamilies 是说本方言的每一家,附上「在人人都发的形状之外,本家**允许**放上线缆的请求体 key」。
var compatFamilies = []struct {
	name     string
	provider func() *compatProvider
	// knobKeys: the keys this family may add. A key here that the family never sends is dead
	// documentation; a key sent but not listed is a leak from the superset body.
	// knobKeys:本家**可以**加的 key。列了却从不发 = 死文档;发了却没列 = 超集 body 的泄漏。
	knobKeys []string
}{
	{"openai", newOpenAIProvider, []string{"max_completion_tokens", "reasoning_effort", "verbosity"}},
	{"deepseek", newDeepSeekProvider, []string{"max_tokens", "thinking", "reasoning_effort"}},
	{"qwen", newQwenProvider, []string{"max_tokens", "enable_thinking", "thinking_budget"}},
	{"zhipu", newZhipuProvider, []string{"max_tokens", "thinking", "tool_choice"}},
	{"moonshot", newMoonshotProvider, []string{"max_completion_tokens", "thinking"}},
	{"openrouter", newOpenRouterProvider, []string{"max_tokens", "reasoning"}},
	{"ollama", newOllamaProvider, []string{"think", "options"}},
	{"custom", newCustomProvider, nil},
}

// baseCompatKeys are the fields every family in this dialect sends. They are not knobs and are not
// listed per family. 本方言每一家都发的字段。它们不是旋钮,故不逐家列。
var baseCompatKeys = []string{"model", "messages", "stream", "stream_options", "tools"}

// TestCompat_NoFamilyLeaksAnotherFamilysKnobs is the price of the superset request body: every knob
// field lives on one struct, so "nobody sets it" is a claim about our code that only the WIRE can
// settle. This marshals a real request per family and reads the actual JSON keys.
//
// Without it, adding a knob for one provider could silently start sending it to all eight — the
// exact failure the old duplicated files made impossible by construction, and the one thing the
// merge had to buy back with a test.
//
// TestCompat_NoFamilyLeaksAnotherFamilysKnobs 是超集请求体的代价:每个旋钮字段都住在同一个 struct 上,
// 故「没人会设它」是关于**我们代码**的断言,而只有**线缆**能了断它。本测试逐家 marshal 一个真请求、
// 读**真实的** JSON key。
//
// 没有它,给某一家加一个旋钮可能会静默地对**八家**都发出去——那正是旧的重复文件**按构造**杜绝的失败,
// 也是合并必须用一个测试**买回来**的那一样东西。
func TestCompat_NoFamilyLeaksAnotherFamilysKnobs(t *testing.T) {
	// Every knob any family can set, so an unexpected key is recognised as a LEAK rather than
	// dismissed as unknown. 任一家能设的全部旋钮,使意外的 key 被认成**泄漏**、而不是当作不认识。
	allKnobs := map[string]bool{}
	for _, f := range compatFamilies {
		for _, k := range f.knobKeys {
			allKnobs[k] = true
		}
	}

	for _, f := range compatFamilies {
		t.Run(f.name, func(t *testing.T) {
			// A request that turns on EVERY knob any family understands. A family that reads only its
			// own Options keys ignores the rest; a family that reads someone else's fails here.
			// 一个把**任一家**认得的旋钮全部打开的请求。只读自己 Options key 的家会无视其余;读了别人
			// 的那一家会在这里失败。
			req := Request{
				ModelID:   "m",
				Key:       "k",
				BaseURL:   "https://example.invalid/v1",
				Messages:  []LLMMessage{{Role: RoleUser, Content: "hi"}},
				Tools:     []ToolDef{{Name: "t", Description: "d", Parameters: json.RawMessage(`{"type":"object"}`)}},
				MaxTokens: 64,
				Options: map[string]string{
					"reasoning_effort": "high",
					"verbosity":        "low",
					"thinking":         "enabled",
					"enable_thinking":  "true",
					"thinking_budget":  "128",
					"think":            "true",
					"num_ctx":          "4096",
				},
			}
			httpReq, err := f.provider().BuildRequest(context.Background(), req)
			if err != nil {
				t.Fatal(err)
			}
			var body map[string]json.RawMessage
			if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
				t.Fatal(err)
			}
			allowed := append(slices.Clone(baseCompatKeys), f.knobKeys...)
			for _, k := range slices.Sorted(maps.Keys(body)) {
				if slices.Contains(allowed, k) {
					continue
				}
				if allKnobs[k] {
					t.Errorf("%s leaked another family's knob %q onto the wire", f.name, k)
					continue
				}
				t.Errorf("%s sent unexpected key %q — add it to the family's knobKeys if it is deliberate", f.name, k)
			}
			// The other direction: a knob listed but never sent is documentation that has drifted.
			// 另一个方向:列了却从不发的旋钮,是已经漂掉的文档。
			for _, k := range f.knobKeys {
				if _, ok := body[k]; !ok {
					t.Errorf("%s declares knob %q but never sends it", f.name, k)
				}
			}
		})
	}
}

// TestCompat_WireMaskMatchesTheEncoder pairs the two independent declarations about what a dialect
// can carry: the [partMask] the capability layer reads, and the encoder that actually writes parts.
// They were free to drift before — a mask promising video for a family whose encoder ignores it is
// a SILENT drop, which reaches the user as a model that "did not look at" a video it was never sent.
//
// TestCompat_WireMaskMatchesTheEncoder 把「一条方言能承载什么」的**两处独立声明**对起来:能力层读的
// [partMask],与真正写 part 的编码器。它们此前可以自由漂移——一个为「编码器根本不理会 video」的家承诺
// video 的掩码,是一次**静默丢弃**,而它抵达用户时是一个「没去看」一段**从没发给它**的视频的模型。
func TestCompat_WireMaskMatchesTheEncoder(t *testing.T) {
	for _, f := range compatFamilies {
		t.Run(f.name, func(t *testing.T) {
			p := f.provider()
			msg := LLMMessage{Role: RoleUser, Parts: []ContentPart{
				{Type: PartText, Text: "look"},
				{Type: PartImageURL, ImageURL: "data:image/png;base64,AAA="},
				{Type: PartVideoURL, VideoURL: "https://example.invalid/v.mp4"},
				{Type: PartInputAudio, MediaType: "audio/wav", Data: "AAA="},
				{Type: "file", Filename: "d.pdf", MediaType: "application/pdf", Data: "AAA="},
			}}
			// OpenAI's known vocabulary excludes video but includes input_audio for its gpt-audio
			// models; feed the encoder exactly the parts this family claims.
			if f.name == "openai" {
				msg.Parts = []ContentPart{msg.Parts[0], msg.Parts[1], msg.Parts[3], msg.Parts[4]}
			}
			cm, err := p.toMessage(msg)
			if err != nil {
				t.Fatal(err)
			}
			raw, _ := json.Marshal(cm)
			carried := string(raw)
			for _, tc := range []struct {
				kind    string
				claimed bool
				token   string
			}{
				{"image", p.spec.wire.image, "image"},
				{"video", p.spec.wire.video, "video_url"},
				{"audio", p.spec.wire.audio, "input_audio"},
				{"file", p.spec.wire.file, "\"file\""},
			} {
				got := strings.Contains(carried, tc.token)
				if tc.claimed && !got {
					t.Errorf("%s's partMask claims %s but the encoder never writes it: %s", f.name, tc.kind, carried)
				}
				if !tc.claimed && got {
					t.Errorf("%s writes %s that its partMask does not claim: %s", f.name, tc.kind, carried)
				}
			}
		})
	}
}
