package orm

import (
	"errors"
	"testing"
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
