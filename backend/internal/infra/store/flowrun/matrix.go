// matrix.go implements flowrundomain.Repository.RunMatrix — the node×run status grid (scheduler
// 工单⑩) feeding the operations page's third face (S5 AnRunMatrix). TWO bounded queries, never
// N+1: ① the workflow's last RecentN runs on the existing idx_fr_ws_workflow (workspace_id,
// workflow_id, started_at DESC, id DESC — exactly this ORDER BY/LIMIT), ② every node row of those
// runs in ONE `flowrun_id IN (…)` on idx_frn_run. Zero schema change.
//
// ② takes the raw-read escape hatch + manual workspace scoping (the stats.go idiom) for ONE
// load-bearing reason: the orm row mapping would hydrate FlowRunNode.Result — the memoized result
// blob of every node of 20 runs (the 650KB-per-node payloads F168-M7 exists to keep off the wire).
// The grid needs five scalar columns; raw SELECT takes only those. ① stays on the orm (20 header
// rows, auto workspace isolation, pinned_refs is a small map).
//
// Row/cell ordering and the iteration aggregation are done in Go, not SQL: the ordering key is
// COALESCE(started_at, ready_at, created_at) over columns of MIXED precision (⑫ ADD COLUMN rows vs
// legacy), which SQLite would compare as TEXT and mis-order at the sub-second margins — the same
// trap stats.go answers with julianday(). Parsed time.Time comparison in Go has no such margin, and
// the batch is bounded (≤20 runs) so it costs nothing.
//
// matrix.go 实现 flowrundomain.Repository.RunMatrix——节点×run 状态格阵（scheduler 工单⑩），喂运营主页
// 第三脸（S5 AnRunMatrix）。**两条**有界查询、绝不 N+1：① 该 workflow 近 RecentN 个 run，走既有
// idx_fr_ws_workflow（workspace_id, workflow_id, started_at DESC, id DESC——正是本 ORDER BY/LIMIT）；
// ② 这批 run 的全部节点行，一条 `flowrun_id IN (…)` 走 idx_frn_run。零 schema 变更。
//
// ② 走原始读逃生口 + 手动 workspace 隔离（stats.go 惯用形），只为一个**承重**理由：orm 行映射会水合
// FlowRunNode.Result——20 个 run 每个节点的记忆化 result blob（F168-M7 正是为把这类 650KB 载荷挡在线缆外
// 而存在）。格阵只要五个标量列；raw SELECT 就只取这五个。① 留在 orm 上（20 行头、自动 workspace 隔离、
// pinned_refs 是小 map）。
//
// 行/格排序与迭代聚合在 Go 里做、不在 SQL：排序键是 COALESCE(started_at, ready_at, created_at)，跨的是
// **精度混杂**的列（⑫ ADD COLUMN 的行 vs 旧行），SQLite 会按 TEXT 比较、在亚秒边缘错序——正是 stats.go
// 用 julianday() 解的那个坑。Go 里解析成 time.Time 比较没有这个边缘，且批是有界的（≤20 run）、不花钱。
package flowrun

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"strings"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// matrixNode is one flowrun_nodes row reduced to what the grid needs, plus its ordering key.
//
// matrixNode 是一条 flowrun_nodes 行削到格阵所需，外加它的排序键。
type matrixNode struct {
	runID     string
	nodeID    string
	kind      string
	status    string
	id        string
	iteration int
	order     time.Time
}

// nodeStatusRank ranks a node row's disposition for the per-cell aggregation: the WORST across a
// loop's iterations wins the cell (failed > parked > completed). See MatrixCell's contract.
//
// nodeStatusRank 给节点行的处置定档，供逐格聚合：loop 各迭代中**最坏**的赢得该格（failed > parked >
// completed）。契约见 MatrixCell。
func nodeStatusRank(status string) int {
	switch status {
	case flowrundomain.NodeFailed:
		return 3
	case flowrundomain.NodeParked:
		return 2
	default: // completed
		return 1
	}
}

