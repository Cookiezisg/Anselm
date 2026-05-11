// apply.go — ops engine for Function pending-version authoring.
//
// LLM emits a sequence of Ops (set_meta / set_code / set_parameters /
// set_return_schema / set_dependencies / set_python_version) and Service
// applies them in order to a VersionDraft, running per-op + cumulative +
// final validation. On success the resulting VersionDraft is persisted as
// a pending FunctionVersion; on per-op failure the partial draft is
// surfaced + index of the failing op (D5 — each trinity domain owns its
// own apply.go without reuse).
//
// apply.go —— Function pending 版本编辑的 ops 引擎。
//
// LLM 发一串 Op,Service 按序应用到 VersionDraft 上,每 op 跑 per-op +
// cumulative 校验,全部完成后跑 final 校验。成功则落库为 pending
// FunctionVersion;per-op 失败时返部分 draft + 失败索引(D5——每个 trinity
// 域各自维护 apply.go 不复用)。

package function

import (
	"context"
	"encoding/json"
	"fmt"

	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"

	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
)

// Op is a discriminated union encoded as JSON. LLM emits []Op, system applies
// each in order with per-op + cumulative + final validation. Type lives in the
// JSON `op` field; Raw holds the full body so each op handler self-decodes.
//
// Op 是判别式 union(JSON 序列化)。LLM 发 []Op,系统按序 apply,每 op 后跑
// per-op 校验,全部应用完跑 final 校验。Type 在 JSON `op` 字段;Raw 存完整
// body 让各 op handler 自取字段。
type Op struct {
	Type string          `json:"op"`
	Raw  json.RawMessage `json:"-"`
}

// VersionDraft is the in-memory snapshot accumulated during ops apply. After
// final validation passes, fields are copied onto a persisted FunctionVersion
// row by Service.CreatePending / Service.EditPending.
//
// VersionDraft 是 ops 应用过程中的可变快照(累积态)。final 校验通过后,
// 由 Service.CreatePending / EditPending 拷贝到持久化 FunctionVersion 行。
type VersionDraft struct {
	Name          string
	Description   string
	Tags          []string
	Code          string
	Parameters    []functiondomain.ParameterSpec
	ReturnSchema  map[string]any
	Dependencies  []string
	PythonVersion string
}

// OpResult is the per-op outcome surfaced back to the LLM via the tool result.
//
// OpResult 是单 op 应用结果,经 tool result 返给 LLM。
type OpResult struct {
	Index int    `json:"index"`
	Type  string `json:"type"`
	OK    bool   `json:"ok"`
}

// ApplyOps applies a series of ops to a base draft. Emits one progress delta
// per op via the eventlog Emitter in ctx (no-op if no progress block).
// Returns the final draft + per-op outcomes. On per-op or final validation
// failure, returns the partial draft (nil here, partial state internal) +
// the wrapped error.
//
// ApplyOps 把一组 ops 应用到 base 草稿上。每 op emit 一个 progress delta。
// 返最终 draft + per-op outcomes;失败时返 nil draft + 包装后错误。
func (s *Service) ApplyOps(ctx context.Context, base *VersionDraft, ops []Op, progressBlockID string) (*VersionDraft, []OpResult, error) {
	state := cloneDraft(base)
	results := make([]OpResult, 0, len(ops))
	em := eventlogpkg.From(ctx)

	for i, op := range ops {
		if err := applyOne(state, op); err != nil {
			return nil, results, fmt.Errorf("functionapp.ApplyOps: ops[%d] type=%q: %w: %v", i, op.Type, functiondomain.ErrOpInvalid, err)
		}
		if err := validateIncremental(state); err != nil {
			return nil, results, fmt.Errorf("functionapp.ApplyOps: ops[%d] left state invalid: %w: %v", i, functiondomain.ErrOpInvalid, err)
		}
		results = append(results, OpResult{Index: i, Type: op.Type, OK: true})
		if em != nil && progressBlockID != "" {
			payload, _ := json.Marshal(map[string]any{"op": op.Type, "index": i})
			em.DeltaBlock(ctx, progressBlockID, string(payload)+"\n")
		}
	}
	if err := validateFinal(state); err != nil {
		return nil, results, fmt.Errorf("functionapp.ApplyOps: final validation: %w: %v", functiondomain.ErrASTParseError, err)
	}
	return state, results, nil
}

