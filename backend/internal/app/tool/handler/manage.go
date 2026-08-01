package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	handlerapp "github.com/sunweilin/anselm/backend/internal/app/handler"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// --- revert_handler --------------------------------------------------------

type RevertHandler struct{ svc *handlerapp.Service }

// revertHandlerArgs preserves the public integer schema while accepting the exact
// integer-string encoding emitted by some hosted models. No other coercion is allowed.
type revertHandlerArgs struct {
	HandlerID string
	Version   int
}

func (a *revertHandlerArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		HandlerID string          `json:"handlerId"`
		Version   json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	version, err := decodeRevertVersion(raw.Version)
	if err != nil {
		return fmt.Errorf("version: %w", err)
	}
	*a = revertHandlerArgs{HandlerID: raw.HandlerID, Version: version}
	return nil
}

func decodeRevertVersion(raw json.RawMessage) (int, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be integer, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be integer, got %q", text)
	}
	return value, nil
}

func (t *RevertHandler) Name() string { return "revert_handler" }

func (t *RevertHandler) Description() string {
	return "Switch a handler's active version to an existing version by number, then restart the resident instance to run it. Only moves the active pointer — newer versions stay in history. Note: name, description and tags are NOT versioned (they live on the handler), so a revert restores only the versioned snapshot (methods/code) and leaves name/description/tags unchanged — use update_handler_meta to also change those (without a restart)."
}

func (t *RevertHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId", "version"],
		"properties": {
			"handlerId": {"type": "string"},
			"version": {"type": "integer", "description": "The version number to make active."}
		}
	}`)
}

func (t *RevertHandler) ValidateInput(args json.RawMessage) error {
	var a revertHandlerArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("revert_handler: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	if a.Version <= 0 {
		return ErrVersionPositive
	}
	return nil
}

func (t *RevertHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args revertHandlerArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("revert_handler: bad args: %w", err)
	}
	v, err := t.svc.Revert(ctx, args.HandlerID, args.Version)
	if err != nil {
		return "", fmt.Errorf("revert_handler: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.HandlerID, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- delete_handler --------------------------------------------------------

type DeleteHandler struct {
	svc  *handlerapp.Service
	deps toolapp.DependentCounter
}

func (t *DeleteHandler) Name() string { return "delete_handler" }

func (t *DeleteHandler) Description() string {
	return "Delete a handler from the active product surface: stop its resident instance and soft-delete the handler row. Immutable versions remain available for audit, environments are destroyed best-effort, and relation edges are purged. The handler and its actions are not recoverable through the active API. The result reports which other entities referenced it (and may now fail) — to check dependents BEFORE deleting, use get_relations."
}

func (t *DeleteHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId"],
		"properties": {"handlerId": {"type": "string"}}
	}`)
}

func (t *DeleteHandler) ValidateInput(args json.RawMessage) error {
	var a struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_handler: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	return nil
}

func (t *DeleteHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("delete_handler: bad args: %w", err)
	}
	deps := toolapp.DependentRefs(ctx, t.deps, relationdomain.EntityKindHandler, args.HandlerID)
	if err := t.svc.Delete(ctx, args.HandlerID); err != nil {
		return "", fmt.Errorf("delete_handler: %w", err)
	}
	return toolapp.ToJSON(handlerDeleteResult(args.HandlerID, deps)), nil
}

// handlerDeleteResult keeps the destructive result honest and machine-readable: the active
// handler is gone, but immutable versions remain auditable and cleanup is best-effort.
func handlerDeleteResult(id string, deps []map[string]string) map[string]any {
	return toolapp.AnnotateDependents(map[string]any{
		"id":      id,
		"deleted": true,
		"retention": map[string]any{
			"handler":  "soft_deleted",
			"versions": "retained_for_audit",
			"sandbox":  "destroy_requested_best_effort",
			"actions":  "not_found",
		},
	}, deps)
}

// --- restart_handler -------------------------------------------------------

type RestartHandler struct{ svc *handlerapp.Service }

func (t *RestartHandler) Name() string { return "restart_handler" }

func (t *RestartHandler) Description() string {
	return "Restart a handler's resident process: gracefully shut down the running instance (runs shutdown()) and start a fresh one with the latest config + code. Use when a handler is misbehaving — a stale DB connection, an expired session, a wedged state. Returns the new runtime state."
}

