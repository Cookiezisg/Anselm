package orm

import "context"

// Repo[T] is a typed handle to one table. A store holds a Repo and either calls
// its by-pk conveniences (Get/Create/Save/Delete) or starts a chain through
// Query() (or the Where*/Order/... shorthands). T must be a struct whose fields
// carry `db:"col,..."` tags, including exactly one `,pk`.
//
// Repo[T] 是某张表的类型化句柄。store 持有它，调 by-pk 便利方法（Get/Create/Save/Delete），
// 或经 Query()（及 Where*/Order/… 简写）起链。T 须是带 `db` tag 的 struct，含且仅含一个 `,pk`。
type Repo[T any] struct {
	db    *DB
	meta  *tableMeta
	table string
}

// For builds a Repo[T] bound to db + table; T's db tags are reflected once and cached.
//
// For 构造绑定 db + table 的 Repo[T]；T 的 db tag 反射一次并缓存。
func For[T any](db *DB, table string) *Repo[T] {
	return &Repo[T]{db: db, meta: metaOf[T](), table: table}
}

// Query starts a fresh chainable builder on this table — use it for a query with
// no leading condition, e.g. r.Query().Count(ctx) or r.Query().Page(ctx, ...).
// The Where*/Order/... methods below are shorthands that also start a chain.
//
// Query 在该表上起一条新链——用于没有前置条件的查询，如 r.Query().Count(ctx)。
// 下面的 Where*/Order/… 是同样起链的简写。
func (r *Repo[T]) Query() *Query[T] {
	return &Query[T]{db: r.db, meta: r.meta, table: r.table}
}

// ---- chain entry shorthands: each starts a fresh Query ----
// ---- 链式入口简写：各起一条新 Query ----

func (r *Repo[T]) Where(expr string, args ...any) *Query[T]  { return r.Query().Where(expr, args...) }
func (r *Repo[T]) WhereEq(col string, val any) *Query[T]     { return r.Query().WhereEq(col, val) }
func (r *Repo[T]) WhereIn(col string, vals ...any) *Query[T] { return r.Query().WhereIn(col, vals...) }
func (r *Repo[T]) WhereNull(col string) *Query[T]            { return r.Query().WhereNull(col) }
func (r *Repo[T]) WhereNotNull(col string) *Query[T]         { return r.Query().WhereNotNull(col) }
func (r *Repo[T]) Order(clause string) *Query[T]             { return r.Query().Order(clause) }
func (r *Repo[T]) Limit(n int) *Query[T]                     { return r.Query().Limit(n) }
func (r *Repo[T]) Offset(n int) *Query[T]                    { return r.Query().Offset(n) }
func (r *Repo[T]) Unscoped() *Query[T]                       { return r.Query().Unscoped() }
func (r *Repo[T]) CrossWorkspace() *Query[T]                 { return r.Query().CrossWorkspace() }

// Get fetches one row by primary key (auto workspace + non-deleted); ErrNotFound if none.
//
// Get 按主键取一行（自动 workspace + 非删除）；无则 ErrNotFound。
func (r *Repo[T]) Get(ctx context.Context, id any) (*T, error) {
	return r.Query().WhereEq(r.meta.pk.name, id).First(ctx)
}
