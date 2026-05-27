package main

import (
	"fmt"
	"sort"
	"strings"
)

// Validate reports strict-mode violations in the matrix:
//   - any truth row with 0 covering tests (uncovered)
//   - any `// covers:` annotation pointing at non-existent truth (orphan)
//   - any pipeline test function missing a `// covers:` annotation
//
// Returns the violation list (empty when clean) so the caller can print + decide
// the exit code.
//
// Validate 报告矩阵严格模式违规:0 覆盖 / orphan annotation / 漏注释测试。
// 返违规列表(无违规返空切片),由调用方决定退出码。
func Validate(m Matrix) []string {
	var violations []string

	uncovered := []string{}
	for _, r := range m.Endpoints {
		if len(r.Tests) == 0 {
			uncovered = append(uncovered, fmt.Sprintf("endpoint:  %s %s", r.Endpoint.Method, r.Endpoint.Path))
		}
	}
	for _, r := range m.ErrCodes {
		if len(r.Tests) == 0 {
			uncovered = append(uncovered, fmt.Sprintf("errcode:   %s (HTTP %d)", r.ErrCode.Code, r.ErrCode.HTTPStatus))
		}
	}
	for _, r := range m.SSE {
		if len(r.Tests) == 0 {
			uncovered = append(uncovered, "sse:       "+r.SSE.Key())
		}
	}
	for _, r := range m.Cross {
		if len(r.Tests) == 0 {
			uncovered = append(uncovered, "cross:     "+r.Seam.ID)
		}
	}
	for _, r := range m.Lifecycle {
		if len(r.Tests) == 0 {
			uncovered = append(uncovered, "lifecycle: "+r.Seam.ID)
		}
	}
	sort.Strings(uncovered)
	if len(uncovered) > 0 {
		violations = append(violations,
			fmt.Sprintf("%d uncovered targets:\n  %s", len(uncovered),
				strings.Join(uncovered, "\n  ")))
	}

	if len(m.Orphans) > 0 {
		lines := make([]string, len(m.Orphans))
		for i, o := range m.Orphans {
			lines[i] = fmt.Sprintf("%s:%d  %s  (in %s)", o.File, o.Line, o.Annotation, o.TestFunc)
		}
		violations = append(violations,
			fmt.Sprintf("%d orphan annotations:\n  %s", len(m.Orphans),
				strings.Join(lines, "\n  ")))
	}

	if len(m.Unannotated) > 0 {
		lines := make([]string, len(m.Unannotated))
		for i, u := range m.Unannotated {
			lines[i] = fmt.Sprintf("%s:%d  %s", u.File, u.Line, u.TestFunc)
		}
		violations = append(violations,
			fmt.Sprintf("%d tests missing `// covers:` annotation:\n  %s", len(m.Unannotated),
				strings.Join(lines, "\n  ")))
	}

	return violations
}
