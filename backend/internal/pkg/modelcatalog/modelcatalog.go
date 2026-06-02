// Package modelcatalog describes provider/model-native options and compiles
// saved option values into internal request knobs.
package modelcatalog

import (
	"strconv"
	"strings"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

const SafetyBuffer = 2000

type OptionValue struct {
	Value string `json:"value"`
	Label string `json:"label"`
}

type OptionDescriptor struct {
	Key          string        `json:"key"`
	Label        string        `json:"label"`
	Control      string        `json:"control"`
	Values       []OptionValue `json:"values,omitempty"`
	DefaultValue string        `json:"defaultValue,omitempty"`
}

type ModelDescriptor struct {
	Provider      string             `json:"provider"`
	ModelID       string             `json:"modelId"`
	DisplayName   string             `json:"displayName"`
	ContextWindow int                `json:"contextWindow"`
	MaxOutput     int                `json:"maxOutput"`
	Options       []OptionDescriptor `json:"options"`
}

type Capability struct {
	ContextWindow int
	MaxOutput     int
}

func (c Capability) UsableInput() int {
	u := c.ContextWindow - c.MaxOutput - SafetyBuffer
	if u < 1000 {
		u = 1000
	}
	return u
}

type ThinkingSpec struct {
	Mode   string
	Effort string
	Budget int
}

type CompileResult struct {
	ModelID    string
	Options    modeldomain.ModelOptions
	Thinking   *ThinkingSpec
	Capability Capability
}

type modelRule struct {
	provider      string
	prefix        string
	contextWindow int
	maxOutput     int
	options       []OptionDescriptor
}

func Describe(provider, modelID string) ModelDescriptor {
	p := normalize(provider)
	id := strings.TrimSpace(modelID)
	spec := Lookup(p, id)
	return ModelDescriptor{
		Provider:      p,
		ModelID:       id,
		DisplayName:   prettyModelName(id),
		ContextWindow: spec.ContextWindow,
		MaxOutput:     spec.MaxOutput,
		Options:       spec.Options,
	}
}

func DescribeModels(provider string, modelIDs []string) []ModelDescriptor {
	seen := map[string]bool{}
	out := make([]ModelDescriptor, 0, len(modelIDs))
	for _, id := range modelIDs {
		id = strings.TrimSpace(id)
		if id == "" || seen[id] {
			continue
		}
		seen[id] = true
		out = append(out, Describe(provider, id))
	}
	return out
}

func Compile(provider, modelID string, opts modeldomain.ModelOptions) CompileResult {
	p := normalize(provider)
	id := strings.TrimSpace(modelID)
	options := normalizeOptions(opts)
	cap := Lookup(p, id).Capability()
	if options["context"] == "1m" && p == "anthropic" {
		cap.ContextWindow = 1_000_000
	}
	return CompileResult{
		ModelID:    id,
		Options:    options,
		Thinking:   compileThinking(p, id, options),
		Capability: cap,
	}
}

func (m ModelDescriptor) Capability() Capability {
	return Capability{ContextWindow: m.ContextWindow, MaxOutput: m.MaxOutput}
}

func Lookup(provider, modelID string) ModelDescriptor {
	p := normalize(provider)
	id := strings.ToLower(strings.TrimSpace(modelID))
	for _, r := range modelRules {
		if r.provider != p {
			continue
		}
		if r.prefix == "" || strings.HasPrefix(id, r.prefix) {
			return ModelDescriptor{
				Provider:      p,
				ModelID:       strings.TrimSpace(modelID),
				DisplayName:   prettyModelName(strings.TrimSpace(modelID)),
				ContextWindow: r.contextWindow,
				MaxOutput:     r.maxOutput,
				Options:       cloneOptions(r.options),
			}
		}
	}
	return ModelDescriptor{
		Provider:      p,
		ModelID:       strings.TrimSpace(modelID),
		DisplayName:   prettyModelName(strings.TrimSpace(modelID)),
		ContextWindow: 32_768,
		MaxOutput:     8_192,
		Options:       nil,
	}
}

var modelRules = []modelRule{
	{"anthropic", "claude-opus-4-7", 1_000_000, 128_000, anthropicOptions()},
	{"anthropic", "claude-opus-4-8", 1_000_000, 128_000, anthropicOptions()},
	{"anthropic", "claude-opus-4-6", 1_000_000, 128_000, anthropicOptions()},
	{"anthropic", "claude-sonnet-4-6", 1_000_000, 64_000, anthropicOptions()},
	{"anthropic", "claude-sonnet-4", 200_000, 64_000, anthropicOptions()},
	{"anthropic", "claude-haiku-4", 200_000, 64_000, anthropicOptions()},
	{"anthropic", "claude-opus-4", 200_000, 64_000, anthropicOptions()},
	{"anthropic", "claude", 200_000, 32_000, anthropicOptions()},
	{"openai", "gpt-5.5", 1_000_000, 128_000, openAIOptions("medium", "none", "low", "medium", "high", "xhigh")},
	{"openai", "gpt-5.2", 400_000, 128_000, openAIOptions("medium", "none", "low", "medium", "high", "xhigh")},
	{"openai", "gpt-5.1", 400_000, 128_000, openAIOptions("medium", "none", "low", "medium", "high")},
	{"openai", "gpt-5", 400_000, 128_000, openAIOptions("medium", "none", "minimal", "low", "medium", "high")},
	{"openai", "o", 200_000, 100_000, openAIOptions("medium", "none", "low", "medium", "high")},
	{"openai", "gpt-4", 128_000, 16_000, nil},
	{"deepseek", "deepseek-v4", 1_000_000, 384_000, deepSeekOptions()},
	{"deepseek", "deepseek-reasoner", 128_000, 64_000, deepSeekOptions()},
	{"deepseek", "deepseek", 128_000, 64_000, nil},
	{"google", "gemini-3", 1_000_000, 64_000, geminiLevelOptions()},
	{"google", "gemini-2.5", 1_048_576, 65_536, geminiAutoOptions()},
	{"google", "gemini", 1_000_000, 64_000, geminiLevelOptions()},
	{"qwen", "qwen3-max", 262_144, 32_768, toggleOptions("on")},
	{"qwen", "qwen-long", 10_000_000, 32_768, nil},
	{"qwen", "qwen-turbo", 1_000_000, 16_384, toggleOptions("on")},
	{"qwen", "qwen", 1_000_000, 32_768, toggleOptions("on")},
	{"zhipu", "glm-4.6", 200_000, 128_000, toggleOptions("on")},
	{"zhipu", "glm-4.5", 131_072, 96_000, toggleOptions("on")},
	{"zhipu", "glm", 200_000, 128_000, toggleOptions("on")},
	{"moonshot", "kimi-k2-thinking", 262_144, 32_768, toggleOptions("on")},
	{"moonshot", "kimi-k2", 262_144, 32_768, toggleOptions("on")},
	{"moonshot", "moonshot-v1-128k", 131_072, 32_768, nil},
	{"moonshot", "moonshot-v1-32k", 32_768, 32_768, nil},
	{"moonshot", "moonshot-v1", 8_192, 32_768, nil},
	{"doubao", "doubao-seed-1-8", 256_000, 64_000, doubaoOptions()},
	{"doubao", "doubao-seed-2", 256_000, 64_000, doubaoOptions()},
	{"doubao", "doubao-seed-1-6", 256_000, 16_000, doubaoOptions()},
	{"doubao", "doubao", 256_000, 16_000, doubaoOptions()},
	{"openrouter", "", 128_000, 32_000, openRouterOptions()},
	{"ollama", "", 4_096, 0, ollamaOptions()},
}

func deepSeekOptions() []OptionDescriptor {
	return []OptionDescriptor{enum("thinking", "Thinking", "high", []OptionValue{
		{"off", "Off"},
		{"high", "High"},
		{"max", "Max"},
	})}
}

func openAIOptions(def string, values ...string) []OptionDescriptor {
	return []OptionDescriptor{enum("reasoning_effort", "Reasoning effort", def, optionValues(values...))}
}

func anthropicOptions() []OptionDescriptor {
	return []OptionDescriptor{
		enum("thinking", "Thinking", "off", []OptionValue{
			{"off", "Off"},
			{"on", "On"},
		}),
		enum("context", "Context", "200k", []OptionValue{
			{"200k", "200K"},
			{"1m", "1M"},
		}),
	}
}

func geminiLevelOptions() []OptionDescriptor {
	return []OptionDescriptor{enum("thinking", "Thinking", "medium", optionValues("minimal", "low", "medium", "high"))}
}

func geminiAutoOptions() []OptionDescriptor {
	return []OptionDescriptor{enum("thinking", "Thinking", "auto", []OptionValue{
		{"off", "Off"},
		{"auto", "Auto"},
	})}
}

func toggleOptions(def string) []OptionDescriptor {
	return []OptionDescriptor{enum("thinking", "Thinking", def, []OptionValue{
		{"off", "Off"},
		{"on", "On"},
	})}
}

func doubaoOptions() []OptionDescriptor {
	return []OptionDescriptor{enum("thinking", "Thinking", "auto", []OptionValue{
		{"auto", "Auto"},
		{"off", "Off"},
		{"on", "On"},
	})}
}

func openRouterOptions() []OptionDescriptor {
	return []OptionDescriptor{enum("reasoning", "Reasoning", "medium", []OptionValue{
		{"off", "Off"},
		{"low", "Low"},
		{"medium", "Medium"},
		{"high", "High"},
	})}
}

func ollamaOptions() []OptionDescriptor {
	return []OptionDescriptor{enum("thinking", "Thinking", "medium", []OptionValue{
		{"none", "None"},
		{"low", "Low"},
		{"medium", "Medium"},
		{"high", "High"},
	})}
}

func optionValues(values ...string) []OptionValue {
	out := make([]OptionValue, 0, len(values))
	for _, v := range values {
		out = append(out, OptionValue{Value: v, Label: prettyOptionLabel(v)})
	}
	return out
}

func cloneOptions(in []OptionDescriptor) []OptionDescriptor {
	if len(in) == 0 {
		return nil
	}
	out := make([]OptionDescriptor, len(in))
	copy(out, in)
	for i := range out {
		if len(out[i].Values) > 0 {
			out[i].Values = append([]OptionValue(nil), out[i].Values...)
		}
	}
	return out
}

func compileThinking(provider, modelID string, options modeldomain.ModelOptions) *ThinkingSpec {
	switch provider {
	case "deepseek":
		switch options["thinking"] {
		case "off", "disabled":
			return &ThinkingSpec{Mode: "off"}
		case "max":
			return &ThinkingSpec{Mode: "on", Effort: "max"}
		case "high", "":
			return &ThinkingSpec{Mode: "on", Effort: "high"}
		}
	case "openai":
		v := options["reasoning_effort"]
		if v == "" {
			return nil
		}
		if v == "none" || v == "off" {
			return &ThinkingSpec{Mode: "off"}
		}
		return &ThinkingSpec{Mode: "on", Effort: v}
	case "anthropic":
		switch options["thinking"] {
		case "on", "enabled":
			return &ThinkingSpec{Mode: "on"}
		case "off", "disabled":
			return &ThinkingSpec{Mode: "off"}
		}
	case "google":
		switch options["thinking"] {
		case "off":
			return &ThinkingSpec{Mode: "off"}
		case "auto":
			return &ThinkingSpec{Mode: "on", Budget: -1}
		case "minimal", "low", "medium", "high":
			return &ThinkingSpec{Mode: "on", Effort: options["thinking"]}
		}
	case "qwen":
		switch options["thinking"] {
		case "off":
			return &ThinkingSpec{Mode: "off"}
		case "on":
			return &ThinkingSpec{Mode: "on", Budget: intOption(options["thinking_budget"])}
		}
	case "zhipu", "moonshot":
		switch options["thinking"] {
		case "off":
			return &ThinkingSpec{Mode: "off"}
		case "on":
			return &ThinkingSpec{Mode: "on"}
		}
	case "doubao":
		switch options["thinking"] {
		case "off":
			return &ThinkingSpec{Mode: "off"}
		case "on":
			return &ThinkingSpec{Mode: "on"}
		}
	case "openrouter":
		switch options["reasoning"] {
		case "off":
			return &ThinkingSpec{Mode: "off"}
		case "low", "medium", "high":
			return &ThinkingSpec{Mode: "on", Effort: options["reasoning"]}
		}
	case "ollama":
		switch options["thinking"] {
		case "none", "off":
			return &ThinkingSpec{Mode: "off"}
		case "low", "medium", "high":
			return &ThinkingSpec{Mode: "on", Effort: options["thinking"]}
		}
	}
	_ = modelID
	return nil
}

func enum(key, label, def string, values []OptionValue) OptionDescriptor {
	return OptionDescriptor{Key: key, Label: label, Control: "segmented", Values: values, DefaultValue: def}
}

func normalizeOptions(in modeldomain.ModelOptions) modeldomain.ModelOptions {
	if len(in) == 0 {
		return nil
	}
	out := modeldomain.ModelOptions{}
	for k, v := range in {
		k = strings.ToLower(strings.TrimSpace(k))
		v = strings.ToLower(strings.TrimSpace(v))
		if k != "" && v != "" {
			out[k] = v
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func intOption(v string) int {
	n, _ := strconv.Atoi(v)
	return n
}

func normalize(s string) string {
	return strings.ToLower(strings.TrimSpace(s))
}

func prettyModelName(id string) string {
	parts := strings.FieldsFunc(id, func(r rune) bool { return r == '-' || r == '_' || r == ':' || r == '/' })
	for i, p := range parts {
		if p != "" {
			parts[i] = strings.ToUpper(p[:1]) + p[1:]
		}
	}
	name := strings.Join(parts, " ")
	if name == "" {
		return id
	}
	return name
}

func prettyOptionLabel(v string) string {
	if v == "xhigh" {
		return "X High"
	}
	return prettyModelName(v)
}
