// Package handler provides the LLM system tools for the user's handler library:
// search / get / create / edit / revert / delete / call / update_config / restart +
// call-log inspection. These are lazy tools (Toolset.Lazy), surfaced via search_tools.
//
// restart_handler is the conversational "this handler is broken, restart it" path; the
// HTTP :restart endpoint is the editor-button path. Both reset the resident instance.
//
// Package handler 提供操作用户 handler 库的 LLM system tool。这些是懒加载工具，经 search_tools
// 浮现。restart_handler 是对话内"这个 handler 坏了，重启它"路径；HTTP :restart 是编辑器按钮路径。
package handler

import (
	"encoding/json"

	envfixapp "github.com/sunweilin/forgify/backend/internal/app/envfix"
	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// HandlerTools constructs the handler system tools over the app service.
func HandlerTools(svc *handlerapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchHandler{svc: svc},
		&GetHandler{svc: svc},
		&CreateHandler{svc: svc},
		&EditHandler{svc: svc},
		&RevertHandler{svc: svc},
		&DeleteHandler{svc: svc},
		&CallHandler{svc: svc},
		&UpdateHandlerConfig{svc: svc},
		&RestartHandler{svc: svc},
		&SearchHandlerCalls{svc: svc},
		&GetHandlerCall{svc: svc},
	}
}

// forgeSink accumulates env-fix attempts so create/edit can fold them into their result.
type forgeSink struct{ attempts []envfixapp.Attempt }

func (s *forgeSink) OnAttempt(a envfixapp.Attempt) { s.attempts = append(s.attempts, a) }
func (s *forgeSink) OnFixing(int)                  {}

func toJSON(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}
