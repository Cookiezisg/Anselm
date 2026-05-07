// block_repo.go — BlockV2Repository port for Phase 1. Coexists with the
// legacy Repository (which still owns Save/Get/List for messages +
// legacy Block) until the Phase 4 cutover, after which BlockV2 paths
// fold into Repository and this file goes away.
//
// block_repo.go ——Phase 1 的 BlockV2Repository port。在 Phase 4 cutover 前
// 与 legacy Repository（仍管 messages + legacy Block 的 Save/Get/List）共
// 存；cutover 后 BlockV2 路径并入 Repository，本文件删除。
package chat

import "context"

// BlockV2Repository is the persistence port for the new event-log
// blocks. The chat-loop dual-writer (Phase 2) calls Save / AppendDelta
// / FinalizeStop alongside the eventlog Bridge so DB and SSE never
// disagree.
//
// BlockV2Repository 是新事件日志 block 的持久化 port。chat-loop 的
// dual-writer（Phase 2）与 eventlog Bridge 同步调 Save / AppendDelta /
// FinalizeStop，避免 DB 与 SSE 分叉。
type BlockV2Repository interface {
	// Save inserts (or overwrites) the row by primary key. Used at
	// block_start emit (status=streaming, content="") and at block_stop
	// emit (status=completed/error/cancelled). Concurrent appends to
	// content are owned by AppendDelta.
	//
	// Save 按主键插入（或覆盖）行。block_start emit 时调（status=streaming
	// content=""）和 block_stop emit 时调（status=completed/error/cancelled）。
	// 对 content 的并发追加由 AppendDelta 拥有。
	Save(ctx context.Context, b *BlockV2) error

	// AppendDelta atomically appends delta to blockID's content.
	// Returns ErrBlockNotFound if blockID does not exist.
	//
	// AppendDelta 原子地把 delta 追加到 blockID 的 content。
	// blockID 不存在时返 ErrBlockNotFound。
	AppendDelta(ctx context.Context, blockID, delta string) error

	// FinalizeStop sets status + error on blockID. Convenience wrapper
	// around Save that callers use at block_stop without rebuilding the
	// full BlockV2 struct.
	//
	// FinalizeStop 给 blockID 设 status + error。调用方在 block_stop 时
	// 用，免去重建完整 BlockV2 struct。
	FinalizeStop(ctx context.Context, blockID, status, errStr string) error

	// GetByID returns blockID's row. ErrBlockNotFound when absent.
	//
	// GetByID 返 blockID 的行。缺失返 ErrBlockNotFound。
	GetByID(ctx context.Context, blockID string) (*BlockV2, error)

	// ListByConversation returns all live blocks of conversationID
	// ordered by seq ASC. Used for history replay (DB → events → UI).
	// Phase 5 will add cursor pagination once we see how big real
	// conversations get; for Phase 1 a simple list is fine since
	// conversations are bounded (~hundreds of events typical).
	//
	// ListByConversation 返 conversationID 的所有 live block，按 seq ASC
	// 排序。给历史回放用（DB → events → UI）。Phase 5 视真实对话规模
	// 加 cursor 分页；Phase 1 简单列表够用（典型 ~百条）。
	ListByConversation(ctx context.Context, conversationID string) ([]*BlockV2, error)

	// ListByMessage returns all blocks belonging to messageID, ordered
	// by seq ASC. Useful for rendering a single message's full block
	// tree without fetching the entire conversation.
	//
	// ListByMessage 返 messageID 的所有 block，按 seq ASC 排序。
	// 渲染单条 message 的完整 block 树时用，不需要拉整个对话。
	ListByMessage(ctx context.Context, messageID string) ([]*BlockV2, error)
}
