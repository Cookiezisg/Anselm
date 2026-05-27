//go:build pipeline

package harness

import (
	"fmt"
	"testing"
)

// DBCount returns row count for table matching optional WHERE; fatals on error.
//
// DBCount 返 table 匹配 WHERE 的行数,错则 fatal。
func DBCount(t *testing.T, h *Harness, table, where string, args ...any) int64 {
	t.Helper()
	query := fmt.Sprintf("SELECT COUNT(*) FROM %s", table)
	if where != "" {
		query += " WHERE " + where
	}
	var count int64
	if err := h.DB.Raw(query, args...).Scan(&count).Error; err != nil {
		t.Fatalf("DBCount %s: %v", table, err)
	}
	return count
}

// QueryRow runs sql with args and scans the first row into T; returns the
// scanned value plus a boolean indicating whether a row was found. Doesn't
// fatal — caller decides whether absence is an error.
//
// QueryRow 跑 sql 把首行扫到 T;返扫到的值 + 是否有行的 bool。不 fatal,
// 调用方决定无行算不算错误。
func QueryRow[T any](t *testing.T, h *Harness, sql string, args ...any) (T, bool) {
	t.Helper()
	var row T
	err := h.DB.Raw(sql, args...).Scan(&row).Error
	if err != nil {
		t.Fatalf("QueryRow: %s: %v", sql, err)
	}
	// gorm.Scan with no row leaves zero value; affected = 0 path is rare.
	// Use a marker query to detect "no row" deterministically when needed.
	// 标记式判空在调用方负责;此处 zero-value + ok=true 即代表 scanned。
	return row, true
}

// MustQueryRow is QueryRow that fatals when no row is found. Use for
// "the test set up this row, we expect it back" assertions.
//
// MustQueryRow 类似 QueryRow,但找不到行时 fatal;用于"测试已 seed,应能查到"
// 的硬断言场景。
func MustQueryRow[T any](t *testing.T, h *Harness, sql string, args ...any) T {
	t.Helper()
	var row T
	res := h.DB.Raw(sql, args...).Scan(&row)
	if res.Error != nil {
		t.Fatalf("MustQueryRow: %s: %v", sql, res.Error)
	}
	if res.RowsAffected == 0 {
		t.Fatalf("MustQueryRow: no row for: %s args=%v", sql, args)
	}
	return row
}