// applyOne mutates state per a single op. Unknown op types are rejected.
//
// applyOne 单 op 应用到 state。未知 op 类型拒绝。
func applyOne(state *VersionDraft, op Op) error {
	switch op.Type {
	case "set_meta":
		var p struct {
			Name        *string  `json:"name,omitempty"`
			Description *string  `json:"description,omitempty"`
			Tags        []string `json:"tags,omitempty"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_meta unmarshal: %w", err)
		}
		if p.Name != nil {
			state.Name = *p.Name
		}
		if p.Description != nil {
			state.Description = *p.Description
		}
		if p.Tags != nil {
			state.Tags = p.Tags
		}
	case "set_code":
		var p struct {
			Code string `json:"code"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_code unmarshal: %w", err)
		}
		state.Code = p.Code
	case "set_parameters":
		var p struct {
			Parameters []functiondomain.ParameterSpec `json:"parameters"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_parameters unmarshal: %w", err)
		}
		state.Parameters = p.Parameters
	case "set_return_schema":
		var p struct {
			ReturnSchema map[string]any `json:"returnSchema"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_return_schema unmarshal: %w", err)
		}
		state.ReturnSchema = p.ReturnSchema
	case "set_dependencies":
		var p struct {
			Deps []string `json:"deps"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_dependencies unmarshal: %w", err)
		}
		state.Dependencies = p.Deps
	case "set_python_version":
		var p struct {
			Version string `json:"version"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_python_version unmarshal: %w", err)
		}
		state.PythonVersion = p.Version
	default:
		return fmt.Errorf("unknown op type: %q", op.Type)
	}
	return nil
}

// ParseOps decodes the wire format the LLM emits into []Op. Expects a JSON
// array of objects each with an `op` discriminator field and op-specific
// data fields. Each Op.Raw holds the full object body — apply handlers'
// inner unmarshal ignores the extra `op` field.
//
// ParseOps 把 LLM 发的线上格式解码为 []Op。期望 JSON 数组,每对象含 `op`
// 判别字段 + 各 op 特有字段。Op.Raw 存完整 object body——apply handler
// 内部 unmarshal 会忽略多余 `op` 字段。
func ParseOps(raw json.RawMessage) ([]Op, error) {
	var arr []json.RawMessage
	if err := json.Unmarshal(raw, &arr); err != nil {
		return nil, fmt.Errorf("ops array unmarshal: %w", err)
	}
	ops := make([]Op, 0, len(arr))
	for i, r := range arr {
		var disc struct {
			Op string `json:"op"`
		}
		if err := json.Unmarshal(r, &disc); err != nil {
			return nil, fmt.Errorf("ops[%d]: %w", i, err)
		}
		if disc.Op == "" {
			return nil, fmt.Errorf("ops[%d]: missing 'op' discriminator", i)
		}
		ops = append(ops, Op{Type: disc.Op, Raw: r})
	}
	return ops, nil
}

// cloneDraft deep-copies a VersionDraft so ApplyOps can mutate without
// affecting the caller's base. Nil input returns an empty draft.
//
// cloneDraft 深拷贝 VersionDraft,ApplyOps 改 state 不影响 caller 的 base。
// nil 入参返空 draft。
func cloneDraft(d *VersionDraft) *VersionDraft {
	if d == nil {
		return &VersionDraft{}
	}
	out := *d
	out.Tags = append([]string(nil), d.Tags...)
	out.Parameters = append([]functiondomain.ParameterSpec(nil), d.Parameters...)
	out.Dependencies = append([]string(nil), d.Dependencies...)
	if d.ReturnSchema != nil {
		out.ReturnSchema = make(map[string]any, len(d.ReturnSchema))
		for k, v := range d.ReturnSchema {
			out.ReturnSchema[k] = v
		}
	}
	return &out
}
