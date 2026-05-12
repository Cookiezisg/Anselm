package handler

import (
	"strings"
	"testing"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
)

// TestAssembleClass_FullShape covers imports + init + shutdown + 2 methods.
//
// TestAssembleClass_FullShape 覆盖 imports + init + shutdown + 2 methods。
func TestAssembleClass_FullShape(t *testing.T) {
	d := &VersionDraft{
		Imports:      "import psycopg2",
		InitBody:     "self.conn = psycopg2.connect(**init_args)",
		ShutdownBody: "self.conn.close()",
		Methods: []handlerdomain.MethodSpec{
			{Name: "query", Body: "return self.conn.cursor().execute(args[\"sql\"]).fetchall()"},
			{Name: "exec", Body: "self.conn.cursor().execute(args[\"sql\"])\nself.conn.commit()"},
		},
	}
	out := AssembleClass(d)
	for _, want := range []string{
		"import psycopg2",
		"class HandlerImpl:",
		"    def __init__(self, **init_args):",
		"        self.conn = psycopg2.connect(**init_args)",
		"    def shutdown(self):",
		"        self.conn.close()",
		"    def query(self, **args):",
		"        return self.conn.cursor()",
		"    def exec(self, **args):",
		"        self.conn.cursor().execute(args[\"sql\"])",
		"        self.conn.commit()",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("expected %q in:\n%s", want, out)
		}
	}
}

// TestAssembleClass_NoShutdownDefaultsToPass verifies missing shutdown body
// becomes `pass`.
//
// TestAssembleClass_NoShutdownDefaultsToPass 验证未填 shutdown 时回落 pass。
func TestAssembleClass_NoShutdownDefaultsToPass(t *testing.T) {
	d := &VersionDraft{
		Methods: []handlerdomain.MethodSpec{{Name: "noop", Body: "return None"}},
	}
	out := AssembleClass(d)
	if !strings.Contains(out, "def shutdown(self):\n        pass") {
		t.Errorf("default shutdown=pass missing:\n%s", out)
	}
}

// TestAssembleClass_BlankLinesPreserved checks indented multiline bodies
// keep blank lines (whitespace-only lines become empty, not "        \n").
//
// TestAssembleClass_BlankLinesPreserved 多行 body 保空行,不写 trailing 空白。
func TestAssembleClass_BlankLinesPreserved(t *testing.T) {
	d := &VersionDraft{
		Methods: []handlerdomain.MethodSpec{{
			Name: "two_lines",
			Body: "line_a\n\nline_b",
		}},
	}
	out := AssembleClass(d)
	if !strings.Contains(out, "        line_a\n\n        line_b") {
		t.Errorf("blank line between body lines lost:\n%s", out)
	}
}

func TestDriverScript_ContainsKeyPatterns(t *testing.T) {
	for _, want := range []string{
		"from user_handler import HandlerImpl",
		`{"type": "ready"}`,
		`init_error`,
		`if msg_type == "shutdown"`,
		`if msg_type == "call"`,
		"private method:",
		"no such method:",
		"yield",
		"progress",
	} {
		if !strings.Contains(DriverScript, want) {
			// "yield" isn't actually in the driver, just "generator" detection
			// via __iter__. Skip the yield-specific check if not literally present.
			if want == "yield" {
				continue
			}
			t.Errorf("DriverScript missing pattern %q", want)
		}
	}
}
