package db

import (
	"context"
	"fmt"

	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
)

// Migrate applies schema DDL statements in order, inside one transaction. Every
// statement must be idempotent (CREATE TABLE/INDEX/TRIGGER IF NOT EXISTS) so
// Migrate is safe to run on every startup. The gateway holds no schema itself —
// each module's store exports its DDL and bootstrap collects + passes it here.
//
// Migrate 在单个事务内按序应用 schema DDL。每条须幂等（CREATE … IF NOT EXISTS），
// 故每次启动跑都安全。网关本身不持 schema——各模块 store 导出自己的 DDL，由
// bootstrap 汇总后传入。
func Migrate(db *ormpkg.DB, stmts ...string) error {
	if db == nil {
		return fmt.Errorf("db: migrate: nil db")
	}
	ctx := context.Background()
	return db.Transaction(ctx, func(tx *ormpkg.DB) error {
		for i, stmt := range stmts {
			if _, err := tx.Exec(ctx, stmt); err != nil {
				return fmt.Errorf("db: migrate stmt #%d: %w", i, err)
			}
		}
		return nil
	})
}
