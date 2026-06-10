// Package ask provides the ask_user system tool — the agent's structured request for human input
// (durable human-in-the-loop, R0064). It implements tool.InteractiveTool: in a parking-capable host
// (chat / agent-invoke) the loop NEVER calls Execute — it parks the run, surfaces the call's args as
// the elicitation request, and the human's resolution (accept / decline / cancel) fills the
// tool_result. Execute runs only in a non-interactive host (subagent / workflow-agent), where it
// reports there is no user to ask so the model adapts. The request shape mirrors MCP elicitation:
// a message + optional quick-pick options.
//
// Package ask 提供 ask_user system tool——agent 向用户结构化要输入（durable 人在环，R0064）。它实现
// tool.InteractiveTool：在可 park 的 host（chat / agent-invoke）里 loop **从不**调 Execute——它 park 本次运行、
// 把调用 args 当 elicitation 请求露出、由人的决议（accept / decline / cancel）填 tool_result。Execute 只在非交互
// host（subagent / workflow-agent）跑，报告无用户可问使模型自适应。请求形态对标 MCP elicitation：message + 可选
// 快速选项。
package ask

import (
	"context"
	"encoding/json"
	"errors"
	"strings"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// AskUser is the ask_user tool. Stateless — its "result" is the human's answer, supplied at resolve.
//
// AskUser 是 ask_user 工具。无状态——它的「结果」是人的答案，在 resolve 时给。
type AskUser struct{}

func New() *AskUser { return &AskUser{} }

var (
	_ toolapp.Tool            = (*AskUser)(nil)
	_ toolapp.InteractiveTool = (*AskUser)(nil)
)

// Interactive marks this as an InteractiveTool so a parking-capable host parks instead of running it.
//
// Interactive 标记为 InteractiveTool，使可 park 的 host park 而非执行它。
func (*AskUser) Interactive() {}

func (*AskUser) Name() string { return "ask_user" }

func (*AskUser) Description() string {
	return "Ask the user a question and wait for their answer before continuing. Use this when you " +
		"genuinely need information or a decision only the user can provide (a clarification, a choice " +
		"between options, a missing value) — not for confirmation of your own dangerous actions (those " +
		"are gated separately). Provide a clear `message`; optionally provide `options` as quick-pick " +
		"choices. The user's answer comes back as this call's result; they may also decline to answer."
}

func (*AskUser) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"message": {"type": "string", "description": "The question to ask the user, in their language."},
			"options": {"type": "array", "items": {"type": "string"}, "description": "Optional list of quick-pick answers; the user may still type a free-text answer."}
		},
		"required": ["message"]
	}`)
}

func (*AskUser) ValidateInput(args json.RawMessage) error {
	var a struct {
		Message string `json:"message"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return errors.New("ask_user: invalid args: " + err.Error())
	}
	if strings.TrimSpace(a.Message) == "" {
		return errors.New("ask_user: message is required")
	}
	return nil
}

// Execute runs only outside a parking-capable host (no interactive user) — it tells the model so it
// proceeds without asking. In chat / agent-invoke the loop parks before this is ever reached.
//
// Execute 只在非可 park 的 host（无交互用户）跑——告诉模型使其不问而继续。chat / agent-invoke 里 loop 在到达此处前已 park。
func (*AskUser) Execute(context.Context, string) (string, error) {
	return "", errors.New("no interactive user is available in this context; make your best decision and proceed without asking")
}
