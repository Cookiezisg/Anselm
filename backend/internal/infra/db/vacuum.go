// vacuum.go owns disk-space reclamation. SQLite's DELETE only moves pages to the freelist — it never
// returns bytes to the filesystem, so run-history retention (PurgeTerminalRunsBefore) deletes real
// rows yet the .db file does not shrink one byte (auto_vacuum defaults to NONE). This gateway runs
// the DB in auto_vacuum=INCREMENTAL and reclaims the freed pages after a retention sweep, so the
// storage panel's "Run history retention" actually frees disk instead of being a paper promise.
//
// NOT a D1 physical-delete carve-out: neither VACUUM nor incremental_vacuum deletes a logical row —
// they only hand already-freed pages back to the OS. The row deletion is PurgeTerminalRunsBefore
// (carve-out #2, legislated in database.md); this is pure space reclamation and needs no legislation.
//
// vacuum.go 拥有磁盘空间回收。SQLite 的 DELETE 只把页移到 freelist——绝不把字节还给文件系统，故 run 历史
// 保留清理（PurgeTerminalRunsBefore）删了真行、.db 文件却一字节不缩（auto_vacuum 默认 NONE）。本网关让 DB
// 跑在 auto_vacuum=INCREMENTAL，并在保留清理后回收腾出的页，使存储面板的「Run 历史保留」真正腾磁盘、而非
// 一纸空头承诺。
//
// **不是 D1 物理删例外**：VACUUM 与 incremental_vacuum 都不删任何逻辑行——它们只把**已经腾空**的页还给 OS。
// 删行的是 PurgeTerminalRunsBefore（例外②，立法在 database.md）；这里是纯空间回收、无需立法。
package db

