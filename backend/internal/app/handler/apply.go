// apply.go — method-level ops engine for Handler pending-version authoring.
// Per spec D15, ops are method-level (vs Function's whole-file ops):
//
//   set_meta              — name/description/tags
//   set_imports           — class top-level imports
//   set_init              — __init__ body
//   set_shutdown          — shutdown body (optional, no-op default)
//   set_init_args_schema  — list of InitArgSpec
//   add_method            — append a MethodSpec (name unique)
//   update_method         — JSON Merge Patch (RFC 7396) on existing method
//   delete_method         — remove by name
//   set_dependencies      — PEP 508 deps list
//   set_python_version    — PEP 440 spec
//
// LLM emits []Op, Service.ApplyOps runs each in order with per-op + final
// validation. One progress block delta is emitted per op via the eventlog
// Emitter in ctx (no-op if no progress block ID).
//
// apply.go —— Handler pending 版本编辑的 method-level ops 引擎(D15)。
// LLM 发 []Op,Service.ApplyOps 按序应用 + per-op/final 校验,每 op emit 1
// progress delta。

package handler

import (
	"context"
	"encoding/json"
	"fmt"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
)

// Op is a discriminated union encoded as JSON. Type is the discriminator;
// Raw holds the full body so each op handler self-decodes (consistent with
// functionapp.Op).
//
// Op JSON 判别 union。Type 判别;Raw 存完整 body 各 op handler 自取(跟 function 一致)。
type Op struct {
	Type string          `json:"op"`
	Raw  json.RawMessage `json:"-"`
}

// VersionDraft is the accumulated mutable snapshot during ops apply. After
// final validation, fields copy onto a persisted Version row.
//
// VersionDraft 是 ops 应用过程中的可变快照;final 通过后拷到 Version 行。
type VersionDraft struct {
	Name           string
	Description    string
	Tags           []string
	Imports        string
	InitBody       string
	ShutdownBody   string
	Methods        []handlerdomain.MethodSpec
	InitArgsSchema []handlerdomain.InitArgSpec
	Dependencies   []string
	PythonVersion  string
}

// OpResult is the per-op outcome surfaced back to the LLM via tool result.
//
// OpResult 是单 op 应用结果,经 tool result 返 LLM。
type OpResult struct {
	Index int    `json:"index"`
	Type  string `json:"type"`
	OK    bool   `json:"ok"`
}

// ApplyOps applies a series of ops to a base draft (nil = fresh draft).
// Emits one progress delta per op via the eventlog Emitter in ctx.
//
// Per-op apply errors wrap ErrOpInvalid (400 FUNCTION_OP_INVALID-style);
// final-validation errors wrap ErrASTParseError. Sentinel mapping happens
// at handler/errmap, but we wrap here so errors.Is in the upper layers
// matches without inspecting the message.
//
// ApplyOps 把 ops 应用到 base draft(nil = 空);per op 1 progress delta;
// per-op 错误包 ErrOpInvalid,final 错误包 ErrASTParseError。
func (s *Service) ApplyOps(ctx context.Context, base *VersionDraft, ops []Op, progressBlockID string) (*VersionDraft, []OpResult, error) {
	state := cloneDraft(base)
	results := make([]OpResult, 0, len(ops))
	em := eventlogpkg.From(ctx)

	for i, op := range ops {
		if err := applyOne(state, op); err != nil {
			return nil, results, fmt.Errorf("handlerapp.ApplyOps: ops[%d] type=%q: %w: %v",
				i, op.Type, handlerdomain.ErrOpInvalid, err)
		}
		if err := validateIncremental(state); err != nil {
			return nil, results, fmt.Errorf("handlerapp.ApplyOps: ops[%d] left state invalid: %w: %v",
				i, handlerdomain.ErrOpInvalid, err)
		}
		results = append(results, OpResult{Index: i, Type: op.Type, OK: true})
		if em != nil && progressBlockID != "" {
			payload, _ := json.Marshal(map[string]any{"op": op.Type, "index": i})
			em.DeltaBlock(ctx, progressBlockID, string(payload)+"\n")
		}
	}
	if err := validateFinal(state); err != nil {
		return nil, results, fmt.Errorf("handlerapp.ApplyOps: final validation: %w: %v",
			handlerdomain.ErrASTParseError, err)
	}
	return state, results, nil
}

// ParseOps decodes the LLM wire format into []Op. Mirrors functionapp.ParseOps.
//
// ParseOps 把 LLM wire 格式解为 []Op(跟 functionapp.ParseOps 同)。
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

