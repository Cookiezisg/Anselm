package function

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	functionapp "github.com/sunweilin/anselm/backend/internal/app/function"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// --- run_function ----------------------------------------------------------

type RunFunction struct{ svc *functionapp.Service }

func (t *RunFunction) Name() string { return "run_function" }

func (t *RunFunction) Description() string {
	return `Run a function with keyword arguments; returns {ok, output, errorMsg, elapsedMs, logs} — logs carries the function's print()/debug output. Omit version to run the active version. For an explicit version, prefer a JSON integer number (for example 2); the boundary also accepts the exact decimal string "2" from managed callers, but not other strings. Example: {"functionId":"fn_...","args":{"text":"hello"},"version":2}. Each run is recorded — inspect history with search_function_executions / get_function_execution.`
}

func (t *RunFunction) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["functionId", "args"],
		"properties": {
			"functionId": {"type": "string"},
			"args": {"type": "object", "description": "Keyword arguments passed to the function; always send an object, e.g. {\"text\":\"hello\"}."},
			"version": {"type": "integer", "description": "Optional version number; prefer a JSON integer such as 2 and omit for the active version. For managed callers, the exact decimal string \"2\" is also accepted; other strings are invalid."}
		}
	}`)
}

func (t *RunFunction) ValidateInput(args json.RawMessage) error {
	var a struct {
		FunctionID string `json:"functionId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("run_function: bad args: %w", err)
	}
	if a.FunctionID == "" {
		return ErrFunctionIDRequired
	}
	return nil
}

func (t *RunFunction) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args runFunctionArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("run_function: bad args: %w", err)
	}

	versionID := ""
	if args.Version > 0 {
		v, err := t.svc.GetVersionByNumber(ctx, args.FunctionID, args.Version)
		if err != nil {
			return "", fmt.Errorf("run_function: %w", err)
		}
		versionID = v.ID
	}

	res, err := t.svc.RunFunction(ctx, functionapp.RunInput{
		FunctionID:  args.FunctionID,
		VersionID:   versionID,
		Input:       args.Args,
		TriggeredBy: triggerFromCtx(ctx),
	})
	if err != nil {
		return "", fmt.Errorf("run_function: %w", err)
	}
	return toolapp.ToJSON(res), nil
}

// runFunctionArgs keeps the public schema strongly typed while tolerating the
// stringified integer emitted by some managed model callers. This mirrors the
// scalar compatibility boundary used by attachment tools: accept another
// encoding of the same integer, but do not guess arrays, decimals, or words.
type runFunctionArgs struct {
	FunctionID string            `json:"functionId"`
	Args       toolapp.ObjectMap `json:"args"`
	Version    int               `json:"version"`
}

func (a *runFunctionArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		FunctionID string            `json:"functionId"`
		Args       toolapp.ObjectMap `json:"args"`
		Version    json.RawMessage   `json:"version"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	version, err := decodeRunVersion(raw.Version)
	if err != nil {
		return fmt.Errorf("version: %w", err)
	}
	*a = runFunctionArgs{FunctionID: raw.FunctionID, Args: raw.Args, Version: version}
	return nil
}

func decodeRunVersion(raw json.RawMessage) (int, error) {
	return decodeFunctionToolInt(raw)
}

func decodeFunctionToolInt(raw json.RawMessage) (int, error) {
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

// triggerFromCtx derives the execution body: a subagent context means an agent run,
// otherwise a normal chat turn. (Workflow runs call Service.RunFunction directly, not
// via this tool, and set workflow themselves.)
//
// triggerFromCtx 推导执行体：有 subagent 上下文即 agent 运行，否则普通 chat 回合。（workflow
// 直接调 Service.RunFunction、不经此工具，自设 workflow。）
func triggerFromCtx(ctx context.Context) string {
	if _, ok := reqctxpkg.GetSubagentID(ctx); ok {
		return functiondomain.TriggeredByAgent
	}
	return functiondomain.TriggeredByChat
}

// --- search_function_executions --------------------------------------------

type SearchFunctionExecutions struct{ svc *functionapp.Service }

func (t *SearchFunctionExecutions) Name() string { return "search_function_executions" }

func (t *SearchFunctionExecutions) Description() string {
	return `List a function's execution history (most recent first) with an ok/failed rollup. Filter by status (ok|failed|cancelled|timeout) or version id. Omit limit for the default page size; when paginating, prefer a JSON integer such as 2 (the boundary also accepts the exact decimal string "2" from managed callers) and pass nextCursor verbatim. Use get_function_execution on an id for the full record including logs.`
}

