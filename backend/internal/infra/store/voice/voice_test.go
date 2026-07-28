package voice

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) (*Store, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB)), reqctxpkg.SetWorkspaceID(context.Background(), "ws_1111111111111111")
}

func voice(name, upstream string) *voicedomain.Voice {
	return &voicedomain.Voice{
		ID: idgenpkg.New("vce"), Name: name, Provider: "qwen",
		UpstreamID: upstream, CreatedAt: time.Now().UTC(),
	}
}

// TestCreate_DuplicateNameIsTheDomainError, not a driver string: a second enrollment under one name
// would ORPHAN the first registration upstream, where nothing local can address it again. The
// caller has to be able to tell that case apart to say "delete it first" — so the store translates
// the UNIQUE violation instead of leaking it.
//
// TestCreate_DuplicateNameIsTheDomainError:同名的第二次登记会让第一次在上游变成**孤儿**,而本地再没有
// 东西够得着它。调用方必须分得出这一种情况才说得出「先删掉它」——故 store **翻译** UNIQUE 违例,而不是
// 把驱动的字符串漏出去。
func TestCreate_DuplicateNameIsTheDomainError(t *testing.T) {
	s, ctx := newStore(t)
	if err := s.Create(ctx, voice("narrator", "up_1")); err != nil {
		t.Fatalf("first create: %v", err)
	}
	err := s.Create(ctx, voice("narrator", "up_2"))
	if !errors.Is(err, voicedomain.ErrNameTaken) {
		t.Fatalf("second create err = %v, want ErrNameTaken", err)
	}
}

// TestGetByName_ResolvesToTheUpstreamID — the row's whole job. Losing this lookup strands the
// upstream registration, because the id it holds is the only handle anything has on it.
//
// TestGetByName_ResolvesToTheUpstreamID——行的全部职责。丢了这次查找,上游那个登记就搁浅了,因为它持有
// 的 id 是任何东西对它的唯一把手。
func TestGetByName_ResolvesToTheUpstreamID(t *testing.T) {
	s, ctx := newStore(t)
	if err := s.Create(ctx, voice("narrator", "qwen-voice-abc")); err != nil {
		t.Fatalf("create: %v", err)
	}
	got, err := s.GetByName(ctx, "narrator")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.UpstreamID != "qwen-voice-abc" {
		t.Fatalf("upstream id = %q, want qwen-voice-abc", got.UpstreamID)
	}
	if _, err := s.GetByName(ctx, "nobody"); !errors.Is(err, voicedomain.ErrNotFound) {
		t.Fatalf("missing name err = %v, want ErrNotFound", err)
	}
}

// TestNamesAreUniquePerWorkspace_NotGlobally: the uniqueness that protects against orphaning is
// per workspace, because that is the isolation axis everything else uses. Two workspaces both
// calling a voice "narrator" is not a collision — they are different voices upstream.
//
// TestNamesAreUniquePerWorkspace_NotGlobally:防孤儿的那个唯一性是**每 workspace** 的,因为那是其余
// 一切所用的隔离轴。两个 workspace 都把音色叫「narrator」不是冲突——它们在上游是**不同的音色**。
func TestNamesAreUniquePerWorkspace_NotGlobally(t *testing.T) {
	s, ctx := newStore(t)
	if err := s.Create(ctx, voice("narrator", "up_1")); err != nil {
		t.Fatalf("create: %v", err)
	}
	other := reqctxpkg.SetWorkspaceID(context.Background(), "ws_2222222222222222")
	if err := s.Create(other, voice("narrator", "up_2")); err != nil {
		t.Fatalf("another workspace must be free to use the same name: %v", err)
	}
	rows, err := s.List(other)
	if err != nil || len(rows) != 1 {
		t.Fatalf("list = %v (err %v), want exactly this workspace's one voice", rows, err)
	}
}

// TestDelete_MissingRowIsNotFound: the caller deletes upstream first and the row second, so a
// second delete arriving on a gone row must be distinguishable from a write failure.
//
// TestDelete_MissingRowIsNotFound:调用方先删上游、后删行,故第二次删落在已消失的行上时,必须与「写
// 失败」区分得开。
func TestDelete_MissingRowIsNotFound(t *testing.T) {
	s, ctx := newStore(t)
	v := voice("narrator", "up_1")
	if err := s.Create(ctx, v); err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := s.Delete(ctx, v.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if err := s.Delete(ctx, v.ID); !errors.Is(err, voicedomain.ErrNotFound) {
		t.Fatalf("second delete err = %v, want ErrNotFound", err)
	}
	// And the name is free again — a hard delete, not a soft one holding the unique slot.
	// 而名字又空出来了——**硬删**,不是一个还占着唯一位的软删。
	if err := s.Create(ctx, voice("narrator", "up_2")); err != nil {
		t.Fatalf("the name must be reusable after deletion: %v", err)
	}
}
