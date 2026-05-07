// block_v2.go — GORM-backed BlockV2Repository implementation. Owns
// the message_blocks_v2 table (Phase 1 coexists with legacy
// message_blocks; Phase 4 cutover renames + drops legacy).
//
// User scoping: BlockV2 has no user_id column — auth lives on the
// parent Message row. Methods do NOT filter by ctx user; callers that
// need user scoping should resolve through Message.Get first. This is
// pragmatic for Phase 1 (single user; emitter writes are server-side
// trusted). Phase 5 will revisit.
//
// block_v2.go ——BlockV2Repository 的 GORM 实现。拥有 message_blocks_v2
// 表（Phase 1 与 legacy message_blocks 共存；Phase 4 cutover 重命名 + 删
// legacy）。
//
// 用户过滤：BlockV2 无 user_id 列——auth 在父 Message 行上。方法不按 ctx
// 用户过滤；要求用户过滤的调用方先经 Message.Get 解析。Phase 1 务实选择
// （单用户；emitter 写是 server-side 可信）。Phase 5 复审。
package chat

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
)

// BlockV2Store is the GORM-backed implementation of
// chatdomain.BlockV2Repository.
//
// BlockV2Store 是 chatdomain.BlockV2Repository 的 GORM 实现。
type BlockV2Store struct {
	db *gorm.DB
}

// NewBlockV2Store constructs a BlockV2Store bound to db.
//
// NewBlockV2Store 基于 db 构造 BlockV2Store。
func NewBlockV2Store(db *gorm.DB) *BlockV2Store {
	return &BlockV2Store{db: db}
}

// Save inserts the row, or replaces it on PK conflict (used at
// block_start with status=streaming, then again at block_stop with
// terminal status). CreatedAt is preserved on conflict; UpdatedAt is
// always written.
//
// Save 插入行，PK 冲突时替换（block_start 用 status=streaming 写一次，
// block_stop 用终态再写一次）。冲突时 CreatedAt 保留；UpdatedAt 总写。
func (s *BlockV2Store) Save(ctx context.Context, b *chatdomain.BlockV2) error {
	if b.CreatedAt.IsZero() {
		b.CreatedAt = time.Now().UTC()
	}
	b.UpdatedAt = time.Now().UTC()
	err := s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "id"}},
		DoUpdates: clause.AssignmentColumns([]string{
			"content", "status", "error", "attrs", "updated_at",
		}),
	}).Create(b).Error
	if err != nil {
		return fmt.Errorf("chatstore.BlockV2.Save: %w", err)
	}
	return nil
}

// AppendDelta atomically appends delta via SQL string-concat. Avoids
// read-modify-write race when many DeltaBlock emits arrive
// concurrently (rare in practice — a single chat loop publishes per
// conversation — but the cost is one short SQL statement).
//
// AppendDelta 经 SQL 字符串拼接原子追加 delta。避免 DeltaBlock 并发到
// 达时的 read-modify-write 竞争（实践中罕见——单 chat loop per 对话——
// 但代价仅一条短 SQL）。
func (s *BlockV2Store) AppendDelta(ctx context.Context, blockID, delta string) error {
	res := s.db.WithContext(ctx).
		Model(&chatdomain.BlockV2{}).
		Where("id = ?", blockID).
		Updates(map[string]any{
			"content":    gorm.Expr("content || ?", delta),
			"updated_at": time.Now().UTC(),
		})
	if res.Error != nil {
		return fmt.Errorf("chatstore.BlockV2.AppendDelta: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return chatdomain.ErrBlockNotFound
	}
	return nil
}

// FinalizeStop updates status + error on blockID. Returns
// ErrBlockNotFound if the row doesn't exist.
//
// FinalizeStop 给 blockID 更新 status + error。行不存在返 ErrBlockNotFound。
func (s *BlockV2Store) FinalizeStop(ctx context.Context, blockID, status, errStr string) error {
	res := s.db.WithContext(ctx).
		Model(&chatdomain.BlockV2{}).
		Where("id = ?", blockID).
		Updates(map[string]any{
			"status":     status,
			"error":      errStr,
			"updated_at": time.Now().UTC(),
		})
	if res.Error != nil {
		return fmt.Errorf("chatstore.BlockV2.FinalizeStop: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return chatdomain.ErrBlockNotFound
	}
	return nil
}

// GetByID returns blockID's row. ErrBlockNotFound when absent.
//
// GetByID 返 blockID 的行。缺失返 ErrBlockNotFound。
func (s *BlockV2Store) GetByID(ctx context.Context, blockID string) (*chatdomain.BlockV2, error) {
	var b chatdomain.BlockV2
	err := s.db.WithContext(ctx).Where("id = ?", blockID).First(&b).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, chatdomain.ErrBlockNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("chatstore.BlockV2.GetByID: %w", err)
	}
	return &b, nil
}

// ListByConversation returns all blocks of conversationID, seq ASC.
//
// ListByConversation 返 conversationID 的所有 block，seq ASC。
func (s *BlockV2Store) ListByConversation(ctx context.Context, conversationID string) ([]*chatdomain.BlockV2, error) {
	var rows []*chatdomain.BlockV2
	err := s.db.WithContext(ctx).
		Where("conversation_id = ?", conversationID).
		Order("seq ASC").
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("chatstore.BlockV2.ListByConversation: %w", err)
	}
	return rows, nil
}

