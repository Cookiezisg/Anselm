package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"

	envfixapp "github.com/sunweilin/anselm/backend/internal/app/envfix"
	handlerapp "github.com/sunweilin/anselm/backend/internal/app/handler"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
)

// --- create_handler --------------------------------------------------------

type CreateHandler struct{ svc *handlerapp.Service }

func (t *CreateHandler) Name() string { return "create_handler" }

func (t *CreateHandler) Description() string {
	return `Build a new stateful handler (a Python class that stays resident across calls, so self.xxx persists — for DB connections, API sessions, caches). v1 takes effect immediately (no separate accept). Required ops: set_meta + at least one add_method. The class is assembled as HandlerImpl with __init__(self, ...initArgs), shutdown(self), and your methods.

IMPORTANT: this is a HANDLER, not a stateless function. Never emit the function ops set_code, set_inputs, or set_outputs; never emit set_methods or a whole class/code blob. Handler code is split into set_init/set_shutdown and add_method, with the complete method nested under the method key. For a one-method handler, use this shape exactly:
  {"ops":[{"op":"set_meta","name":"ping_handler"},{"op":"add_method","method":{"name":"ping","inputs":[],"outputs":[{"name":"pong","type":"boolean"}],"body":"return {\\"pong\\": true}","streaming":false}}]}

OP SHAPES:
  {"op":"set_meta", "name":"snake_case", "description":"one line", "tags":["..."]}
  {"op":"set_imports", "imports":"import requests"}
  {"op":"set_init", "initBody":"self.session = requests.Session()"}     — __init__ body (after init args)
  {"op":"set_shutdown", "shutdownBody":"self.session.close()"}          — cleanup on stop/restart
  {"op":"set_init_args_schema", "args":[{"name":"api_key","type":"string","required":true,"sensitive":true}]}
  {"op":"add_method", "method":{"name":"fetch","inputs":[{"name":"url","type":"string"}],"outputs":[{"name":"body","type":"object"}],"body":"return self.session.get(url).json()","streaming":false,"timeout":30000}}
  {"op":"update_method", "name":"fetch", "patch":{"description":"..."}}  — RFC 7396 merge patch
  {"op":"delete_method", "name":"fetch"}
  {"op":"set_dependencies", "dependencies":["requests==2.31"]}
  {"op":"set_python_version", "version":"3.12"}

init_args (secrets like api_key) are NOT set here — the user fills them via the config; mark sensitive:true to encrypt at rest. A method's optional "timeout" (ms) bounds that one call's wall clock; omit it and the call falls back to the global handler-call default — set a tighter timeout for a method that could hang (a slow/blocking call holds the resident instance's serial pipe for its whole duration). A streaming method body yields {"progress": ...} items to stream progress; its call result is then either the last NON-progress value it yields OR its return-statement value (both honored — a bare return is NOT dropped). The instance starts once config is complete; failed dependency installs auto-fix (≤3) with an LLM.

The ops value should be a JSON array. For hosted-model compatibility, an exact JSON-encoded array string is also accepted; malformed strings, objects, and non-array values are rejected.`
}

