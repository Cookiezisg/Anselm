// Package voice is the orm-backed implementation of voicedomain.Repository plus the voices DDL.
// Rows are hard-deleted: a row is a pointer to an upstream registration, and a soft-deleted pointer
// would keep occupying its unique name while addressing a voice the user believes is gone.
//
// Package voice 是 voicedomain.Repository 的 orm 实现 + voices 表 DDL。行**硬删**:一行是指向上游
// 登记的指针,而一个软删的指针会继续占着它那个唯一名、同时指向一个用户以为已经没了的音色。
package voice

import (
	"context"
	"errors"
	"fmt"

	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Schema is the voices DDL. The UNIQUE index is the physical enforcement of "one name, one upstream
// registration": without it a second enrollment under the same name would orphan the first one
// upstream, where nothing local can reach it again.
//
// Schema 是 voices 表 DDL。UNIQUE 索引是「一名一登记」的物理执行:少了它,同名的第二次登记会让第一次
// 在上游变成孤儿,而本地再没有东西够得着它。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS voices (
		id                   TEXT PRIMARY KEY,
		workspace_id         TEXT NOT NULL,
		name                 TEXT NOT NULL,
		provider             TEXT NOT NULL,
		upstream_id          TEXT NOT NULL,
		source_attachment_id TEXT NOT NULL DEFAULT '',
		created_at           DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_voice_name ON voices(workspace_id, name)`,
}

// Store implements voicedomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 voicedomain.Repository。
type Store struct {
	repo *ormpkg.Repo[voicedomain.Voice]
}

// New builds a Store bound to the voices table.
//
// New 构造绑定 voices 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[voicedomain.Voice](db, "voices")}
}

var _ voicedomain.Repository = (*Store)(nil)

// Create inserts one voice, translating the unique-name collision into the domain's own error so
// callers never have to read a driver string.
//
// Create 插入一个音色,把唯一名冲突翻译成 domain 自己的错误,使调用方永远不必去读驱动的字符串。
func (s *Store) Create(ctx context.Context, v *voicedomain.Voice) error {
	if err := s.repo.Create(ctx, v); err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			return voicedomain.ErrNameTaken
		}
		return fmt.Errorf("voicestore.Create: %w", err)
	}
	return nil
}

// List returns every voice in the workspace, newest first.
//
// List 返回本 workspace 的全部音色,新的在前。
func (s *Store) List(ctx context.Context) ([]*voicedomain.Voice, error) {
	out, err := s.repo.Order("created_at DESC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("voicestore.List: %w", err)
	}
	return out, nil
}

// GetByName resolves the user-facing name to the row (hence to the upstream id).
//
// GetByName 把用户可见的名字解析成行(从而解析成上游 id)。
func (s *Store) GetByName(ctx context.Context, name string) (*voicedomain.Voice, error) {
	v, err := s.repo.WhereEq("name", name).First(ctx)
	if err != nil {
		if errors.Is(err, ormpkg.ErrNotFound) {
			return nil, voicedomain.ErrNotFound
		}
		return nil, fmt.Errorf("voicestore.GetByName: %w", err)
	}
	return v, nil
}

// Delete removes the row. The caller deletes UPSTREAM FIRST — a row removed while its registration
// survives is a voice nobody can see or reclaim.
//
// Delete 删行。调用方**先删上游**——登记还活着而行没了,那是一个谁也看不见、谁也收不回的音色。
func (s *Store) Delete(ctx context.Context, id string) error {
	ok, err := s.repo.Delete(ctx, id)
	if err != nil {
		return fmt.Errorf("voicestore.Delete: %w", err)
	}
	if !ok {
		return voicedomain.ErrNotFound
	}
	return nil
}
