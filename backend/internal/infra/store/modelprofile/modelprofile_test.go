package modelprofile

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	profiledomain "github.com/sunweilin/anselm/backend/internal/domain/modelprofile"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = db.Close() })
	for _, stmt := range Schema {
		if _, err := db.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(db))
}

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

func profile(id, identityKey string, now time.Time) *profiledomain.Profile {
	return &profiledomain.Profile{
		ID: id, IdentityKey: identityKey, Provider: "custom", APIKeyID: "aki_1", ModelID: "x",
		RequestClass: profiledomain.RequestClassText, EndpointFingerprint: "ep", CredentialFingerprint: "cred",
		ConfigFingerprint: "cfg", LowestOverflowPredicted: 900_000, Overflows: 1, RecoveredOverflows: 1,
		ExpiresAt: now.Add(time.Hour), CreatedAt: now, UpdatedAt: now,
	}
}

func TestFindSaveWorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	now := time.Date(2026, 7, 24, 0, 0, 0, 0, time.UTC)
	p := profile("mpr_1", "route-sha", now)
	if err := s.Save(ctxWS("ws_1"), p); err != nil {
		t.Fatal(err)
	}
	got, found, err := s.Find(ctxWS("ws_1"), "route-sha")
	if err != nil || !found || got.ID != "mpr_1" || got.LowestOverflowPredicted != 900_000 {
		t.Fatalf("find = %+v, %v, %v", got, found, err)
	}
	if _, found, err := s.Find(ctxWS("ws_2"), "route-sha"); err != nil || found {
		t.Fatalf("workspace leak: found=%v err=%v", found, err)
	}

	got.Successes = 2
	got.UpdatedAt = now.Add(time.Minute)
	if err := s.Save(ctxWS("ws_1"), got); err != nil {
		t.Fatal(err)
	}
	got, found, err = s.Find(ctxWS("ws_1"), "route-sha")
	if err != nil || !found || got.Successes != 2 {
		t.Fatalf("update = %+v, %v, %v", got, found, err)
	}
}
