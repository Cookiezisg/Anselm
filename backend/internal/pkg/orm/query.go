package orm

import (
	"fmt"
	"strings"
)

// Query[T] is a chainable builder for table T. Every chain method returns the
// same *Query[T], so calls compose; state only accumulates — nothing hits the
// DB until a terminal method (First/Find/Count/.../Update/Delete) runs.
//
// Query[T] 是表 T 的链式构建器。每个链式方法返回同一 *Query[T]，调用可组合；
// 只累积状态——直到终结方法（First/Find/Count/…/Update/Delete）才碰 DB。
type Query[T any] struct {
	db       *DB
	meta     *tableMeta
	table    string
	conds    []cond
	order    string
	limit    int
	offset   int
	unscoped bool
	crossWS  bool
	keyset   *column // keyset-pagination time column; nil → Page defaults to the created column
}

// cond is one WHERE fragment plus its args; fragments join with AND.
//
// cond 是一个 WHERE 片段及其参数；片段间以 AND 连接。
type cond struct {
	expr string
	args []any
}

// Where adds a raw AND condition, e.g. Where("provider = ?", p). Express OR with
// a raw fragment: Where("(a = ? OR b = ?)", x, y).
//
// Where 加一个原始 AND 条件。OR 用原始片段表达：Where("(a = ? OR b = ?)", x, y)。
func (q *Query[T]) Where(expr string, args ...any) *Query[T] {
	q.conds = append(q.conds, cond{expr: expr, args: args})
	return q
}

// WhereEq adds `col = ?`.
//
// WhereEq 加 `col = ?`。
func (q *Query[T]) WhereEq(col string, val any) *Query[T] {
	return q.Where(col+" = ?", val)
}

// WhereIn adds `col IN (?, …)`. Empty vals compile to a never-match guard
// (avoids invalid `IN ()`).
//
// WhereIn 加 `col IN (?, …)`。空 vals 编译成永假条件（避免非法 `IN ()`）。
func (q *Query[T]) WhereIn(col string, vals ...any) *Query[T] {
	if len(vals) == 0 {
		return q.Where("1 = 0")
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?, ", len(vals)), ", ")
	return q.Where(col+" IN ("+placeholders+")", vals...)
}

// WhereNull adds `col IS NULL`.
//
// WhereNull 加 `col IS NULL`。
func (q *Query[T]) WhereNull(col string) *Query[T] { return q.Where(col + " IS NULL") }

// WhereNotNull adds `col IS NOT NULL`.
//
// WhereNotNull 加 `col IS NOT NULL`。
func (q *Query[T]) WhereNotNull(col string) *Query[T] { return q.Where(col + " IS NOT NULL") }

// WhereLike adds a case-insensitive substring match `col LIKE '%term%'`, escaping the term's
// LIKE metacharacters so a user's literal % or _ never acts as a wildcard. A blank/whitespace
// term is a no-op — callers pass raw filter input and an empty search means "no filter".
//
// WhereLike 加大小写不敏感子串匹配 `col LIKE '%term%'`，转义 term 的 LIKE 元字符，使用户字面的
// % 或 _ 绝不当通配符。空/纯空白 term 为 no-op——调用方直接传原始 filter 输入，空搜索即「不过滤」。
func (q *Query[T]) WhereLike(col, term string) *Query[T] {
	term = strings.TrimSpace(term)
	if term == "" {
		return q
	}
	// SQLite LIKE is ASCII case-insensitive; ESCAPE '\' lets the escaped % _ match literally.
	// SQLite LIKE 对 ASCII 大小写不敏感；ESCAPE '\' 让被转义的 % _ 字面匹配。
	return q.Where(col+" LIKE ? ESCAPE '\\'", "%"+likeEscaper.Replace(term)+"%")
}

// likeEscaper escapes SQL LIKE metacharacters for use under `ESCAPE '\'`. Backslash first
// (it is the escape char itself), then the two wildcards.
//
// likeEscaper 转义 SQL LIKE 元字符以配合 `ESCAPE '\'`。先反斜杠（转义字符本身），再两个通配符。
var likeEscaper = strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)

// Order sets the ORDER BY clause (without the keyword), replacing any prior one.
//
// Order 设置 ORDER BY 子句（不含关键字），替换之前的。
func (q *Query[T]) Order(clause string) *Query[T] { q.order = clause; return q }

// PageKeyset overrides the keyset column Page/PageAsc key their cursor on (default = the created
// column). The named column must exist on the table — a time.Time when paginated by Page (time, DESC),
// or a string when paginated by PageAsc (string, ASC). Use it when the list's ORDER BY sorts by a
// non-default column (e.g. conversations by last_message_at, or by title for sort=name) so the keyset
// cursor's WHERE and next-cursor encode track the SAME column as the sort — otherwise pages
// skip/duplicate rows. A missing column name is a programming error (panics, like meta config errors).
//
// PageKeyset 覆盖 Page/PageAsc 游标所键的列（默认 created 列）。列须存在——经 Page（时间、降序）时为 time.Time、
// 经 PageAsc（字符串、升序）时为字符串。当列表 ORDER BY 按非默认列排序（如 conversations 按 last_message_at、或
// sort=name 按 title）时用它，使游标 WHERE 与下一页 encode 跟同一列对齐——否则跨页漏/重行。列名写错 panic。
func (q *Query[T]) PageKeyset(col string) *Query[T] {
	for i := range q.meta.cols {
		if q.meta.cols[i].name == col {
			q.keyset = &q.meta.cols[i]
			return q
		}
	}
	panic(fmt.Sprintf("orm: PageKeyset column %q not found on %s", col, q.table))
}

// Limit caps the row count (<= 0 means no limit).
//
// Limit 限制行数（<= 0 表示不限）。
func (q *Query[T]) Limit(n int) *Query[T] { q.limit = n; return q }

// Offset skips n rows.
//
// Offset 跳过 n 行。
func (q *Query[T]) Offset(n int) *Query[T] { q.offset = n; return q }

// Unscoped includes soft-deleted rows (skips the auto `deleted_at IS NULL`).
//
// Unscoped 包含软删除行（跳过自动 `deleted_at IS NULL`）。
func (q *Query[T]) Unscoped() *Query[T] { q.unscoped = true; return q }

// CrossWorkspace skips the auto workspace_id filter — system-level queries only.
//
// CrossWorkspace 跳过自动 workspace_id 过滤——仅限系统级查询。
func (q *Query[T]) CrossWorkspace() *Query[T] { q.crossWS = true; return q }
