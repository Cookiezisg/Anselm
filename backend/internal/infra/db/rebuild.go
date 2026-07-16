package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// MigrateRebuild rebuilds `table` when its LIVE DDL (sqlite_master) lacks `marker` — the
// idempotent-by-outcome escape hatch for schema changes SQLite has no ALTER for (a CHECK gaining
// a word, first use: trigger_firings status += 'missed', scheduler 工单⑨). CREATE TABLE IF NOT
// EXISTS never touches an existing table, so an install predating the change keeps the old CHECK
// forever; this inspects the stored DDL and, only while the marker is absent, runs the caller's
// rebuild statements (new table → copy → drop → rename → recreate indexes) in one transaction.
// A fresh install (Migrate already created the table with the current DDL) and every
// post-rebuild boot read the marker and no-op. A missing table is a no-op too (callers run this
// AFTER Migrate, so absence means a test schema that doesn't include the table at all).
//
// MigrateRebuild 在 `table` 的**现行** DDL（sqlite_master）缺少 `marker` 时重建它——SQLite 没有
// 对应 ALTER 的 schema 变更（CHECK 加词，首用：trigger_firings status += 'missed'，scheduler
// 工单⑨）的**结果幂等**逃生口。CREATE TABLE IF NOT EXISTS 永不碰已存在的表，旧安装的旧 CHECK
// 会永远留着；本函数检查落库 DDL，仅当标记词缺席才在单事务内跑调用方给的重建语句（建新表→拷贝→
// 删旧→改名→重建索引）。全新安装（Migrate 已按当前 DDL 建表）与重建后的每次启动读到标记词即
// no-op。表不存在同样 no-op（调用方在 Migrate **之后**跑，缺表意味着测试 schema 根本不含它）。
func MigrateRebuild(db *ormpkg.DB, table, marker string, stmts ...string) error {
	if db == nil {
		return fmt.Errorf("db: migrate-rebuild: nil db")
	}
	ctx := context.Background()
	var ddl string
	err := db.QueryRow(ctx, `SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?`, table).Scan(&ddl)
	if errors.Is(err, sql.ErrNoRows) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("db: migrate-rebuild %s: read ddl: %w", table, err)
	}
	if strings.Contains(ddl, marker) {
		return nil // already on the current shape. 已是当前形状。
	}
	return db.Transaction(ctx, func(tx *ormpkg.DB) error {
		for i, stmt := range stmts {
			if _, err := tx.Exec(ctx, stmt); err != nil {
				return fmt.Errorf("db: migrate-rebuild %s stmt #%d: %w", table, i, err)
			}
		}
		return nil
	})
}