func (t *CreateHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["ops"],
		"properties": {
			"ops": {"type": "array", "description": "HANDLER ops only: set_meta, set_imports, set_init, set_shutdown, set_init_args_schema, add_method, update_method, delete_method, set_dependencies, set_python_version. Never use function set_code/set_inputs/set_outputs, set_methods, or a whole class code blob. add_method must nest its complete MethodSpec under method.", "items": {"type": "object"}},
			"changeReason": {"type": "string", "description": "One-line reason for this creation."}
		}
	}`)
}

// decodeHandlerOps accepts the declared array shape and the exact JSON-encoded
// array form emitted by some hosted models. Keeping this compatibility here
// lets ValidateInput and Execute enforce the same boundary.
func decodeHandlerOps(raw json.RawMessage) ([]json.RawMessage, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}

	var ops []json.RawMessage
	switch raw[0] {
	case '[':
		if err := json.Unmarshal(raw, &ops); err != nil {
			return nil, fmt.Errorf("ops must be a JSON array: %w", err)
		}
	case '"':
		var encoded string
		if err := json.Unmarshal(raw, &encoded); err != nil {
			return nil, fmt.Errorf("ops must be a JSON array or an exact JSON-encoded array: %w", err)
		}
		encoded = string(bytes.TrimSpace([]byte(encoded)))
		if len(encoded) == 0 || encoded[0] != '[' {
			return nil, fmt.Errorf("ops string must contain a JSON array")
		}
		if err := json.Unmarshal([]byte(encoded), &ops); err != nil {
			return nil, fmt.Errorf("ops string must contain a valid JSON array: %w", err)
		}
	default:
		return nil, fmt.Errorf("ops must be a JSON array or an exact JSON-encoded array")
	}
	return ops, nil
}

func parseHandlerOps(raw json.RawMessage) ([]handlerapp.Op, error) {
	items, err := decodeHandlerOps(raw)
	if err != nil {
		return nil, err
	}
	if len(items) == 0 {
		return nil, nil
	}
	items, err = normalizeHandlerOps(items)
	if err != nil {
		return nil, err
	}
	normalized, err := json.Marshal(items)
	if err != nil {
		return nil, fmt.Errorf("ops normalization: %w", err)
	}
	return handlerapp.ParseOps(normalized)
}

// normalizeHandlerOps keeps the public update_method shape strict while
// repairing one deterministic hosted-model alias at the execution boundary.
// Models occasionally camel-case the op and emit method/methodName plus
// top-level patch fields; converting only the known fields avoids making
// arbitrary malformed ops valid.
func normalizeHandlerOps(items []json.RawMessage) ([]json.RawMessage, error) {
	return normalizeHandlerOpsWithExistingMethods(items, nil)
}

// normalizeHandlerOpsWithExistingMethods applies the same compatibility rules as the create path,
// but lets an edit distinguish a legacy full method list's existing methods from genuinely new ones.
// Older hosted models still emit set_methods while editing; treating every complete method as
// add_method produces a visible "already exists" tool failure before the model self-corrects.
func normalizeHandlerOpsWithExistingMethods(items []json.RawMessage, existingMethods map[string]struct{}) ([]json.RawMessage, error) {
	const opUpdateMethod = "update_method"
	patchFields := []string{"description", "body", "inputs", "outputs", "streaming", "timeout"}
	normalized := make([]json.RawMessage, 0, len(items))
	// A few older hosted models still emit a whole-class Function-shaped build for a
	// Handler. Know whether an explicit method list is present before translating
	// set_code, so the class parser can supply init/shutdown without duplicating the
	// later set_methods/add_method definitions.
	hasExplicitMethods := false
	hasLegacyMethodList := false
	hasLegacyClassCode := false
	legacyMethodsNeedClassMethods := false
	for _, item := range items {
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(item, &fields); err != nil {
			continue
		}
		op := handlerOpName(fields)
		switch op {
		case "add_method":
			hasExplicitMethods = true
		case "set_methods":
			hasLegacyMethodList = true
			if legacyMethodListNeedsClassMethods(fields) {
				legacyMethodsNeedClassMethods = true
			}
		case "set_code":
			hasLegacyClassCode = true
		}
	}
	for i, item := range items {
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(item, &fields); err != nil {
			return nil, fmt.Errorf("ops[%d] normalization: %w", i, err)
		}
		fields = canonicalizeLegacyDiscriminator(fields)
		canonicalItem, err := json.Marshal(fields)
		if err != nil {
			return nil, fmt.Errorf("ops[%d] discriminator normalization: %w", i, err)
		}
		item = canonicalItem
		includeLegacyClassMethods := !hasExplicitMethods && (!hasLegacyMethodList || legacyMethodsNeedClassMethods)
		if legacyOps, err := normalizeLegacyHandlerOp(fields, includeLegacyClassMethods, hasLegacyClassCode, legacyMethodsNeedClassMethods, existingMethods); err != nil {
			return nil, fmt.Errorf("ops[%d] legacy Handler compatibility: %w", i, err)
		} else if legacyOps != nil {
			normalized = append(normalized, legacyOps...)
			continue
		}
		var op string
		if err := json.Unmarshal(fields["op"], &op); err != nil {
			var kind string
			if kindErr := json.Unmarshal(fields["kind"], &kind); kindErr != nil || kind != "set_method" {
				normalized = append(normalized, item)
				continue
			}
			for key := range fields {
				if key != "kind" && key != "method" {
					return nil, fmt.Errorf("ops[%d] set_method unknown field %q", i, key)
				}
			}
			var method map[string]json.RawMessage
			if err := json.Unmarshal(fields["method"], &method); err != nil || method == nil {
				return nil, fmt.Errorf("ops[%d] set_method requires a method object", i)
			}
			for key := range method {
				allowed := key == "name"
				for _, patchKey := range patchFields {
					if key == patchKey {
						allowed = true
						break
					}
				}
				if !allowed {
					return nil, fmt.Errorf("ops[%d] set_method unknown method field %q", i, key)
				}
			}
			fields = map[string]json.RawMessage{"op": json.RawMessage(`"update_method"`)}
			for key, value := range method {
				fields[key] = value
			}
			op = opUpdateMethod
		}
		if op == "updateMethod" {
			op = opUpdateMethod
			fields["op"] = json.RawMessage(`"update_method"`)
		}
		if op != opUpdateMethod {
			normalized = append(normalized, item)
			continue
		}
		nameRaw, hasName := fields["name"]
		patchRaw, hasPatch := fields["patch"]
		if hasName && hasPatch {
			normalized = append(normalized, item)
			continue
		}
		allowed := map[string]bool{
			"op": true, "name": true, "patch": true, "method": true, "methodName": true,
			"description": true, "body": true, "inputs": true, "outputs": true,
			"streaming": true, "timeout": true,
		}
		for key := range fields {
			if !allowed[key] {
				return nil, fmt.Errorf("ops[%d] update_method unknown field %q", i, key)
			}
		}
		if !hasName {
			for _, alias := range []string{"method", "methodName"} {
				if candidate, ok := fields[alias]; ok {
					nameRaw, hasName = candidate, true
					break
				}
			}
		}
		if !hasName {
			return nil, fmt.Errorf("ops[%d] update_method requires name (or a known method alias)", i)
		}
		var name string
		if err := json.Unmarshal(nameRaw, &name); err != nil || name == "" {
			return nil, fmt.Errorf("ops[%d] update_method method alias must be a non-empty string", i)
		}
		if !hasPatch {
			patch := make(map[string]json.RawMessage)
			for _, key := range patchFields {
				if value, ok := fields[key]; ok {
					patch[key] = value
				}
			}
			if len(patch) == 0 {
				return nil, fmt.Errorf("ops[%d] update_method requires patch fields", i)
			}
			var err error
			patchRaw, err = json.Marshal(patch)
			if err != nil {
				return nil, fmt.Errorf("ops[%d] update_method patch normalization: %w", i, err)
			}
		}
		canonical := map[string]json.RawMessage{
			"op":    fields["op"],
			"name":  nameRaw,
			"patch": patchRaw,
		}
		value, err := json.Marshal(canonical)
		if err != nil {
			return nil, fmt.Errorf("ops[%d] update_method normalization: %w", i, err)
		}
		normalized = append(normalized, value)
	}
	return normalized, nil
}

func (t *CreateHandler) ValidateInput(args json.RawMessage) error {
	var a struct {
		Ops json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_handler: bad args: %w", err)
	}
	ops, err := decodeHandlerOps(a.Ops)
	if err != nil {
		return fmt.Errorf("create_handler: bad args: %w", err)
	}
	if len(ops) == 0 {
		return ErrOpsRequired
	}
	return nil
}

func (t *CreateHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_handler: bad args: %w", err)
	}
	ops, err := parseHandlerOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("create_handler: bad args: %w", err)
	}
	sink := newBuildSink(ctx)
	defer sink.Close()
	h, v, err := t.svc.Create(ctx, handlerapp.CreateInput{Ops: ops, ChangeReason: args.ChangeReason, Progress: sink})
	if err != nil {
		return "", fmt.Errorf("create_handler: %w", err)
	}
	// No runtimeState on create: a fresh handler does not spawn (it almost always needs config first),
	// so "not running" is expected here and would only be noise. The signal matters on EDIT, where a
	// broken change can brick a previously-running instance.
	// create 不报 runtimeState：新建 handler 不 spawn（几乎总要先配 config），此处"未运行"是预期、只会成噪声。
	return toolapp.ToJSON(buildOutput(h.ID, v, len(ops), sink.attempts, "", false)), nil
}

// --- edit_handler ----------------------------------------------------------

type EditHandler struct{ svc *handlerapp.Service }

func (t *EditHandler) Name() string { return "edit_handler" }

func (t *EditHandler) Description() string {
	return `Edit a handler: apply ops on top of its active version, producing a new version that takes effect immediately — the resident instance is restarted to load the new code (which WIPES in-memory state). EXCEPTION: a metadata-only edit (all ops are set_meta — just name/description/tags) does NOT mint a version or restart, so it preserves in-memory state; prefer it for pure renames.

