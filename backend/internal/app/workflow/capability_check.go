package workflow

import (
	"context"
	"fmt"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// CapabilityReport is the pre-flight check response for the editor's
// "Capability check" button. ok=false when any issue is found.
//
// CapabilityReport 是编辑器 "Capability check" 按钮的预检响应。
// 有任何问题时 ok=false。
type CapabilityReport struct {
	OK     bool              `json:"ok"`
	Issues []CapabilityIssue `json:"issues"`
}

// CapabilityIssue is one finding from the check; NodeID may be empty when the
// issue is graph-level (e.g., missing trigger).
//
// CapabilityIssue 一条检查发现；NodeID 空时表示图级别问题（如无 trigger）。
type CapabilityIssue struct {
	Severity string `json:"severity"`         // "error" — blocks deploy; future: "warning"
	NodeID   string `json:"nodeId,omitempty"` // empty when graph-level
	Message  string `json:"message"`
}

// CapabilityCheck runs the same validation that AcceptPending uses, but
// returns the result as a report instead of rejecting the call. Caller's
// active version is checked by default; no parameters for now.
//
// CapabilityCheck 跑 AcceptPending 用的同一套校验，但返报告而非拒绝。
// 默认检查 active version；当前不接其他参数。
func (s *Service) CapabilityCheck(ctx context.Context, workflowID string) (*CapabilityReport, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.CapabilityCheck: %w", err)
	}
	w, err := s.repo.GetWorkflow(ctx, workflowID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.CapabilityCheck: %w", err)
	}
	if w.ActiveVersionID == "" {
		return &CapabilityReport{
			OK: false,
			Issues: []CapabilityIssue{{
				Severity: "error",
				Message:  "workflow has no active version (must accept a pending first)",
			}},
		}, nil
	}
	v, err := s.repo.GetVersion(ctx, w.ActiveVersionID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.CapabilityCheck: load active: %w", err)
	}
	s.attachGraph(v)
	if v.GraphParsed == nil {
		return &CapabilityReport{
			OK: false,
			Issues: []CapabilityIssue{{
				Severity: "error",
				Message:  "active version has unparseable graph (corrupted state)",
			}},
		}, nil
	}
	// ValidateGraph short-circuits on first violation; V1 report carries 0 or 1
	// issue. Multi-issue accumulation is a follow-up enhancement when users
	// request "show me all errors at once".
	//
	// ValidateGraph 遇第一个违规即返；V1 报告 0 或 1 条 issue。
	// 多 issue 收集等用户提"一次性看所有错"再做。
	if err := ValidateGraph(ctx, v.GraphParsed, s.checker); err != nil {
		return &CapabilityReport{
			OK: false,
			Issues: []CapabilityIssue{{
				Severity: "error",
				Message:  err.Error(),
			}},
		}, nil
	}
	return &CapabilityReport{OK: true, Issues: []CapabilityIssue{}}, nil
}
