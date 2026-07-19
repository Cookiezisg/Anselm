package db

import (
	"context"
	"fmt"
	"strings"

	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Migrate applies schema DDL statements in order, inside one transaction. Every
// statement must be idempotent (CREATE TABLE/INDEX/TRIGGER IF NOT EXISTS) so
// Migrate is safe to run on every startup. The gateway holds no schema itself —
// each module's store exports its DDL and bootstrap collects + passes it here.
//
// Column evolution: SQLite has no ADD COLUMN IF NOT EXISTS, so an additive
// `ALTER TABLE … ADD COLUMN` is idempotent BY OUTCOME — its "duplicate column
// name" error is the already-applied signal and is skipped, never surfaced.
// Any other error on any statement still fails the whole migration.
//
// Migrate 在单个事务内按序应用 schema DDL。每条须幂等（CREATE … IF NOT EXISTS），
// 故每次启动跑都安全。网关本身不持 schema——各模块 store 导出自己的 DDL，由
// bootstrap 汇总后传入。
//
// 列演化：SQLite 无 ADD COLUMN IF NOT EXISTS，加列的 `ALTER TABLE … ADD COLUMN`
// 靠**结果幂等**——它的 "duplicate column name" 错误即「已应用」信号，跳过不冒泡。
// 任何语句的其他错误仍令整个迁移失败。
func Migrate(db *ormpkg.DB, stmts ...string) error {
	if db == nil {
		return fmt.Errorf("db: migrate: nil db")
	}
	ctx := context.Background()
	return db.Transaction(ctx, func(tx *ormpkg.DB) error {
		for i, stmt := range stmts {
			if _, err := tx.Exec(ctx, stmt); err != nil {
				if isAddColumnApplied(stmt, err) {
					continue
				}
				return fmt.Errorf("db: migrate stmt #%d: %w", i, err)
			}
		}
		return nil
	})
}

// isAddColumnApplied reports whether err is the "duplicate column name" outcome of an additive
// ALTER TABLE … ADD COLUMN — i.e. the column already exists and the statement is a no-op re-run.
// Guarded on the statement text so a genuine duplicate-column error from any other DDL still fails.
//
// isAddColumnApplied 判断 err 是否加列 ALTER TABLE … ADD COLUMN 的 "duplicate column name" 结果——
// 即列已存在、本条是重复执行的 no-op。以语句文本守卫，其他 DDL 的真重复列错误仍失败。
func isAddColumnApplied(stmt string, err error) bool {
	s := strings.ToUpper(stmt)
	return strings.Contains(s, "ALTER TABLE") && strings.Contains(s, "ADD COLUMN") &&
		strings.Contains(err.Error(), "duplicate column name")
}