OP SHAPES (exact): update_method MUST be {"op":"update_method","name":"place","patch":{"description":"..."}}. Use the top-level "name" field to select the existing method and put every changed method field inside the RFC 7396 "patch" object. Do NOT use "methodName" and do NOT put "description", "body", "inputs", or "outputs" beside "patch". Do NOT use set_methods for an edit; use update_method for an existing method and add_method only for a genuinely new method. Other op shapes are the same as create_handler: add_method nests its MethodSpec under "method"; set_meta uses name/description/tags; delete_method uses name.


If the user asks to rebuild or retry a failed Handler environment while keeping the code, dependencies, and config unchanged, call this tool with exactly {"handlerId":"...","ops":[]} — it applies no ops and mints no version. Do not substitute restart_handler: restart_handler only resets a resident process and never rebuilds or reinstalls an environment. Empty ops rebuilds the environment and attempts to restart the resident instance, which WIPES in-memory state when the restart succeeds (the result carries restarted:true only when runtimeState is "running"). The result includes runtimeState: if it is not "running" after an edit, the new version failed to spawn (broken __init__, missing config, or environment failure) — call get_handler for details, fix the code, or revert_handler to the last good version. Use revert_handler to switch to an older version, and restart_handler only to reset a misbehaving resident instance.`
}

func (t *EditHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId", "ops"],
		"properties": {
			"handlerId": {"type": "string"},
			"ops": {"type": "array", "description": "Build ops. Empty array = rebuild the environment and attempt a resident restart, with no ops applied and no new version. Use this exact empty array to retry a failed environment without changing the handler definition; do not use restart_handler for that case. For update_method use {op, name, patch}; name selects the existing method and patch is the RFC 7396 object. Do not use methodName, set_methods, or top-level method fields; use add_method only for a new method.", "items": {"type": "object"}},
			"changeReason": {"type": "string", "description": "One-line reason for this edit."}
		}
	}`)
}