func (s *Store) RunMatrix(ctx context.Context, q flowrundomain.MatrixQuery) (*flowrundomain.Matrix, error) {
	out := &flowrundomain.Matrix{
		Cols:  []*flowrundomain.MatrixCol{},
		Rows:  []*flowrundomain.MatrixRow{},
		Cells: []*flowrundomain.MatrixCell{},
	}

	// ① Columns: the workflow's last RecentN runs, newest→oldest — the same (started_at, id) order
	// every run list renders, so a column and its row in the big table are the same run at the same
	// position. orm path: auto workspace isolation, and idx_fr_ws_workflow covers it.
	// ① 列：该 workflow 近 RecentN 个 run，新→旧——与所有 run 列表同一 (started_at, id) 序，故一列与它
	// 在大表里的行是同位的同一个 run。orm 路：自动 workspace 隔离，idx_fr_ws_workflow 覆盖。
	runs, err := s.runs.WhereEq("workflow_id", q.WorkflowID).Order("started_at DESC, id DESC").Limit(q.RecentN).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunMatrix cols: %w", err)
	}
	if len(runs) == 0 {
		return out, nil
	}
	idArgs := make([]any, 0, len(runs))
	for _, r := range runs {
		col := &flowrundomain.MatrixCol{FlowRunID: r.ID, StartedAt: r.StartedAt, Status: r.Status}
		if r.CompletedAt != nil {
			ms := r.CompletedAt.Sub(r.StartedAt).Milliseconds()
			col.ElapsedMs = &ms
		}
		out.Cols = append(out.Cols, col)
		idArgs = append(idArgs, r.ID)
	}

	// ② Cells: every node row of those runs in ONE query. Five scalar columns + the three stamps the
	// ordering key coalesces — deliberately NOT result/error (see the package note).
	// ② 格：这批 run 的全部节点行，一条查询取完。五个标量列 + 排序键 coalesce 的三个戳——刻意**不取**
	// result/error（见包注释）。
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	in := "(" + strings.TrimSuffix(strings.Repeat("?, ", len(idArgs)), ", ") + ")"
	args := append([]any{wsID}, idArgs...)
	rows, err := s.db.Query(ctx, `
		SELECT flowrun_id, node_id, iteration, kind, status, id, started_at, ready_at, created_at
		FROM flowrun_nodes
		WHERE workspace_id = ? AND flowrun_id IN `+in, args...)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunMatrix cells: %w", err)
	}
	defer rows.Close()

	byRun := make(map[string][]matrixNode, len(runs))
	for rows.Next() {
		var (
			n                    matrixNode
			startedRaw, readyRaw sql.NullTime
			createdAt            time.Time
		)
		if err := rows.Scan(&n.runID, &n.nodeID, &n.iteration, &n.kind, &n.status, &n.id, &startedRaw, &readyRaw, &createdAt); err != nil {
			return nil, fmt.Errorf("flowrunstore.RunMatrix cells scan: %w", err)
		}
		// Execution order, best available: started_at (the engine began processing this turn) →
		// ready_at (it was queued) → created_at (the record-once write). The seed trigger row has
		// neither stamp (it never queued — written at run creation) and lands first via created_at,
		// which is exactly right; pre-⑫ rows have neither either and fall back to completion order.
		// 执行序，取最好的可得：started_at（引擎开始处理这一轮）→ ready_at（它排上队）→ created_at
		// （record-once 写入）。seed trigger 行两个戳都没有（它从不排队——run 创建时即写），靠 created_at
		// 落在最前，正确；⑫ 前旧行也两戳皆无、回落成完成序。
		switch {
		case startedRaw.Valid:
			n.order = startedRaw.Time.UTC()
		case readyRaw.Valid:
			n.order = readyRaw.Time.UTC()
		default:
			n.order = createdAt.UTC()
		}
		byRun[n.runID] = append(byRun[n.runID], n)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("flowrunstore.RunMatrix cells rows: %w", err)
	}

	// Walk the columns newest→oldest; within a run, execution order. First appearance of a node id
	// mints its row (and stamps the row's kind from that newest occurrence); each (run, node)'s
	// iterations collapse into one cell at the node's first position in that run.
	// 扫列新→旧；每个 run 内按执行序。node id 首次出现即铸一行（kind 取自这最新一次出现）；每个
	// (run, 节点) 的各迭代坍缩成一格、落在该节点在该 run 内的首现位置。
	seenRow := make(map[string]bool)
	for _, col := range out.Cols {
		nodes := byRun[col.FlowRunID]
		sort.Slice(nodes, func(i, j int) bool {
			if !nodes[i].order.Equal(nodes[j].order) {
				return nodes[i].order.Before(nodes[j].order)
			}
			return nodes[i].id < nodes[j].id
		})
		order := make([]string, 0, len(nodes))
		cells := make(map[string]*flowrundomain.MatrixCell, len(nodes))
		ranks := make(map[string]int, len(nodes))
		for _, n := range nodes {
			if !seenRow[n.nodeID] {
				seenRow[n.nodeID] = true
				out.Rows = append(out.Rows, &flowrundomain.MatrixRow{NodeID: n.nodeID, Kind: n.kind})
			}
			cell, ok := cells[n.nodeID]
			if !ok {
				order = append(order, n.nodeID)
				cells[n.nodeID] = &flowrundomain.MatrixCell{
					FlowRunID: col.FlowRunID, NodeID: n.nodeID, Status: n.status,
					Iteration: n.iteration, Iterations: 1,
				}
				ranks[n.nodeID] = nodeStatusRank(n.status)
				continue
			}
			cell.Iterations++
			// >= so a tie within a rank goes to the LATEST iteration (nodes is in execution order).
			// >= 使同档相持取**最新**迭代（nodes 已是执行序）。
			if r := nodeStatusRank(n.status); r >= ranks[n.nodeID] {
				ranks[n.nodeID] = r
				cell.Status = n.status
				cell.Iteration = n.iteration
			}
		}
		for _, nodeID := range order {
			out.Cells = append(out.Cells, cells[nodeID])
		}
	}
	return out, nil
}
