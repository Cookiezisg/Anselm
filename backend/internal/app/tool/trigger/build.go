package trigger

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	triggerapp "github.com/sunweilin/anselm/backend/internal/app/trigger"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// --- create_trigger --------------------------------------------------------

type CreateTrigger struct{ svc *triggerapp.Service }

func (t *CreateTrigger) Name() string { return "create_trigger" }

func (t *CreateTrigger) Description() string {
	return "Create a trigger — a signal source that fires the workflows listening to it. The trigger node's " +
		"result (what a downstream node reads by node id, e.g. start.path) IS the FIRE PAYLOAD listed per kind:\n" +
		"• cron — config.expression (5-field cron, e.g. \"0 9 * * *\"). Fire payload: {firedAt}. get_trigger returns a computed nextFireAt for cron triggers (the next scheduled fire), so read it instead of computing the schedule yourself.\n" +
		"• webhook — config.path is the mount SUBpath, NOT the full URL: callers POST to /api/v1/webhooks/{triggerId}/{config.path} (triggerId = the id THIS call returns). AUTH (optional, tell whoever wires the caller the EXACT header or signed POSTs get 401): config.secret with NO signatureAlgo = plain shared-secret, caller sends header `X-Webhook-Secret: <secret>` OR query `?token=<secret>`; config.secret + config.signatureAlgo \"hmac-sha256-hex\" = HMAC, caller sends header `X-Hub-Signature-256: sha256=<lowercase-hex hmac_sha256(rawBody, secret)>` (rename the header via config.signatureHeader). Fire payload: {firedAt, method, path, headers, body (the POSTed JSON, parsed) | bodyRaw (the raw string when the body is not JSON)}. IDEMPOTENCY (built-in): identical request bodies POSTed within the SAME wall-clock minute collapse to ONE firing per workflow (dedup key = hash(body) + minute-bucket), so a client/network retry of the same payload runs the workflow once; the same body in the next minute fires again, and a different body always fires.\n" +
		"• fsnotify — config.path (absolute dir/file to watch); optional config.events [create|modify|delete|rename|chmod] and config.pattern (glob). Fire payload: {firedAt, path, eventKind} — eventKind is one of those same lowercase tokens (combined events join with \"|\", e.g. \"create|modify\").\n" +
		"• sensor — periodically invokes a function/handler/mcp tool and fires when a CEL condition holds: config.targetKind (function|handler|mcp), config.targetId (must reference an EXISTING function/handler/mcp — a dangling target is rejected at create/edit), config.method (required for handler/mcp — the method/tool name), config.intervalSec (≥5), config.condition (CEL bool over `payload` = the return value), config.output (canonical form is a CEL string building the fire payload, e.g. `{\\\"total\\\": payload.total}`; for natural requests like 'emit total and healthy', an object map of field names to CEL expression strings is also accepted and normalized before validation). LEVEL-TRIGGERED: it fires on EVERY interval the condition holds, not just on a false→true flip — a sustained bad state keeps firing each poll (the listening workflow's concurrency policy bounds the overlap; the default `serial` queues them, so set `skip`/`buffer_one` if you only want one run at a time). There is no built-in edge-trigger/dedup; if you need fire-once-per-transition, track the prior state inside a handler's condition. For stateful/incremental probing bind a handler method (the resident process keeps its own cursor).\n" +
		"For hosted-model compatibility, config may be the native object or an exact JSON-encoded object string; arrays, scalar values, and malformed strings are rejected. A trigger only runs while an active workflow references it."
}

func (t *CreateTrigger) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name", "kind", "config"],
		"properties": {
			"name": {"type": "string", "description": "Unique display name."},
			"description": {"type": "string"},
			"kind": {"type": "string", "enum": ["cron", "webhook", "fsnotify", "sensor"]},
			"config": {"type": "object", "description": "Source-specific settings; see the tool description per kind. Native objects and exact JSON-encoded object strings are accepted; arrays, scalar values, and malformed strings are rejected. Sensor output accepts a CEL string or an object map of output field names to CEL expression strings; the map is normalized to a CEL object literal."},
			"outputs": {"type": "array", "description": "Declared payload fields delivered to listening workflows: each {name, type, description}. ONLY needed for sensor (describe what config.output emits); for cron/webhook/fsnotify it is set automatically from the kind's fixed fire payload and any value you pass is ignored.", "items": {"type": "object"}}
		}
	}`)
}

func (t *CreateTrigger) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
		Kind string `json:"kind"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_trigger: bad args: %w", err)
	}
	if a.Name == "" {
		return ErrNameRequired
	}
	if !triggerdomain.IsValidKind(a.Kind) {
		return triggerdomain.ErrInvalidKind
	}
	return nil
}

