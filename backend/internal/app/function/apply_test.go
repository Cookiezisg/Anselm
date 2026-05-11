package function

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
)

// TestApplyOps_SetMeta covers the happy path:set_meta op mutates name +
// description fields without affecting un-set fields. Verifies cloneDraft
// did not mutate base.
//
// TestApplyOps_SetMeta 覆盖 happy path:set_meta op 改 name + description,
// 不影响未 set 字段。验证 cloneDraft 没动 base。
func TestApplyOps_SetMeta(t *testing.T) {
	s := &Service{}
	base := &VersionDraft{}
	rawMeta, _ := json.Marshal(map[string]any{
		"name":        "to-pdf",
		"description": "convert markdown to pdf",
	})
	ops := []Op{{Type: "set_meta", Raw: rawMeta}}

	out, results, err := s.ApplyOps(context.Background(), base, ops, "")
	// final 校验会因为没 set_code 而失败 — 是预期
	if err == nil {
		t.Fatalf("expected final validation to fail without code, got nil")
	}
	if !strings.Contains(err.Error(), "code is required") {
		t.Fatalf("expected code-required error, got: %v", err)
	}
	// per-op result should still be recorded
	if len(results) != 1 || !results[0].OK {
		t.Errorf("expected 1 OK per-op result before final fail, got %+v", results)
	}
	// base must not be mutated
	if base.Name != "" {
		t.Errorf("cloneDraft failed: base.Name mutated to %q", base.Name)
	}
	_ = out
}

// TestApplyOps_FullHappyPath set_meta + set_code together;final passes.
//
// TestApplyOps_FullHappyPath set_meta + set_code 一起;final 通过。
func TestApplyOps_FullHappyPath(t *testing.T) {
	s := &Service{}
	rawMeta, _ := json.Marshal(map[string]any{"name": "to_pdf", "description": "convert"})
	rawCode, _ := json.Marshal(map[string]any{"code": "def to_pdf(x):\n    return x\n"})
	ops := []Op{
		{Type: "set_meta", Raw: rawMeta},
		{Type: "set_code", Raw: rawCode},
	}
	out, results, err := s.ApplyOps(context.Background(), &VersionDraft{}, ops, "")
	if err != nil {
		t.Fatalf("ApplyOps full path: %v", err)
	}
	if out.Name != "to_pdf" {
		t.Errorf("expected name=to_pdf, got %q", out.Name)
	}
	if !strings.Contains(out.Code, "def to_pdf") {
		t.Errorf("expected code to contain 'def to_pdf', got %q", out.Code)
	}
	if len(results) != 2 || !results[0].OK || !results[1].OK {
		t.Errorf("expected 2 OK results, got %+v", results)
	}
}

// TestApplyOps_UnknownOpRejected rejects unknown op types.
func TestApplyOps_UnknownOpRejected(t *testing.T) {
	s := &Service{}
	ops := []Op{{Type: "frobnicate", Raw: json.RawMessage(`{}`)}}
	_, _, err := s.ApplyOps(context.Background(), &VersionDraft{}, ops, "")
	if err == nil || !strings.Contains(err.Error(), "unknown op type") {
		t.Errorf("expected unknown-op-type error, got %v", err)
	}
}

// TestApplyOps_DuplicateParam catches duplicate parameter names in
// incremental validation.
func TestApplyOps_DuplicateParam(t *testing.T) {
	s := &Service{}
	rawParams, _ := json.Marshal(map[string]any{
		"parameters": []map[string]any{
			{"name": "x", "type": "string", "required": true},
			{"name": "x", "type": "integer", "required": false},
		},
	})
	ops := []Op{{Type: "set_parameters", Raw: rawParams}}
	_, _, err := s.ApplyOps(context.Background(), &VersionDraft{}, ops, "")
	if err == nil || !strings.Contains(err.Error(), "duplicate parameter") {
		t.Errorf("expected duplicate parameter error, got %v", err)
	}
}

// TestApplyOps_InvalidName catches bad name characters in incremental.
func TestApplyOps_InvalidName(t *testing.T) {
	s := &Service{}
	rawMeta, _ := json.Marshal(map[string]any{"name": "BadName"})
	ops := []Op{{Type: "set_meta", Raw: rawMeta}}
	_, _, err := s.ApplyOps(context.Background(), &VersionDraft{}, ops, "")
	if err == nil || !strings.Contains(err.Error(), "invalid") {
		t.Errorf("expected name-invalid error, got %v", err)
	}
}

// TestApplyOps_FinalMissingName final-only check for required fields.
func TestApplyOps_FinalMissingName(t *testing.T) {
	s := &Service{}
	rawCode, _ := json.Marshal(map[string]any{"code": "def x():\n    pass\n"})
	ops := []Op{{Type: "set_code", Raw: rawCode}}
	_, _, err := s.ApplyOps(context.Background(), &VersionDraft{}, ops, "")
	if err == nil || !strings.Contains(err.Error(), "name is required") {
		t.Errorf("expected 'name is required' error, got %v", err)
	}
}

// TestApplyOps_ASTScanRejectsHandlerImport D7 blacklist catches handler
// client imports in the function code.
func TestApplyOps_ASTScanRejectsHandlerImport(t *testing.T) {
	s := &Service{}
	rawMeta, _ := json.Marshal(map[string]any{"name": "bad"})
	rawCode, _ := json.Marshal(map[string]any{
		"code": "from forgify_handler import call\ndef bad():\n    return call()\n",
	})
	ops := []Op{
		{Type: "set_meta", Raw: rawMeta},
		{Type: "set_code", Raw: rawCode},
	}
	_, _, err := s.ApplyOps(context.Background(), &VersionDraft{}, ops, "")
	if err == nil || !strings.Contains(err.Error(), "handler import not allowed") {
		t.Errorf("expected D7 handler-import error, got %v", err)
	}
}
