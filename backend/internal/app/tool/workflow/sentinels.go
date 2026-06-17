package workflow

import errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"

// Input-validation sentinels shared across this package's tools (ValidateInput presence /
// range checks). One sentinel per distinct physical violation — tools reuse them, never
// re-declare per-tool copies (S20; the duplicate-wire-code guard enforces uniqueness).
//
// 本包各工具 ValidateInput 共享的输入校验 sentinel（必填 / 范围检查）。每种物理违例一个
// sentinel——工具复用、不逐工具重复声明（S20；撞码守卫兜唯一性）。

var (
	ErrWorkflowIDRequired = errorspkg.New(errorspkg.KindInvalid, "WORKFLOW_ID_REQUIRED", "workflowId is required")
	ErrFlowrunIDRequired  = errorspkg.New(errorspkg.KindInvalid, "FLOWRUN_ID_REQUIRED", "flowrunId is required")
	ErrNameRequired       = errorspkg.New(errorspkg.KindInvalid, "WORKFLOW_NAME_REQUIRED", "name is required")
	ErrOpsRequired        = errorspkg.New(errorspkg.KindInvalid, "WORKFLOW_OPS_REQUIRED", "ops is required (non-empty)")
	ErrVersionPositive    = errorspkg.New(errorspkg.KindInvalid, "WORKFLOW_VERSION_POSITIVE", "version must be a positive integer")
)
