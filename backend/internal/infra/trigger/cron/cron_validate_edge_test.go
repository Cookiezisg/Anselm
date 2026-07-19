package cron

import "testing"

// TestValidate_RejectsMalformedFields — C-cron-5: beyond @descriptors (covered by
// TestValidate_RejectsAtDescriptors), Validate must also reject the structural malformations
// a create/edit request can carry: an empty expression, a 6-field (seconds-granularity)
// expression, a zero/negative step (*/0), and out-of-range fields. Each is mapped by the app
// layer (crud.go) to TRIGGER_INVALID_CRON. Valid 5-field step expressions still pass.
//
// TestValidate_RejectsMalformedFields — C-cron-5：除 @descriptors（已由 TestValidate_RejectsAtDescriptors
// 覆盖），Validate 还须拒绝 create/edit 可能带来的结构畸形：空表达式、6 字段（秒粒度）、零步长（*/0）、
// 越界字段。每个都被 app 层（crud.go）映射为 TRIGGER_INVALID_CRON。合法 5 字段步长表达式仍通过。
func TestValidate_RejectsMalformedFields(t *testing.T) {
	reject := []struct {
		expr, why string
	}{
		{"", "empty expression"},
		{"   ", "whitespace-only expression"},
		{"* * * * * *", "6 fields (seconds granularity is not the 5-field standard)"},
		{"* * * *", "4 fields (too few)"},
		{"*/0 * * * *", "zero step */0"},
		{"60 * * * *", "minute field out of range (max 59)"},
		{"* 24 * * *", "hour field out of range (max 23)"},
		{"* * * * 8", "day-of-week out of range (max 6/7)"},
	}
	for _, c := range reject {
		if err := Validate(c.expr); err == nil {
			t.Errorf("Validate(%q) should reject (%s), got nil", c.expr, c.why)
		}
	}

	accept := []string{
		"*/5 * * * *",  // every 5 minutes — the canonical */x form
		"*/15 * * * *", // every 15 minutes
		"0 */2 * * *",  // every 2 hours
		"0 0 * * *",    // daily at midnight
	}
	for _, expr := range accept {
		if err := Validate(expr); err != nil {
			t.Errorf("Validate(%q) should accept a valid 5-field step expression, got %v", expr, err)
		}
	}
}
