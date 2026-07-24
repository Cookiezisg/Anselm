// Package model is the application layer for model capabilities and selection plumbing. It owns no
// store: it aggregates the model catalog by reading apikey's probe archives and parsing each via
// the provider's self-describing DescribeModels, then exposes "what models can I use, and how is
// each configured" to the frontend.
//
// Package model 是模型能力与选择管道的 app 层。它不持有 store：通过读 apikey 的探测档案、经各家
// provider 自描述的 DescribeModels 解析，聚合模型目录，向前端暴露「我能用哪些模型、每个怎么配」。
package model

import (
	"context"
	"strconv"
	"strings"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llmpkg "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// CapabilityView is one usable (key, model) pair with its capability specs and native configurable
// knobs — the unit the frontend renders for model selection. Knobs reuse the llm descriptor (its
// keys/values are native, never normalised), so there is no second copy of that shape here.
//
// CapabilityView 是一个可用的 (key, model) 对，带能力规格与原生可调旋钮——前端做模型选择渲染的
// 单元。Knobs 直接复用 llm 描述符（key/取值全原生、不归一），故此处不另造一份同形结构。
type CapabilityView struct {
	APIKeyID             string        `json:"apiKeyId"`
	KeyName              string        `json:"keyName"`
	Provider             string        `json:"provider"`
	ModelID              string        `json:"modelId"`
	DisplayName          string        `json:"displayName"`
	ContextWindow        int           `json:"contextWindow"`
	MaxOutput            int           `json:"maxOutput"`
	TextInputLimit       int           `json:"textInputLimit,omitempty"`
	MultimodalInputLimit int           `json:"multimodalInputLimit,omitempty"`
	Vision               bool          `json:"vision"`     // accepts image input natively / 原生接收图片
	Video                bool          `json:"video"`      // accepts native video input / 原生接收视频
	Audio                bool          `json:"audio"`      // accepts native audio input / 原生接收音频
	NativeDocs           bool          `json:"nativeDocs"` // accepts an inline document (PDF) natively / 原生接收内联文档(PDF)
	MaxMediaParts        int           `json:"maxMediaParts,omitempty"`
	MaxMediaBytes        int64         `json:"maxMediaBytes,omitempty"`
	Knobs                []llmpkg.Knob `json:"knobs"`
}

// CapabilityService aggregates the model catalog across a workspace's probed keys.
//
// CapabilityService 跨 workspace 已探测的 key 聚合模型目录。
type CapabilityService struct {
	probes apikeydomain.ProbeReader
	log    *zap.Logger
}

// NewCapabilityService wires the probe reader; panics on nil logger.
//
// NewCapabilityService 装配探测读取端口；nil logger panic。
func NewCapabilityService(probes apikeydomain.ProbeReader, log *zap.Logger) *CapabilityService {
	if log == nil {
		panic("model.NewCapabilityService: logger is nil")
	}
	return &CapabilityService{probes: probes, log: log.Named("modelcap")}
}

// List returns every usable (key, model) pair in the current workspace: for each live key, it parses
// that provider's probe archive into models (+ each model's native knobs). A key whose probe failed
// or whose body doesn't parse contributes nothing — capabilities reflect what's actually reachable,
// not merely what's been entered.
//
// List 返回当前 workspace 每个可用的 (key, model) 对：对每把活跃 key，把该 provider 的探测档案
// 解析成模型（+ 每个模型的原生旋钮）。探测失败或 body 解析不出的 key 不贡献——capabilities 反映
// 真正可达的，而非仅仅录入过的。
func (s *CapabilityService) List(ctx context.Context) ([]CapabilityView, error) {
	probed, err := s.probes.ListProbed(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]CapabilityView, 0)
	for _, pk := range probed {
		if pk.TestStatus != apikeydomain.TestStatusOK {
			continue
		}
		models, err := llmpkg.DescribeModels(pk.Provider, pk.TestResponse)
		if err != nil {
			// A single key's unparseable archive must not blank the whole catalog.
			// 单把 key 的档案解析不出，不该让整个目录变空。
			s.log.Warn("describe models failed",
				zap.String("api_key_id", pk.ID), zap.String("provider", pk.Provider), zap.Error(err))
			continue
		}
		for _, m := range models {
			out = append(out, CapabilityView{
				APIKeyID:             pk.ID,
				KeyName:              pk.DisplayName,
				Provider:             pk.Provider,
				ModelID:              m.ID,
				DisplayName:          m.DisplayName,
				ContextWindow:        m.ContextWindow,
				MaxOutput:            m.MaxOutput,
				TextInputLimit:       m.TextInputLimit,
				MultimodalInputLimit: m.MultimodalInputLimit,
				Vision:               m.Vision,
				Video:                m.Video,
				Audio:                m.Audio,
				NativeDocs:           m.NativeDocs,
				MaxMediaParts:        m.MaxMediaParts,
				MaxMediaBytes:        m.MaxMediaBytes,
				Knobs:                m.Knobs,
			})
		}
	}
	return out, nil
}

// ValidateOptions enforces the contract behind the generic settings picker before a ModelRef is
// persisted. Only values listed by the exact probed key/model pair may cross this boundary; the
// provider adapter consequently never has to silently ignore a user-visible setting. A model with
// no published knobs remains runnable with an empty options map, which keeps unprobed/custom
// models usable without pretending their native request schema is known.
//
// ValidateOptions 在 ModelRef 持久化前落实通用设置 picker 背后的契约。只有该精确已探测
// key/model 对列出的值可穿过这道边界，因此 provider adapter 无须静默忽略用户可见设置。没有公开
// knobs 的模型仍可带空 options 运行，既保留未探测/custom 模型可用性，也不假装知道其原生请求 schema。
func (s *CapabilityService) ValidateOptions(ctx context.Context, ref modeldomain.ModelRef) error {
	if len(ref.Options) == 0 {
		return nil
	}
	caps, err := s.List(ctx)
	if err != nil {
		return err
	}
	var cap *CapabilityView
	for i := range caps {
		if caps[i].APIKeyID == ref.APIKeyID && caps[i].ModelID == ref.ModelID {
			cap = &caps[i]
			break
		}
	}
	if cap == nil {
		return modeldomain.ErrOptionUnsupported
	}
	knobs := make(map[string]llmpkg.Knob, len(cap.Knobs))
	for _, knob := range cap.Knobs {
		knobs[knob.Key] = knob
	}
	for key, value := range ref.Options {
		knob, ok := knobs[key]
		if !ok || strings.TrimSpace(key) == "" {
			return modeldomain.ErrOptionUnsupported
		}
		if !validKnobValue(knob, value) {
			return modeldomain.ErrOptionValueInvalid
		}
	}
	return nil
}

func validKnobValue(knob llmpkg.Knob, value string) bool {
	switch knob.Type {
	case "enum":
		for _, allowed := range knob.Values {
			if value == allowed {
				return true
			}
		}
		return false
	case "bool":
		return value == "true" || value == "false"
	case "int":
		_, err := strconv.Atoi(value)
		return err == nil
	default:
		// A descriptor with an unknown control type must never become an implicit
		// passthrough. Publish a supported type first, then make it configurable.
		return false
	}
}
