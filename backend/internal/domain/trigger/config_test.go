package trigger

import "testing"

// TestValidateConfig_SensorTargets covers the three sensor target kinds: function (whole
// unit, no method), handler (needs a method name), mcp (needs a tool name) — plus rejection
// of an unknown kind or a missing sub-unit name.
//
// TestValidateConfig_SensorTargets 覆盖三种 sensor target：function（整体，无 method）、handler
// （需 method 名）、mcp（需 tool 名）——以及未知 kind / 缺子单元名的拒绝。
func TestValidateConfig_SensorTargets(t *testing.T) {
	cfg := func(kind, id, method string) map[string]any {
		return map[string]any{
			"targetKind": kind, "targetId": id, "method": method,
			"intervalSec": 10.0, "condition": "true", "output": "payload",
		}
	}

	if err := ValidateConfig(KindSensor, cfg("function", "fn_1", "")); err != nil {
		t.Fatalf("function sensor (no method) should validate: %v", err)
	}
	if err := ValidateConfig(KindSensor, cfg("handler", "hd_1", "process")); err != nil {
		t.Fatalf("handler sensor should validate: %v", err)
	}
	if err := ValidateConfig(KindSensor, cfg("handler", "hd_1", "")); err == nil {
		t.Fatal("handler sensor without a method should fail")
	}
	if err := ValidateConfig(KindSensor, cfg("mcp", "github", "create_issue")); err != nil {
		t.Fatalf("mcp sensor should validate: %v", err)
	}
	if err := ValidateConfig(KindSensor, cfg("mcp", "github", "")); err == nil {
		t.Fatal("mcp sensor without a tool name should fail")
	}
	if err := ValidateConfig(KindSensor, cfg("weird", "x", "")); err == nil {
		t.Fatal("unknown target kind should fail")
	}
}