func (t *CreateTrigger) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name        string            `json:"name"`
		Description string            `json:"description"`
		Kind        string            `json:"kind"`
		Config      json.RawMessage   `json:"config"`
		Outputs     []schemapkg.Field `json:"outputs"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_trigger: bad args: %w", err)
	}
	config, err := decodeTriggerConfig(args.Config)
	if err != nil {
		return "", fmt.Errorf("create_trigger: bad args: %w", err)
	}
	if err := normalizeSensorOutput(args.Kind, config); err != nil {
		return "", fmt.Errorf("create_trigger: %w", err)
	}
	tr, err := t.svc.Create(ctx, triggerapp.CreateInput{
		Name: args.Name, Description: args.Description, Kind: args.Kind, Config: config, Outputs: args.Outputs,
	})
	if err != nil {
		return "", fmt.Errorf("create_trigger: %w", err)
	}
	return toolapp.ToJSON(tr), nil
}

// decodeTriggerConfig accepts the schema-correct object and the exact JSON-encoded object string
// emitted by some hosted models. It tolerates an encoding variant, not a different value: arrays,
// scalars, malformed strings, and null remain invalid for create; null/omission is returned as nil
// so edit can preserve its documented partial-update semantics.
//
// decodeTriggerConfig 接受 schema 规定的对象以及部分托管模型发出的「精确 JSON 编码对象字符串」。
// 它只容忍编码差异，不猜测错误值：数组、标量、坏字符串和 null 对 create 仍由 service 拒绝；
// 对 edit 返回 nil 以保留其“省略字段即不修改”的语义。
func decodeTriggerConfig(raw json.RawMessage) (map[string]any, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}

	var config map[string]any
	switch raw[0] {
	case '{':
		if err := json.Unmarshal(raw, &config); err != nil {
			return nil, fmt.Errorf("config must be a JSON object: %w", err)
		}
	case '"':
		var encoded string
		if err := json.Unmarshal(raw, &encoded); err != nil {
			return nil, fmt.Errorf("config must be a JSON object or an exact JSON-encoded object string: %w", err)
		}
		encodedBytes := bytes.TrimSpace([]byte(encoded))
		if len(encodedBytes) == 0 || encodedBytes[0] != '{' {
			return nil, fmt.Errorf("config string must contain a JSON object")
		}
		if err := json.Unmarshal(encodedBytes, &config); err != nil {
			return nil, fmt.Errorf("config string must contain a valid JSON object: %w", err)
		}
	default:
		return nil, fmt.Errorf("config must be a JSON object or an exact JSON-encoded object string")
	}
	return config, nil
}

// normalizeSensorOutput accepts the object-shaped shorthand models naturally produce for a
// request such as "emit total and healthy", while keeping the stored contract as one CEL string.
// normalizeSensorOutput 接受模型对「输出 total 与 healthy」自然生成的对象简写，但落盘契约仍是单个 CEL 字符串。
func normalizeSensorOutput(kind string, config map[string]any) error {
	if kind != triggerdomain.KindSensor || config == nil {
		return nil
	}
	output, ok := config["output"]
	if !ok {
		return nil
	}
	fields, ok := output.(map[string]any)
	if !ok {
		return nil
	}
	keys := make([]string, 0, len(fields))
	for key := range fields {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		expr, ok := fields[key].(string)
		if !ok || strings.TrimSpace(expr) == "" {
			return fmt.Errorf("sensor output field %q must be a non-empty CEL expression", key)
		}
		parts = append(parts, strconv.Quote(key)+": "+strings.TrimSpace(expr))
	}
	config["output"] = "{" + strings.Join(parts, ", ") + "}"
	return nil
}

// --- edit_trigger ----------------------------------------------------------

type EditTrigger struct{ svc *triggerapp.Service }

func (t *EditTrigger) Name() string { return "edit_trigger" }

func (t *EditTrigger) Description() string {
	return "Edit a trigger's name / description / config (kind is immutable — to change source kind, delete and recreate). If the trigger is currently live, the new config takes effect immediately. Pass only the fields you want to change. For hosted-model compatibility, config may be the native object or an exact JSON-encoded object string; arrays, scalar values, and malformed strings are rejected."
}

func (t *EditTrigger) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["triggerId"],
		"properties": {
			"triggerId": {"type": "string"},
			"name": {"type": "string"},
			"description": {"type": "string"},
			"config": {"type": "object", "description": "Full replacement config for the trigger's kind. Native objects and exact JSON-encoded object strings are accepted; arrays, scalar values, and malformed strings are rejected."},
			"outputs": {"type": "array", "description": "Declared payload fields delivered to workflows: each {name, type, description}. ONLY needed for sensor; for cron/webhook/fsnotify it is set automatically from the kind's fixed fire payload (any value passed is ignored).", "items": {"type": "object"}}
		}
	}`)
}

