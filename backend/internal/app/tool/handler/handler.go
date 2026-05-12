// Package handler provides the 8 system tools the LLM uses to interact with
// the user's handler library: search/get/create/edit/revert/delete/call_handler
// + update_handler_config.
//
// Per §S13 nested sub-package alias rule, importers alias as `handlertool`
// (distinct from `handlerapp` and `handlerdomain`).
//
// Streaming model:
//   - create_handler / edit_handler — ops engine emits 1 progress delta per op
//   - call_handler — Service.Call's OnProgress fires for each Python yield
//   - search/get/revert/delete/update_config — one-shot tool_result
//
// Package handler 提供 8 个 system tool。alias 按 §S13 用 `handlertool`。
package handler

import (
	"go.uber.org/zap"

	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// HandlerTools constructs the 8 handler system tools wired with their
// dependencies.
//
// HandlerTools 构造装配好依赖的 8 个 handler system tool。
func HandlerTools(
	svc *handlerapp.Service,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
	log *zap.Logger,
) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchHandler{svc: svc, picker: picker, keys: keys, factory: factory, log: log},
		&GetHandler{svc: svc},
		&CreateHandler{svc: svc},
		&EditHandler{svc: svc},
		&RevertHandler{svc: svc},
		&DeleteHandler{svc: svc},
		&CallHandler{svc: svc},
		&UpdateHandlerConfig{svc: svc},
		&SearchHandlerCalls{svc: svc},
		&GetHandlerCall{svc: svc},
	}
}
