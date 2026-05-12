// edit.go — edit_function system tool: applies a sequence of ops on top of
// the current pending (or active, when no pending) version. Iterate-same-
// pending semantics (D-redo-11): a second edit while a pending exists
// rewrites the same row instead of erroring with PendingConflict.
//
// On env install failure, enters the C2 env-fix loop: up to 3 attempts where
// the main-chat LLM revises the dependency list. Unlike create_function the
// tool does NOT auto-accept on success — Edit's contract is "leave a pending
// for the user to review", so the final tool result reports the pending and
// its terminal env state.
//
// edit.go —— edit_function 工具:在 pending(或 active 无 pending 时)之上应用
// ops;iterate-same-pending 不返冲突。env 装失败时跑 env-fix loop(同 create);
// 跟 create 不同的是不 auto-accept(Edit 契约是留 pending 给用户审)。

package function

import (
	"context"
	"encoding/json"
	"fmt"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	envfixpkg "github.com/sunweilin/forgify/backend/internal/pkg/envfix"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
)

type EditFunction struct {
	svc     *functionapp.Service
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
}

func (t *EditFunction) Name() string { return "edit_function" }

func (t *EditFunction) Description() string {
	return "Edit an existing function by applying a sequence of ops. Creates (or iterates) " +
		"a pending version. Pass ops=[] to force-rebuild the active version's env (D-redo-22). " +
		"If the venv install fails, an internal env-fix loop retries up to 3 times by asking " +
		"the LLM to revise the dependency list. The tool returns the pending version's " +
		"terminal state — the user reviews and accepts/rejects."
}

func (t *EditFunction) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"id": {"type": "string", "description": "Function ID to edit"},
			"ops": {
				"type": "array",
				"description": "Sequence of ops to apply (see create_function). Empty array forces env rebuild.",
				"items": {"type": "object"}
			},
			"changeReason": {"type": "string", "description": "One-line reason for this edit"}
		},
		"required": ["id", "ops"]
	}`)
}

func (t *EditFunction) IsReadOnly() bool        { return false }
func (t *EditFunction) NeedsReadFirst() bool    { return false }
func (t *EditFunction) RequiresWorkspace() bool { return false }

func (t *EditFunction) ValidateInput(json.RawMessage) error { return nil }
func (t *EditFunction) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *EditFunction) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID           string          `json:"id"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_function: bad args: %w", err)
	}
	if args.ID == "" {
		return "", fmt.Errorf("edit_function: id required")
	}
	ops, err := functionapp.ParseOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("edit_function: %w", err)
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage":      "applying ops",
		"count":      len(ops),
		"functionId": args.ID,
	})
	defer em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	v, err := t.svc.Edit(ctx, functionapp.EditInput{
		ID:              args.ID,
		Ops:             ops,
		ChangeReason:    args.ChangeReason,
		ProgressBlockID: progID,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		return "", fmt.Errorf("edit_function: %w", err)
	}

	if v.EnvStatus == functiondomain.EnvStatusReady {
		return marshalEditOutput(v.ID, v.EnvStatus, "", 1, nil, len(ops)), nil
	}

	bundle, bundleErr := llmclientpkg.Resolve(ctx, t.picker, t.keys, t.factory)
	if bundleErr != nil {
		em.DeltaBlock(ctx, progID, fmt.Sprintf("[Attempt 1] env install failed: %s\n", truncForUI(v.EnvError)))
		em.DeltaBlock(ctx, progID, fmt.Sprintf("env-fix loop unavailable: %v\n", bundleErr))
		return marshalEditOutput(v.ID, v.EnvStatus, v.EnvError, 1, nil, len(ops)), nil
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
			retryV, err := t.svc.Edit(ctx, functionapp.EditInput{
				ID: args.ID,
				Ops: []functionapp.Op{{
					Type: "set_dependencies",
					Raw:  depsOp,
				}},
				ChangeReason:    fmt.Sprintf("env-fix retry: %d deps", len(newDeps)),
				ProgressBlockID: progID,
			})
			if err != nil {
				return "", "", err
			}
			return retryV.EnvStatus, retryV.EnvError, nil
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
		return "", fmt.Errorf("edit_function: %w", result.FatalErr)
	}

	return marshalEditOutput(v.ID, result.FinalEnvStatus, result.FinalEnvError,
		result.AttemptsUsed, result.History, len(ops)), nil
}

// marshalEditOutput is the single source of truth for the edit_function tool's
// wire shape. Distinct from create_function's envelope because Edit does not
// flip active version — the result is a pending awaiting user accept.
//
// marshalEditOutput edit_function 工具线协议;跟 create 不同 — 不翻 active,
// 返一个待用户审的 pending。
func marshalEditOutput(
	pendingID string,
	envStatus, envError string,
	attemptsUsed int,
	history []envfixpkg.Attempt,
	opsApplied int,
) string {
	out := map[string]any{
		"pendingId":    pendingID,
		"envStatus":    envStatus,
		"opsApplied":   opsApplied,
		"attemptsUsed": attemptsUsed,
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