// ListByMessage returns all blocks of messageID, seq ASC.
//
// ListByMessage 返 messageID 的所有 block，seq ASC。
func (s *BlockV2Store) ListByMessage(ctx context.Context, messageID string) ([]*chatdomain.BlockV2, error) {
	var rows []*chatdomain.BlockV2
	err := s.db.WithContext(ctx).
		Where("message_id = ?", messageID).
		Order("seq ASC").
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("chatstore.BlockV2.ListByMessage: %w", err)
	}
	return rows, nil
}

// ReplayEventsAfter reconstructs the block-event stream from DB rows.
// See chatdomain.BlockV2Repository.ReplayEventsAfter for contract.
//
// ReplayEventsAfter 从 DB 行重构 block 事件流。契约见
// chatdomain.BlockV2Repository.ReplayEventsAfter。
func (s *BlockV2Store) ReplayEventsAfter(ctx context.Context, conversationID string, fromSeq int64) ([]chatdomain.ReplayEnvelope, error) {
	var rows []*chatdomain.BlockV2
	err := s.db.WithContext(ctx).
		Where("conversation_id = ? AND seq > ?", conversationID, fromSeq).
		Order("seq ASC").
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("chatstore.BlockV2.ReplayEventsAfter: %w", err)
	}

	out := make([]chatdomain.ReplayEnvelope, 0, len(rows)*3)
	for _, b := range rows {
		var attrs map[string]any
		if b.Attrs != "" {
			_ = json.Unmarshal([]byte(b.Attrs), &attrs)
		}

		// Reconstruct ParentID for the wire: empty parent_block_id in DB
		// means "top-level block of the message" → wire ParentID = MessageID.
		// Non-empty → wire ParentID = parent_block_id (nested case).
		//
		// 从 DB 重构 wire ParentID：parent_block_id 空 = 顶层 → wire
		// ParentID = MessageID；非空 = 嵌套 → wire ParentID = parent_block_id。
		parentID := b.ParentBlockID
		if parentID == "" {
			parentID = b.MessageID
		}

		// block_start
		out = append(out, chatdomain.ReplayEnvelope{
			Type: "block_start",
			Seq:  b.Seq,
			Payload: map[string]any{
				"conversationId": conversationID,
				"id":             b.ID,
				"parentId":       parentID,
				"messageId":      b.MessageID,
				"blockType":      b.Type,
				"attrs":          attrs,
			},
		})

		// block_delta (single delta carries full content)
		if b.Content != "" {
			out = append(out, chatdomain.ReplayEnvelope{
				Type: "block_delta",
				Seq:  b.Seq,
				Payload: map[string]any{
					"conversationId": conversationID,
					"id":             b.ID,
					"delta":          b.Content,
				},
			})
		}

		// block_stop
		stopPayload := map[string]any{
			"conversationId": conversationID,
			"id":             b.ID,
			"status":         b.Status,
		}
		if b.Error != "" {
			stopPayload["error"] = b.Error
		}
		out = append(out, chatdomain.ReplayEnvelope{
			Type:    "block_stop",
			Seq:     b.Seq,
			Payload: stopPayload,
		})
	}
	return out, nil
}

// Compile-time check.
//
// 编译期检查。
var _ chatdomain.BlockV2Repository = (*BlockV2Store)(nil)
