package orm

import (
	"context"
	"fmt"
	"strings"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// whereClause assembles the full WHERE: auto workspace isolation + auto
// soft-delete filter + the user's accumulated conditions, all AND-joined.
// Returns ("", nil, nil) when there is nothing to filter. Errors only when a
// workspace-scoped table is queried without a workspace id in ctx.
//
// whereClause 拼出完整 WHERE：自动 workspace 隔离 + 自动软删除过滤 + 用户累积条件，
// 全部 AND 连接。无可过滤时返 ("", nil, nil)。仅当按 workspace 隔离的表在缺 workspace
// 的 ctx 下查询时返错。
func (q *Query[T]) whereClause(ctx context.Context) (string, []any, error) {
	var exprs []string
	var args []any

	// Auto workspace isolation — the safety net that replaces hand-written
	// `WHERE workspace_id = ?` in every store method.
	// 自动 workspace 隔离——取代每个 store 方法手写的 `WHERE workspace_id = ?`。
	if q.meta.ws != nil && !q.crossWS {
		ws, err := reqctxpkg.RequireWorkspaceID(ctx)
		if err != nil {
			return "", nil, err
		}
		exprs = append(exprs, q.meta.ws.name+" = ?")
		args = append(args, ws)
	}

	// Auto soft-delete filter.
	// 自动软删除过滤。
	if q.meta.deleted != nil && !q.unscoped {
		exprs = append(exprs, q.meta.deleted.name+" IS NULL")
	}

	for _, c := range q.conds {
		exprs = append(exprs, c.expr)
		args = append(args, c.args...)
	}

	if len(exprs) == 0 {
		return "", nil, nil
	}
	return " WHERE " + strings.Join(exprs, " AND "), args, nil
}

// buildSelect compiles the query into a SELECT statement and its args.
//
// buildSelect 把查询编译成 SELECT 语句及其参数。
func (q *Query[T]) buildSelect(ctx context.Context) (string, []any, error) {
	cols := q.meta.columnNames()
	where, args, err := q.whereClause(ctx)
	if err != nil {
		return "", nil, err
	}

	var b strings.Builder
	fmt.Fprintf(&b, "SELECT %s FROM %s", strings.Join(cols, ", "), q.table)
	b.WriteString(where)
	if q.order != "" {
		b.WriteString(" ORDER BY ")
		b.WriteString(q.order)
	}
	if q.limit > 0 {
		fmt.Fprintf(&b, " LIMIT %d", q.limit)
	}
	if q.offset > 0 {
		fmt.Fprintf(&b, " OFFSET %d", q.offset)
	}
	return b.String(), args, nil
}
