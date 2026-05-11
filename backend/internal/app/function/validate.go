// validate.go — incremental + final validation for VersionDraft.
//
// Incremental rules run after each ops application (cumulative state must be
// self-consistent: name char-set, parameter name uniqueness, parameter types).
// Final rules run once after all ops are applied (required fields, AST scan,
// signature consistency per D14). Final-only checks would falsely flag mid-
// edit states where the LLM has not yet emitted `set_code`.
//
// validate.go —— VersionDraft 的 incremental + final 校验。
//
// incremental 每 op 应用后跑(累积态需自洽:name 字符集 / 参数名唯一 / 参数
// 类型);final 全部 ops 应用完跑一次(必填字段 + AST 扫 + 签名一致性 D14)。
// 把 final-only check 提前会误伤 LLM 还没 emit `set_code` 的中间态。

package function

import (
	"fmt"
	"regexp"
	"strings"

	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
)

// validateIncremental runs after each op application — checks state is
// internally coherent without requiring all ops applied.
//
// validateIncremental 每 op 应用后跑——检查累积态自洽,但不要求全部 ops 完成。
func validateIncremental(d *VersionDraft) error {
	if d.Name != "" {
		if !validNameRe.MatchString(d.Name) {
			return fmt.Errorf("name %q invalid: lowercase alphanum + dashes/underscores only", d.Name)
		}
	}
	if len(d.Parameters) > 0 {
		seen := map[string]bool{}
		for _, p := range d.Parameters {
			if p.Name == "" {
				return fmt.Errorf("parameter has empty name")
			}
			if seen[p.Name] {
				return fmt.Errorf("duplicate parameter name: %q", p.Name)
			}
			seen[p.Name] = true
			if !isValidParamType(p.Type) {
				return fmt.Errorf("parameter %q invalid type: %q", p.Name, p.Type)
			}
		}
	}
	return nil
}

// validateFinal runs after all ops applied — required for the entity to be
// persisted. Includes Python AST scan + parameters/code consistency check.
//
// validateFinal 全部 ops 应用完跑——entity 持久化的前置条件。包括 Python AST
// 扫 + parameters/code 签名一致性校验(D14)。
func validateFinal(d *VersionDraft) error {
	if d.Name == "" {
		return fmt.Errorf("name is required")
	}
	if d.Code == "" {
		return fmt.Errorf("code is required")
	}
	if err := scanPythonAST(d.Code, d.Name); err != nil {
		return fmt.Errorf("AST scan: %w", err)
	}
	if err := checkParamConsistency(d.Code, d.Name, d.Parameters); err != nil {
		return fmt.Errorf("param consistency: %w", err)
	}
	return nil
}

var validNameRe = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,63}$`)

func isValidParamType(t string) bool {
	switch t {
	case "string", "number", "integer", "boolean", "object", "array":
		return true
	}
	return false
}

// scanPythonAST validates code contains a top-level def matching name and has
// no Handler-client imports (D7 blacklist). V1 uses simple substring scan;
// V1.5 switches to real `python -c 'import ast; ast.parse(...)'` in sandbox
// for accuracy (multi-line defs / decorator stacks would fool the V1 scan).
//
// scanPythonAST V1 用字符串扫(简单),V1.5 切 sandbox 跑真 ast.parse(准确)。
func scanPythonAST(code, name string) error {
	if !strings.Contains(code, "def "+name) {
		return fmt.Errorf("code must define a function named %q", name)
	}
	for _, blacklisted := range handlerImportBlacklist {
		if strings.Contains(code, blacklisted) {
			return fmt.Errorf("D7: handler import not allowed: %q", blacklisted)
		}
	}
	return nil
}

var handlerImportBlacklist = []string{
	"from forgify_handler import",
	"import forgify_handler",
}

// checkParamConsistency cross-checks declared ParameterSpec against the
// Python function signature. V1 returns nil — implementation tracked as
// Task 10b (switch to sandbox real AST per D14).
//
// checkParamConsistency 比对 declared ParameterSpec 跟 Python 函数签名。
// V1 占位返 nil;真实现走 Task 10b(切 sandbox 真 AST per D14)。
func checkParamConsistency(code, name string, params []functiondomain.ParameterSpec) error {
	_ = code
	_ = name
	_ = params
	return nil
}
