package errors

import (
	stderrors "errors"
	"fmt"
	"sort"
	"strings"
)

// Surface returns the user/LLM-facing text for an error: the first *Error in the chain's clean
// Message plus its Details — NOT err.Error()'s wrapped chain, which leaks the internal Go
// package/method breadcrumbs app layers add via fmt.Errorf("pkg.Method: %w", …) (e.g.
// "functionapp.RunFunction:"). The actionable part for self-correction is Message + Details, never
// the call path (S20). A non-structured error (raw stdlib) has only its text, returned as-is.
//
// This is the single source for every error surface the LLM / a flowrun node / an agent execution
// reads — it was independently copied as the loop's llmErrText (F89) and the scheduler's nodeErrText
// (F104) before a third call site (agent invoke) made the duplication a foundation gap (principle #8).
//
// Surface 返回错误的「用户/LLM 可见」文本：链中第一个 *Error 的干净 Message + Details——**非**
// err.Error() 的包裹链（会泄露 app 层经 fmt.Errorf("pkg.Method: %w", …) 加的内部 Go 包/方法面包屑）。
// 自纠所需是 Message + Details、绝非调用路径（S20）。非结构化错误（裸 stdlib）只有其文本、原样返回。
// 这是 LLM / flowrun 节点 / agent 执行读取的每个错误面的单一来源——曾被独立抄成 loop 的 llmErrText
// （F89）与 scheduler 的 nodeErrText（F104），第三个调用点（agent invoke）使这份重复成了地基缺口（原则 #8）。
// Wrap wraps a domain sentinel around a lower-layer cause WITHOUT shadowing the cause's structured
// Details: it lifts the cause's Details (if the cause is, or wraps, an *Error) onto a clone of the
// sentinel and keeps the cause in the chain via WithCause. Surface reads the OUTERMOST *Error, so this
// surfaces BOTH the sentinel's category Message AND the cause's Details (e.g. a Python traceback).
//
// Prefer this over fmt.Errorf("%w: %v", sentinel, cause): the %v FLATTENS the cause to a string and
// drops it from the error chain entirely, so a deeper *Error's Details (which Surface would have
// rendered) are lost — exactly how F131's __init__ path shipped broken (the infra error carried the
// traceback Details, but the app-layer %v re-wrap erased them).
//
// Wrap 把 domain sentinel 包在底层 cause 外、但**不遮蔽** cause 的结构化 Details：把 cause 的 Details（若 cause
// 是/包 *Error）抬到 sentinel 的克隆上、并经 WithCause 保留 cause 于链中。Surface 读最外层 *Error，故同时浮出
// sentinel 的类别 Message 与 cause 的 Details（如 Python traceback）。优于 fmt.Errorf("%w: %v", …)——后者 %v 把
// cause 拍平成串、从错误链整个移除，深层 *Error 的 Details 全丢（F131 的 __init__ 路径正是这样发坏的）。
func Wrap(sentinel *Error, cause error) *Error {
	e := sentinel
	var inner *Error
	if stderrors.As(cause, &inner) && len(inner.Details) > 0 {
		e = e.WithDetails(inner.Details)
	}
	return e.WithCause(cause)
}

func Surface(err error) string {
	if err == nil {
		return ""
	}
	var de *Error
	if !stderrors.As(err, &de) {
		return err.Error()
	}
	msg := de.Message
	if len(de.Details) > 0 {
		parts := make([]string, 0, len(de.Details))
		for k, v := range de.Details {
			parts = append(parts, fmt.Sprintf("%s=%v", k, v))
		}
		sort.Strings(parts)
		msg += " (" + strings.Join(parts, "; ") + ")"
	}
	return msg
}
