// ExecutionResult is the outcome of a single sandbox Run call for a function.
// Lives in the domain layer so infra/sandbox can return it without importing
// app/function (which would create a circular dependency through the Sandbox
// port). Mirrors the shape of forgedomain.ExecutionResult — separate type so
// each domain owns its own contract (forge is being removed after Plan 01).
//
// ExecutionResult 是单次 sandbox Run function 的执行结果。定义在 domain 层，
// 让 infra/sandbox 可返回它而不必 import app/function（否则循环依赖）。
// 形状与 forgedomain.ExecutionResult 一致——保持各域自有契约（forge 在
// Plan 01 之后会被删除）。
package function

type ExecutionResult struct {
	OK        bool   `json:"ok"`
	Output    any    `json:"output"`
	ErrorMsg  string `json:"errorMsg"`
	ElapsedMs int64  `json:"elapsedMs"`
}
