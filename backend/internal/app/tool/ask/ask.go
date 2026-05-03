// Package ask provides the AskUserQuestion system tool. It pauses the
// LLM agent loop until the user answers via the
// POST /api/v1/conversations/{id}/answers endpoint, then returns the
// answer as the tool's tool_result so the LLM can continue.
//
// Imported as `asktool` per §S13 nested sub-package alias rule.
//
// The question itself ships with the standard chat.message SSE stream —
// the AskUserQuestion tool_call block carries `question` and optional
// `options` in its arguments map, and the UI renders the prompt off
// that. Decision D11: no separate event family.
//
// Package ask 提供 AskUserQuestion 系统工具：暂停 LLM agent 循环，直到
// 用户经 POST /api/v1/conversations/{id}/answers 回答，然后把答案作为
// tool_result 返回让 LLM 继续。
//
// 按 §S13 嵌套子包别名规则导入为 `asktool`。
//
// 问题本身坐 chat.message SSE 流——AskUserQuestion tool_call block 的
// arguments 里带 `question` 与可选 `options`，UI 据此渲染。决策 D11：
// 不新建事件家族。
package ask

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	askapp "github.com/sunweilin/forgify/backend/internal/app/ask"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// ── Limits & defaults ─────────────────────────────────────────────────────────

const (
	// defaultTimeout is the wall-clock the tool blocks waiting for an
	// answer before giving up. 5 minutes lets the user step away briefly
	// without the agent loop hanging forever.
	//
	// defaultTimeout 是工具等答案的墙钟。5 分钟让用户短暂离开也不会让
	// agent 循环永挂。
	defaultTimeout = 5 * time.Minute
)

// ── Validation sentinels ──────────────────────────────────────────────────────

var (
	// ErrEmptyQuestion: question missing or empty.
	// ErrEmptyQuestion：question 缺失或为空。
	ErrEmptyQuestion = errors.New("question is required and must be non-empty")
)

// ── Description & schema ──────────────────────────────────────────────────────

const askDescription = `Pause the agent loop and ask the user a question. Returns the user's answer.

Usage:
- ` + "`question`" + ` is the question text shown to the user.
- ` + "`options`" + ` (optional) is a list of suggested answers; the UI may render them as click-to-pick buttons. The user is NOT restricted to these — they may type any answer.
- The tool blocks for up to 5 minutes; if the user does not respond in that window the result is "User did not respond within the timeout".
- Use this when you genuinely need user input to proceed (e.g. ambiguous request, destructive action confirmation, missing data). Do NOT use it for things you can deduce from context.`

var askSchema = json.RawMessage(`{
	"type": "object",
	"required": ["question"],
	"properties": {
		"question": {
			"type": "string",
			"description": "The question text shown to the user."
		},
		"options": {
			"type": "array",
			"items": {"type": "string"},
			"description": "Optional list of suggested answers (the UI may render them as buttons; user is NOT restricted to these)."
		}
	}
}`)

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// AskUserQuestion implements the AskUserQuestion system tool.
//
// AskUserQuestion struct 是 AskUserQuestion 系统工具。
type AskUserQuestion struct {
	svc     *askapp.Service
	timeout time.Duration // overridable for tests
}

// AskTools constructs the ask system tools sharing one Service.
//
// AskTools 用一个 Service 构造 ask 系统工具。
func AskTools(svc *askapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&AskUserQuestion{svc: svc, timeout: defaultTimeout},
	}
}

// Identity --------------------------------------------------------------------

func (t *AskUserQuestion) Name() string                { return "AskUserQuestion" }
func (t *AskUserQuestion) Description() string         { return askDescription }
func (t *AskUserQuestion) Parameters() json.RawMessage { return askSchema }

// Static metadata -------------------------------------------------------------

func (t *AskUserQuestion) IsReadOnly() bool        { return true }
func (t *AskUserQuestion) NeedsReadFirst() bool    { return false }
func (t *AskUserQuestion) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ──────────────────────────────────────────────────────

// ValidateInput rejects empty question pre-Execute.
//
// ValidateInput 在 Execute 前拒绝空 question。
func (t *AskUserQuestion) ValidateInput(args json.RawMessage) error {
	var a struct {
		Question string `json:"question"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("AskUserQuestion.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Question) == "" {
		return ErrEmptyQuestion
	}
	return nil
}

func (t *AskUserQuestion) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

// Execute pulls the LLM-assigned tool_call_id from ctx, registers a
// pending question with the Service, and blocks until either the answer
// arrives or the timeout elapses. The chat.message SSE stream already
// carries the tool_call block (with `question` + `options` in
// arguments), so the UI sees the prompt without any new event type.
//
// Failure paths return LLM-friendly strings (not Go errors) so the LLM
// can read the situation and reword / retry.
//
// Execute 从 ctx 取 LLM 分配的 tool_call_id，注册 pending 问题，阻塞
// 直至答案到达或超时。chat.message SSE 已携带 tool_call block（arguments
// 含 question/options），UI 无需新事件就能看到提示。
//
// 失败路径返友好字符串（非 Go err），让 LLM 看清情况并改述 / 重试。
func (t *AskUserQuestion) Execute(ctx context.Context, argsJSON string) (string, error) {
	callID, _ := reqctxpkg.GetToolCallID(ctx)
	if callID == "" {
		return "Cannot ask the user: no tool_call_id in context (chat layer wiring bug).", nil
	}
	answer, err := t.svc.Wait(ctx, callID, t.timeout)
	switch {
	case errors.Is(err, askapp.ErrTimeout):
		return "User did not respond within the timeout. Re-ask later if still needed.", nil
	case errors.Is(err, context.Canceled):
		return "Question cancelled by the user (conversation interrupted).", nil
	case err != nil:
		return fmt.Sprintf("Asking the user failed: %v", err), nil
	}
	return answer, nil
}

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*AskUserQuestion)(nil)
