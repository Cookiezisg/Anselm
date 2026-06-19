package sensor

import (
	"context"
	"errors"
	"testing"
	"time"

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

// slowInvoker signals when a probe enters Invoke and then blocks until released — so a test can
// catch the loop goroutine mid-flight and assert Stop() joins it.
//
// slowInvoker 在 probe 进入 Invoke 时发信号、随后阻塞至放行——使测试能在飞行中截住 loop goroutine 并断言 Stop() join。
type slowInvoker struct {
	entered  chan struct{}
	release  chan struct{}
	returned chan struct{}
}

func (s *slowInvoker) Invoke(_ context.Context, _, _, _ string) (map[string]any, error) {
	// Deliberately ignore ctx.Done() — models a subprocess Invoke already mid-execution that a
	// probe-ctx cancel can't instantly abort; it returns only when the work (release) completes.
	// This is exactly the R19 window: Stop() cancelled the ctx, yet the goroutine is still running.
	// 刻意忽略 ctx.Done()——模拟一个已在执行中的子进程 Invoke：probe-ctx 取消无法瞬时中止它，
	// 它只在工作完成（release）时返回。这正是 R19 窗口：Stop() 已取消 ctx，goroutine 仍在跑。
	close(s.entered)
	<-s.release
	close(s.returned)
	return map[string]any{"count": float64(0)}, nil
}

// TestSensor_Stop_WaitsForInflightProbe: Stop() must not return until the in-flight probe
// goroutine (mid-Invoke, holding a subprocess) has unwound — otherwise it races db.Close (R19).
//
// TestSensor_Stop_WaitsForInflightProbe：Stop() 在飞行中 probe（Invoke 中、持子进程）收尾前不得返回——
// 否则与 db.Close 竞争（R19）。
func TestSensor_Stop_WaitsForInflightProbe(t *testing.T) {
	inv := &slowInvoker{entered: make(chan struct{}), release: make(chan struct{}), returned: make(chan struct{})}
	l := New(inv, zap.NewNop(), func(string, triggerinfra.Activity) {})
	if err := l.Register("trg_1", "ws_1", map[string]any{
		"targetKind": "function", "targetId": "fn_1",
		"condition": "payload.count > 5.0", "output": `{"n": payload.count}`,
		"intervalSec": 3600,
	}); err != nil {
		t.Fatalf("Register: %v", err)
	}

	// Wait until the registration probe is parked inside Invoke.
	select {
	case <-inv.entered:
	case <-time.After(2 * time.Second):
		t.Fatal("probe never entered Invoke")
	}

	stopped := make(chan struct{})
	go func() { l.Stop(); close(stopped) }()

	// Stop() cancels the probe ctx, but the probe is still in Invoke's blocking select. Stop must
	// NOT have returned yet — it has to wait for the goroutine to unwind.
	select {
	case <-stopped:
		t.Fatal("Stop() returned while the probe goroutine was still in flight (no wg.Wait join)")
	case <-time.After(50 * time.Millisecond):
	}

	// Release the probe; Stop() must now complete, and only AFTER the goroutine returned.
	close(inv.release)
	select {
	case <-stopped:
	case <-time.After(2 * time.Second):
		t.Fatal("Stop() did not return after the probe unwound")
	}
	select {
	case <-inv.returned:
	default:
		t.Fatal("Stop() returned before the probe goroutine finished — wg join is missing")
	}
}
