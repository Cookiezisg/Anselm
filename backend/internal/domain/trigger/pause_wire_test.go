package trigger

// pause_wire_test.go locks the pause switch's wire contract (scheduler 工单⑦): `paused` is an
// ALWAYS-PRESENT camelCase bool (the UI's ⏸ badge keys off an explicit value, never absence),
// and the manual-fire refusal carries the stable TRIGGER_PAUSED / 422 pair.
//
// pause_wire_test.go 锁暂停开关的线缆契约（scheduler 工单⑦）：`paused` 是**恒在**的 camelCase
// bool（UI 的 ⏸ 徽章认显式值、不认缺席），手动 :fire 的拒绝带稳定的 TRIGGER_PAUSED / 422 对。

import (
	"encoding/json"
	"strings"
	"testing"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

func TestWire_PausedAlwaysPresent(t *testing.T) {
	b, err := json.Marshal(&Trigger{ID: "trg_1", Kind: KindCron})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(b), `"paused":false`) {
		t.Fatalf("an unpaused trigger must send paused:false explicitly, got %s", b)
	}
	b, err = json.Marshal(&Trigger{ID: "trg_1", Kind: KindCron, Paused: true})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(b), `"paused":true`) {
		t.Fatalf("a paused trigger must send paused:true, got %s", b)
	}
}

func TestErrPaused_WireContract(t *testing.T) {
	if ErrPaused.Code != "TRIGGER_PAUSED" {
		t.Errorf("ErrPaused.Code = %q, want TRIGGER_PAUSED", ErrPaused.Code)
	}
	if ErrPaused.Kind != errorspkg.KindUnprocessable {
		t.Errorf("ErrPaused.Kind = %v, want KindUnprocessable (422)", ErrPaused.Kind)
	}
}
