package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	handlerapp "github.com/sunweilin/anselm/backend/internal/app/handler"
	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
)

// --- call_handler ----------------------------------------------------------

type CallHandler struct{ svc *handlerapp.Service }

func (t *CallHandler) Name() string { return "call_handler" }

func (t *CallHandler) Description() string {
	return "Call a declared method on a handler's resident instance; args are that method's keyword arguments. This does NOT change the handler's init config — never put top-level config here; use update_handler_config for merge-patch config changes. The instance stays alive between calls, so its state persists. Returns the method's result. Each call is recorded — inspect later with search_handler_calls / get_handler_call (logs included)."
}

func (t *CallHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId", "method", "args"],
		"properties": {
			"handlerId": {"type": "string"},
			"method": {"type": "string", "description": "Method name to call."},
			"args": {"type": "object", "description": "Keyword arguments for the method."}
		}
	}`)
}

func (t *CallHandler) ValidateInput(args json.RawMessage) error {
	var envelope map[string]json.RawMessage
	if err := json.Unmarshal(args, &envelope); err != nil {
		return fmt.Errorf("call_handler: bad args: %w", err)
	}
	if _, ok := envelope["config"]; ok {
		return fmt.Errorf("call_handler: top-level config is not a method argument; use update_handler_config")
	}
	var a struct {
		HandlerID string `json:"handlerId"`
		Method    string `json:"method"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("call_handler: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	if a.Method == "" {
		return ErrMethodRequired
	}
	return nil
}

func (t *CallHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	if err := t.ValidateInput([]byte(argsJSON)); err != nil {
		return "", err
	}
	var args struct {
		HandlerID string            `json:"handlerId"`
		Method    string            `json:"method"`
		Args      toolapp.ObjectMap `json:"args"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("call_handler: bad args: %w", err)
	}
	// Stream the method's yields (a streaming handler method emits progress) live as a `progress`
	// block under the tool_call; the final return value is still the tool_result. nil-safe off a
	// streamed turn (no-op → a plain blocking Call).
	//
	// 把 method 的 yield（流式 handler method 发的进度）实时流成 tool_call 下的 `progress` 块；最终返回值
	// 仍是 tool_result。非流式 turn 下 nil 安全（no-op → 退化成普通阻塞 Call）。
	prog := loopapp.ToolProgress(ctx)
	defer prog.Close()
	// TriggeredBy left empty → Service derives it from ctx (subagent → agent, else chat).
	res, err := t.svc.Call(ctx, handlerapp.CallInput{
		HandlerID: args.HandlerID, Method: args.Method, Args: args.Args,
		OnProgress: func(v any) {
			if s, ok := v.(string); ok {
				prog.Print(s + "\n")
				return
			}
			b, _ := json.Marshal(v)
			prog.Print(string(b) + "\n")
		},
	})
	if err != nil {
		return "", fmt.Errorf("call_handler: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"result": res}), nil
}

// --- search_handler_calls --------------------------------------------------

type SearchHandlerCalls struct{ svc *handlerapp.Service }

func (t *SearchHandlerCalls) Name() string { return "search_handler_calls" }

func (t *SearchHandlerCalls) Description() string {
	return `List a handler's call history (most recent first) with an ok/failed rollup. Filter by method or status (ok|failed|cancelled|timeout). Omit limit for the default page size; when paginating, prefer a JSON integer such as 2 (the boundary also accepts the exact decimal string "2" from managed callers) and pass nextCursor verbatim. Use get_handler_call on an id for the full record including logs.`
}

func (t *SearchHandlerCalls) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId"],
		"properties": {
			"handlerId": {"type": "string"},
			"method": {"type": "string"},
			"status": {"type": "string", "description": "ok | failed | cancelled | timeout."},
			"limit": {"type": "integer", "description": "Optional page size (default 50); prefer a JSON integer such as 2. The exact decimal string \"2\" is also accepted from managed callers; other strings are invalid."},
			"cursor": {"type": "string"}
		}
	}`)
}

func (t *SearchHandlerCalls) ValidateInput(args json.RawMessage) error {
	var a struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_handler_calls: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return ErrHandlerIDRequired
	}
	return nil
}

func (t *SearchHandlerCalls) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchHandlerCallsArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_handler_calls: bad args: %w", err)
	}
	res, err := t.svc.SearchCalls(ctx, handlerdomain.CallFilter{
		HandlerID: args.HandlerID, Method: args.Method, Status: args.Status, Limit: args.Limit, Cursor: args.Cursor,
	})
	if err != nil {
		return "", fmt.Errorf("search_handler_calls: %w", err)
	}
	return toolapp.ToJSON(res), nil
}

type searchHandlerCallsArgs struct {
	HandlerID string `json:"handlerId"`
	Method    string `json:"method"`
	Status    string `json:"status"`
	Limit     int    `json:"limit"`
	Cursor    string `json:"cursor"`
}

// UnmarshalJSON keeps the public schema strongly typed while tolerating the exact decimal-string
// scalar emitted by some managed callers. A first-call type rejection only creates a visible red
// card and an avoidable retry; floats, arrays, booleans, and non-numeric strings remain invalid.
func (a *searchHandlerCallsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		HandlerID string          `json:"handlerId"`
		Method    string          `json:"method"`
		Status    string          `json:"status"`
		Limit     json.RawMessage `json:"limit"`
		Cursor    string          `json:"cursor"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	limit, err := decodeHandlerToolInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = searchHandlerCallsArgs{
		HandlerID: raw.HandlerID,
		Method:    raw.Method,
		Status:    raw.Status,
		Limit:     limit,
		Cursor:    raw.Cursor,
	}
	return nil
}

func decodeHandlerToolInt(raw json.RawMessage) (int, error) {
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

// --- get_handler_call ------------------------------------------------------

type GetHandlerCall struct{ svc *handlerapp.Service }

func (t *GetHandlerCall) Name() string { return "get_handler_call" }

func (t *GetHandlerCall) Description() string {
	return "Get one call record (method, input, output, error, logs, timing) by its id. logs carries the method's yields and the handler's print()/stderr output emitted during the call."
}

func (t *GetHandlerCall) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["callId"],
		"properties": {"callId": {"type": "string"}}
	}`)
}

func (t *GetHandlerCall) ValidateInput(args json.RawMessage) error {
	var a struct {
		CallID string `json:"callId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_handler_call: bad args: %w", err)
	}
	if a.CallID == "" {
		return ErrCallIDRequired
	}
	return nil
}

func (t *GetHandlerCall) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		CallID string `json:"callId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_handler_call: bad args: %w", err)
	}
	c, err := t.svc.GetCall(ctx, args.CallID)
	if err != nil {
		return "", fmt.Errorf("get_handler_call: %w", err)
	}
	return toolapp.ToJSON(c), nil
}
