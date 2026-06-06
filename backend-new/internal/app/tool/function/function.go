// Package function provides the LLM system tools for the user's function library:
// search / get / create / edit / revert / delete / run + execution-log inspection.
// These are lazy tools (Toolset.Lazy) — surfaced via search_tools, not resident.
//
// Env-fix progress (the AI dep-repair loop) is captured by a forgeSink and folded into
// the create/edit tool result, so the LLM sees the full self-heal narrative. Live
// streaming of each attempt is a chat-host seam (M5.2); the sink is that seam.
//
// Package function 提供操作用户 function 库的 LLM system tool。这些是懒加载工具
// （Toolset.Lazy）——经 search_tools 浮现，非常驻。env-fix 进度（AI 改依赖循环）由 forgeSink
// 收集并折进 create/edit 结果，使 LLM 看到完整自愈叙事。逐尝试 live 推流是 chat-host 接缝
// （M5.2）；sink 即该缝。
package function

import (
	"encoding/json"

	envfixapp "github.com/sunweilin/forgify/backend/internal/app/envfix"
	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// FunctionTools constructs the function system tools over the app service.
//
// FunctionTools 基于 app service 构造 function system tool。
func FunctionTools(svc *functionapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchFunction{svc: svc},
		&GetFunction{svc: svc},
		&CreateFunction{svc: svc},
		&EditFunction{svc: svc},
		&RevertFunction{svc: svc},
		&DeleteFunction{svc: svc},
		&RunFunction{svc: svc},
		&SearchFunctionExecutions{svc: svc},
		&GetFunctionExecution{svc: svc},
	}
}

// forgeSink accumulates env-fix attempts so create/edit can fold them into their result.
//
// forgeSink 累积 env-fix 尝试，供 create/edit 折进结果。
type forgeSink struct{ attempts []envfixapp.Attempt }

func (s *forgeSink) OnAttempt(a envfixapp.Attempt) { s.attempts = append(s.attempts, a) }
func (s *forgeSink) OnFixing(int)                  {}

func toJSON(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}
