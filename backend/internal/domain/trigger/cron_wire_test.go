package trigger

import (
	"testing"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// TestErrInvalidCron_WireContract — C-cron-5: the sentinel the app layer returns when a cron
// expression fails Validate must carry the stable wire code TRIGGER_INVALID_CRON and the
// Unprocessable (422) Kind — that pair is the contract clients (and error-codes.md) rely on
// to distinguish a bad cron from other 4xx. Locks the code/kind against accidental drift.
//
// TestErrInvalidCron_WireContract — C-cron-5：app 层在 cron 表达式 Validate 失败时返回的 sentinel 必须
// 带稳定 wire code TRIGGER_INVALID_CRON 与 Unprocessable(422) Kind——该对是客户端（及 error-codes.md）
// 区分坏 cron 与其他 4xx 的契约。锁死 code/kind 防漂移。
func TestErrInvalidCron_WireContract(t *testing.T) {
	if ErrInvalidCron.Code != "TRIGGER_INVALID_CRON" {
		t.Errorf("ErrInvalidCron.Code = %q, want TRIGGER_INVALID_CRON", ErrInvalidCron.Code)
	}
	if ErrInvalidCron.Kind != errorspkg.KindUnprocessable {
		t.Errorf("ErrInvalidCron.Kind = %v, want KindUnprocessable (422)", ErrInvalidCron.Kind)
	}
}

// TestValidateConfig_CronRequiresExpression — C-cron-5: the domain's structural gate rejects
// a cron config with a missing/empty expression BEFORE the app layer runs robfig syntax
// validation, returning ErrInvalidCron. (Non-empty-but-malformed expressions are caught by
// the infra cron.Validate step, see cron_validate_edge_test.go.)
//
// TestValidateConfig_CronRequiresExpression — C-cron-5：domain 结构门在 app 层跑 robfig 语法校验前，
// 先拒绝缺失 / 空表达式的 cron config，返 ErrInvalidCron。（非空但畸形的表达式由 infra cron.Validate 捕获。）
func TestValidateConfig_CronRequiresExpression(t *testing.T) {
	if err := ValidateConfig(KindCron, map[string]any{}); err != ErrInvalidCron {
		t.Errorf("cron config with no expression → %v, want ErrInvalidCron", err)
	}
	if err := ValidateConfig(KindCron, map[string]any{"expression": ""}); err != ErrInvalidCron {
		t.Errorf("cron config with empty expression → %v, want ErrInvalidCron", err)
	}
	// A non-empty expression clears the domain gate (syntax is the app layer's job).
	if err := ValidateConfig(KindCron, map[string]any{"expression": "*/5 * * * *"}); err != nil {
		t.Errorf("cron config with a non-empty expression should clear the domain gate, got %v", err)
	}
}
