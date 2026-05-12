// Package function provides the 7 system tools the LLM uses to interact with
// the user's function library: search_function / get_function / create_function
// / edit_function / revert_function / delete_function / run_function.
//
// Per §S13 nested sub-package alias rule, importers use the alias
// `functiontool` (`<sub><parent>` = function + tool). Distinguish from
// `functionapp` (app/function service) and `functiondomain` (entities).
//
// Streaming model (per CLAUDE.md §S18 emit pattern):
//   - create_function / edit_function — ApplyOps emits one progress delta per
//     op; the tool opens a progress block before calling Service and stops it
//     after.
//   - run_function — Service.RunFunction's sync env stage progress is streamed
//     via the same Emitter; the tool wraps the call in a progress block.
//   - search_function / get_function / revert_function / delete_function — no
//     streaming; one-shot tool_result.
//
// Package function 提供 7 个 system tool。alias 按 §S13 用 `functiontool`。
// 流式模型见 §S18:create/edit/run 通过 progress block emit;search/get/revert/
// delete 一次性 tool_result。

package function

import (
	"go.uber.org/zap"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	forgepkg "github.com/sunweilin/forgify/backend/internal/pkg/forge"
)

// FunctionTools constructs the 7 function system tools wired with their
// dependencies. Returns []toolapp.Tool because chat ReAct loop consumes the
// abstract interface.
//
// forge is the forge-stream Publisher (C4 D-redo-4) used by Create/Edit
// to emit forge_started / forge_env_attempt / forge_completed. Pass a
// noop publisher (forgepkg.New(nil, log)) in tests / unwired services
// to disable the forge double-write.
//
// FunctionTools 构造装配好依赖的 7 个 function system tool。forge 是
// forge-stream Publisher(C4 D-redo-4),Create/Edit 经它发 forge 事件。
// 测试/未接线时传 noop publisher 关闭 forge 双写。
func FunctionTools(
	svc *functionapp.Service,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
	forge forgepkg.Publisher,
	log *zap.Logger,
) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchFunction{svc: svc, picker: picker, keys: keys, factory: factory, log: log},
		&GetFunction{svc: svc},
		&CreateFunction{svc: svc, picker: picker, keys: keys, factory: factory, forge: forge},
		&EditFunction{svc: svc, picker: picker, keys: keys, factory: factory, forge: forge},
		&RevertFunction{svc: svc},
		&DeleteFunction{svc: svc},
		&RunFunction{svc: svc},
		&SearchFunctionExecutions{svc: svc},
		&GetFunctionExecution{svc: svc},
	}
}