// applyOne mutates state per a single op.
//
// applyOne 单 op 应用到 state。
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

	case "set_imports":
		var p struct {
			Imports string `json:"imports"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_imports unmarshal: %w", err)
		}
		state.Imports = p.Imports

	case "set_init":
		var p struct {
			InitBody string `json:"init_body"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_init unmarshal: %w", err)
		}
		state.InitBody = p.InitBody

	case "set_shutdown":
		var p struct {
			ShutdownBody string `json:"shutdown_body"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_shutdown unmarshal: %w", err)
		}
		state.ShutdownBody = p.ShutdownBody

	case "set_init_args_schema":
		var p struct {
			Args []handlerdomain.InitArgSpec `json:"args"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("set_init_args_schema unmarshal: %w", err)
		}
		state.InitArgsSchema = p.Args

	case "add_method":
		var p struct {
			Method handlerdomain.MethodSpec `json:"method"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("add_method unmarshal: %w", err)
		}
		if p.Method.Name == "" {
			return fmt.Errorf("add_method: method.name required")
		}
		for _, m := range state.Methods {
			if m.Name == p.Method.Name {
				return fmt.Errorf("add_method: method %q already exists", p.Method.Name)
			}
		}
		state.Methods = append(state.Methods, p.Method)

	case "update_method":
		var p struct {
			Name  string          `json:"name"`
			Patch json.RawMessage `json:"patch"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("update_method unmarshal: %w", err)
		}
		idx := findMethodIdx(state.Methods, p.Name)
		if idx < 0 {
			return fmt.Errorf("update_method: method %q not found", p.Name)
		}
		merged, err := mergeMethodPatch(state.Methods[idx], p.Patch)
		if err != nil {
			return fmt.Errorf("update_method: %w", err)
		}
		state.Methods[idx] = merged

	case "delete_method":
		var p struct {
			Name string `json:"name"`
		}
		if err := json.Unmarshal(op.Raw, &p); err != nil {
			return fmt.Errorf("delete_method unmarshal: %w", err)
		}
		idx := findMethodIdx(state.Methods, p.Name)
		if idx < 0 {
			return fmt.Errorf("delete_method: method %q not found", p.Name)
		}
		state.Methods = append(state.Methods[:idx], state.Methods[idx+1:]...)

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

// findMethodIdx returns the index of a method by name, or -1.
//
// findMethodIdx 按 name 找 method 索引;无则 -1。
func findMethodIdx(methods []handlerdomain.MethodSpec, name string) int {
	for i, m := range methods {
		if m.Name == name {
			return i
		}
	}
	return -1
}

// mergeMethodPatch applies a JSON Merge Patch (RFC 7396) to one MethodSpec.
// Round-trip via JSON for the merge: marshal target → merge with patch → unmarshal.
//
// mergeMethodPatch 对 MethodSpec 应用 JSON Merge Patch(RFC 7396)。
// JSON round-trip 实现:marshal target → 合并 patch → unmarshal。
func mergeMethodPatch(target handlerdomain.MethodSpec, patch json.RawMessage) (handlerdomain.MethodSpec, error) {
	// 1. Marshal target to a generic map.
	rawTarget, err := json.Marshal(target)
	if err != nil {
		return target, fmt.Errorf("marshal target: %w", err)
	}
	var targetMap map[string]any
	if err := json.Unmarshal(rawTarget, &targetMap); err != nil {
		return target, fmt.Errorf("target → map: %w", err)
	}

	// 2. Unmarshal patch as a map.
	var patchMap map[string]any
	if err := json.Unmarshal(patch, &patchMap); err != nil {
		return target, fmt.Errorf("patch unmarshal: %w", err)
	}

	// 3. Apply per RFC 7396: patch values overwrite; nil deletes the key.
	mergedMap := mergePatch(targetMap, patchMap)

	// 4. Round-trip back to MethodSpec.
	rawMerged, err := json.Marshal(mergedMap)
	if err != nil {
		return target, fmt.Errorf("marshal merged: %w", err)
	}
	var merged handlerdomain.MethodSpec
	if err := json.Unmarshal(rawMerged, &merged); err != nil {
		return target, fmt.Errorf("merged → MethodSpec: %w", err)
	}
	return merged, nil
}

// mergePatch implements RFC 7396 — patch values overwrite recursively; nil
// values in patch delete the target key.
//
// mergePatch 实现 RFC 7396 — patch 值覆盖(递归);nil 值删 target 键。
func mergePatch(target, patch map[string]any) map[string]any {
	if target == nil {
		target = map[string]any{}
	}
	for k, v := range patch {
		if v == nil {
			delete(target, k)
			continue
		}
		if patchSub, ok := v.(map[string]any); ok {
			if targetSub, ok := target[k].(map[string]any); ok {
				target[k] = mergePatch(targetSub, patchSub)
				continue
			}
		}
		target[k] = v
	}
	return target
}

// cloneDraft deep-copies a VersionDraft so ApplyOps can mutate without
// affecting caller's base.
//
// cloneDraft 深拷贝 VersionDraft。
func cloneDraft(d *VersionDraft) *VersionDraft {
	if d == nil {
		return &VersionDraft{}
	}
	out := *d
	out.Tags = append([]string(nil), d.Tags...)
	out.Methods = append([]handlerdomain.MethodSpec(nil), d.Methods...)
	out.InitArgsSchema = append([]handlerdomain.InitArgSpec(nil), d.InitArgsSchema...)
	out.Dependencies = append([]string(nil), d.Dependencies...)
	return &out
}