import (
	"context"
	"fmt"

	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// autoVacuumIncremental is the PRAGMA auto_vacuum value for INCREMENTAL mode (0=NONE, 1=FULL, 2=
// INCREMENTAL). We pick INCREMENTAL over FULL deliberately: FULL reclaims on EVERY commit (a standing
// per-write cost on this high-frequency single-writer app), whereas INCREMENTAL only tracks freed
// pages in the pointer map and reclaims them when we explicitly ask — right after a retention sweep,
// off the request path. This is SQLite's recommended pattern for reclaim-on-a-schedule.
//
// autoVacuumIncremental 是 PRAGMA auto_vacuum 的 INCREMENTAL 值（0=NONE/1=FULL/2=INCREMENTAL）。刻意选
// INCREMENTAL 而非 FULL：FULL 每次 commit 都回收（对这个高频单写者 app 是常驻的每写开销），而 INCREMENTAL
// 只在指针图里记下腾空的页、等我们显式索要时才回收——恰在保留清理后、离开请求路径。这是 SQLite 官方推荐的
// 「按计划回收」模式。
const autoVacuumIncremental = 2

// reclaimMinDeadFraction / reclaimMinDeadBytes gate steady-state reclamation. The freelist is a
// RATCHET, not a leak: in steady operation new runs REUSE the pages retention frees, so reclaiming
// on every 6h sweep would just thrash the file down and back up. We reclaim only when dead space is
// genuinely worth returning — either a large fraction of the file (a small DB gone mostly empty) or
// a large absolute chunk (a big DB after the user tightens the retention line, the one scenario that
// motivated this whole fix). Routine churn clears neither gate.
//
// reclaimMinDeadFraction / reclaimMinDeadBytes 给稳态回收设闸。freelist 是**棘轮**、非泄漏：稳态里新 run
// **复用**保留清理腾出的页，故每 6h 清理都回收只会把文件缩下去又涨回来空折腾。只在死空间真正值得归还时才回收
// ——要么占文件很大比例（小库大半空了）、要么绝对量很大（大库在用户**收紧保留线**后，正是催生本次修复的场景）。
// 日常 churn 两道闸都过不了。
const (
	reclaimMinDeadFraction = 0.25
	reclaimMinDeadBytes    = 128 << 20 // 128 MiB
)

// EnsureIncrementalAutoVacuum brings a file DB into auto_vacuum=INCREMENTAL. A fresh install is born
// there (buildDSN lists auto_vacuum FIRST, before journal_mode initializes the header — the ONLY
// ordering the glebarez driver honours), so this no-ops. An install predating this change carries
// auto_vacuum=NONE in its header, which PRAGMA alone cannot flip: the mode change only takes effect
// after a full VACUUM that rewrites the file with the pointer map. That one-time VACUUM ALSO reclaims
// the dead space such an install has been accumulating — the user-visible fix for a retention line
// that never freed disk. Idempotent by outcome: once the header reads INCREMENTAL, every later boot
// skips without touching the DB.
//
// Best-effort by contract: VACUUM needs roughly the DB's size in free scratch space, which the very
// disk-full user this fixes may lack — so a failure is returned for the caller to log-and-continue,
// never to fail boot. The next boot retries.
//
// EnsureIncrementalAutoVacuum 把文件库带进 auto_vacuum=INCREMENTAL。全新安装天生就在那儿（buildDSN 把
// auto_vacuum 排在**最前**、在 journal_mode 初始化文件头之前——glebarez 驱动唯一认的顺序），故此处 no-op。
// 本次改动之前的安装文件头里带 auto_vacuum=NONE，光靠 PRAGMA 翻不动：模式变更只在一次**用指针图重写整个文件
// 的全量 VACUUM** 之后生效。那一次性 VACUUM **同时**回收这类安装一直在攒的死空间——正是「保留线从不腾磁盘」的
// 用户可感修复。结果幂等：文件头一旦读作 INCREMENTAL，此后每次 boot 碰都不碰 DB 就跳过。
//
// 契约上尽力而为：VACUUM 需要约等于库大小的空闲临时空间，而本修复面向的磁盘将满的用户恰恰可能没有——故失败
// 会返回给调用方记日志后继续、**绝不**令 boot 失败。下次 boot 重试。
func EnsureIncrementalAutoVacuum(ctx context.Context, db *ormpkg.DB) (migrated bool, reclaimedBytes int64, err error) {
	mode, err := pragmaInt(ctx, db, "auto_vacuum")
	if err != nil {
		return false, 0, err
	}
	if mode == autoVacuumIncremental {
		return false, 0, nil // born or already migrated. 天生或已迁移。
	}
	before, err := dbBytes(ctx, db)
	if err != nil {
		return false, 0, err
	}
	// The mode change is inert until a VACUUM rewrites the file. VACUUM cannot run inside a
	// transaction — Exec runs directly on the pool (never wrapped), so this is safe.
	// 模式变更在 VACUUM 重写文件前是死的。VACUUM 不能在事务里跑——Exec 直接跑在池上（从不裹事务），故安全。
	if _, err := db.Exec(ctx, `PRAGMA auto_vacuum = INCREMENTAL`); err != nil {
		return false, 0, fmt.Errorf("db: set auto_vacuum incremental: %w", err)
	}
	if _, err := db.Exec(ctx, `VACUUM`); err != nil {
		return false, 0, fmt.Errorf("db: vacuum for auto_vacuum migration: %w", err)
	}
	if err := checkpointTruncate(ctx, db); err != nil {
		return false, 0, err
	}
	mode, err = pragmaInt(ctx, db, "auto_vacuum")
	if err != nil {
		return false, 0, err
	}
	if mode != autoVacuumIncremental {
		return false, 0, fmt.Errorf("db: auto_vacuum still %d after VACUUM migration", mode)
	}
	after, err := dbBytes(ctx, db)
	if err != nil {
		return false, 0, err
	}
	return true, before - after, nil
}

// ReclaimFreePages returns the DB's freed pages to the filesystem after a retention sweep, when the
// dead space clears the reclaim gate. It checkpoints the WAL first (deletes land in the WAL, and the
// freelist / incremental_vacuum operate on the main file — without this, reclaim measures and frees
// nothing, the ledger's instrument-accident #5), then drains incremental_vacuum, then truncates the
// WAL again so the shrunk file lands on disk. Returns bytes reclaimed (0 when the gate is not met).
//
// Interruptible: the drain checks ctx per page, so shutdown stops it at a page boundary exactly like
// the retention batch loop — no straggler holds the single connection past the shutdown grace.
//
// ReclaimFreePages 在保留清理后、当死空间越过回收闸时，把 DB 腾空的页还给文件系统。它先 checkpoint WAL（删
// 落在 WAL 里，而 freelist / incremental_vacuum 作用于主文件——没有它，回收量到零、什么也不腾，台账的仪器事故
// #5），再 drain incremental_vacuum，再 truncate 一次 WAL 使缩小的文件落盘。返回回收字节数（未过闸时为 0）。
//
// 可打断：drain 逐页查 ctx，故关停在页边界停下、与保留批循环一模一样——没有掉队者把唯一连接攥过关停宽限。
func ReclaimFreePages(ctx context.Context, db *ormpkg.DB) (reclaimedBytes int64, err error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	mode, err := pragmaInt(ctx, db, "auto_vacuum")
	if err != nil {
		return 0, err
	}
	if mode != autoVacuumIncremental {
		// The one-time migration hasn't succeeded yet (e.g. a disk-full boot). incremental_vacuum is a
		// no-op without the pointer map, so there is nothing to do until a later boot migrates.
		// 一次性迁移还没成功（如磁盘将满时 boot）。没有指针图 incremental_vacuum 是 no-op，等后续 boot 迁移前无事可做。
		return 0, nil
	}
	if err := checkpointTruncate(ctx, db); err != nil {
		return 0, err
	}
	free, err := pragmaInt(ctx, db, "freelist_count")
	if err != nil {
		return 0, err
	}
	pageCount, err := pragmaInt(ctx, db, "page_count")
	if err != nil {
		return 0, err
	}
	pageSize, err := pragmaInt(ctx, db, "page_size")
	if err != nil {
		return 0, err
	}
	deadBytes := free * pageSize
	if float64(free) < reclaimMinDeadFraction*float64(pageCount) && deadBytes < reclaimMinDeadBytes {
		return 0, nil // routine churn — reusing these pages is cheaper than reclaiming them. 日常 churn——复用比回收更省。
	}
	before := pageCount * pageSize

	// Drain via Query, NOT Exec: with the glebarez/modernc driver Exec steps `PRAGMA incremental_vacuum`
	// exactly ONCE (frees ONE page) because it does not drain the pragma's per-page result rows —
	// measured. Iterating rows.Next() to completion frees every page. Checking ctx per page keeps the
	// hold on the single connection interruptible at shutdown.
	// 用 Query 而非 Exec drain：glebarez/modernc 驱动下 Exec 对 `PRAGMA incremental_vacuum` 只 step **一次**
	// （腾**一页**），因为它不 drain 该 pragma 的逐页结果行——实测。遍历 rows.Next() 到底才腾光每一页。逐页查
	// ctx 使对唯一连接的占用在关停时可打断。
	rows, err := db.Query(ctx, `PRAGMA incremental_vacuum`)
	if err != nil {
		return 0, fmt.Errorf("db: incremental_vacuum: %w", err)
	}
	for rows.Next() {
		if ctx.Err() != nil {
			break
		}
	}
	rerr := rows.Err()
	rows.Close()
	if rerr != nil {
		return 0, fmt.Errorf("db: incremental_vacuum drain: %w", rerr)
	}
	if err := checkpointTruncate(ctx, db); err != nil {
		return 0, err
	}
	after, err := dbBytes(ctx, db)
	if err != nil {
		return 0, err
	}
	return before - after, nil
}

// checkpointTruncate runs a TRUNCATE checkpoint, folding the WAL into the main file and shrinking the
// -wal back to zero. QueryRow (not Exec) so the single result row is read and the checkpoint is
// guaranteed to have run. A no-op on a non-WAL / :memory: DB (returns busy=0, log=-1).
//
// checkpointTruncate 跑 TRUNCATE checkpoint，把 WAL 折进主文件并把 -wal 缩回零。用 QueryRow（非 Exec）以读
// 走那一行结果、保证 checkpoint 真跑了。非 WAL / :memory: 库上是 no-op（返回 busy=0、log=-1）。
func checkpointTruncate(ctx context.Context, db *ormpkg.DB) error {
	var busy, logFrames, checkpointed int64
	if err := db.QueryRow(ctx, `PRAGMA wal_checkpoint(TRUNCATE)`).Scan(&busy, &logFrames, &checkpointed); err != nil {
		return fmt.Errorf("db: wal_checkpoint: %w", err)
	}
	return nil
}

// dbBytes is the DB's logical size in bytes (page_count × page_size). After a TRUNCATE checkpoint the
// -wal is empty, so this equals the .db file size — the number the storage panel reports.
//
// dbBytes 是 DB 的逻辑字节数（page_count × page_size）。TRUNCATE checkpoint 后 -wal 为空，故它等于 .db 文件
// 大小——存储面板报告的那个数。
func dbBytes(ctx context.Context, db *ormpkg.DB) (int64, error) {
	pageCount, err := pragmaInt(ctx, db, "page_count")
	if err != nil {
		return 0, err
	}
	pageSize, err := pragmaInt(ctx, db, "page_size")
	if err != nil {
		return 0, err
	}
	return pageCount * pageSize, nil
}

// pragmaInt reads a scalar integer PRAGMA. The name is a compile-time literal (PRAGMA names cannot be
// bound parameters), never user input.
//
// pragmaInt 读一个标量整型 PRAGMA。名字是编译期字面量（PRAGMA 名不能是绑定参数）、绝非用户输入。
func pragmaInt(ctx context.Context, db *ormpkg.DB, name string) (int64, error) {
	var v int64
	if err := db.QueryRow(ctx, "PRAGMA "+name).Scan(&v); err != nil {
		return 0, fmt.Errorf("db: pragma %s: %w", name, err)
	}
	return v, nil
}
