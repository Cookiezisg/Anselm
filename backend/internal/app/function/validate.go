package function

import (
	"fmt"
	"regexp"
	"strings"

	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

var validNameRe = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,63}$`)

// validateIncremental checks invariants that must hold after every op (cheap, partial).
//
// validateIncremental 校验每个 op 后必须成立的不变式（廉价、部分）。
// Validation failures carry the specific reason in the sentinel's Details (not a fmt-wrapped
// string tail), so it survives the LLM error surface: llmErrText (F89) strips the wrapped %v/%w
// chain to avoid leaking Go call-paths, which also swallowed the actionable reason here — an agent
// only saw "invalid build op" and could not learn WHY (e.g. a camelCase name). Details rides through
// to both the LLM (llmErrText renders it) and HTTP N1 error.details (F-create_function-opacity).
//
// 校验失败把具体原因放进 sentinel 的 Details（非 fmt 包裹的串尾），使其穿过 LLM 错误面：llmErrText
// （F89）为防泄露 Go 调用路径会剥掉 %v/%w 包裹链，连带吞掉了这里的可操作原因——agent 只见 "invalid
// build op"、学不到为何（如 camelCase 名）。Details 同时透到 LLM（llmErrText 渲染）与 HTTP N1 error.details。
func validateIncremental(d *VersionDraft) error {
	if d.Name != "" && !validNameRe.MatchString(d.Name) {
		return functiondomain.ErrOpInvalid.WithDetails(map[string]any{
			"reason": fmt.Sprintf("name %q invalid: lowercase alphanumeric + dashes/underscores, 1-64 chars", d.Name)})
	}
	if err := schemapkg.ValidateFields(d.Inputs); err != nil {
		return functiondomain.ErrOpInvalid.WithDetails(map[string]any{"reason": "inputs: " + err.Error()}).WithCause(err)
	}
	if err := schemapkg.ValidateFields(d.Outputs); err != nil {
		return functiondomain.ErrOpInvalid.WithDetails(map[string]any{"reason": "outputs: " + err.Error()}).WithCause(err)
	}
	return nil
}

// validateFinal checks the completed draft is runnable. This is a deliberately light
// lexical check — not a real AST parse: code must declare at least one top-level def
// and must not import the handler SDK (functions are stateless, handlers persistent;
// a function importing anselm_handler would blur that boundary).
//
// validateFinal 校验完成的草稿可运行。这是刻意轻量的词法检查——非真 AST 解析：代码须至少一个
// 顶层 def，且不得 import handler SDK（function 无状态、handler 常驻；function import
// anselm_handler 会模糊这条边界）。
// validateFinal carries the right sentinel so the wire code/message points the user at the actual
// problem: a missing name is FUNCTION_INVALID_NAME, not FUNCTION_INVALID_CODE — else an empty name on
// perfectly valid code reads as "function code invalid" and sends the user to debug their fine code.
//
// validateFinal 带对的 sentinel，使 wire code/message 指向真问题：缺名是 FUNCTION_INVALID_NAME、非
// FUNCTION_INVALID_CODE——否则合法代码上的空名报成"function code invalid"、误导用户去查没问题的代码。
func validateFinal(d *VersionDraft) error {
	if d.Name == "" {
		return functiondomain.ErrInvalidName.WithDetails(map[string]any{"reason": "name is required"})
	}
	if strings.TrimSpace(d.Code) == "" {
		return functiondomain.ErrInvalidCode.WithDetails(map[string]any{"reason": "code is required"})
	}
	if !strings.HasPrefix(d.Code, "def ") && !strings.Contains(d.Code, "\ndef ") {
		return functiondomain.ErrInvalidCode.WithDetails(map[string]any{"reason": "code must declare at least one top-level def"})
	}
	for _, banned := range handlerImportBlacklist {
		if strings.Contains(d.Code, banned) {
			return functiondomain.ErrInvalidCode.WithDetails(map[string]any{
				"reason": fmt.Sprintf("function code may not import the handler SDK (%q)", banned)})
		}
	}
	return nil
}

var handlerImportBlacklist = []string{
	"from anselm_handler import",
	"import anselm_handler",
}

// entryFuncName extracts the first top-level def's name (the spawn driver calls it).
// Returns "" if none — callers treat that as a validation failure upstream.
//
// Match must be at column 0: an indented def (a class/nested method) physically preceding
// the real entry would otherwise be picked and called by name, yielding a runtime NameError
// — this keeps "top-level" consistent with validateFinal's column-0 requirement.
//
// entryFuncName 抽第一个顶层 def 的名字（spawn driver 调它）。无则返 ""，上游当校验失败处理。
// 必须列 0 匹配：缩进的 def（类/嵌套方法）若物理上先于真入口，否则会被选中并按名调用 → 运行时
// NameError——使「顶层」与 validateFinal 的列 0 要求一致。
func entryFuncName(code string) string {
	for _, line := range strings.Split(code, "\n") {
		if !strings.HasPrefix(line, "def ") {
			continue
		}
		rest := strings.TrimPrefix(line, "def ")
		if idx := strings.IndexAny(rest, "(: "); idx > 0 {
			return rest[:idx]
		}
	}
	return ""
}
