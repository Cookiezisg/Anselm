// queries.go — Service read / control APIs that don't mutate sub-run
// state. Currently just Cancel; extracted as a separate file so future
// query helpers (e.g. ListActive, GetRunByID once we plumb a chat
// query) have an obvious home.
//
// queries.go ——不动 sub-run 状态的 Service 读 / 控制 API。当前仅 Cancel；
// 单独成文件让未来的查询 helper（例如 ListActive、GetRunByID 等）有
// 明确归属。
package subagent

import "context"

// Cancel preempts a running sub-run via its registered cancel func.
// No-op when the run isn't found (already terminated or never spawned —
// the race with finish is benign).
//
// Cancel 通过注册的 cancel func 抢占运行中的 sub-run。run 找不到时
// 空操作（已终止或没起过——与 finish 竞态无害）。
func (s *Service) Cancel(_ context.Context, runID string) error {
	s.activeRunsMu.Lock()
	cancel, ok := s.activeRuns[runID]
	s.activeRunsMu.Unlock()
	if !ok {
		return nil
	}
	cancel()
	return nil
}