func (t *EditTrigger) ValidateInput(args json.RawMessage) error {
	var a struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("edit_trigger: bad args: %w", err)
	}
	if a.TriggerID == "" {
		return ErrTriggerIDRequired
	}
	return nil
}

func (t *EditTrigger) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		TriggerID   string            `json:"triggerId"`
		Name        *string           `json:"name"`
		Description *string           `json:"description"`
		Config      json.RawMessage   `json:"config"`
		Outputs     []schemapkg.Field `json:"outputs"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_trigger: bad args: %w", err)
	}
	config, err := decodeTriggerConfig(args.Config)
	if err != nil {
		return "", fmt.Errorf("edit_trigger: bad args: %w", err)
	}
	if config != nil {
		current, getErr := t.svc.Get(ctx, args.TriggerID)
		if getErr != nil {
			return "", fmt.Errorf("edit_trigger: %w", getErr)
		}
		if err := normalizeSensorOutput(current.Kind, config); err != nil {
			return "", fmt.Errorf("edit_trigger: %w", err)
		}
	}
	tr, err := t.svc.Edit(ctx, args.TriggerID, triggerapp.EditInput{
		Name: args.Name, Description: args.Description, Config: config, Outputs: args.Outputs,
	})
	if err != nil {
		return "", fmt.Errorf("edit_trigger: %w", err)
	}
	return toolapp.ToJSON(tr), nil
}

// --- delete_trigger --------------------------------------------------------

type DeleteTrigger struct {
	svc  *triggerapp.Service
	deps toolapp.DependentCounter
}

func (t *DeleteTrigger) Name() string { return "delete_trigger" }

func (t *DeleteTrigger) MinimumDanger() toolapp.DangerLevel { return toolapp.DangerDangerous }

func (t *DeleteTrigger) Description() string {
	return "This call is always dangerous and requires explicit user approval; never downgrade its danger field. Soft-delete a trigger from normal reads and stop its listener. The trigger primary row is NOT restorable: there is no restore operation. Existing activation and firing history remains readable for audit, but workflows that referenced this trigger stop receiving its signal and may fail capability checks. Relation edges are purged. Pass the required triggerId key; the result reports how many entities referenced it — check get_relations BEFORE deleting."
}

func (t *DeleteTrigger) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["triggerId"],
		"properties": {"triggerId": {"type": "string"}}
	}`)
}

func (t *DeleteTrigger) ValidateInput(args json.RawMessage) error {
	var a struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_trigger: bad args: %w", err)
	}
	if a.TriggerID == "" {
		return ErrTriggerIDRequired
	}
	return nil
}

func (t *DeleteTrigger) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("delete_trigger: bad args: %w", err)
	}
	deps := toolapp.DependentRefs(ctx, t.deps, relationdomain.EntityKindTrigger, args.TriggerID)
	if err := t.svc.Delete(ctx, args.TriggerID); err != nil {
		return "", fmt.Errorf("delete_trigger: %w", err)
	}
	return toolapp.ToJSON(toolapp.AnnotateDependents(map[string]any{"deleted": true, "triggerId": args.TriggerID}, deps)), nil
}
