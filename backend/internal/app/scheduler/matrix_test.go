// matrix_test.go pins the app-layer guards on the two scheduler read/govern paths whose defaults
// live in the service: RunMatrix (工单⑩ — workflowId required, recentN default/clamp) and
// SweepRunRetention (工单⑬ — the batch loop and the verbatim cutoff pass-through).
//
// matrix_test.go 钉死两条 scheduler 路径的 app 层守卫（其默认值住在 service）：RunMatrix（工单⑩——
// workflowId 必填、recentN 默认/钳制）与 SweepRunRetention（工单⑬——批循环与 cutoff 的逐字透传）。
package scheduler

import (
	"context"
	"errors"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// recorderRepo records what the service hands the store. The embedded interface is nil on purpose:
// these tests exercise exactly two methods, and any other call panicking is the point — it proves
// the guard path touches nothing else.
//
// recorderRepo 记录 service 交给 store 的东西。内嵌接口刻意为 nil：这些测试只走两个方法，别的调用 panic
// 正是重点——它证明守卫路径不碰其他任何东西。
type recorderRepo struct {
	RunStore
	lastMatrix flowrundomain.MatrixQuery
	lastCutoff time.Time
	lastBatch  int
	purgeCalls int
	// purgeReturns is the per-call purge count, consumed in order (a short one ends the app's loop).
	// purgeReturns 是逐次调用的清理数、按序消费（短的那次结束 app 的循环）。
	purgeReturns []int
}

func (r *recorderRepo) RunMatrix(_ context.Context, q flowrundomain.MatrixQuery) (*flowrundomain.Matrix, error) {
	r.lastMatrix = q
	return &flowrundomain.Matrix{}, nil
}

func (r *recorderRepo) PurgeTerminalRunsBefore(_ context.Context, cutoff time.Time, batch int) (int, error) {
	r.lastCutoff, r.lastBatch = cutoff, batch
	n := 0
	if r.purgeCalls < len(r.purgeReturns) {
		n = r.purgeReturns[r.purgeCalls]
	}
	r.purgeCalls++
	return n, nil
}

// An absent workflowId is a 400, not an empty grid: the grid's axis IS the workflow, so answering
// "here is the matrix of nothing" would dress a client bug up as data.
// 缺席的 workflowId 是 400、不是空格阵：格阵的轴**就是** workflow，故回答「这是空无的矩阵」= 把客户端 bug
// 打扮成数据。
func TestRunMatrix_WorkflowIDRequired(t *testing.T) {
	svc := &Service{runs: &recorderRepo{}}
	if _, err := svc.RunMatrix(ctxWS("ws_1"), flowrundomain.MatrixQuery{RecentN: 20}); !errors.Is(err, errorspkg.ErrInvalidRequest) {
		t.Fatalf("absent workflowId must reject with ErrInvalidRequest, got %v", err)
	}
}

// recentN: ≤0 takes the default, > cap clamps — a window is a view, and narrowing it is a visual
// downgrade rather than a lie (contrast the flowrun-stats ids cap, which rejects loudly because a
// silent truncation there WOULD lie).
// recentN：≤0 取默认、>上限钳制——窗口是视图，收窄它是视觉降级而非撒谎（对比 flowrun-stats 的 ids 上限
// 大声拒：那里静默截断**会**撒谎）。
func TestRunMatrix_RecentNDefaultAndClamp(t *testing.T) {
	ctx := ctxWS("ws_1")
	for _, tc := range []struct {
		name string
		give int
		want int
	}{
		{"absent takes the default", 0, flowrundomain.MatrixDefaultRecentN},
		{"negative takes the default", -5, flowrundomain.MatrixDefaultRecentN},
		{"over the cap clamps", 999, flowrundomain.MatrixMaxRecentN},
		{"under the cap is honoured", 5, 5},
	} {
		t.Run(tc.name, func(t *testing.T) {
			repo := &recorderRepo{}
			svc := &Service{runs: repo}
			if _, err := svc.RunMatrix(ctx, flowrundomain.MatrixQuery{WorkflowID: "wf_1", RecentN: tc.give}); err != nil {
				t.Fatalf("RunMatrix: %v", err)
			}
			if repo.lastMatrix.RecentN != tc.want {
				t.Fatalf("recentN: store got %d want %d", repo.lastMatrix.RecentN, tc.want)
			}
		})
	}
}

// SweepRunRetention hands the cutoff straight through and loops bounded batches until a short one
// says the line is clear — the batch loop is the app's, the transaction is the store's.
// SweepRunRetention 把 cutoff 直接透传、并循环有界批次直到某个短批宣告线已清干净——批循环归 app、事务归 store。
func TestSweepRunRetention_LoopsBatchesUntilClear(t *testing.T) {
	repo := &recorderRepo{purgeReturns: []int{flowrundomain.RetentionBatchSize, flowrundomain.RetentionBatchSize, 7}}
	svc := &Service{runs: repo}
	cutoff := time.Date(2026, 4, 17, 12, 0, 0, 0, time.UTC)

	n, err := svc.SweepRunRetention(ctxWS("ws_1"), cutoff)
	if err != nil {
		t.Fatalf("SweepRunRetention: %v", err)
	}
	if want := 2*flowrundomain.RetentionBatchSize + 7; n != want {
		t.Fatalf("purged: got %d want %d", n, want)
	}
	if repo.purgeCalls != 3 {
		t.Fatalf("a short batch must end the loop: got %d calls want 3", repo.purgeCalls)
	}
	if !repo.lastCutoff.Equal(cutoff) {
		t.Fatalf("cutoff must pass through verbatim: got %v want %v", repo.lastCutoff, cutoff)
	}
	if repo.lastBatch != flowrundomain.RetentionBatchSize {
		t.Fatalf("batch: got %d want %d", repo.lastBatch, flowrundomain.RetentionBatchSize)
	}
}

// Nothing over the line touches the store exactly once and reports zero — idempotence at the app
// layer. 线上无物：恰好碰一次 store 并报 0——app 层的幂等。
func TestSweepRunRetention_NothingToPurge(t *testing.T) {
	repo := &recorderRepo{purgeReturns: []int{0}}
	svc := &Service{runs: repo}
	n, err := svc.SweepRunRetention(ctxWS("ws_1"), time.Now().UTC())
	if err != nil {
		t.Fatalf("SweepRunRetention: %v", err)
	}
	if n != 0 || repo.purgeCalls != 1 {
		t.Fatalf("empty sweep: purged=%d calls=%d want 0/1", n, repo.purgeCalls)
	}
}

// A cancelled ctx (shutdown) stops the sweep at a BATCH BOUNDARY — committed batches stay committed
// and the next tick resumes. It must never start another batch after the signal.
// 被取消的 ctx（关停）在**批边界**停下清理——已提交的批保持提交、下个 tick 续。信号之后它绝不能再起一批。
func TestSweepRunRetention_StopsAtBatchBoundaryOnCancel(t *testing.T) {
	repo := &recorderRepo{purgeReturns: []int{flowrundomain.RetentionBatchSize, flowrundomain.RetentionBatchSize}}
	svc := &Service{runs: repo}
	ctx, cancel := context.WithCancel(ctxWS("ws_1"))
	cancel()
	if _, err := svc.SweepRunRetention(ctx, time.Now().UTC()); !errors.Is(err, context.Canceled) {
		t.Fatalf("a cancelled sweep must report context.Canceled, got %v", err)
	}
	if repo.purgeCalls != 0 {
		t.Fatalf("no batch may start after cancellation: got %d calls", repo.purgeCalls)
	}
}
