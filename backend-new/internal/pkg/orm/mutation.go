package orm

import (
	"context"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"time"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Create inserts v as a new row, stamping the created + updated columns.
//
// Create 将 v 作为新行插入，打上 created + updated 时间戳。
func (r *Repo[T]) Create(ctx context.Context, v *T) error {
	if err := r.applyWorkspace(ctx, v); err != nil {
		return err
	}
	r.stamp(v, true)
	cols := r.meta.columnNames()
	vals, err := columnValues(v, r.meta)
	if err != nil {
		return err
	}
	stmt := fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s)",
		r.table, strings.Join(cols, ", "), placeholders(len(cols)))
	if _, err := r.db.handle().ExecContext(ctx, stmt, vals...); err != nil {
		return fmt.Errorf("orm: create: %w", err)
	}
	return nil
}

// Save upserts v on the primary key (INSERT ... ON CONFLICT(pk) DO UPDATE). The
// created column is preserved on update (set only at first insert); updated is
// always bumped.
//
// Save 按主键 upsert（冲突则更新）。created 在更新时保留（仅首次插入设），updated 总刷新。
func (r *Repo[T]) Save(ctx context.Context, v *T) error {
	if err := r.applyWorkspace(ctx, v); err != nil {
		return err
	}
	r.stamp(v, false)
	cols := r.meta.columnNames()
	vals, err := columnValues(v, r.meta)
	if err != nil {
		return err
	}
	sets := make([]string, 0, len(r.meta.cols))
	for _, c := range r.meta.cols {
		if c.pk || c.created {
			continue
		}
		sets = append(sets, c.name+" = excluded."+c.name)
	}
	stmt := fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s) ON CONFLICT(%s) DO UPDATE SET %s",
		r.table, strings.Join(cols, ", "), placeholders(len(cols)), r.meta.pk.name, strings.Join(sets, ", "))
	if _, err := r.db.handle().ExecContext(ctx, stmt, vals...); err != nil {
		return fmt.Errorf("orm: save: %w", err)
	}
	return nil
}

// Delete soft-deletes one row by primary key; reports whether a row matched.
//
// Delete 按主键软删一行；返回是否命中。
func (r *Repo[T]) Delete(ctx context.Context, id any) (bool, error) {
	n, err := r.Query().WhereEq(r.meta.pk.name, id).Delete(ctx)
	return n > 0, err
}

// Update sets one column on every row matching the query's WHERE; returns rows affected.
//
// Update 给匹配 WHERE 的每行设一列；返回受影响行数。
func (q *Query[T]) Update(ctx context.Context, col string, val any) (int64, error) {
	return q.Updates(ctx, map[string]any{col: val})
}

// Updates sets multiple columns on matching rows; the updated column is bumped
// automatically. Returns rows affected.
//
// Updates 给匹配行设多列，自动刷新 updated 列。返回受影响行数。
func (q *Query[T]) Updates(ctx context.Context, fields map[string]any) (int64, error) {
	if len(fields) == 0 {
		return 0, nil
	}
	keys := make([]string, 0, len(fields))
	for k := range fields {
		keys = append(keys, k)
	}
	sort.Strings(keys) // stable SQL text → prepared-stmt cache friendly. 稳定 SQL → 利于 stmt 缓存。

	sets := make([]string, 0, len(keys)+1)
	args := make([]any, 0, len(keys)+1)
	for _, k := range keys {
		sets = append(sets, k+" = ?")
		args = append(args, fields[k])
	}
	if q.meta.updated != nil {
		sets = append(sets, q.meta.updated.name+" = ?")
		args = append(args, time.Now().UTC())
	}

	where, wargs, err := q.whereClause(ctx)
	if err != nil {
		return 0, err
	}
	args = append(args, wargs...)

	stmt := "UPDATE " + q.table + " SET " + strings.Join(sets, ", ") + where
	res, err := q.db.handle().ExecContext(ctx, stmt, args...)
	if err != nil {
		return 0, fmt.Errorf("orm: update: %w", err)
	}
	return res.RowsAffected()
}

// Delete removes rows matching the query's WHERE: soft (set deleted_at = now)
// when the table has a deleted column and the query is not Unscoped; otherwise
// a hard DELETE. Returns rows affected.
//
// Delete 删除匹配 WHERE 的行：有 deleted 列且未 Unscoped 时软删（设 deleted_at = now），
// 否则物理 DELETE。返回受影响行数。
func (q *Query[T]) Delete(ctx context.Context) (int64, error) {
	where, args, err := q.whereClause(ctx)
	if err != nil {
		return 0, err
	}
	var stmt string
	if q.meta.deleted != nil && !q.unscoped {
		stmt = "UPDATE " + q.table + " SET " + q.meta.deleted.name + " = ?" + where
		args = append([]any{time.Now().UTC()}, args...)
	} else {
		stmt = "DELETE FROM " + q.table + where
	}
	res, err := q.db.handle().ExecContext(ctx, stmt, args...)
	if err != nil {
		return 0, fmt.Errorf("orm: delete: %w", err)
	}
	return res.RowsAffected()
}

// stamp sets timestamp columns: on insert both created and updated are set to
// now; on save created is set only when still zero, updated always.
//
// stamp 设时间戳列：插入时 created+updated 均设为 now；save 时 created 仅在零值时设，updated 总设。
func (r *Repo[T]) stamp(v *T, isCreate bool) {
	now := time.Now().UTC()
	rv := reflect.ValueOf(v).Elem()
	if c := r.meta.created; c != nil {
		if cur, ok := rv.Field(c.index).Interface().(time.Time); ok && (isCreate || cur.IsZero()) {
			rv.Field(c.index).Set(reflect.ValueOf(now))
		}
	}
	if c := r.meta.updated; c != nil {
		if _, ok := rv.Field(c.index).Interface().(time.Time); ok {
			rv.Field(c.index).Set(reflect.ValueOf(now))
		}
	}
}

// applyWorkspace stamps the workspace column from ctx, so writes are isolated
// the same way reads are — the caller never has to set workspace_id by hand,
// and can never accidentally write into another workspace.
//
// applyWorkspace 从 ctx 写入 workspace 列，使写入与读取同样隔离——调用方无需手设
// workspace_id，也不可能误写进别的 workspace。
func (r *Repo[T]) applyWorkspace(ctx context.Context, v *T) error {
	if r.meta.ws == nil {
		return nil
	}
	ws, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return err
	}
	reflect.ValueOf(v).Elem().Field(r.meta.ws.index).SetString(ws)
	return nil
}

// placeholders returns "?, ?, ..." with n placeholders.
//
// placeholders 返回含 n 个 "?" 的占位串。
func placeholders(n int) string {
	if n <= 0 {
		return ""
	}
	return strings.TrimSuffix(strings.Repeat("?, ", n), ", ")
}
