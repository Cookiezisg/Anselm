// create.go — create_handler system tool: applies method-level ops to build
// a new Handler with auto-accepted v1, runs synchronous env install, and on
// failure enters the C2 LLM env-fix loop (up to 3 attempts). On loop success
// the fixed pending is auto-accepted to flip the active version, so the user
// sees a single ready handler (the failed v1 stays in version history).
// Per discussions/2026-05-12 §E (same shape as create_function).
//
// create.go —— create_handler 工具:method-level ops 建 v1 + 同步装 env;
// 失败时跑 env-fix loop(同 create_function 模式)。

package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	envfixpkg "github.com/sunweilin/forgify/backend/internal/pkg/envfix"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
)

type CreateHandler struct {
	svc     *handlerapp.Service
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
}

func (t *CreateHandler) Name() string { return "create_handler" }

func (t *CreateHandler) Description() string {
	return "Create a new handler by applying a sequence of method-level ops. " +
		"Common ops: set_meta (name + description), set_imports (top-level imports), " +
		"set_init (__init__ body), set_init_args_schema (one entry per init arg, " +
		"mark sensitive=true for secrets), add_method (one Python method spec + body), " +
		"set_dependencies. v1 is auto-accepted; user must configure init_args (via " +
		"update_handler_config) before call_handler can succeed. If the venv install " +
		"fails, an internal env-fix loop retries up to 3 times by asking the LLM to " +
		"revise the dependency list."
}

func (t *CreateHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"ops": {"type": "array", "items": {"type": "object"}, "description": "Method-level ops"},
			"changeReason": {"type": "string", "description": "One-line reason"}
		},
		"required": ["ops"]
	}`)
}

func (t *CreateHandler) IsReadOnly() bool        { return false }
func (t *CreateHandler) NeedsReadFirst() bool    { return false }
func (t *CreateHandler) RequiresWorkspace() bool { return false }

func (t *CreateHandler) ValidateInput(json.RawMessage) error { return nil }
func (t *CreateHandler) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *CreateHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_handler: bad args: %w", err)
	}
	ops, err := handlerapp.ParseOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("create_handler: %w", err)
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage": "applying ops", "count": len(ops),
	})
	defer em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	h, v, err := t.svc.Create(ctx, handlerapp.CreateInput{
		Ops:             ops,
		ChangeReason:    args.ChangeReason,
		ProgressBlockID: progID,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		return "", fmt.Errorf("create_handler: %w", err)
	}

	if v.EnvStatus == handlerdomain.EnvStatusReady {
		return marshalCreateOutput(h.ID, v.ID, v.Version, v.Status, v.EnvStatus, "", 1, nil, len(ops)), nil
	}

	bundle, bundleErr := llmclientpkg.Resolve(ctx, t.picker, t.keys, t.factory)
	if bundleErr != nil {
		em.DeltaBlock(ctx, progID, fmt.Sprintf("[Attempt 1] env install failed: %s\n", truncForUI(v.EnvError)))
		em.DeltaBlock(ctx, progID, fmt.Sprintf("env-fix loop unavailable: %v\n", bundleErr))
		return marshalCreateOutput(h.ID, v.ID, v.Version, v.Status, v.EnvStatus, v.EnvError, 1, nil, len(ops)), nil
	}

	result := envfixpkg.RunLoop(ctx, envfixpkg.Options{
		Bundle: bundle,
		InitialAttempt: envfixpkg.Attempt{
			Number:    1,
			Deps:      append([]string(nil), v.Dependencies...),
			EnvStatus: v.EnvStatus,
			EnvError:  v.EnvError,
		},
		MaxAttempts: envfixpkg.DefaultMaxAttempts,
		ApplyDeps: func(ctx context.Context, newDeps []string) (string, string, error) {
			depsOp, _ := json.Marshal(map[string]any{"deps": newDeps})
			editV, err := t.svc.Edit(ctx, handlerapp.EditInput{
				ID: h.ID,
				Ops: []handlerapp.Op{{
					Type: "set_dependencies",
					Raw:  depsOp,
				}},
				ChangeReason:    fmt.Sprintf("env-fix retry: %d deps", len(newDeps)),
				ProgressBlockID: progID,
			})
			if err != nil {
				return "", "", err
			}
			return editV.EnvStatus, editV.EnvError, nil
		},
		Hooks: envfixpkg.LoopHooks{
			OnFixing: func(ctx context.Context, attempt int) {
				em.DeltaBlock(ctx, progID, fmt.Sprintf("[Attempt %d] AI suggesting revised deps...\n", attempt))
			},
			OnAttemptResult: func(ctx context.Context, a envfixpkg.Attempt) {
				if a.EnvStatus == "ready" {
					em.DeltaBlock(ctx, progID, fmt.Sprintf("[Attempt %d] env ready ✓\n", a.Number))
				} else {
					em.DeltaBlock(ctx, progID, fmt.Sprintf("[Attempt %d] env failed: %s\n", a.Number, truncForUI(a.EnvError)))
				}
			},
		},
	})

	if result.FatalErr != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, result.FatalErr)
		return "", fmt.Errorf("create_handler: %w", result.FatalErr)
	}

	if result.FinalEnvStatus == handlerdomain.EnvStatusReady {
		acceptedV, acceptErr := t.svc.AcceptPending(ctx, h.ID)
		if acceptErr != nil && !errors.Is(acceptErr, handlerdomain.ErrPendingNotFound) {
			em.DeltaBlock(ctx, progID, fmt.Sprintf("[final] AcceptPending failed: %v\n", acceptErr))
			return marshalCreateOutput(h.ID, v.ID, v.Version, v.Status,
				"failed", acceptErr.Error(), result.AttemptsUsed, result.History, len(ops)), nil
		}
		if acceptedV != nil {
			v = acceptedV
		}
	}

	return marshalCreateOutput(h.ID, v.ID, v.Version, v.Status,
		result.FinalEnvStatus, result.FinalEnvError, result.AttemptsUsed, result.History, len(ops)), nil
}

// marshalCreateOutput is the single source of truth for the create_handler
// tool's wire shape (mirrors the function-side helper for consistency).
//
// marshalCreateOutput create_handler 工具线协议 — 跟 function 那侧同形。
func marshalCreateOutput(
	id, versionID string,
	versionN *int,
	status string,
	envStatus, envError string,
	attemptsUsed int,
	history []envfixpkg.Attempt,
	opsApplied int,
) string {
	out := map[string]any{
		"id":           id,
		"versionId":    versionID,
		"version":      versionN,
		"status":       status,
		"envStatus":    envStatus,
		"opsApplied":   opsApplied,
		"attemptsUsed": attemptsUsed,
		"note":         "Use update_handler_config to set init_args before call_handler.",
	}
	if envError != "" {
		out["envError"] = envError
	}
	if len(history) > 1 {
		out["attemptHistory"] = history
	}
	b, _ := json.Marshal(out)
	return string(b)
}

func truncForUI(s string) string {
	const max = 240
	if len(s) <= max {
		return s
	}
	return s[:max] + "…"
}
