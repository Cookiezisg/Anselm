package function

import (
	"context"
	"encoding/json"
	"fmt"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
)

type RunFunction struct {
	svc *functionapp.Service
}

func (t *RunFunction) Name() string { return "run_function" }

func (t *RunFunction) Description() string {
	return "Run a function with kwargs; returns {ok, output, errorMsg, elapsedMs}."
}

func (t *RunFunction) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"functionId": {"type": "string"},
			"version":    {"type": "string", "description": "Omit for active version"},
			"args":       {"type": "object", "description": "Kwargs passed to the function"}
		},
		"required": ["functionId", "args"]
	}`)
}

func (t *RunFunction) IsReadOnly() bool        { return false }
func (t *RunFunction) NeedsReadFirst() bool    { return false }
func (t *RunFunction) RequiresWorkspace() bool { return false }

func (t *RunFunction) ValidateInput(json.RawMessage) error { return nil }
func (t *RunFunction) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *RunFunction) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		FunctionID string         `json:"functionId"`
		Version    string         `json:"version"`
		Args       map[string]any `json:"args"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("run_function: bad args: %w", err)
	}
	if args.FunctionID == "" {
		return "", fmt.Errorf("run_function: functionId required")
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage":      "executing",
		"functionId": args.FunctionID,
	})

	res, err := t.svc.RunFunction(ctx, functionapp.RunInput{
		FunctionID: args.FunctionID,
		VersionID:  args.Version,
		Input:      args.Args,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		return "", fmt.Errorf("run_function: %w", err)
	}
	em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	b, _ := json.Marshal(res)
	return string(b), nil
}
