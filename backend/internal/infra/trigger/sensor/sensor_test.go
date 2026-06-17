package sensor

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
	celpkg "github.com/sunweilin/anselm/backend/internal/pkg/cel"
)

type fakeInvoker struct {
	rv  map[string]any
	err error
}

func (f fakeInvoker) Invoke(ctx context.Context, targetKind, targetID, method string) (map[string]any, error) {
	return f.rv, f.err
}

// probeOnce wires a sensor with the given invoker, runs one probe, and returns the reported Activity.
func probeOnce(t *testing.T, inv SensorInvoker) triggerinfra.Activity {
	t.Helper()
	cond, err := celpkg.Compile("payload.count > 5.0")
	if err != nil {
		t.Fatalf("compile condition: %v", err)
	}
	out, err := celpkg.Compile(`{"n": payload.count}`)
	if err != nil {
		t.Fatalf("compile output: %v", err)
	}
	var got []triggerinfra.Activity
	l := New(inv, zap.NewNop(), func(_ string, a triggerinfra.Activity) { got = append(got, a) })
	l.probe(context.Background(), "trg_1", triggerdomain.SensorConfig{TargetKind: "function", TargetID: "fn_1"}, cond, out)
	if len(got) != 1 {
		t.Fatalf("expected exactly 1 activity report, got %d", len(got))
	}
	return got[0]
}

func TestSensor_Probe_Fires_WhenConditionHolds(t *testing.T) {
	act := probeOnce(t, fakeInvoker{rv: map[string]any{"count": float64(10)}})
	if !act.Fired {
		t.Fatalf("condition 10>5 should fire: %+v", act)
	}
	if act.Payload["n"] != float64(10) {
		t.Fatalf("output CEL should build payload {n:10}, got %+v", act.Payload)
	}
	if act.ReturnValue["count"] != float64(10) {
		t.Fatalf("activity should keep the probe return value: %+v", act.ReturnValue)
	}
}

func TestSensor_Probe_DoesNotFire_ButRecordsReturnValue(t *testing.T) {
	act := probeOnce(t, fakeInvoker{rv: map[string]any{"count": float64(3)}})
	if act.Fired {
		t.Fatalf("condition 3>5 should NOT fire: %+v", act)
	}
	// The whole point of Activation: a non-fired probe still records what it saw + why.
	if act.ReturnValue["count"] != float64(3) || act.Detail == "" {
		t.Fatalf("non-fired probe must keep ReturnValue + Detail: %+v", act)
	}
}

func TestSensor_Probe_InvokeError(t *testing.T) {
	act := probeOnce(t, fakeInvoker{err: errors.New("boom")})
	if act.Fired || act.Error == "" {
		t.Fatalf("invoke error should report Fired=false with Error set: %+v", act)
	}
}
