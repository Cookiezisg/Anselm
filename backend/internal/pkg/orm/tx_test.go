package orm

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestTransaction_Commit(t *testing.T) {
	db, ctx := newTestDB(t)
	err := db.Transaction(ctx, func(tx *DB) error {
		return For[widget](tx, "widgets").Create(ctx, &widget{ID: "w_1", Name: "x"})
	})
	if err != nil {
		t.Fatalf("tx: %v", err)
	}
	if _, err := widgets(db).Get(ctx, "w_1"); err != nil {
		t.Errorf("committed row should exist: %v", err)
	}
}

func TestTransaction_Rollback(t *testing.T) {
	db, ctx := newTestDB(t)
	boom := errors.New("boom")
	err := db.Transaction(ctx, func(tx *DB) error {
		if err := For[widget](tx, "widgets").Create(ctx, &widget{ID: "w_1", Name: "x"}); err != nil {
			return err
		}
		return boom
	})
	if !errors.Is(err, boom) {
		t.Errorf("tx err = %v, want boom", err)
	}
	if _, err := widgets(db).Get(ctx, "w_1"); !errors.Is(err, ErrNotFound) {
		t.Errorf("rolled-back row should be gone, err=%v", err)
	}
}

// TestTransaction_PanicRollsBackAndFreesConnection is the T7 (WRK-070) bricking guard, run on the
// exact bricking arm: a real SQLite pool pinned to ONE connection (newTestDB) and a NON-cancellable
// ctx (Background + workspace value — the reqctx.Detached shape). A panic inside fn must (a)
// propagate — never be swallowed, (b) roll the tx back, and (c) release the pool's only connection,
// or every later DB call in the process blocks forever. The deadline on the follow-up read turns
// "bricked" into a red test instead of a hung one.
//
// TestTransaction_PanicRollsBackAndFreesConnection 是 T7（WRK-070）砖化守卫，跑在精确的砖化臂上：
// 真 SQLite 池钉死单连接（newTestDB）+ **不可取消** ctx（Background + workspace 值——正是
// reqctx.Detached 的形状）。fn 里 panic 必须 (a) 照常上抛——绝不吞，(b) 事务回滚，(c) 释放池中唯一
// 连接，否则此后进程里每次 DB 调用永久阻塞。后续读挂 deadline，把「砖化」变成红灯而非挂死的测试。
func TestTransaction_PanicRollsBackAndFreesConnection(t *testing.T) {
	db, ctx := newTestDB(t)
	func() {
		defer func() {
			if r := recover(); r != "boom" {
				t.Fatalf("recovered %v, want the original panic value to propagate", r)
			}
		}()
		_ = db.Transaction(ctx, func(tx *DB) error {
			if err := For[widget](tx, "widgets").Create(ctx, &widget{ID: "w_1", Name: "x"}); err != nil {
				return err
			}
			panic("boom")
		})
		t.Fatal("Transaction swallowed the panic")
	}()
	// The only connection must be free again AND the write rolled back. Without the defer
	// rollback this Get blocks until the deadline (context deadline exceeded), not ErrNotFound.
	// 唯一连接必须已释放**且**写入已回滚。没有 defer 回滚，这个 Get 会阻塞到 deadline
	// （context deadline exceeded），而非 ErrNotFound。
	qctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	if _, err := widgets(db).Get(qctx, "w_1"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("after panicked tx: err=%v, want ErrNotFound (connection freed + rolled back)", err)
	}
	// And a fresh transaction on the same connection still commits.
	// 且同一连接上新事务照常提交。
	if err := db.Transaction(ctx, func(tx *DB) error {
		return For[widget](tx, "widgets").Create(ctx, &widget{ID: "w_2", Name: "y"})
	}); err != nil {
		t.Fatalf("tx after panic: %v", err)
	}
	if _, err := widgets(db).Get(ctx, "w_2"); err != nil {
		t.Errorf("row from post-panic tx should exist: %v", err)
	}
}
