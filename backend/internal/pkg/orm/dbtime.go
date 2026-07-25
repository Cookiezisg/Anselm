package orm

import (
	"fmt"
	"time"
)

// ParseDBTime normalizes whatever the SQLite driver hands back for a time value into a UTC time.Time.
//
// It exists because a raw read (db.Query — the escape hatch for GROUP BY / UNION / FILTER that the
// row-mapped CRUD cannot express) gets NO help from the driver's declared-type conversion: a plain column
// reference on a `DATETIME` column arrives as a time.Time, but the moment it sits inside an EXPRESSION —
// `MAX(last_message_at)`, a UNION branch, a CASE — the result has no declared type and arrives as TEXT.
// Every raw-read store then needs the same three-layout dance, which is exactly the boilerplate the
// foundation is supposed to own (设计原则 #8) rather than have each domain re-write.
//
// A NULL (no rows in the group / no completed run) is NOT an error: it answers with the zero time, and the
// caller decides what absence means. The layouts are ordered by what actually shows up in this database.
//
// ParseDBTime 把 SQLite 驱动交回来的任何时间值归一成 UTC 的 time.Time。
//
// 它存在，是因为**原始读**（db.Query——行映射 CRUD 表达不了的 GROUP BY / UNION / FILTER 的逃生口）拿不到
// 驱动的声明类型转换:对 `DATETIME` 列的**裸列引用**会作为 time.Time 回来，但它一旦坐进**表达式**里——
// `MAX(last_message_at)`、UNION 的一支、CASE——结果就没有声明类型、于是作为 TEXT 回来。每个走原始读的 store
// 于是都要跳同一支三种格式的舞，而那正是地基该拥有、而不该让各域各抄一遍的样板（设计原则 #8）。
//
// NULL（组内无行 / 无已完成的 run）**不是错误**:它答以零值时间，缺席意味着什么由调用方裁定。格式的顺序按
// 这个库里**实际**出现的先后排。
func ParseDBTime(v any) (time.Time, error) {
	switch t := v.(type) {
	case nil:
		return time.Time{}, nil
	case time.Time:
		return t.UTC(), nil
	case []byte:
		return ParseDBTime(string(t))
	case string:
		if t == "" {
			return time.Time{}, nil
		}
		for _, layout := range []string{
			"2006-01-02 15:04:05.999999999-07:00", // glebarez/go-sqlite write format. 驱动写入格式。
			"2006-01-02 15:04:05.999999999",       // naive legacy rows. 无时区旧行。
			time.RFC3339Nano,
		} {
			if ts, err := time.Parse(layout, t); err == nil {
				return ts.UTC(), nil
			}
		}
		return time.Time{}, fmt.Errorf("orm: unrecognized DATETIME text %q", t)
	default:
		return time.Time{}, fmt.Errorf("orm: unsupported DATETIME value of type %T", v)
	}
}
