// retention.go owns the run-history retention sweep (scheduler 工单⑬, 判决④): the batch loop that
// enforces one workspace's retention line. The caller ticks it per workspace (the bootstrap
// retentionLoop, the CheckTimeouts / SweepMisfires convention) and owns the "how old is too old"
// policy — this service only knows "purge finished runs that reached their terminal before T".
//
// retention.go 拥有 run 历史保留清理（scheduler 工单⑬、判决④）：执行**一个** workspace 保留线的批循环。
// 调用方逐 workspace tick 它（bootstrap 的 retentionLoop，CheckTimeouts / SweepMisfires 惯例）并拥有
// 「多老算太老」的策略——本 service 只知道「清掉在 T 之前落定的终态 run」。
package scheduler

import (
	"context"
	"fmt"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// SweepRunRetention physically purges every finished run of the ctx's workspace that reached its
// terminal before cutoff, in bounded batches, and returns how many runs went (for the caller's log
// and for tests — the SweepMisfires signature family). Idempotent: a second call finds nothing.
//
// running / parked runs are never purged, however old — an in-flight run is not history yet, and a
// run awaiting a human is a live obligation (the inbox must never lose an item to a clock).
//
// Batching is what keeps a 90-day backlog from freezing the app on a single-connection SQLite: each
// batch is its own short transaction, and ctx is checked BETWEEN batches so shutdown interrupts the
// sweep at a batch boundary — every committed batch stays committed (nothing to roll back), and the
// next tick resumes where this left off.
//
// SweepRunRetention 物理清掉 ctx 所属 workspace 中所有在 cutoff 前落定的终态 run，分批进行，返回清掉多少个
// run（供调用方记日志与测试用——SweepMisfires 签名家族）。幂等：再调一次什么也找不到。
//
// running / parked 的 run 永不清，不管多老——在飞的 run 还不是历史，等人的 run 是**活的义务**（收件箱绝不
// 能因为一个时钟丢掉一项）。
//
// 分批正是让 90 天的积压不冻住单连接 SQLite 的关键：每批是自己的短事务，且**批与批之间**查 ctx，故关停在批
// 边界打断清理——已提交的批保持提交（无可回滚），下个 tick 从这里续。
func (s *Service) SweepRunRetention(ctx context.Context, cutoff time.Time) (int, error) {
	total := 0
	for {
		if err := ctx.Err(); err != nil {
			return total, err
		}
		n, err := s.runs.PurgeTerminalRunsBefore(ctx, cutoff, flowrundomain.RetentionBatchSize)
		if err != nil {
			return total, fmt.Errorf("schedulerapp.SweepRunRetention: %w", err)
		}
		total += n
		// A short batch means the line is clear. A batch that purged FEWER headers than it collected
		// (a :replay reopened one mid-sweep and the delete's terminal guard let it live) also stops
		// here — correctly: the sweep yields to the user, and the next tick re-checks.
		// 短批 = 线已清干净。清掉的头比收集的少的批（清理途中一次 :replay 重开了某个 run、删除的终态守卫
		// 放它活）也在此停——正确：清理让位给用户，下个 tick 再查。
		if n < flowrundomain.RetentionBatchSize {
			return total, nil
		}
	}
}