func (t *EditHandler) ValidateInput(args json.RawMessage) error {
	var a struct {
		HandlerID string          `json:"handlerId"`
		Ops       json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("edit_handler: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	if _, err := decodeHandlerOps(a.Ops); err != nil {
		return fmt.Errorf("edit_handler: bad args: %w", err)
	}
	return nil
}

func (t *EditHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		HandlerID    string          `json:"handlerId"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_handler: bad args: %w", err)
	}
	var ops []handlerapp.Op
	if len(bytes.TrimSpace(args.Ops)) > 0 && !bytes.Equal(bytes.TrimSpace(args.Ops), []byte("null")) {
		// Legacy hosted models sometimes send a complete `set_methods` list for an edit. Resolve the
		// active method names first so the compatibility layer can map existing methods to
		// update_method instead of issuing a real add_method failure and making the user watch a red
		// retry card before the model corrects itself.
		current, gerr := t.svc.Get(ctx, args.HandlerID)
		if gerr != nil {
			return "", fmt.Errorf("edit_handler: %w", gerr)
		}
		existingMethods := make(map[string]struct{})
		if current.ActiveVersion != nil {
			for _, method := range current.ActiveVersion.Methods {
				existingMethods[method.Name] = struct{}{}
			}
		}
		items, derr := decodeHandlerOps(args.Ops)
		if derr != nil {
			return "", fmt.Errorf("edit_handler: bad args: %w", derr)
		}
		parsed, perr := parseHandlerOpsWithExistingMethods(items, existingMethods)
		if perr != nil {
			return "", fmt.Errorf("edit_handler: bad args: %w", perr)
		}
		ops = parsed
	}
	sink := newBuildSink(ctx)
	defer sink.Close()
	v, err := t.svc.Edit(ctx, handlerapp.EditInput{ID: args.HandlerID, Ops: ops, ChangeReason: args.ChangeReason, Progress: sink})
	if err != nil {
		return "", fmt.Errorf("edit_handler: %w", err)
	}
	// Surface the post-edit runtime state: a broken __init__ (or other spawn failure) builds the env
	// fine (envStatus=ready) but fails to start the resident instance — the restart error is swallowed,
	// so without this the agent reads a "successful" edit and never learns it bricked the handler
	// (F-handler-broken-init-outage). runtimeState != running after a code edit → fix the code or revert.
	// 上呈编辑后的运行态：坏 __init__（或别的 spawn 失败）env 照样 ready、却起不了常驻实例——restart 错误被吞，
	// 没有这里 agent 读到"成功"编辑、永远不知 handler 已 brick。runtimeState != running → 改代码或 revert。
	runtimeState := ""
	if h, gerr := t.svc.Get(ctx, args.HandlerID); gerr == nil {
		runtimeState = h.RuntimeState
	}
	// Empty ops is the env-rebuild + restart path (no ops, no version) — flag the resulting state wipe.
	return toolapp.ToJSON(buildOutput(args.HandlerID, v, len(ops), sink.attempts, runtimeState, len(ops) == 0 && runtimeState == handlerdomain.RuntimeStateRunning)), nil
}

func parseHandlerOpsWithExistingMethods(items []json.RawMessage, existingMethods map[string]struct{}) ([]handlerapp.Op, error) {
	if len(items) == 0 {
		return nil, nil
	}
	normalized, err := normalizeHandlerOpsWithExistingMethods(items, existingMethods)
	if err != nil {
		return nil, err
	}
	encoded, err := json.Marshal(normalized)
	if err != nil {
		return nil, fmt.Errorf("ops normalization: %w", err)
	}
	return handlerapp.ParseOps(encoded)
}

func buildOutput(handlerID string, v *handlerdomain.Version, opsApplied int, attempts []envfixapp.Attempt, runtimeState string, restarted bool) map[string]any {
	out := map[string]any{
		"id":         handlerID,
		"versionId":  v.ID,
		"version":    v.Version,
		"envStatus":  v.EnvStatus,
		"opsApplied": opsApplied,
	}
	// An empty-ops edit_handler rebuilds the env and RESTARTS the resident instance but applies no ops
	// and mints no version — so opsApplied:0 + an unchanged version reads like a no-op while the restart
	// WIPED in-memory state. Signal the restart so a stateful handler's state loss is visible, not silent.
	// 空 ops 的 edit_handler 重建 env 并重启常驻实例、却不应用 op、不铸版本——故 opsApplied:0 + 版本不变读着像
	// no-op，而重启已抹掉内存态。显式上呈重启，使有状态 handler 的态丢失可见、非静默。
	if restarted {
		out["restarted"] = true
		out["restartNote"] = "rebuilt the environment and restarted the resident instance — in-memory state was wiped (no ops applied, no new version). If you only meant to reset a misbehaving instance, restart_handler does the same; a no-op was not intended here."
	}
	if v.EnvError != "" {
		out["envError"] = v.EnvError
	}
	if runtimeState != "" {
		out["runtimeState"] = runtimeState
		// A non-running instance after an edit means the new code/config didn't come up (broken
		// __init__, missing config, env not ready) — the env can be "ready" yet the handler unusable.
		if runtimeState != handlerdomain.RuntimeStateRunning {
			out["runtimeWarning"] = "the resident instance is not running after this edit — the new version may have a broken __init__ or need config; call get_handler for crash/config details, fix the code, or revert_handler to the last good version"
		}
	}
	if len(attempts) > 1 {
		out["envFixAttempts"] = attempts
	}
	return out
}