func (t *RestartHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId"],
		"properties": {"handlerId": {"type": "string"}}
	}`)
}

func (t *RestartHandler) ValidateInput(args json.RawMessage) error {
	var a struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("restart_handler: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	return nil
}

func (t *RestartHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("restart_handler: bad args: %w", err)
	}
	state, err := t.svc.Restart(ctx, args.HandlerID)
	if err != nil {
		// Restart returns the (failed) state alongside the error — surface both.
		return toolapp.ToJSON(map[string]any{"id": args.HandlerID, "runtimeState": state, "error": err.Error()}), nil
	}
	return toolapp.ToJSON(map[string]any{"id": args.HandlerID, "runtimeState": state}), nil
}

// --- update_handler_config -------------------------------------------------

type UpdateHandlerConfig struct{ svc *handlerapp.Service }

type updateHandlerConfigArgs struct {
	HandlerID string            `json:"handlerId"`
	Config    toolapp.ObjectMap `json:"config"`
}

func (a *updateHandlerConfigArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		HandlerID string          `json:"handlerId"`
		Config    json.RawMessage `json:"config"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	if len(raw.Config) == 0 || string(raw.Config) == "null" {
		return fmt.Errorf("config: must be an object")
	}
	var config toolapp.ObjectMap
	if err := json.Unmarshal(raw.Config, &config); err != nil {
		return fmt.Errorf("config: %w", err)
	}
	*a = updateHandlerConfigArgs{HandlerID: raw.HandlerID, Config: config}
	return nil
}

func (t *UpdateHandlerConfig) Name() string { return "update_handler_config" }

func (t *UpdateHandlerConfig) Description() string {
	return "The only tool for changing a handler's init-args config (the values passed to __init__): pass a partial object (JSON Merge Patch), then the instance restarts to apply it. null deletes a key. Do NOT use call_handler or add a method field for config changes. For hosted-model compatibility, an exact JSON-encoded object string is also accepted, but arrays and malformed strings are rejected. Note: secret values (api keys, db strings) are normally filled by the user, not here — only set values you actually have."
}

func (t *UpdateHandlerConfig) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId", "config"],
		"properties": {
			"handlerId": {"type": "string"},
			"config": {"type": "object", "description": "Partial init-args config (merge patch); null deletes a key."}
		}
	}`)
}

func (t *UpdateHandlerConfig) ValidateInput(args json.RawMessage) error {
	var a updateHandlerConfigArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("update_handler_config: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	return nil
}

func (t *UpdateHandlerConfig) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args updateHandlerConfigArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("update_handler_config: bad args: %w", err)
	}
	if err := t.svc.UpdateConfig(ctx, args.HandlerID, args.Config); err != nil {
		return "", fmt.Errorf("update_handler_config: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.HandlerID, "configUpdated": true}), nil
}

// --- update_handler_meta ---------------------------------------------------

type UpdateHandlerMeta struct{ svc *handlerapp.Service }

func (t *UpdateHandlerMeta) Name() string { return "update_handler_meta" }

func (t *UpdateHandlerMeta) Description() string {
	return "Rename or re-describe a handler WITHOUT restarting it: patches name/description/tags on the handler row only — NO new version, NO restart — so the resident instance keeps running and its in-memory state (self.xxx) survives. This is the correct tool for a pure rename/redescribe. Do NOT reach for edit_handler to rename: a code edit restarts the instance and WIPES its state. Pass only the fields you want to change (omit the rest)."
}

func (t *UpdateHandlerMeta) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId"],
		"properties": {
			"handlerId": {"type": "string"},
			"name": {"type": "string", "description": "New name (lowercase alphanumeric + dashes/underscores, 1-64 chars)."},
			"description": {"type": "string"},
			"tags": {"type": "array", "items": {"type": "string"}}
		}
	}`)
}

func (t *UpdateHandlerMeta) ValidateInput(args json.RawMessage) error {
	var a struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("update_handler_meta: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	return nil
}

func (t *UpdateHandlerMeta) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		HandlerID   string    `json:"handlerId"`
		Name        *string   `json:"name"`
		Description *string   `json:"description"`
		Tags        *[]string `json:"tags"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("update_handler_meta: bad args: %w", err)
	}
	h, err := t.svc.UpdateMeta(ctx, handlerapp.UpdateMetaInput{ID: args.HandlerID, Name: args.Name, Description: args.Description, Tags: args.Tags})
	if err != nil {
		return "", fmt.Errorf("update_handler_meta: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": h.ID, "name": h.Name, "description": h.Description, "tags": h.Tags}), nil
}