func (t *SearchFunctionExecutions) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["functionId"],
		"properties": {
			"functionId": {"type": "string"},
			"status": {"type": "string", "description": "Optional: ok | failed | cancelled | timeout."},
			"versionId": {"type": "string", "description": "Optional version id filter."},
			"limit": {"type": "integer", "description": "Optional page size (default 50); prefer a JSON integer such as 2. The exact decimal string \"2\" is also accepted from managed callers; other strings are invalid."},
			"cursor": {"type": "string", "description": "Opaque pagination cursor."}
		}
	}`)
}

func (t *SearchFunctionExecutions) ValidateInput(args json.RawMessage) error {
	var a struct {
		FunctionID string `json:"functionId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_function_executions: bad args: %w", err)
	}
	if a.FunctionID == "" {
		return ErrFunctionIDRequired
	}
	return nil
}

func (t *SearchFunctionExecutions) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchFunctionExecutionsArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_function_executions: bad args: %w", err)
	}
	res, err := t.svc.SearchExecutions(ctx, functiondomain.ExecutionFilter{
		FunctionID: args.FunctionID,
		Status:     args.Status,
		VersionID:  args.VersionID,
		Limit:      args.Limit,
		Cursor:     args.Cursor,
	})
	if err != nil {
		return "", fmt.Errorf("search_function_executions: %w", err)
	}
	return toolapp.ToJSON(res), nil
}

type searchFunctionExecutionsArgs struct {
	FunctionID string `json:"functionId"`
	Status     string `json:"status"`
	VersionID  string `json:"versionId"`
	Limit      int    `json:"limit"`
	Cursor     string `json:"cursor"`
}

func (a *searchFunctionExecutionsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		FunctionID string          `json:"functionId"`
		Status     string          `json:"status"`
		VersionID  string          `json:"versionId"`
		Limit      json.RawMessage `json:"limit"`
		Cursor     string          `json:"cursor"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	limit, err := decodeFunctionToolInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = searchFunctionExecutionsArgs{
		FunctionID: raw.FunctionID,
		Status:     raw.Status,
		VersionID:  raw.VersionID,
		Limit:      limit,
		Cursor:     raw.Cursor,
	}
	return nil
}

// --- get_function_execution ------------------------------------------------

type GetFunctionExecution struct{ svc *functionapp.Service }

func (t *GetFunctionExecution) Name() string { return "get_function_execution" }

func (t *GetFunctionExecution) Description() string {
	return "Get one execution record (input, output, error, logs, timing) by its id. logs carries the function's print()/debug output."
}

func (t *GetFunctionExecution) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["executionId"],
		"properties": {"executionId": {"type": "string"}}
	}`)
}

func (t *GetFunctionExecution) ValidateInput(args json.RawMessage) error {
	var a struct {
		ExecutionID string `json:"executionId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_function_execution: bad args: %w", err)
	}
	if a.ExecutionID == "" {
		return ErrExecutionIDRequired
	}
	return nil
}

func (t *GetFunctionExecution) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ExecutionID string `json:"executionId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_function_execution: bad args: %w", err)
	}
	e, err := t.svc.GetExecution(ctx, args.ExecutionID)
	if err != nil {
		return "", fmt.Errorf("get_function_execution: %w", err)
	}
	return toolapp.ToJSON(e), nil
}
